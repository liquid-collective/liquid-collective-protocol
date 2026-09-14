// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {VmSafe} from "forge-std/Vm.sol";

import {BLS12_381} from "../../../src/libraries/BLS12_381.sol";
import {BLSSigner} from "../BLSSigner.sol";

/**
 * @title BLSCrosscheckVectors
 * @notice Emits deposit signatures for `scripts/bls-crosscheck.js` to compare against noble-curves.
 * @dev A script rather than a test on purpose: it asserts nothing (the comparison happens in JS),
 *      and as a `*.t.sol` its 12 vectors would add noise to every `npm test` run, which uses
 *      `-vvv` and therefore prints logs.
 *
 *      Prints one space-separated record per line:
 *      `XCHK <seed> <amount> <sk> <signingRoot> <pubkey> <signature>`
 *
 *      Run via `npm run bls:crosscheck`.
 */
contract BLSCrosscheckVectors is Script {
    bytes32 internal constant WITHDRAWAL_CREDENTIALS =
        0x02000000000000000000000000000000000000000000000000000000CAFEBABE;

    uint256 internal constant VECTOR_COUNT = 12;

    function run() external {
        BLSSigner signer = new BLSSigner();
        bytes32 domain = BLS12_381.computeDepositDomain(bytes4(0));

        for (uint256 seed = 0; seed < VECTOR_COUNT; ++seed) {
            // Spread over gwei-aligned amounts, including the 32 ETH minimum and larger
            // Pectra-era deposits, so the amount's little-endian encoding in the signing root is
            // exercised rather than one fixed value.
            uint256 amount = (32 + (seed * 171) % 2017) * 1 ether;

            uint256 sk = signer.secretKeyFromSeed(seed);
            BLSSigner.SignedDeposit memory signed = signer.signDeposit(sk, amount, WITHDRAWAL_CREDENTIALS, domain);
            bytes32 root = signer.depositMessageSigningRoot(signed.pubkey, amount, WITHDRAWAL_CREDENTIALS, domain);

            console.log(
                string.concat(
                    "XCHK ",
                    vm.toString(seed),
                    " ",
                    vm.toString(amount),
                    " ",
                    vm.toString(sk),
                    " ",
                    vm.toString(root),
                    " ",
                    vm.toString(signed.pubkey),
                    " ",
                    vm.toString(signed.signature)
                )
            );
        }
    }
}
