#!/usr/bin/env python3
"""BS-4878: build the calldata for RedeemManagerV1Recovery.repairRedeemQueue.

Read-only. Produces the full corrected queue and ABI encodes it, then re-checks every invariant the
contract enforces so a failing repair is caught here rather than on chain.

The corrected queue is assembled from three sources:
  * ids 0..85   - the pre-upgrade reconstruction in bs4878_hoodi_repair.json
  * id 56       - netted for the claim booked against corrupted id 70, which consumed request 56's
                  entitlement (the migration copied word 4*70 == 5*56)
  * ids 86..    - created after the upgrade, so amount/maxRedeemableEth/recipient/initiator in storage
                  are already correct; only their heights need rebuilding

Heights are never taken verbatim. They are derived from the end-position chain
`endPos[i] = endPos[i-1] + originalSize[i]`, then `height[i] = endPos[i] - amount[i]`, because
`height + amount` is the quantity the claim path holds invariant.

Run bs4878_reconstruct.py against the FROZEN state first - these numbers move with every claim.
"""
import json
import subprocess
import sys

RPC = "https://ethereum-hoodi-rpc.publicnode.com"
RM = "0x5d51E82b75A4F16ef677d5bE20d707b6441A00b7"
UPGRADE_BLOCK = 3027299
REPAIR_JSON = "scripts/bs4878_hoodi_repair.json"
OUT = "scripts/bs4878_repair_calldata.txt"

SELECTOR = "5f59c10e"  # repairRedeemQueue((uint256,uint256,address,uint256,address)[])

T_REQUESTED = "0x9a1bb960783a8679f42036f0c1fe89288fd279ed545a19f86bd284c72947b187"
SEL_COUNT = "0x319798d1"
SEL_DETAILS = "0x9b92d6de"
SEL_WE_COUNT = "0x841ecb85"
SEL_WE_DETAILS = "0x86233754"
SEL_DEMAND = "0x0d8d2a54"

T_CLAIMED = "0x25f4dfa5f0703d4c509bd7216e70f8378f419433c14840c14f3eaadb60642ad1"

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


def main():
    head = int(rpc("eth_blockNumber", []), 16)
    rec = json.load(open(REPAIR_JSON))
    R = {r["id"]: r for r in rec["requests"]}
    count = int(call(SEL_COUNT), 16)
    print(f"head={head}  queue length={count}  reconstruction covers ids 0..{max(R)}")

    post_size = {}
    for lg in scan(T_REQUESTED, UPGRADE_BLOCK, head):
        _h, size, _maxEth, rid = words(lg["data"])
        post_size[rid] = size

    # Original sizes: pre-upgrade from the reconstruction chain, post-upgrade from creation events.
    sizes, prev_end = {}, 0
    for k in sorted(R):
        end = int(R[k]["height"]) + int(R[k]["amount"])
        sizes[k] = end - prev_end
        prev_end = end
    for k in range(len(R), count):
        sizes[k] = post_size[k]

    # Claims booked against the corrupted region since the upgrade consumed a different request's
    # entitlement. The migration wrote index j from pre-migration words 4j..4j+3; when 4j is a multiple
    # of 5 those are exactly request 4j/5's amount, maxRedeemableEth, recipient and height, so the claim
    # must be netted against that request. Anything else is a blend of two records and needs a human.
    netting = {}
    for lg in scan(T_CLAIMED, UPGRADE_BLOCK, head):
        rid = int(lg["topics"][1], 16)
        if rid >= len(R):
            continue
        eth_paid, lsETH, _rem = words(lg["data"])
        if (4 * rid) % 5 != 0:
            raise SystemExit(f"claim on corrupted id {rid} blends two records - attribute it manually")
        source = 4 * rid // 5
        acc = netting.setdefault(source, {"lsETH": 0, "eth": 0, "from": []})
        acc["lsETH"] += lsETH
        acc["eth"] += eth_paid
        acc["from"].append(rid)
    for source, acc in sorted(netting.items()):
        print(f"  netting claim(s) on corrupted id {acc['from']} against request {source}: "
              f"-{acc['lsETH']} LsETH, -{acc['eth']} ETH")

    rows = []
    for k in range(count):
        if k in R:
            amount, maxEth = int(R[k]["amount"]), int(R[k]["maxRedeemableEth"])
            recipient, initiator = R[k]["recipient"], R[k]["initiator"]
            if k in netting:
                amount -= netting[k]["lsETH"]
                maxEth -= netting[k]["eth"]
                if amount < 0 or maxEth < 0:
                    raise SystemExit(f"netting request {k} went negative - re-check the claim attribution")
        else:
            d = detail(k)
            amount, maxEth = d["amount"], d["maxEth"]
            recipient, initiator = d["recipient"], d["initiator"]
        rows.append({"id": k, "amount": amount, "maxEth": maxEth, "recipient": recipient,
                     "initiator": initiator})

    end = 0
    for r in rows:
        end += sizes[r["id"]]
        r["endPos"] = end
        r["height"] = end - r["amount"]

    # Mirror the on-chain checks so a doomed transaction never gets sent.
    prev = 0
    for i, r in enumerate(rows):
        if int(r["recipient"], 16) == 0:
            raise SystemExit(f"request {i}: zero recipient")
        if int(r["initiator"], 16) == 0:
            raise SystemExit(f"request {i}: zero initiator")
        if r["height"] < prev:
            raise SystemExit(f"request {i}: height {r['height']} < previous end {prev}")
        if i != 0 and r["endPos"] <= prev:
            raise SystemExit(f"request {i}: non increasing end position")
        prev = r["endPos"]

    wc = int(call(SEL_WE_COUNT), 16)
    coverage = 0
    if wc:
        a, _we, h = words(call(SEL_WE_DETAILS + f"{wc-1:064x}"))
        coverage = h + a
    demand = int(call(SEL_DEMAND), 16)
    implied = prev - coverage
    print(f"\n  queue end   : {prev}")
    print(f"  coverage    : {coverage}")
    print(f"  implied     : {implied}")
    print(f"  redeemDemand: {demand}")
    if implied != demand:
        raise SystemExit(f"DEMAND MISMATCH - implied {implied} vs stored {demand}; repair would revert")
    print("  -> demand invariant holds, repairRedeemQueue will pass its checks")

    body = f"{32:064x}{len(rows):064x}"
    for r in rows:
        body += (
            f"{r['amount']:064x}{r['maxEth']:064x}{int(r['recipient'],16):064x}"
            f"{r['height']:064x}{int(r['initiator'],16):064x}"
        )
    calldata = "0x" + SELECTOR + body

    with open(OUT, "w") as f:
        f.write(calldata + "\n")
    print(f"\n  requests encoded : {len(rows)}")
    print(f"  calldata bytes   : {len(calldata[2:])//2}")
    print(f"  wrote {OUT}")
    print("\n  Send from the RedeemManagerProxyFirewall as:")
    print(f"    upgradeToAndCall(<RedeemManagerV1Recovery>, <{OUT}>)")


if __name__ == "__main__":
    sys.exit(main())
