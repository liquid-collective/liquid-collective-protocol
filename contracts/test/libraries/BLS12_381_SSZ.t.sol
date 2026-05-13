// SPDX-License-Identifier: CC0-1.0
pragma solidity 0.8.34;

import {Test} from "forge-std/Test.sol";
import {BLS12_381} from "../../src/libraries/BLS12_381.sol";
import {LibUint256} from "../../src/libraries/LibUint256.sol";

/// @dev Thin harness to expose internal library functions for testing.
contract BLS12_381Harness {
    function computeDepositDomain(bytes4 genesisForkVersion) external view returns (bytes32) {
        return BLS12_381.computeDepositDomain(genesisForkVersion);
    }

    function computeSigningRoot(bytes calldata pubkey, uint256 amount, bytes32 wc, bytes32 domain)
        external
        view
        returns (bytes32)
    {
        return BLS12_381.depositMessageSigningRoot(pubkey, amount, wc, domain);
    }
}

contract BLS12_381_SSZTest is Test {
    BLS12_381Harness harness;

    function setUp() public {
        harness = new BLS12_381Harness();
    }

    // -----------------------------------------------------------------------
    // computeDepositDomain must hash 64 bytes (two SSZ leaves).
    //
    // Ethereum consensus spec (phase0):
    //   ForkData = Container(current_version: Version, genesis_validators_root: Root)
    //   hash_tree_root(ForkData) = sha256(
    //       current_version || bytes28(0)   <- 32-byte leaf 0
    //       genesis_validators_root         <- 32-byte leaf 1 (zero for deposit domain)
    //   )
    // -----------------------------------------------------------------------
    function test_computeDepositDomain_matchesSpec() public {
        bytes4 mainnetFork = 0x00000000;

        // Spec-correct: sha256 over 64 bytes (two SSZ leaves)
        bytes32 correctForkDataRoot = sha256(abi.encodePacked(mainnetFork, bytes28(0), bytes32(0)));
        bytes32 expectedDomain = bytes32(bytes4(0x03000000)) | (correctForkDataRoot >> 32);

        bytes32 actualDomain = harness.computeDepositDomain(mainnetFork);
        assertEq(actualDomain, expectedDomain, "computeDepositDomain does not match spec ForkData SSZ encoding");
    }

    function test_computeDepositDomain_holeskyFork() public {
        bytes4 holeskyFork = 0x01017000;

        bytes32 correctForkDataRoot = sha256(abi.encodePacked(holeskyFork, bytes28(0), bytes32(0)));
        bytes32 expectedDomain = bytes32(bytes4(0x03000000)) | (correctForkDataRoot >> 32);

        bytes32 actualDomain = harness.computeDepositDomain(holeskyFork);
        assertEq(actualDomain, expectedDomain, "computeDepositDomain holesky does not match spec");
    }

    // -----------------------------------------------------------------------
    // _computeSigningRoot amount node must hash 64 bytes.
    //
    // DepositMessage = Container(pubkey, withdrawal_credentials, amount)
    //   3 fields -> 4 SSZ leaves (padded to next power of 2):
    //     leaf0 = sha256(pubkey || bytes16(0))
    //     leaf1 = withdrawal_credentials
    //     leaf2 = amount_LE_padded_to_32_bytes
    //     leaf3 = bytes32(0)              (virtual zero leaf)
    //   depositMessageRoot = sha256(sha256(leaf0 || leaf1), sha256(leaf2 || leaf3))
    //   signingRoot = sha256(depositMessageRoot || domain)
    // -----------------------------------------------------------------------
    function test_computeSigningRoot_matchesSpec() public {
        bytes memory pubkey = new bytes(48);
        pubkey[0] = 0xab;
        bytes32 wc = keccak256("withdrawal_credentials");
        bytes32 domain = keccak256("domain");
        uint256 amount = 32 ether;
        uint256 amountGwei = amount / 1 gwei;

        // Spec-correct computation inline
        bytes32 pubkeyRoot = sha256(abi.encodePacked(pubkey, bytes16(0)));
        bytes32 amountChunk = bytes32(LibUint256.toLittleEndian64(amountGwei));
        bytes32 specDepositMessageRoot = sha256(
            abi.encodePacked(
                sha256(abi.encodePacked(pubkeyRoot, wc)), sha256(abi.encodePacked(amountChunk, bytes32(0)))
            )
        );
        bytes32 expectedSigningRoot = sha256(abi.encodePacked(specDepositMessageRoot, domain));

        bytes32 actualSigningRoot = harness.computeSigningRoot(pubkey, amount, wc, domain);
        assertEq(actualSigningRoot, expectedSigningRoot, "signing root does not match spec SSZ encoding");
    }

    function test_computeSigningRoot_1ETH() public {
        bytes memory pubkey = new bytes(48);
        bytes32 wc = bytes32(uint256(1));
        bytes32 domain = bytes32(uint256(0xdeadbeef));
        uint256 amount = 1 ether;
        uint256 amountGwei = amount / 1 gwei;

        bytes32 pubkeyRoot = sha256(abi.encodePacked(pubkey, bytes16(0)));
        bytes32 amountChunk = bytes32(LibUint256.toLittleEndian64(amountGwei));
        bytes32 specDepositMessageRoot = sha256(
            abi.encodePacked(
                sha256(abi.encodePacked(pubkeyRoot, wc)), sha256(abi.encodePacked(amountChunk, bytes32(0)))
            )
        );
        bytes32 expectedSigningRoot = sha256(abi.encodePacked(specDepositMessageRoot, domain));

        bytes32 actualSigningRoot = harness.computeSigningRoot(pubkey, amount, wc, domain);
        assertEq(actualSigningRoot, expectedSigningRoot, "signing root does not match spec for 1 ETH deposit");
    }
}
