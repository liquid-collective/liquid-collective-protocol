#!/usr/bin/env python3
"""BS-4878: rehearse the full staging recovery on a Tenderly Virtual TestNet forked from hoodi.

This is the dress rehearsal for the runbook. It forks hoodi at the current block and executes every
step against real state - the real corrupted queue, the real withdrawal stack, the real balances -
then asserts the queue is restored and that a previously stuck request actually pays out.

Steps executed on the fork:
    0. read pre-state and confirm the queue really is corrupted
    1. TUPProxy.pause()                          from the proxy admin
    2. confirm claims are blocked while paused
    3. deploy RedeemManagerV1Recovery
    4. upgradeToAndCall(recovery, repairRedeemQueue(...))
    5. verify every one of the requests matches the intended payload
    6. verify heights are monotonic and queue end - coverage == redeemDemand
    7. upgradeTo(RedeemManagerV1) to drop the recovery surface
    8. TUPProxy.unpause()
    9. resolve and claim a restored request, checking the payout

Nothing here touches real hoodi. Every transaction goes to the Virtual TestNet RPC.

Setup - either point at an existing Virtual TestNet:
    export TENDERLY_VNET_RPC=https://virtual.hoodi.rpc.tenderly.co/<uuid>
or let this script create one:
    export TENDERLY_ACCESS_KEY=...
    export TENDERLY_ACCOUNT=...      # account slug
    export TENDERLY_PROJECT=...      # project slug

Run scripts/bs4878_build_repair_calldata.py first. This script re-derives the calldata against the
fork itself (BS4878_RPC), so a claim landing on hoodi between generation and rehearsal cannot make
the two disagree.
"""
import json
import os
import subprocess
import sys

HOODI_CHAIN_ID = 560048

RM = "0x5d51E82b75A4F16ef677d5bE20d707b6441A00b7"
RM_PROXY_ADMIN = "0x0C20959C12Eb226eC7DddC25109124AE850ED4BE"  # RedeemManagerProxyFirewall
CLEAN_IMPL_1_3_0 = "0xf155e40F0549f60842243F97794D5939c2E72F98"
DEPLOYER = "0x00000000000000000000000000000000BeeF4878"

ARTIFACT = "out/RedeemManagerV1Recovery.sol/RedeemManagerV1Recovery.json"
CALLDATA_FILE = "scripts/bs4878_repair_calldata.txt"

SEL_COUNT = "0x319798d1"
SEL_DETAILS = "0x9b92d6de"
SEL_WE_COUNT = "0x841ecb85"
SEL_WE_DETAILS = "0x86233754"
SEL_DEMAND = "0x0d8d2a54"
SEL_PAUSE = "0x8456cb59"  # pause()
SEL_UNPAUSE = "0x3f4ba83a"  # unpause()
SEL_UPGRADE_TO = "0x3659cfe6"  # upgradeTo(address)
SEL_UPGRADE_TO_AND_CALL = "0x4f1ef286"  # upgradeToAndCall(address,bytes)
SEL_RESOLVE = "0x5f2e5f07"  # resolveRedeemRequests(uint32[])
SEL_CLAIM = "0x9332525d"  # claimRedeemRequests(uint32[],uint32[])

# The proxy blocks every caller except address zero while paused, so all reads go from there.
ZERO = "0x0000000000000000000000000000000000000000"

_id = [0]
RPC = None


def rpc(method, params, rpc_url=None):
    _id[0] += 1
    payload = json.dumps({"jsonrpc": "2.0", "id": _id[0], "method": method, "params": params})
    r = subprocess.run(
        ["curl", "-s", "-m", "120", "-X", "POST", rpc_url or RPC,
         "-H", "content-type: application/json", "-d", payload],
        capture_output=True, text=True,
    )
    if r.returncode != 0:
        raise RuntimeError(f"curl failed: {r.stderr}")
    d = json.loads(r.stdout)
    if "error" in d:
        raise RuntimeError(f"{method}: {d['error']}")
    return d["result"]


def call(to, data):
    return rpc("eth_call", [{"from": ZERO, "to": to, "data": data}, "latest"])


def try_call(to, data, sender=None):
    """eth_call that returns (ok, result_or_error) instead of raising."""
    tx = {"to": to, "data": data}
    if sender:
        tx["from"] = sender
    _id[0] += 1
    payload = json.dumps({"jsonrpc": "2.0", "id": _id[0], "method": "eth_call", "params": [tx, "latest"]})
    r = subprocess.run(
        ["curl", "-s", "-m", "120", "-X", "POST", RPC, "-H", "content-type: application/json", "-d", payload],
        capture_output=True, text=True,
    )
    d = json.loads(r.stdout)
    if "error" in d:
        return False, d["error"].get("message", str(d["error"]))
    return True, d["result"]


def send(frm, to, data, value=0, label=""):
    tx = {"from": frm, "data": data, "gas": hex(30_000_000)}
    if to:
        tx["to"] = to
    if value:
        tx["value"] = hex(value)
    tx_hash = rpc("eth_sendTransaction", [tx])
    receipt = rpc("eth_getTransactionReceipt", [tx_hash])
    status = int(receipt["status"], 16)
    gas = int(receipt["gasUsed"], 16)
    print(f"    {label or 'tx'}: status={status} gas={gas:,} {tx_hash}")
    if status != 1:
        raise RuntimeError(f"{label} reverted - {tx_hash}")
    return receipt


def words(h):
    h = h[2:]
    return [int(h[i : i + 64], 16) for i in range(0, len(h), 64)]


def detail(idx):
    w = words(call(RM, SEL_DETAILS + f"{idx:064x}"))
    return {"amount": w[0], "maxEth": w[1], "recipient": "0x" + f"{w[2]:040x}", "height": w[3],
            "initiator": "0x" + f"{w[4]:040x}"}


def eth(v):
    return f"{v/1e18:,.6f}"


def create_vnet():
    missing = [v for v in ("TENDERLY_ACCESS_KEY", "TENDERLY_ACCOUNT", "TENDERLY_PROJECT") if not os.environ.get(v)]
    if missing:
        raise SystemExit(
            "Set TENDERLY_VNET_RPC to use an existing Virtual TestNet, or set "
            + ", ".join(missing)
            + " to have one created.\n"
            "  TENDERLY_ACCOUNT and TENDERLY_PROJECT are the slugs from your Tenderly dashboard URL:\n"
            "    https://dashboard.tenderly.co/<account>/<project>"
        )
    key = os.environ["TENDERLY_ACCESS_KEY"]
    account = os.environ["TENDERLY_ACCOUNT"]
    project = os.environ["TENDERLY_PROJECT"]
    url = f"https://api.tenderly.co/api/v1/account/{account}/project/{project}/vnets"
    head = int(rpc("eth_blockNumber", [], "https://ethereum-hoodi-rpc.publicnode.com"), 16)
    slug = f"bs4878-recovery-rehearsal-{head}"
    body = json.dumps({
        "slug": slug,
        "display_name": f"BS-4878 recovery rehearsal @ hoodi {head}",
        "fork_config": {"network_id": HOODI_CHAIN_ID, "block_number": head},
        "virtual_network_config": {"chain_config": {"chain_id": HOODI_CHAIN_ID}},
        "sync_state_config": {"enabled": False},
        "explorer_page_config": {"enabled": False, "verification_visibility": "bytecode"},
    })
    r = subprocess.run(
        ["curl", "-s", "-m", "120", "-X", "POST", url,
         "-H", "content-type: application/json", "-H", f"X-Access-Key: {key}", "-d", body],
        capture_output=True, text=True,
    )
    d = json.loads(r.stdout)
    if "rpcs" not in d:
        raise SystemExit(f"could not create Virtual TestNet: {r.stdout[:600]}")
    admin = next((x["url"] for x in d["rpcs"] if "admin" in x.get("name", "").lower()), d["rpcs"][0]["url"])
    print(f"  created Virtual TestNet '{slug}' forked from hoodi block {head}")
    print(f"  admin RPC: {admin}")
    return admin


def main():
    global RPC
    RPC = os.environ.get("TENDERLY_VNET_RPC") or create_vnet()
    print(f"\nusing fork RPC {RPC[:60]}...")
    print(f"fork chainId={int(rpc('eth_chainId', []), 16)}  block={int(rpc('eth_blockNumber', []), 16)}\n")

    # Fund the accounts we drive the rehearsal from.
    for who in (RM_PROXY_ADMIN, DEPLOYER):
        rpc("tenderly_setBalance", [who, hex(100 * 10**18)])

    print("=" * 78)
    print("0. pre-state")
    print("=" * 78)
    count = int(call(RM, SEL_COUNT), 16)
    demand = int(call(RM, SEL_DEMAND), 16)
    balance = int(rpc("eth_getBalance", [RM, "latest"]), 16)
    print(f"  queue length {count}   redeemDemand {eth(demand)}   balance {eth(balance)} ETH")
    absurd = [i for i in range(min(count, 86)) if detail(i)["amount"] > 10**24]
    print(f"  requests with absurd amounts (corruption present): {len(absurd)} -> {absurd[:8]}...")
    if not absurd:
        raise SystemExit("fork does not look corrupted - is this really hoodi?")

    # Re-derive the calldata against the fork so generation and rehearsal cannot disagree.
    print("\n  re-deriving repair calldata against the fork...")
    env = dict(os.environ, BS4878_RPC=RPC)
    gen = subprocess.run([sys.executable, "scripts/bs4878_build_repair_calldata.py"],
                         capture_output=True, text=True, env=env)
    if gen.returncode != 0:
        raise SystemExit(f"calldata generation failed:\n{gen.stdout}\n{gen.stderr}")
    for line in gen.stdout.splitlines():
        if any(k in line for k in ("queue end", "coverage", "implied", "redeemDemand", "invariant", "netting")):
            print("   ", line.strip())
    calldata = open(CALLDATA_FILE).read().strip()
    payload = words("0x" + calldata[2 + 8 :])[2:]
    intended = [
        {"amount": payload[i * 5], "maxEth": payload[i * 5 + 1],
         "recipient": "0x" + f"{payload[i*5+2]:040x}", "height": payload[i * 5 + 3],
         "initiator": "0x" + f"{payload[i*5+4]:040x}"}
        for i in range(count)
    ]

    print("\n" + "=" * 78)
    print("1. pause the proxy")
    print("=" * 78)
    send(RM_PROXY_ADMIN, RM, SEL_PAUSE, label="pause()")

    print("\n" + "=" * 78)
    print("2. confirm claims are blocked while paused")
    print("=" * 78)
    ok, err = try_call(RM, SEL_COUNT, sender=DEPLOYER)
    print(f"  call from a normal sender while paused: blocked={not ok}  ({str(err)[:70]})")
    if ok:
        raise SystemExit("proxy did not block calls while paused")

    print("\n" + "=" * 78)
    print("3. deploy RedeemManagerV1Recovery")
    print("=" * 78)
    bytecode = json.load(open(ARTIFACT))["bytecode"]["object"]
    receipt = send(DEPLOYER, None, bytecode, label="deploy")
    recovery = receipt["contractAddress"]
    print(f"    recovery implementation at {recovery}")

    print("\n" + "=" * 78)
    print("4. upgradeToAndCall(recovery, repairRedeemQueue(...))")
    print("=" * 78)
    inner = bytes.fromhex(calldata[2:])
    data = (
        SEL_UPGRADE_TO_AND_CALL
        + f"{int(recovery,16):064x}"
        + f"{64:064x}"
        + f"{len(inner):064x}"
        + inner.hex()
        + "00" * ((32 - len(inner) % 32) % 32)
    )
    send(RM_PROXY_ADMIN, RM, data, label="upgradeToAndCall")

    print("\n" + "=" * 78)
    print("5. verify every request matches the intended payload")
    print("=" * 78)
    mismatches = []
    for i in range(count):
        got, want = detail(i), intended[i]
        for f in ("amount", "maxEth", "height"):
            if got[f] != want[f]:
                mismatches.append((i, f, got[f], want[f]))
        for f in ("recipient", "initiator"):
            if got[f].lower() != want[f].lower():
                mismatches.append((i, f, got[f], want[f]))
    print(f"  requests checked: {count}   mismatches: {len(mismatches)}")
    if mismatches:
        for m in mismatches[:10]:
            print(f"    id {m[0]} {m[1]}: got {m[2]} want {m[3]}")
        raise SystemExit("repair did not restore the queue")
    print("  -> all fields restored exactly")

    print("\n" + "=" * 78)
    print("6. verify invariants")
    print("=" * 78)
    prev, nonmono = 0, []
    for i in range(count):
        d = detail(i)
        if d["height"] < prev:
            nonmono.append(i)
        prev = d["height"] + d["amount"]
    wc = int(call(RM, SEL_WE_COUNT), 16)
    a, _we, h = words(call(RM, SEL_WE_DETAILS + f"{wc-1:064x}"))
    coverage = h + a
    demand_after = int(call(RM, SEL_DEMAND), 16)
    print(f"  heights monotonic: {not nonmono}")
    print(f"  queue end {eth(prev)} - coverage {eth(coverage)} = {eth(prev-coverage)}")
    print(f"  redeemDemand                                  = {eth(demand_after)}")
    print(f"  invariant holds: {prev - coverage == demand_after}")
    if nonmono or prev - coverage != demand_after:
        raise SystemExit("post-repair invariants failed")

    print("\n" + "=" * 78)
    print("7 & 8. restore the clean implementation and unpause")
    print("=" * 78)
    send(RM_PROXY_ADMIN, RM, SEL_UPGRADE_TO + f"{int(CLEAN_IMPL_1_3_0,16):064x}", label="upgradeTo(1.3.0)")
    send(RM_PROXY_ADMIN, RM, SEL_UNPAUSE, label="unpause()")

    print("\n" + "=" * 78)
    print("9. claim a restored request end to end")
    print("=" * 78)
    target = next(
        (i for i in range(count)
         if intended[i]["amount"] > 0 and intended[i]["height"] + intended[i]["amount"] <= coverage),
        None,
    )
    if target is None:
        print("  no fully covered open request to claim - skipping")
        return 0
    want = intended[target]
    print(f"  claiming request {target}: {eth(want['amount'])} LsETH to {want['recipient']}")
    resolved = words(call(RM, SEL_RESOLVE + f"{32:064x}{1:064x}{target:064x}"))
    event_id = resolved[2]
    # resolveRedeemRequests returns int64: -1 unsatisfied, -2 out of bounds.
    if event_id >= 2**63:
        raise SystemExit(f"request {target} resolved to {event_id - 2**64} - not claimable after repair")
    print(f"    resolves to withdrawal event {event_id}")
    before = int(rpc("eth_getBalance", [want["recipient"], "latest"]), 16)
    claim_data = SEL_CLAIM + f"{64:064x}{128:064x}{1:064x}{target:064x}{1:064x}{event_id:064x}"
    send(DEPLOYER, RM, claim_data, label="claimRedeemRequests")
    after = int(rpc("eth_getBalance", [want["recipient"], "latest"]), 16)
    paid = after - before
    print(f"    recipient received {eth(paid)} ETH (cap was {eth(want['maxEth'])})")
    print(f"    remaining amount   {eth(detail(target)['amount'])}")
    if paid == 0:
        raise SystemExit("claim paid nothing - recovery incomplete")

    print("\n" + "=" * 78)
    print("REHEARSAL PASSED - the runbook works against real hoodi state")
    print("=" * 78)
    return 0


if __name__ == "__main__":
    sys.exit(main())
