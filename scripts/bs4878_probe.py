#!/usr/bin/env python3
"""Ad-hoc probe for BS-4878: hoodi/devHoodi RedeemManager state around the BYOV v1.3.0 upgrade.

The public Hoodi endpoints are not archive nodes, so the pre-upgrade queue is reconstructed from
events rather than historical eth_call. Uses curl for transport because cast/rustls rejects the
local TLS interception CA.
"""
import json
import subprocess
import sys

RPC = "https://ethereum-hoodi-rpc.publicnode.com"

IMPL_SLOT = "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc"
QUEUE_LEN_SLOT = "0x232f0d723a47bd57c991606dd0525f28484745095475b69dffe8416b3749c3c1"
QUEUE_BASE = 0x013D6916B68C2B6EFBB8C2F8C8D56F3ABF6894E8E6DB274A9605654E9EC7CD17

T_UPGRADED = "0xbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b"
T_INITIALIZE = "0x1809e49bba43f2d39fa57894b50cd6ccb428cc438230e065cac3eb24a1355a71"
T_REQUESTED = "0x9a1bb960783a8679f42036f0c1fe89288fd279ed545a19f86bd284c72947b187"
T_CLAIMED = "0x25f4dfa5f0703d4c509bd7216e70f8378f419433c14840c14f3eaadb60642ad1"

SEL_COUNT = "0x319798d1"
SEL_DETAILS = "0x9b92d6de"
SEL_VERSION = "0x54fd4d50"

SEL_INIT_V1 = "c8fade5a"
SEL_INIT_V1_2 = "b69dd9e6"

TARGETS = {
    "hoodi (staging)": {
        "redeemManager": "0x5d51E82b75A4F16ef677d5bE20d707b6441A00b7",
        "impl_1_2_1": "0x770604A7c8423d82a28c52F7ba77f981E7302AAC",
        "impl_1_3_0": "0xf155e40F0549f60842243F97794D5939c2E72F98",
    },
    "devHoodi (dev)": {
        "redeemManager": "0xc4e7190a0cFde634C1e0A9Dc4eB3c18612B407b4",
        "impl_1_2_1": "0x1bb6C684A681d15cd0017B957C76da3F40B8EECB",
        "impl_1_3_0": "0xC0d70Bf38009CA2F3Bbe16C5C58de26630A148bC",
    },
}

_id = [0]


def rpc(method, params):
    _id[0] += 1
    payload = json.dumps({"jsonrpc": "2.0", "id": _id[0], "method": method, "params": params})
    out = subprocess.run(
        ["curl", "-s", "-m", "60", "-X", "POST", RPC, "-H", "content-type: application/json", "-d", payload],
        capture_output=True,
        text=True,
    )
    if out.returncode != 0:
        raise RuntimeError(f"curl failed: {out.stderr}")
    res = json.loads(out.stdout)
    if "error" in res:
        raise RuntimeError(f"{method}: {res['error']}")
    return res["result"]


def call(to, data, block="latest"):
    return rpc("eth_call", [{"to": to, "data": data}, block])


def scan_logs(address, topic0, start, end, step=45000):
    logs, b = [], start
    while b <= end:
        hi = min(b + step - 1, end)
        logs.extend(
            rpc(
                "eth_getLogs",
                [{"address": address, "topics": [topic0], "fromBlock": hex(b), "toBlock": hex(hi)}],
            )
        )
        b = hi + 1
    return logs


def words(hexstr):
    h = hexstr[2:]
    return [int(h[i : i + 64], 16) for i in range(0, len(h), 64)]


def dec_request(hexstr):
    w = words(hexstr)
    return {
        "amount": w[0],
        "maxRedeemableEth": w[1],
        "recipient": "0x" + f"{w[2]:040x}",
        "height": w[3],
        "initiator": "0x" + f"{w[4]:040x}",
    }


def eth(v):
    return f"{v/1e18:,.6f}"


def main():
    head = int(rpc("eth_blockNumber", []), 16)
    print(f"RPC {RPC}   chainId={int(rpc('eth_chainId', []), 16)}   head={head}")

    for name, t in TARGETS.items():
        rm = t["redeemManager"]
        print("\n" + "=" * 96)
        print(f"{name}   RedeemManager {rm}")
        print("=" * 96)

        cur = "0x" + rpc("eth_getStorageAt", [rm, IMPL_SLOT, "latest"])[-40:]
        label = {
            t["impl_1_2_1"].lower(): "1.2.1 (pre-BYOV)",
            t["impl_1_3_0"].lower(): "1.3.0 (BYOV)",
        }.get(cur.lower(), "UNKNOWN")
        print(f"  current impl : {cur}  -> {label}")

        ups = scan_logs(rm, T_UPGRADED, 0, head)
        inits = scan_logs(rm, T_INITIALIZE, 0, head)
        upgrade_block = None
        print("\n  Proxy history:")
        for lg in ups:
            impl = "0x" + lg["topics"][1][-40:]
            blk = int(lg["blockNumber"], 16)
            tag = "  <-- BYOV v1.3.0" if impl.lower() == t["impl_1_3_0"].lower() else ""
            if tag:
                upgrade_block = blk
            print(f"    block {blk:>9}  Upgraded -> {impl}{tag}")
        for lg in inits:
            d = lg["data"][2:]
            v = int(d[0:64], 16)
            off = int(d[64:128], 16) * 2
            sel = d[off + 64 : off + 64 + 8]
            fn = {SEL_INIT_V1: "initializeRedeemManagerV1(address)", SEL_INIT_V1_2: "initializeRedeemManagerV1_2()"}.get(
                sel, "?"
            )
            print(f"    block {int(lg['blockNumber'],16):>9}  Initialize(version={v})  0x{sel}  {fn}")

        if upgrade_block is None:
            print("\n  >> BYOV v1.3.0 upgrade NOT executed on this network.")
            cutoff = head
        else:
            cutoff = upgrade_block - 1

        # Reconstruct the queue as it stood at `cutoff` from events (no archive node available).
        reqs = {}
        for lg in scan_logs(rm, T_REQUESTED, 0, cutoff):
            w = words(lg["data"])
            rid = w[3]
            reqs[rid] = {
                "recipient": "0x" + lg["topics"][1][-40:],
                "height": w[0],
                "size": w[1],
                "maxRedeemableEth": w[2],
                "remaining": w[1],
                "block": int(lg["blockNumber"], 16),
            }
        for lg in scan_logs(rm, T_CLAIMED, 0, cutoff):
            rid = int(lg["topics"][1], 16)
            w = words(lg["data"])
            if rid in reqs:
                reqs[rid]["remaining"] = w[2]  # remainingLsEthAmount

        total = len(reqs)
        open_ids = sorted(i for i, r in reqs.items() if r["remaining"] > 0)
        print(f"\n  --- redeem queue at BYOV upgrade time (block {cutoff}) ---")
        print(f"  requests ever created        : {total}")
        print(f"  OPEN (unclaimed remainder)   : {len(open_ids)}")
        print(f"  fully claimed                : {total - len(open_ids)}")
        if open_ids:
            tot = sum(reqs[i]["remaining"] for i in open_ids)
            print(f"  total open LsETH             : {eth(tot)} LsETH")
            print(f"\n  {'id':>4} {'remaining LsETH':>20} {'original size':>20} {'height':>20}  recipient")
            for i in open_ids:
                r = reqs[i]
                print(
                    f"  {i:>4} {eth(r['remaining']):>20} {eth(r['size']):>20} {eth(r['height']):>20}"
                    f"  {r['recipient']}"
                )

        # Post-upgrade on-chain reality.
        if upgrade_block is not None:
            cnt = int(call(rm, SEL_COUNT, "latest"), 16)
            print(f"\n  --- same queue NOW (block {head}, post-upgrade) ---")
            print(f"  getRedeemRequestCount() = {cnt}")
            corrupted = []
            for i in range(cnt):
                r = dec_request(call(rm, SEL_DETAILS + f"{i:064x}", "latest"))
                pre = reqs.get(i)
                flag = ""
                if pre:
                    if r["amount"] != pre["remaining"] or r["recipient"].lower() != pre["recipient"].lower():
                        flag = "  <-- CORRUPTED"
                        corrupted.append(i)
                print(
                    f"  {i:>4} amount={eth(r['amount']):>26}  height={eth(r['height']):>26}"
                    f"  recipient={r['recipient']}{flag}"
                )
            print(f"\n  corrupted request ids: {corrupted if corrupted else 'none'}")
            print(
                f"  of which still open at upgrade time: "
                f"{sorted(set(corrupted) & set(open_ids)) if corrupted else 'none'}"
            )


if __name__ == "__main__":
    sys.exit(main())
