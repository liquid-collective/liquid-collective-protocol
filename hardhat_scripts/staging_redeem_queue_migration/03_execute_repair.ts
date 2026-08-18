import * as fs from "fs";
import * as path from "path";
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
// Either way the transaction goes to the ProxyFirewall and is forwarded to the proxy, so a fork
// exercises the identical path including the forwarding.
//
// There is no pause step. repairRedeemQueue verifies a hash of the queue the payload was built
// against, so a claim landing between building and sending makes it revert rather than silently
// replay stale amounts. Freezing the proxy would only add oracle downtime for no extra safety.
//
// The payload comes from the preflight artifact, which is the file a human reviewed. Nothing rebuilds
// it at send time, so what ships is what was signed off.
//
//   BS4878_STEP=deploy|repair|restore   which step to run
//   BS4878_EXECUTE=1                    actually send; default is print-only
//   BS4878_SEQUENCE=1                   run every step in order; forks only
//   BS4878_RECOVERY=0x...               the deployed recovery implementation
//   BS4878_PREFLIGHT=<path>             preflight json; auto-detected when only one is present
//   BS4878_CLAIM_CHECK=1                after restore, claim one request; forks only
//
// Print-only output is enough to submit from a Safe or hardware wallet instead.
//
// Steps are separate on purpose: the queue must be verified between `repair` and `restore`, and a
// half-finished sequence is easier to reason about when each transaction was a separate decision.

const REAL_HOODI_CHAIN_ID = 560048;
const PREFLIGHT_DIR = "hardhat_scripts/staging_redeem_queue_migration";
const STEPS = ["deploy", "repair", "restore"] as const;
type Step = (typeof STEPS)[number];

const PROXY_INTERFACE = new hre.ethers.utils.Interface([
  "function upgradeTo(address)",
  "function upgradeToAndCall(address,bytes)",
]);
const FIREWALL_INTERFACE = new hre.ethers.utils.Interface(["function getAdmin() view returns (address)"]);

// TUPProxy blocks every caller but the zero address while paused, so all reads go from there.
const FROM_ZERO = { from: hre.ethers.constants.AddressZero };

/// Resolve the account that signs, and prove it is allowed to.
///
/// A print-only run needs no key at all - that is the point of it, so payloads can be produced for a
/// Safe or hardware wallet. The signer is only required when actually sending.
async function resolveSigner(
  provider: EthersType.providers.JsonRpcProvider,
  chainId: number,
  shouldExecute: boolean
): Promise<{ signer?: EthersType.Signer; signerAddress: string; impersonated: boolean }> {
  // Read the admin off the Firewall rather than hardcoding it, so this works for any deployment.
  const firewallAdmin: string = await new hre.ethers.Contract(
    REDEEM_MANAGER_PROXY_ADMIN,
    FIREWALL_INTERFACE,
    provider
  ).getAdmin(FROM_ZERO);

  if (!shouldExecute) {
    return { signer: undefined, signerAddress: firewallAdmin, impersonated: false };
  }

  if (chainId === REAL_HOODI_CHAIN_ID) {
    const signers = await hre.ethers.getSigners();
    if (signers.length === 0) throw new Error("no signer configured - set PRIVATE_KEY for the Firewall admin");
    const signerAddress = await signers[0].getAddress();
    if (signerAddress.toLowerCase() !== firewallAdmin.toLowerCase()) {
      throw new Error(`signer ${signerAddress} is not the Firewall admin ${firewallAdmin} - fix PRIVATE_KEY`);
    }
    return { signer: signers[0], signerAddress, impersonated: false };
  }

  await provider.send("tenderly_setBalance", [
    firewallAdmin,
    hre.ethers.utils.hexValue(hre.ethers.utils.parseEther("100")),
  ]);
  return { signer: provider.getSigner(firewallAdmin), signerAddress: firewallAdmin, impersonated: true };
}

/// Load the reviewed preflight artifact and check it is internally consistent.
///
/// repairRedeemQueue(tuple[] , bytes32) encodes the array as an offset, so the head is
/// [offset, expectedQueueHash] and the hash is the second word after the selector - not the last 32
/// bytes, which are the final record's initiator. Comparing it against the artifact's own
/// expectedQueueHash catches a payload edited or swapped after review.
function loadReviewedPayload(): { calldata: string; queueHash: string; block: number; generatedAt: string } {
  const explicit = process.env.BS4878_PREFLIGHT;
  let file = explicit;
  if (!file) {
    const found = fs.readdirSync(PREFLIGHT_DIR).filter((f) => /^preflight-\d+\.json$/.test(f));
    if (found.length !== 1) {
      throw new Error(
        `expected exactly one preflight-<block>.json in ${PREFLIGHT_DIR}, found ${found.length}` +
          ` - set BS4878_PREFLIGHT to choose`
      );
    }
    file = path.join(PREFLIGHT_DIR, found[0]);
  }
  const artifact = JSON.parse(fs.readFileSync(file, "utf8"));
  const { calldata, expectedQueueHash, generatedAtBlock, generatedAtISO } = artifact;
  if (!calldata || !expectedQueueHash) throw new Error(`${file} is missing calldata or expectedQueueHash`);
  const encodedHash = `0x${calldata.slice(2 + 8 + 64, 2 + 8 + 128)}`;
  if (encodedHash.toLowerCase() !== expectedQueueHash.toLowerCase()) {
    throw new Error(`${file} is inconsistent: payload carries ${encodedHash}, artifact says ${expectedQueueHash}`);
  }
  console.log(`  payload from ${file}`);
  console.log(`    built at block ${generatedAtBlock} (${generatedAtISO})`);
  console.log(`    queue hash ${expectedQueueHash}`);
  return { calldata, queueHash: expectedQueueHash, block: generatedAtBlock, generatedAt: generatedAtISO };
}

async function readQueueState(redeemManager: EthersType.Contract, provider: EthersType.providers.Provider) {
  return {
    requestCount: (await redeemManager.callStatic.getRedeemRequestCount(FROM_ZERO)).toNumber(),
    redeemDemand: await redeemManager.callStatic.getRedeemDemand(FROM_ZERO),
    withdrawalCoverage: await withdrawalStackEnd(redeemManager),
    contractBalance: await provider.getBalance(REDEEM_MANAGER),
  };
}

async function main() {
  const rpcUrl = (hre.network.config as any).url as string;
  if (!rpcUrl) throw new Error("network has no url");
  const provider = new hre.ethers.providers.JsonRpcProvider(rpcUrl);
  const chainId = (await provider.getNetwork()).chainId;
  const isRealHoodi = chainId === REAL_HOODI_CHAIN_ID;
  const shouldExecute = process.env.BS4878_EXECUTE === "1";
  const runWholeSequence = process.env.BS4878_SEQUENCE === "1";

  if (runWholeSequence && isRealHoodi) {
    throw new Error("sequence mode is for forks only - staging needs verification between repair and restore");
  }
  const stepsToRun: Step[] = runWholeSequence ? [...STEPS] : [process.env.BS4878_STEP as Step];
  if (stepsToRun.some((step) => !STEPS.includes(step))) {
    throw new Error(`set BS4878_STEP to one of: ${STEPS.join(", ")}   (or BS4878_SEQUENCE=1)`);
  }

  const redeemManager = await redeemManagerAt(hre, provider);
  const { signer, signerAddress, impersonated } = await resolveSigner(provider, chainId, shouldExecute);
  let recoveryImplementation = process.env.BS4878_RECOVERY;

  const initialState = await readQueueState(redeemManager, provider);
  console.log(`${isRealHoodi ? "REAL HOODI" : "fork"}  chainId ${chainId}  block ${await provider.getBlockNumber()}`);
  console.log(`  ${shouldExecute ? "signer" : "must be signed by"} ${signerAddress}${impersonated ? " (impersonated)" : ""}`);
  console.log(`  requests ${initialState.requestCount}   redeemDemand ${eth(initialState.redeemDemand)}`);
  console.log(`  balance ${eth(initialState.contractBalance)} ETH\n`);

  for (const step of stepsToRun) {
    let transactionData: string;

    if (step === "deploy") {
      const artifact = await hre.artifacts.readArtifact("RedeemManagerV1Recovery");
      console.log(`step deploy: RedeemManagerV1Recovery, ${(artifact.bytecode.length - 2) / 2} bytes, no constructor args`);
      if (!shouldExecute) {
        console.log("  print-only - set BS4878_EXECUTE=1 to deploy\n");
        continue;
      }
      const deployed = await new hre.ethers.ContractFactory(artifact.abi, artifact.bytecode, signer!)
        .deploy({ gasLimit: 10_000_000 });
      await deployed.deployed();
      recoveryImplementation = deployed.address;
      console.log(`  deployed at ${recoveryImplementation}\n`);
      continue;
    }

    if (step === "repair") {
      if (!recoveryImplementation) throw new Error("set BS4878_RECOVERY to the deployed recovery implementation");
      const { calldata: repairCalldata } = loadReviewedPayload();
      transactionData = PROXY_INTERFACE.encodeFunctionData("upgradeToAndCall", [recoveryImplementation, repairCalldata]);
    } else {
      transactionData = PROXY_INTERFACE.encodeFunctionData("upgradeTo", [CLEAN_IMPL_1_3_0]);
    }

    console.log(`step ${step}:`);
    console.log(`  to    ${REDEEM_MANAGER_PROXY_ADMIN}   (ProxyFirewall, forwards to the proxy)`);
    console.log(`  from  ${signerAddress}`);
    console.log(
      `  data  ${transactionData.length > 160
        ? `${transactionData.slice(0, 160)}… (${(transactionData.length - 2) / 2} bytes)`
        : transactionData}`
    );

    if (!shouldExecute) {
      console.log("  print-only - set BS4878_EXECUTE=1 to send, or submit this yourself\n");
      continue;
    }
    const transaction = await signer!.sendTransaction({
      to: REDEEM_MANAGER_PROXY_ADMIN,
      data: transactionData,
      gasLimit: step === "repair" ? 30_000_000 : 500_000,
    });
    const receipt = await transaction.wait();
    console.log(`  status ${receipt.status}  gas ${receipt.gasUsed.toString()}  ${transaction.hash}\n`);
    if (receipt.status !== 1) throw new Error(`${step} reverted`);
  }

  // Only meaningful once something was actually sent: on a print-only run this would just restate the
  // corrupted queue and read like a failure.
  if (!shouldExecute) {
    console.log("print-only run - nothing sent, so no post-state check");
    return;
  }

  const finalState = await readQueueState(redeemManager, provider);
  let previousEnd = hre.ethers.constants.Zero;
  let heightsMonotonic = true;
  for (let id = 0; id < finalState.requestCount; ++id) {
    const request = await retry<any>(() => redeemManager.callStatic.getRedeemRequestDetails(id, FROM_ZERO));
    if (request.height.lt(previousEnd)) heightsMonotonic = false;
    previousEnd = request.height.add(request.amount);
  }
  const impliedDemand = previousEnd.sub(finalState.withdrawalCoverage);
  console.log("post-state");
  console.log(`  heights monotonic ${heightsMonotonic}`);
  console.log(`  queueEnd - coverage ${eth(impliedDemand)}   redeemDemand ${eth(finalState.redeemDemand)}` +
              `   invariant ${impliedDemand.eq(finalState.redeemDemand)}`);

  if (process.env.BS4878_CLAIM_CHECK === "1" && !isRealHoodi && shouldExecute) {
    const [withdrawalEventId] = await redeemManager.resolveRedeemRequests([2]);
    if (withdrawalEventId.gte(0)) {
      const request = await redeemManager.getRedeemRequestDetails(2);
      const balanceBefore = await provider.getBalance(request.recipient);
      await (await redeemManager.connect(signer!)["claimRedeemRequests(uint32[],uint32[])"]([2], [withdrawalEventId])).wait();
      const paid = (await provider.getBalance(request.recipient)).sub(balanceBefore);
      console.log(`  claim check: request 2 paid ${eth(paid)} ETH (cap ${eth(request.maxRedeemableEth)})`);
    }
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
