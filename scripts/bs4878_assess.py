#!/usr/bin/env python3
"""BS-4878: damage, exposure and post-repair solvency assessment for the hoodi RedeemManager.

Read-only. Consumes scripts/bs4878_hoodi_repair.json (produced by bs4878_reconstruct.py) and
reports:

  1. per-field damage across the 86 pre-upgrade requests
  2. claims executed since the BYOV upgrade, and whether any exceeded its entitlement
  3. live exposure: corrupted requests that are claimable right now
  4. whether the repaired queue would be solvent against the contract's ETH balance

Section 4 is the gate on the repair plan: it must report SOLVENT before claims are re-enabled.
Re-run this against the frozen state immediately before repairing - the numbers move with every
claim, and the headroom is thin.
"""
import json
import subprocess
import sys

RPC = "https://ethereum-hoodi-rpc.publicnode.com"
RM = "0x5d51E82b75A4F16ef677d5bE20d707b6441A00b7"
UPGRADE_BLOCK = 3027299
REPAIR_JSON = "scripts/bs4878_hoodi_repair.json"

T_REQUESTED = "0x9a1bb960783a8679f42036f0c1fe89288fd279ed545a19f86bd284c72947b187"
T_CLAIMED = "0x25f4dfa5f0703d4c509bd7216e70f8378f419433c14840c14f3eaadb60642ad1"

SEL_COUNT = "0x319798d1"
SEL_DETAILS = "0x9b92d6de"
SEL_WE_COUNT = "0x841ecb85"
SEL_WE_DETAILS = "0x86233754"
SEL_DEMAND = "0x0d8d2a54"

# The claim booked against corrupted id 70 actually consumed true request 56's entitlement,
# because the migration copied word 4*70 == 5*56. Repair must net it against 56, not 70.
MISATTRIBUTED = {"claimedOn": 70, "belongsTo": 56, "lsETH": 983561000000000000, "eth": 10**18}

_id = [0]


def rpc(method, params):
    _id[0] += 1
    payload = json.dumps({"jsonrpc": "2.0", "id": _id[0], "method": method, "params": params})
    r = subprocess.run(
        ["curl", "-s", "-m", "60", "-X", "POST", RPC, "-H", "content-type: application/json", "-d", payload],
        capture_output=True,
        text=True,
    )
    d = json.loads(r.stdout)
    if "error" in d:
        raise RuntimeError(f"{method}: {d['error']}")
    return d["result"]


def call(data):
    return rpc("eth_call", [{"to": RM, "data": data}, "latest"])


def scan(topic0, a, b, step=45000):
    out, x = [], a
    while x <= b:
        y = min(x + step - 1, b)
        out += rpc("eth_getLogs", [{"address": RM, "topics": [topic0], "fromBlock": hex(x), "toBlock": hex(y)}])
        x = y + 1
    return out


def words(h):
    h = h[2:]
    return [int(h[i : i + 64], 16) for i in range(0, len(h), 64)]


def detail(idx):
    w = words(call(SEL_DETAILS + f"{idx:064x}"))
    return {"amount": w[0], "maxEth": w[1], "recipient": "0x" + f"{w[2]:040x}", "height": w[3],
            "initiator": "0x" + f"{w[4]:040x}"}


def e(v):
    return f"{v/1e18:,.6f}"


def main():
    head = int(rpc("eth_blockNumber", []), 16)
    rec = json.load(open(REPAIR_JSON))
    R = {r["id"]: r for r in rec["requests"]}
    print(f"hoodi RedeemManager {RM}   head={head}\n")

    print("=" * 78)
    print("1. per-field damage across the 86 pre-upgrade requests")
    print("=" * 78)
    fields = ["amount", "maxRedeemableEth", "recipient", "height", "initiator"]
    counts = dict.fromkeys(fields, 0)
    payload_bad, intact = [], []
    for k in sorted(R):
        cur, exp = detail(k), R[k]
        cmp = {
            "amount": cur["amount"] == int(exp["amount"]),
            "maxRedeemableEth": cur["maxEth"] == int(exp["maxRedeemableEth"]),
            "recipient": cur["recipient"].lower() == exp["recipient"].lower(),
            "height": cur["height"] == int(exp["height"]),
            "initiator": cur["initiator"].lower() == exp["initiator"].lower(),
        }
        bad = [f for f in fields if not cmp[f]]
        for f in bad:
            counts[f] += 1
        if not bad:
            intact.append(k)
        elif set(bad) - {"initiator"}:
            payload_bad.append(k)
    print(f"  fully intact: {len(intact)}   payload-damaged: {len(payload_bad)}")
    for f in fields:
        print(f"    {f:<18} {counts[f]}")
    openids = {r["id"] for r in rec["requests"] if r["open"]}
    print(f"  payload-damaged AND open at upgrade: {len(set(payload_bad) & openids)}")

    print("\n" + "=" * 78)
    print("2. claims since the BYOV upgrade")
    print("=" * 78)
    post_size, post_cap = {}, {}
    for lg in scan(T_REQUESTED, UPGRADE_BLOCK, head):
        h, size, maxEth, rid = words(lg["data"])
        post_size[rid], post_cap[rid] = size, maxEth
    over = []
    for lg in sorted(scan(T_CLAIMED, UPGRADE_BLOCK, head), key=lambda l: int(l["blockNumber"], 16)):
        rid = int(lg["topics"][1], 16)
        eth_paid, ls, rem = words(lg["data"])
        if rid < 86:
            true_cap = int(R[rid]["maxRedeemableEth"])
            flag = "  <-- against CORRUPTED region"
            if eth_paid > true_cap:
                over.append((rid, eth_paid, true_cap))
        else:
            flag = "" if eth_paid <= post_cap.get(rid, 0) else "  <-- EXCEEDS CAP"
        print(f"  id {rid:>3}  ETH={e(eth_paid):>14}  lsETH={e(ls):>14}{flag}")
    for rid, paid, cap in over:
        print(f"  !! id {rid} paid {e(paid)} ETH vs true entitlement {e(cap)} ETH")
    print(f"  note: the id {MISATTRIBUTED['claimedOn']} claim consumed request "
          f"{MISATTRIBUTED['belongsTo']}'s entitlement; repair nets it against "
          f"{MISATTRIBUTED['belongsTo']}")

    print("\n" + "=" * 78)
    print("3. live exposure")
    print("=" * 78)
    wc = int(call(SEL_WE_COUNT), 16)
    a, _we, h = words(call(SEL_WE_DETAILS + f"{wc-1:064x}"))
    cover = h + a
    bal = int(rpc("eth_getBalance", [RM, "latest"]), 16)
    risky = [k for k in range(86) if (d := detail(k))["amount"] > 0 and d["height"] < cover]
    absurd = [k for k in risky if detail(k)["amount"] > 10**24]
    print(f"  withdrawal coverage 0..{e(cover)} LsETH   balance {e(bal)} ETH")
    print(f"  corrupted ids claimable now: {len(risky)}   of which absurd amounts: {len(absurd)} {absurd}")
    print("  -> freeze claims before repairing; one such claim can exhaust the solvency headroom")

    print("\n" + "=" * 78)
    print("4. post-repair solvency")
    print("=" * 78)
    rows, sizes, prev_end = [], {}, 0
    for k in range(86):
        end = int(R[k]["height"]) + int(R[k]["amount"])
        sizes[k] = end - prev_end
        prev_end = end
        amt, mx = int(R[k]["amount"]), int(R[k]["maxRedeemableEth"])
        if k == MISATTRIBUTED["belongsTo"]:
            amt -= MISATTRIBUTED["lsETH"]
            mx -= MISATTRIBUTED["eth"]
        rows.append({"id": k, "amount": max(amt, 0), "maxEth": max(mx, 0)})
    for k in range(86, int(call(SEL_COUNT), 16)):
        d = detail(k)
        rows.append({"id": k, "amount": d["amount"], "maxEth": d["maxEth"]})
        sizes[k] = post_size[k]

    end = 0
    for r in rows:
        end += sizes[r["id"]]
        r["endPos"] = end
        r["height"] = end - r["amount"]

    demand = int(call(SEL_DEMAND), 16)
    print(f"  repaired queue end : {e(end)} LsETH")
    print(f"  coverage           : {e(cover)} LsETH")
    print(f"  gap                : {e(end - cover)}   redeemDemand() = {e(demand)}"
          f"   match: {end - cover == demand}")

    claimable = 0
    for r in rows:
        if r["amount"] == 0:
            continue
        portion = min(r["endPos"], cover) - r["height"]
        if portion > 0:
            claimable += r["maxEth"] * portion // r["amount"]
    print(f"\n  ETH claimable immediately after repair : {e(claimable)}")
    print(f"  contract balance                       : {e(bal)}")
    print(f"  -> {'SOLVENT' if bal >= claimable else 'SHORT'} by {e(abs(bal - claimable))} ETH")
    print(f"  open requests after repair: {sum(1 for r in rows if r['amount'] > 0)}")
    return 0 if bal >= claimable else 1


if __name__ == "__main__":
    sys.exit(main())
