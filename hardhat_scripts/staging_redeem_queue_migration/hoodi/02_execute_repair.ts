import * as fs from "fs";
import * as path from "path";
import hre from "hardhat";
import { ethers as EthersType } from "ethers";
import {
  CLEAN_IMPL_1_3_0,
  REDEEM_MANAGER,
  REDEEM_MANAGER_PROXY_ADMIN,
  currentQueueHash,
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
// Everything else - which artifact, which implementation, whether to run the claim smoke test - is
// derived from the repo and the chain id, so a mistyped environment variable cannot steer a live
// upgrade.
//
//   BS4878_EXECUTE=1            actually send; default is print-only

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

  // A dry run only reports who must sign, so it deliberately does not require access to a private key.
  if (!shouldExecute) return { signer: undefined, signerAddress: firewallAdmin, impersonated: false };

  // Real Hoodi must be signed by the configured Firewall admin; reject any accidentally selected key.
  if (chainId === REAL_HOODI_CHAIN_ID) {
    const signers = await hre.ethers.getSigners();
    if (signers.length === 0) throw new Error("no signer configured - set PRIVATE_KEY for the Firewall admin");
    const signerAddress = await signers[0].getAddress();
    if (signerAddress.toLowerCase() !== firewallAdmin.toLowerCase()) {
      throw new Error(`signer ${signerAddress} is not the Firewall admin ${firewallAdmin} - fix PRIVATE_KEY`);
    }
    return { signer: signers[0], signerAddress, impersonated: false };
  }

  // Fork rehearsals impersonate the same admin and fund it locally so they exercise the production call path.
  await provider.send("tenderly_setBalance", [
    firewallAdmin,
    hre.ethers.utils.hexValue(hre.ethers.utils.parseEther("100")),
  ]);
  return { signer: provider.getSigner(firewallAdmin), signerAddress: firewallAdmin, impersonated: true };
}

/// Load the reviewed preflight artifact and check it is internally consistent.
///
/// Decode through the compiled recovery ABI so the selector, tuple layout and expected queue hash
/// are validated rather than inferred from fixed calldata offsets.
function loadReviewedPayload(recoveryInterface: EthersType.utils.Interface): {
  calldata: string;
  queueHash: string;
  records: any[];
} {
  // Always the committed artifact, never a path passed in at run time - the reviewed file is the one
  // in the repo.
  const found = fs.readdirSync(PREFLIGHT_DIR).filter((f) => /^preflight-\d+\.json$/.test(f));
  if (found.length !== 1) {
    throw new Error(`expected exactly one preflight-<block>.json in ${PREFLIGHT_DIR}, found ${found.length}`);
  }
  const file = path.join(PREFLIGHT_DIR, found[0]);

  // Read the exact reviewed records and calldata; this script never reconstructs them at execution time.
  const { calldata, expectedQueueHash, generatedAtBlock, generatedAtISO, records } = JSON.parse(
    fs.readFileSync(file, "utf8")
  );
  if (!calldata || !expectedQueueHash) throw new Error(`${file} is missing calldata or expectedQueueHash`);

  // ABI decoding validates the function selector and tuple layout before checking the embedded queue hash.
  const encodedHash = recoveryInterface.decodeFunctionData("repairRedeemQueue", calldata)._expectedQueueHash;
  if (encodedHash.toLowerCase() !== expectedQueueHash.toLowerCase()) {
    throw new Error(`${file} is inconsistent: payload carries ${encodedHash}, artifact says ${expectedQueueHash}`);
  }
  console.log(`payload ${file}`);
  console.log(`  built at block ${generatedAtBlock} (${generatedAtISO}), queue hash ${expectedQueueHash}\n`);
  return { calldata, queueHash: expectedQueueHash, records };
}

/// Read the implementation currently installed in the proxy's standard EIP-1967 storage slot.
async function readImplementation(provider: EthersType.providers.Provider): Promise<string> {
  return hre.ethers.utils.getAddress(
    `0x${(await provider.getStorageAt(REDEEM_MANAGER, EIP1967_IMPL_SLOT)).slice(-40)}`
  );
}

/// Send one Firewall transaction and wait for its receipt before the sequence advances.
async function send(signer: EthersType.Signer, label: string, data: string, gasLimit: number): Promise<void> {
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

  // Compare every repaired field with the reviewed preflight and rebuild the queue end as we go.
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

  // Independently prove queueEnd - withdrawalCoverage == redeemDemand, matching the on-chain repair check.
  const redeemDemand = await redeemManager.callStatic.getRedeemDemand(FROM_ZERO);
  const impliedDemand = previousEnd.sub(await withdrawalStackEnd(redeemManager));
  console.log(`  records matching the reviewed payload : ${records.length - mismatches.length}/${records.length}`);
  console.log(`  heights monotonic                     : ${heightsMonotonic}`);
  console.log(
    `  queueEnd - coverage ${eth(impliedDemand)} == redeemDemand ${eth(redeemDemand)} : ${impliedDemand.eq(
      redeemDemand
    )}`
  );

  // Throw before restore if any record or accounting invariant differs from the reviewed result.
  if (mismatches.length) throw new Error(`repair did not apply cleanly: ${mismatches.slice(0, 12).join(", ")}`);
  if (!heightsMonotonic) throw new Error("heights are not monotonic after the repair");
  if (!impliedDemand.eq(redeemDemand)) throw new Error("demand invariant broken after the repair");
}

async function main() {
  // Establish the target chain first; chainId controls whether signing is real or impersonated.
  const rpcUrl = (hre.network.config as any).url as string;
  if (!rpcUrl) throw new Error("network has no url");
  const provider = new hre.ethers.providers.JsonRpcProvider(rpcUrl);
  const chainId = (await provider.getNetwork()).chainId;
  const isRealHoodi = chainId === REAL_HOODI_CHAIN_ID;
  const shouldExecute = process.env.BS4878_EXECUTE === "1";

  // Load the recovery ABI once and reuse the same artifact for payload validation and optional deployment.
  const artifact = await hre.artifacts.readArtifact("RedeemManagerV1Recovery");
  const recoveryInterface = new hre.ethers.utils.Interface(artifact.abi);

  // Bind the live proxy, resolve the authorized signer, and load the exact payload approved in preflight.
  const redeemManager = await redeemManagerAt(hre, provider);
  const { signer, signerAddress, impersonated } = await resolveSigner(provider, chainId, shouldExecute);
  const { calldata, queueHash, records } = loadReviewedPayload(recoveryInterface);

  // Capture the implementation that is actually live rather than trusting the constant, so restore
  // puts back what was there. A mismatch means staging is not where we think it is.
  const liveImplementation = await readImplementation(provider);
  if (liveImplementation.toLowerCase() !== CLEAN_IMPL_1_3_0.toLowerCase()) {
    console.error(`live implementation is ${liveImplementation}, expected ${CLEAN_IMPL_1_3_0}`);
    console.error(`if a previous run left the recovery implementation installed, restore it with:`);
    console.error(`  to        ${REDEEM_MANAGER_PROXY_ADMIN}`);
    console.error(`  calldata  ${PROXY_INTERFACE.encodeFunctionData("upgradeTo", [CLEAN_IMPL_1_3_0])}`);
    throw new Error("unexpected live implementation - stop and investigate");
  }

  // The repair refuses to apply to any queue but the one the payload was built against. Check that
  // here so a stale artifact aborts locally instead of burning 30M gas on a guaranteed revert.
  const liveQueueHash = await currentQueueHash(hre, redeemManager);
  if (liveQueueHash.toLowerCase() !== queueHash.toLowerCase()) {
    throw new Error(
      `queue has moved since the artifact was generated (live ${liveQueueHash}, artifact ${queueHash})` +
        ` - rerun hoodi/01_preflight.ts, review the new artifact, and replace the committed one`
    );
  }

  console.log(`${isRealHoodi ? "REAL HOODI" : "fork"}  chainId ${chainId}  block ${await provider.getBlockNumber()}`);
  console.log(
    `  ${shouldExecute ? "signer" : "must be signed by"} ${signerAddress}${impersonated ? " (impersonated)" : ""}`
  );
  console.log(`  live implementation ${liveImplementation}`);
  console.log(`  requests ${(await redeemManager.callStatic.getRedeemRequestCount(FROM_ZERO)).toNumber()}`);
  console.log(`  balance ${eth(await provider.getBalance(REDEEM_MANAGER))} ETH`);
  console.log(`  queue hash matches the artifact\n`);

  // Stop here in print-only mode after showing the complete transaction sequence and its actors.
  if (!shouldExecute) {
    console.log("print-only. The sequence would be:");
    console.log(
      `  1 deploy  RedeemManagerV1Recovery, ${(artifact.bytecode.length - 2) / 2} bytes, no constructor args`
    );
    console.log(`  2 repair  to ${REDEEM_MANAGER_PROXY_ADMIN}  from ${signerAddress}`);
    console.log(`            upgradeToAndCall(<recovery>, <${(calldata.length - 2) / 2} byte payload>)`);
    console.log(`  3 verify  every record against the reviewed payload, then the invariants`);
    console.log(`  4 restore to ${REDEEM_MANAGER_PROXY_ADMIN}  upgradeTo(${liveImplementation})`);
    console.log("\nset BS4878_EXECUTE=1 to run it, or submit these yourself");
    return;
  }

  // Step 1: deploy the temporary recovery implementation, always fresh from the compiled artifact.
  // This is the target of a delegatecall on a proxy holding the redeem manager's ETH, so it must be
  // code this run produced rather than an address someone pasted in.
  console.log("1 deploy recovery implementation");
  const deployed = await new hre.ethers.ContractFactory(artifact.abi, artifact.bytecode, signer!).deploy({
    gasLimit: 10_000_000,
  });
  await deployed.deployed();
  const recoveryImplementation = deployed.address;
  console.log(`  deployed at ${recoveryImplementation}\n`);

  // Step 2: atomically install the recovery implementation and execute the reviewed queue rewrite.
  console.log("2 repair redeem queue");
  await send(
    signer!,
    "repair",
    PROXY_INTERFACE.encodeFunctionData("upgradeToAndCall", [recoveryImplementation, calldata]),
    5_000_000
  );

  // Step 3: compare the repaired queue with preflight.
  //
  // A failure here must not leave the recovery implementation installed. By this point the repair
  // transaction has landed, so the one-off flag is already consumed and repairRedeemQueue can never run
  // again - the recovery implementation is functionally just RedeemManagerV1 with a dead entry point, and
  // keeping it on the proxy adds surface for nothing. A verify failure is also as likely to be a dropped
  // RPC read partway through 125 record fetches as it is a bad repair. Restoring touches no queue state,
  // so it costs nothing for a post-mortem either way.
  //
  // Deliberately not a try/finally: a throw from the restore inside `finally` would replace the
  // verification error, which is the diagnostic that matters most. Catch it, restore exactly once, then
  // decide which error to surface.
  let verifyError: unknown;
  try {
    console.log("\n3 verify migration");
    await verifyRepair(redeemManager, records);
  } catch (error) {
    verifyError = error;
    console.error(`\n  VERIFICATION FAILED: ${(error as Error).message}`);
    console.error("  restoring the original implementation first, then reporting this failure");
  }

  // Step 4: remove the recovery surface and confirm the proxy points back to the original implementation.
  console.log("\n4 restore old implementation");
  const restoreCalldata = PROXY_INTERFACE.encodeFunctionData("upgradeTo", [liveImplementation]);
  try {
    await send(signer!, "restore", restoreCalldata, 500_000);
    const restored = await readImplementation(provider);
    if (restored.toLowerCase() !== liveImplementation.toLowerCase()) {
      throw new Error(`restore did not take: implementation is ${restored}`);
    }
    console.log(`  implementation back to ${restored}`);
  } catch (restoreError) {
    // The recovery implementation is still installed. That is the more urgent of the two problems, so
    // it wins, but the verification failure is printed above so both are in the transcript.
    console.error("\n  RESTORE FAILED - the recovery implementation is still installed. Submit manually:");
    console.error(`    to        ${REDEEM_MANAGER_PROXY_ADMIN}`);
    console.error(`    calldata  ${restoreCalldata}`);
    throw restoreError;
  }

  // Surface the verification failure now that the proxy is back on the reviewed implementation. Stops
  // short of the smoke test below, which would be meaningless against a queue that did not verify.
  if (verifyError) {
    throw verifyError;
  }

  // Fork-only smoke test: claim one repaired request and report the actual ETH paid. Gated on the
  // chain id so it can never be switched on against real holders' funds.
  if (!isRealHoodi) {
    const [withdrawalEventId] = await redeemManager.resolveRedeemRequests([2]);
    if (withdrawalEventId.gte(0)) {
      const request = await redeemManager.getRedeemRequestDetails(2);
      const balanceBefore = await provider.getBalance(request.recipient);
      await (
        await redeemManager.connect(signer!)["claimRedeemRequests(uint32[],uint32[])"]([2], [withdrawalEventId])
      ).wait();
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
