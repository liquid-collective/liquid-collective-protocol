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
} from "../redeem_queue_repair";

// BS-4878: perform the redeem queue repair.
//
//   npx hardhat run hardhat_scripts/staging_redeem_queue_migration/hoodi/02_execute_repair.ts --network hoodi
//
// Runs deploy, repair, verify, restore as one sequence. They were separate at first so the queue could
// be inspected between repair and restore, but repairRedeemQueue validates itself on chain - the queue
// hash, the per-record geometry and the demand invariant all have to hold or it reverts. So a
// successful repair already means the queue is right, and there is nothing useful to eyeball in the
// gap. The verify stage below runs automatically instead, and aborts before restore if anything is
// off, which is the check that manual stepping was meant to provide.
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
// There is no pause step. The queue hash makes a claim landing mid-run revert rather than silently
// replay stale amounts, so freezing would only add oracle downtime for no extra safety.
//
// The payload comes from the preflight artifact, which is the file a human reviewed. Nothing rebuilds
// it at send time, so what ships is what was signed off.
//
//   BS4878_EXECUTE=1            actually send; default is print-only
//   BS4878_PREFLIGHT=<path>     preflight json; auto-detected when only one is present
//   BS4878_RECOVERY=0x...       skip the deploy and reuse an already deployed implementation
//   BS4878_CLAIM_CHECK=1        after restore, claim one request; forks only

const REAL_HOODI_CHAIN_ID = 560048;
const PREFLIGHT_DIR = "hardhat_scripts/staging_redeem_queue_migration";
const EIP1967_IMPL_SLOT = "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc";

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

  if (!shouldExecute) return { signer: undefined, signerAddress: firewallAdmin, impersonated: false };

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
/// repairRedeemQueue(tuple[], bytes32) encodes the array behind an offset, so the head is
/// [offset, expectedQueueHash] and the hash is the second word after the selector - not the trailing
/// 32 bytes, which are the last record's initiator.
function loadReviewedPayload(): { calldata: string; queueHash: string; records: any[] } {
  let file = process.env.BS4878_PREFLIGHT;
  if (!file) {
    const found = fs.readdirSync(PREFLIGHT_DIR).filter((f) => /^preflight-\d+\.json$/.test(f));
    if (found.length !== 1) {
      throw new Error(`expected one preflight-<block>.json in ${PREFLIGHT_DIR}, found ${found.length} - set BS4878_PREFLIGHT`);
    }
    file = path.join(PREFLIGHT_DIR, found[0]);
  }
  const { calldata, expectedQueueHash, generatedAtBlock, generatedAtISO, records } =
    JSON.parse(fs.readFileSync(file, "utf8"));
  if (!calldata || !expectedQueueHash) throw new Error(`${file} is missing calldata or expectedQueueHash`);
  const encodedHash = `0x${calldata.slice(2 + 8 + 64, 2 + 8 + 128)}`;
  if (encodedHash.toLowerCase() !== expectedQueueHash.toLowerCase()) {
    throw new Error(`${file} is inconsistent: payload carries ${encodedHash}, artifact says ${expectedQueueHash}`);
  }
  console.log(`payload ${file}`);
  console.log(`  built at block ${generatedAtBlock} (${generatedAtISO}), queue hash ${expectedQueueHash}\n`);
  return { calldata, queueHash: expectedQueueHash, records };
}

async function readImplementation(provider: EthersType.providers.Provider): Promise<string> {
  return hre.ethers.utils.getAddress(
    `0x${(await provider.getStorageAt(REDEEM_MANAGER, EIP1967_IMPL_SLOT)).slice(-40)}`
  );
}

async function send(
  signer: EthersType.Signer,
  label: string,
  data: string,
  gasLimit: number
): Promise<void> {
  const transaction = await signer.sendTransaction({ to: REDEEM_MANAGER_PROXY_ADMIN, data, gasLimit });
  const receipt = await transaction.wait();
  console.log(`  status ${receipt.status}  gas ${receipt.gasUsed.toString()}  ${transaction.hash}`);
  if (receipt.status !== 1) throw new Error(`${label} reverted`);
}

/// Confirm the queue matches the reviewed payload, and that the invariants still hold. Runs between
/// repair and restore and throws rather than returning, so a bad repair never reaches restore.
async function verifyRepair(redeemManager: EthersType.Contract, records: any[]): Promise<void> {
  const mismatches: string[] = [];
  let previousEnd = hre.ethers.constants.Zero;
  let heightsMonotonic = true;

  for (let id = 0; id < records.length; ++id) {
    const onChain = await retry<any>(() => redeemManager.callStatic.getRedeemRequestDetails(id, FROM_ZERO));
    const want = records[id].intended;
    if (!onChain.amount.eq(want.amount)) mismatches.push(`${id}.amount`);
    if (!onChain.maxRedeemableEth.eq(want.maxRedeemableEth)) mismatches.push(`${id}.maxRedeemableEth`);
    if (!onChain.height.eq(want.height)) mismatches.push(`${id}.height`);
    if (onChain.recipient.toLowerCase() !== want.recipient.toLowerCase()) mismatches.push(`${id}.recipient`);
    if (onChain.initiator.toLowerCase() !== want.initiator.toLowerCase()) mismatches.push(`${id}.initiator`);
    if (onChain.height.lt(previousEnd)) heightsMonotonic = false;
    previousEnd = onChain.height.add(onChain.amount);
  }

  const redeemDemand = await redeemManager.callStatic.getRedeemDemand(FROM_ZERO);
  const impliedDemand = previousEnd.sub(await withdrawalStackEnd(redeemManager));
  console.log(`  records matching the reviewed payload : ${records.length - mismatches.length}/${records.length}`);
  console.log(`  heights monotonic                     : ${heightsMonotonic}`);
  console.log(`  queueEnd - coverage ${eth(impliedDemand)} == redeemDemand ${eth(redeemDemand)} : ${impliedDemand.eq(redeemDemand)}`);

  if (mismatches.length) throw new Error(`repair did not apply cleanly: ${mismatches.slice(0, 12).join(", ")}`);
  if (!heightsMonotonic) throw new Error("heights are not monotonic after the repair");
  if (!impliedDemand.eq(redeemDemand)) throw new Error("demand invariant broken after the repair");
}

async function main() {
  const rpcUrl = (hre.network.config as any).url as string;
  if (!rpcUrl) throw new Error("network has no url");
  const provider = new hre.ethers.providers.JsonRpcProvider(rpcUrl);
  const chainId = (await provider.getNetwork()).chainId;
  const isRealHoodi = chainId === REAL_HOODI_CHAIN_ID;
  const shouldExecute = process.env.BS4878_EXECUTE === "1";

  const redeemManager = await redeemManagerAt(hre, provider);
  const { signer, signerAddress, impersonated } = await resolveSigner(provider, chainId, shouldExecute);
  const { calldata, records } = loadReviewedPayload();

  // Capture the implementation that is actually live rather than trusting the constant, so restore
  // puts back what was there. A mismatch means staging is not where we think it is.
  const liveImplementation = await readImplementation(provider);
  if (liveImplementation.toLowerCase() !== CLEAN_IMPL_1_3_0.toLowerCase()) {
    throw new Error(`live implementation ${liveImplementation} is not the expected ${CLEAN_IMPL_1_3_0} - stop and investigate`);
  }

  console.log(`${isRealHoodi ? "REAL HOODI" : "fork"}  chainId ${chainId}  block ${await provider.getBlockNumber()}`);
  console.log(`  ${shouldExecute ? "signer" : "must be signed by"} ${signerAddress}${impersonated ? " (impersonated)" : ""}`);
  console.log(`  live implementation ${liveImplementation}`);
  console.log(`  requests ${(await redeemManager.callStatic.getRedeemRequestCount(FROM_ZERO)).toNumber()}`);
  console.log(`  balance ${eth(await provider.getBalance(REDEEM_MANAGER))} ETH\n`);

  let recoveryImplementation = process.env.BS4878_RECOVERY;
  const artifact = await hre.artifacts.readArtifact("RedeemManagerV1Recovery");

  if (!shouldExecute) {
    console.log("print-only. The sequence would be:");
    console.log(`  1 deploy  RedeemManagerV1Recovery, ${(artifact.bytecode.length - 2) / 2} bytes, no constructor args`);
    console.log(`  2 repair  to ${REDEEM_MANAGER_PROXY_ADMIN}  from ${signerAddress}`);
    console.log(`            upgradeToAndCall(<recovery>, <${(calldata.length - 2) / 2} byte payload>)`);
    console.log(`  3 verify  every record against the reviewed payload, then the invariants`);
    console.log(`  4 restore to ${REDEEM_MANAGER_PROXY_ADMIN}  upgradeTo(${liveImplementation})`);
    console.log("\nset BS4878_EXECUTE=1 to run it, or submit these yourself");
    return;
  }

  if (!recoveryImplementation) {
    console.log("1 deploy");
    const deployed = await new hre.ethers.ContractFactory(artifact.abi, artifact.bytecode, signer!)
      .deploy({ gasLimit: 10_000_000 });
    await deployed.deployed();
    recoveryImplementation = deployed.address;
    console.log(`  deployed at ${recoveryImplementation}\n`);
  } else {
    console.log(`1 deploy skipped, reusing ${recoveryImplementation}\n`);
  }

  console.log("2 repair");
  await send(
    signer!,
    "repair",
    PROXY_INTERFACE.encodeFunctionData("upgradeToAndCall", [recoveryImplementation, calldata]),
    30_000_000
  );

  console.log("\n3 verify");
  await verifyRepair(redeemManager, records);

  console.log("\n4 restore");
  await send(signer!, "restore", PROXY_INTERFACE.encodeFunctionData("upgradeTo", [liveImplementation]), 500_000);
  const restored = await readImplementation(provider);
  if (restored.toLowerCase() !== liveImplementation.toLowerCase()) {
    throw new Error(`restore did not take: implementation is ${restored}`);
  }
  console.log(`  implementation back to ${restored}`);

  if (process.env.BS4878_CLAIM_CHECK === "1" && !isRealHoodi) {
    const [withdrawalEventId] = await redeemManager.resolveRedeemRequests([2]);
    if (withdrawalEventId.gte(0)) {
      const request = await redeemManager.getRedeemRequestDetails(2);
      const balanceBefore = await provider.getBalance(request.recipient);
      await (await redeemManager.connect(signer!)["claimRedeemRequests(uint32[],uint32[])"]([2], [withdrawalEventId])).wait();
      const paid = (await provider.getBalance(request.recipient)).sub(balanceBefore);
      console.log(`\nclaim check: request 2 paid ${eth(paid)} ETH (cap ${eth(request.maxRedeemableEth)})`);
    }
  }

  console.log("\nREPAIR COMPLETE");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
