#!/usr/bin/env python3
"""BS-4878: reconstruct the hoodi RedeemManager queue as it stood immediately before the BYOV upgrade.

Read-only. Emits scripts/bs4878_hoodi_repair.json with the correct 5 fields for every request id.

Reconstruction rules, from RedeemManager.1.sol:
  * RequestedRedeem(recipient, height, size, maxRedeemableEth, id) gives the creation-time values.
  * _claimRedeemRequest holds `height + amount` constant and moves height forward as the request is
    satisfied, so:  height_now = height0 + size0 - remaining
  * maxRedeemableEth is decremented by the (capped) eth paid out, which ClaimedRedeemRequest reports
    as `ethAmount`, so:  maxRedeemableEth_now = maxRedeemableEth0 - sum(ethAmount)
  * `initiator` is not in any event. Pre-1.3.0 code set it to msg.sender, so it is River's address
    when the request was routed through River.requestRedeem, else the EOA that sent the tx.
"""
import json
import subprocess
import sys

RPC = "https://ethereum-hoodi-rpc.publicnode.com"
RM = "0x5d51E82b75A4F16ef677d5bE20d707b6441A00b7"
RIVER = "0x0CA0c58b1986a55876552E0D9532C963625D5646"

DEPLOY_BLOCK = 307784
UPGRADE_BLOCK = 3027299
CUTOFF = UPGRADE_BLOCK - 1

T_REQUESTED = "0x9a1bb960783a8679f42036f0c1fe89288fd279ed545a19f86bd284c72947b187"
T_CLAIMED = "0x25f4dfa5f0703d4c509bd7216e70f8378f419433c14840c14f3eaadb60642ad1"

OUT = "scripts/bs4878_hoodi_repair.json"

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


def main():
    print(f"scanning {RM} blocks {DEPLOY_BLOCK}..{CUTOFF}")

    reqs = {}
    for lg in scan(T_REQUESTED, DEPLOY_BLOCK, CUTOFF):
        h, size, maxEth, rid = words(lg["data"])
        reqs[rid] = {
            "id": rid,
            "recipient": "0x" + lg["topics"][1][-40:],
            "height0": h,
            "size0": size,
            "maxEth0": maxEth,
            "endPos": h + size,
            "claimedEth": 0,
            "remaining": size,
            "createdBlock": int(lg["blockNumber"], 16),
            "createdTx": lg["transactionHash"],
        }
    print(f"  RequestedRedeem events: {len(reqs)}")

    claims = scan(T_CLAIMED, DEPLOY_BLOCK, CUTOFF)
    claims.sort(key=lambda l: (int(l["blockNumber"], 16), int(l["logIndex"], 16)))
    for lg in claims:
        rid = int(lg["topics"][1], 16)
        ethAmount, lsEthAmount, remaining = words(lg["data"])
        if rid in reqs:
            reqs[rid]["claimedEth"] += ethAmount
            reqs[rid]["remaining"] = remaining
    print(f"  ClaimedRedeemRequest events: {len(claims)}")

    # initiator: River if the creating tx targeted River, else the sender.
    tx_cache = {}
    for r in reqs.values():
        tx = tx_cache.get(r["createdTx"]) or rpc("eth_getTransactionByHash", [r["createdTx"]])
        tx_cache[r["createdTx"]] = tx
        to = (tx.get("to") or "").lower()
        r["viaRiver"] = to == RIVER.lower()
        r["initiator"] = RIVER.lower() if r["viaRiver"] else tx["from"].lower()

    for r in reqs.values():
        r["amount"] = r["remaining"]
        r["height"] = r["endPos"] - r["remaining"]
        r["maxRedeemableEth"] = r["maxEth0"] - r["claimedEth"]
        r["open"] = r["remaining"] > 0

    ids = sorted(reqs)
    openids = [i for i in ids if reqs[i]["open"]]

    print(f"\n  total requests   : {len(ids)}")
    print(f"  open at upgrade  : {len(openids)}")
    print(f"  open LsETH       : {sum(reqs[i]['amount'] for i in openids)/1e18:,.6f}")
    print(f"  via River        : {sum(1 for i in ids if reqs[i]['viaRiver'])}  (initiator = River)")
    print(f"  direct           : {sum(1 for i in ids if not reqs[i]['viaRiver'])}  (initiator = EOA)")

    # Sanity: end positions must form a contiguous non-decreasing chain.
    bad = [i for i in ids[1:] if reqs[i]["height0"] != reqs[i - 1]["endPos"]]
    print(f"  chain height0[i] == endPos[i-1] for all i: {not bad}" + (f"  violations {bad}" if bad else ""))

    print(f"\n  {'id':>4} {'amount':>16} {'maxRedeemableEth':>18} {'height':>16} {'init':>6}  recipient")
    for i in openids:
        r = reqs[i]
        print(
            f"  {i:>4} {r['amount']/1e18:>16.6f} {r['maxRedeemableEth']/1e18:>18.6f} {r['height']/1e18:>16.6f}"
            f" {'River' if r['viaRiver'] else 'EOA':>6}  {r['recipient']}"
        )

    payload = {
        "network": "hoodi",
        "redeemManager": RM,
        "river": RIVER,
        "upgradeBlock": UPGRADE_BLOCK,
        "reconstructedAtBlock": CUTOFF,
        "requestCount": len(ids),
        "openCount": len(openids),
        "requests": [
            {
                "id": i,
                "amount": str(reqs[i]["amount"]),
                "maxRedeemableEth": str(reqs[i]["maxRedeemableEth"]),
                "recipient": reqs[i]["recipient"],
                "height": str(reqs[i]["height"]),
                "initiator": reqs[i]["initiator"],
                "open": reqs[i]["open"],
            }
            for i in ids
        ],
    }
    with open(OUT, "w") as f:
        json.dump(payload, f, indent=2)
    print(f"\n  wrote {OUT}")


if __name__ == "__main__":
    sys.exit(main())
