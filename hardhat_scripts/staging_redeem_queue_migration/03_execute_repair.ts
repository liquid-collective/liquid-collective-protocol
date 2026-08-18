import * as fs from "fs";
import hre from "hardhat";
import { ethers as EthersType } from "ethers";
import {
  CLEAN_IMPL_1_3_0,
  REDEEM_MANAGER,
  REDEEM_MANAGER_PROXY_ADMIN,
  redeemManagerAt,
  retry,
  withdrawalStackEnd,
  eth,
} from "./redeem_queue_repair";

// BS-4878: perform the redeem queue repair.
//
// One script for both the rehearsal and the real thing, so what gets tested is what gets run. The
// network only decides how the transaction is signed:
//
//   real hoodi (chainId 560048)  the configured PRIVATE_KEY, asserted to be the Firewall admin
//   anything else (a fork)       that same admin address, impersonated
//
// Either way the transaction goes to the ProxyFirewall and is forwarded to the proxy, so the fork
// exercises the identical path including the forwarding.
//
//   BS4878_STEP=pause|deploy|repair|restore|unpause   which step to run
//   BS4878_EXECUTE=1                                  actually send; default is print-only
//   BS4878_SEQUENCE=1                                 run every step in order; forks only
//   BS4878_RECOVERY=0x...                             the deployed recovery implementation
//   BS4878_CLAIM_CHECK=1                              after unpause, claim one request; forks only
//
// Print-only output is enough to submit from a Safe or hardware wallet instead.
//
// Steps are separate on purpose: the queue must be verified between `repair` and `restore`, and a
// half-finished sequence is easier to reason about when each transaction was a separate decision.

const REAL_HOODI = 560048;
const CALLDATA_FILE = "hardhat_scripts/staging_redeem_queue_migration/repair-calldata.txt";
// pause/unpause are no longer part of the sequence: repairRedeemQueue verifies the queue hash, so a
// claim landing mid-window makes it revert rather than silently replay stale amounts. They remain
// selectable via BS4878_STEP if you want to freeze anyway.
const STEPS = ["deploy", "repair", "restore"] as const;
const ALL_STEPS = ["pause", "deploy", "repair", "restore", "unpause"] as const;
type Step = (typeof ALL_STEPS)[number];

const PROXY_IFACE = new hre.ethers.utils.Interface([
  "function pause()",
  "function unpause()",
  "function paused() view returns (bool)",
  "function upgradeTo(address)",
  "function upgradeToAndCall(address,bytes)",
]);
const FIREWALL_IFACE = new hre.ethers.utils.Interface(["function getAdmin() view returns (address)"]);

const ZERO = { from: hre.ethers.constants.AddressZero };

/// Resolve the account that signs, and prove it is allowed to.
///
/// A print-only run needs no key at all - that is the point of it, so payloads can be produced for a
/// Safe or hardware wallet. The signer is only required when actually sending.
async function resolveSigner(provider: EthersType.providers.JsonRpcProvider, chainId: number, execute: boolean) {
  // Read the admin off the Firewall rather than hardcoding it, so this works for any deployment.
  const firewallAdmin: string = await new hre.ethers.Contract(
    REDEEM_MANAGER_PROXY_ADMIN,
    FIREWALL_IFACE,
    provider
  ).getAdmin(ZERO);

  if (!execute) {
    return { signer: undefined, addr: firewallAdmin, impersonated: false };
  }

  if (chainId === REAL_HOODI) {
    const signers = await hre.ethers.getSigners();
    if (signers.length === 0) throw new Error("no signer configured - set PRIVATE_KEY for the Firewall admin");
    const addr = await signers[0].getAddress();
    if (addr.toLowerCase() !== firewallAdmin.toLowerCase()) {
      throw new Error(`signer ${addr} is not the Firewall admin ${firewallAdmin} - set PRIVATE_KEY accordingly`);
    }
    return { signer: signers[0], addr, impersonated: false };
  }

  await provider.send("tenderly_setBalance", [
    firewallAdmin,
    hre.ethers.utils.hexValue(hre.ethers.utils.parseEther("100")),
  ]);
  return { signer: provider.getSigner(firewallAdmin), addr: firewallAdmin, impersonated: true };
}

async function readState(rm: EthersType.Contract, provider: EthersType.providers.Provider) {
  const paused: boolean = await new hre.ethers.Contract(REDEEM_MANAGER, PROXY_IFACE, provider).paused(ZERO);
  return {
    paused,
    count: (await rm.callStatic.getRedeemRequestCount(ZERO)).toNumber(),
    demand: await rm.callStatic.getRedeemDemand(ZERO),
    coverage: await withdrawalStackEnd(rm),
    balance: await provider.getBalance(REDEEM_MANAGER),
  };
}

async function main() {
  const url = (hre.network.config as any).url as string;
  if (!url) throw new Error("network has no url");
  const provider = new hre.ethers.providers.JsonRpcProvider(url);
  const chainId = (await provider.getNetwork()).chainId;
  const isReal = chainId === REAL_HOODI;
  const execute = process.env.BS4878_EXECUTE === "1";
  const sequence = process.env.BS4878_SEQUENCE === "1";

  if (sequence && isReal) {
    throw new Error("sequence mode is for forks only - staging needs verification between repair and restore");
  }
  const steps: Step[] = sequence ? [...STEPS] : [process.env.BS4878_STEP as Step];
  if (steps.some((s) => !ALL_STEPS.includes(s))) {
    throw new Error(`set BS4878_STEP to one of: ${ALL_STEPS.join(", ")}   (or BS4878_SEQUENCE=1)`);
  }

  const rm = await redeemManagerAt(hre, provider);
  const { signer, addr, impersonated } = await resolveSigner(provider, chainId, execute);
  let recovery = process.env.BS4878_RECOVERY;

  const s0 = await readState(rm, provider);
  console.log(`${isReal ? "REAL HOODI" : "fork"}  chainId ${chainId}  block ${await provider.getBlockNumber()}`);
  console.log(`  ${execute ? "signer" : "must be signed by"} ${addr}${impersonated ? " (impersonated)" : ""}   execute ${execute}`);
  console.log(`  paused ${s0.paused}   requests ${s0.count}   redeemDemand ${eth(s0.demand)}`);
  console.log(`  balance ${eth(s0.balance)} ETH\n`);

  for (const step of steps) {
    const st = await readState(rm, provider);
    let data: string;

    if (step === "deploy") {
      const art = await hre.artifacts.readArtifact("RedeemManagerV1Recovery");
      console.log(`step deploy: RedeemManagerV1Recovery, ${(art.bytecode.length - 2) / 2} bytes, no constructor args`);
      if (!execute) {
        console.log("  print-only - set BS4878_EXECUTE=1 to deploy\n");
        continue;
      }
      const c = await new hre.ethers.ContractFactory(art.abi, art.bytecode, signer!).deploy({ gasLimit: 10_000_000 });
      await c.deployed();
      recovery = c.address;
      console.log(`  deployed at ${recovery}\n`);
      continue;
    }

    switch (step) {
      case "pause":
        if (st.paused) throw new Error("already paused");
        data = PROXY_IFACE.encodeFunctionData("pause");
        break;
      case "repair": {
        // The repair overwrites amounts. A claim landing between building the payload and sending it
        // would be silently reverted, letting a paid request be claimed again, and no on-chain check
        // catches that because a claim moves neither queueEnd, coverage nor redeemDemand.
        if (!recovery) throw new Error("set BS4878_RECOVERY to the deployed recovery implementation");
        if (!fs.existsSync(CALLDATA_FILE)) throw new Error(`missing ${CALLDATA_FILE} - run 02_build_repair_calldata.ts`);
        const inner = fs.readFileSync(CALLDATA_FILE, "utf8").trim();
        console.log(`  payload ${(inner.length - 2) / 2} bytes from ${CALLDATA_FILE}`);
        data = PROXY_IFACE.encodeFunctionData("upgradeToAndCall", [recovery, inner]);
        break;
      }
      case "restore":
        data = PROXY_IFACE.encodeFunctionData("upgradeTo", [CLEAN_IMPL_1_3_0]);
        break;
      case "unpause":
        if (!st.paused) throw new Error("already unpaused");
        data = PROXY_IFACE.encodeFunctionData("unpause");
        break;
    }

    console.log(`step ${step}:`);
    console.log(`  to    ${REDEEM_MANAGER_PROXY_ADMIN}   (ProxyFirewall, forwards to the proxy)`);
    console.log(`  from  ${addr}`);
    console.log(`  data  ${data!.length > 160 ? data!.slice(0, 160) + `… (${(data!.length - 2) / 2} bytes)` : data}`);

    if (!execute) {
      console.log("  print-only - set BS4878_EXECUTE=1 to send, or submit this yourself\n");
      continue;
    }
    const tx = await signer!.sendTransaction({
      to: REDEEM_MANAGER_PROXY_ADMIN,
      data: data!,
      gasLimit: step === "repair" ? 30_000_000 : 500_000,
    });
    const rc = await tx.wait();
    console.log(`  status ${rc.status}  gas ${rc.gasUsed.toString()}  ${tx.hash}\n`);
    if (rc.status !== 1) throw new Error(`${step} reverted`);
  }

  // Post-repair sanity, cheap enough to always run.
  const end = await readState(rm, provider);
  let prev = hre.ethers.constants.Zero;
  let monotonic = true;
  for (let i = 0; i < end.count; ++i) {
    const d = await retry<any>(() => rm.callStatic.getRedeemRequestDetails(i, ZERO));
    if (d.height.lt(prev)) monotonic = false;
    prev = d.height.add(d.amount);
  }
  console.log("post-state");
  console.log(`  paused ${end.paused}   heights monotonic ${monotonic}`);
  console.log(`  queueEnd - coverage ${eth(prev.sub(end.coverage))}   redeemDemand ${eth(end.demand)}` +
              `   invariant ${prev.sub(end.coverage).eq(end.demand)}`);

  if (process.env.BS4878_CLAIM_CHECK === "1" && !isReal && execute && !end.paused) {
    const target = (await rm.resolveRedeemRequests([2]))[0];
    if (target.gte(0)) {
      const d = await rm.getRedeemRequestDetails(2);
      const before = await provider.getBalance(d.recipient);
      await (await rm.connect(signer!)["claimRedeemRequests(uint32[],uint32[])"]([2], [target])).wait();
      const paid = (await provider.getBalance(d.recipient)).sub(before);
      console.log(`  claim check: request 2 paid ${eth(paid)} ETH (cap ${eth(d.maxRedeemableEth)})`);
    }
  }
}

main().catch((e) => {
  console.error(e);
  process.exitCode = 1;
});
