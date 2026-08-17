#!/usr/bin/env python3
"""BS-4878: who holds the corrupted legacy redeem requests, and how old are they.

Read-only. Answers "who is affected, how many people, how old" for the pre-upgrade (legacy) region of
the hoodi queue - the ids the replayed migration destroyed.

Reports per recipient: open request count, LsETH at stake, the wallet that actually submitted the
request, whether the recipient is a contract (likely an integration rather than a person), and the
age of their oldest and newest request.
"""
import json
import subprocess
import sys
import time

RPC = "https://ethereum-hoodi-rpc.publicnode.com"
RM = "0x5d51E82b75A4F16ef677d5bE20d707b6441A00b7"
UPGRADE_BLOCK = 3027299
DEPLOY_BLOCK = 307784
REPAIR_JSON = "scripts/bs4878_hoodi_repair.json"

T_REQUESTED = "0x9a1bb960783a8679f42036f0c1fe89288fd279ed545a19f86bd284c72947b187"
T_CLAIMED = "0x25f4dfa5f0703d4c509bd7216e70f8378f419433c14840c14f3eaadb60642ad1"

_id = [0]


def rpc(method, params):
    _id[0] += 1
    payload = json.dumps({"jsonrpc": "2.0", "id": _id[0], "method": method, "params": params})
    r = subprocess.run(
        ["curl", "-s", "-m", "60", "-X", "POST", RPC, "-H", "content-type: application/json", "-d", payload],
        capture_output=True, text=True,
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
    head = int(rpc("eth_blockNumber", []), 16)
    now = int(rpc("eth_getBlockByNumber", [hex(head), False])["timestamp"], 16)
    rec = json.load(open(REPAIR_JSON))
    R = {r["id"]: r for r in rec["requests"]}

    # Creation metadata for the legacy region.
    meta = {}
    for lg in scan(T_REQUESTED, DEPLOY_BLOCK, UPGRADE_BLOCK - 1):
        _h, size, _cap, rid = words(lg["data"])
        meta[rid] = {"block": int(lg["blockNumber"], 16), "tx": lg["transactionHash"], "size": size}

    # A claim booked against a corrupted id consumed request 4*id/5's entitlement, so that request is
    # settled by the repair even though the pre-upgrade snapshot shows it open.
    netted = set()
    for lg in scan(T_CLAIMED, UPGRADE_BLOCK, head):
        rid = int(lg["topics"][1], 16)
        if rid < len(R) and (4 * rid) % 5 == 0:
            netted.add(4 * rid // 5)

    legacy_open = [i for i in sorted(R) if R[i]["open"] and i not in netted]
    print(f"hoodi RedeemManager {RM}")
    print(f"legacy region = ids 0..{max(R)} (created before the BYOV upgrade at block {UPGRADE_BLOCK})\n")

    ts_cache = {}
    for i in legacy_open:
        b = meta[i]["block"]
        if b not in ts_cache:
            ts_cache[b] = int(rpc("eth_getBlockByNumber", [hex(b), False])["timestamp"], 16)

    tx_cache = {}
    holders = {}
    for i in legacy_open:
        m = meta[i]
        if m["tx"] not in tx_cache:
            tx_cache[m["tx"]] = rpc("eth_getTransactionByHash", [m["tx"]])["from"].lower()
        recipient = R[i]["recipient"].lower()
        h = holders.setdefault(recipient, {"ids": [], "lsETH": 0, "senders": set(), "ts": []})
        h["ids"].append(i)
        h["lsETH"] += int(R[i]["amount"])
        h["senders"].add(tx_cache[m["tx"]])
        h["ts"].append(ts_cache[m["block"]])

    for addr, h in holders.items():
        h["contract"] = rpc("eth_getCode", [addr, "latest"]) not in ("0x", "0x0")

    total = sum(h["lsETH"] for h in holders.values())
    ages = [(now - t) / 86400 for h in holders.values() for t in h["ts"]]
    print("=" * 100)
    print(f"AFFECTED: {len(holders)} unique recipients holding {len(legacy_open)} open corrupted requests, "
          f"{total/1e18:,.4f} LsETH")
    print(f"age of these requests: oldest {max(ages):.0f} days, newest {min(ages):.0f} days, "
          f"median {sorted(ages)[len(ages)//2]:.0f} days")
    print("=" * 100)

    print(f"\n{'recipient':<44}{'reqs':>5}{'LsETH':>14}{'oldest':>9}{'newest':>9}  type")
    print("-" * 100)
    for addr, h in sorted(holders.items(), key=lambda kv: -kv[1]["lsETH"]):
        oldest = (now - min(h["ts"])) / 86400
        newest = (now - max(h["ts"])) / 86400
        kind = "contract" if h["contract"] else "EOA"
        same = h["senders"] == {addr}
        note = "" if same else f"  submitted by {', '.join(sorted(h['senders']))[:44]}"
        print(f"{addr:<44}{len(h['ids']):>5}{h['lsETH']/1e18:>14,.4f}{oldest:>8.0f}d{newest:>8.0f}d  {kind}{note}")

    print("\nper-request detail (oldest first)")
    print(f"{'id':>4}{'LsETH':>14}{'age':>8}  {'created':<12} recipient")
    print("-" * 100)
    for i in sorted(legacy_open, key=lambda i: ts_cache[meta[i]["block"]]):
        t = ts_cache[meta[i]["block"]]
        age = (now - t) / 86400
        day = time.strftime("%Y-%m-%d", time.gmtime(t))
        print(f"{i:>4}{int(R[i]['amount'])/1e18:>14,.4f}{age:>7.0f}d  {day:<12} {R[i]['recipient']}")

    buckets = {"> 1 year": 0, "6-12 months": 0, "3-6 months": 0, "< 3 months": 0}
    for i in legacy_open:
        age = (now - ts_cache[meta[i]["block"]]) / 86400
        key = "> 1 year" if age > 365 else "6-12 months" if age > 182 else "3-6 months" if age > 91 else "< 3 months"
        buckets[key] += 1
    print("\nage distribution")
    for k, v in buckets.items():
        print(f"  {k:<14}{v:>4} requests")

    if netted:
        print(f"\nnote: request(s) {sorted(netted)} show as open in the pre-upgrade snapshot but are settled by")
        print("      the repair, because a post-upgrade claim on the corrupted region already paid them out.")


if __name__ == "__main__":
    sys.exit(main())
