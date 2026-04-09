// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "forge-std/Test.sol";

import "../src/libraries/BLS12_381.sol";
import "../src/libraries/LibUint256.sol";

/// @title BLS12_381SSZHarness
/// @notice Exposes BLS12_381 internal pure functions for SSZ correctness testing.
contract BLS12_381SSZHarness {
    function computeDepositDomain(bytes4 genesisForkVersion) external pure returns (bytes32) {
        return BLS12_381.computeDepositDomain(genesisForkVersion);
    }

    /// @dev Expose _computeSigningRoot via a calldata-forwarding wrapper.
    function computeSigningRoot(bytes calldata pubkey, uint256 amount, bytes32 wc, bytes32 domain)
        external
        pure
        returns (bytes32)
    {
        return BLS12_381._computeSigningRoot(pubkey, amount, wc, domain);
    }
}

/// @title BLS12_381SSZTest
/// @notice Pure unit tests (no fork required) demonstrating two SSZ serialization bugs
///         in BLS12_381.sol's computeDepositDomain and _computeSigningRoot.
///
///         Bug A: computeDepositDomain hashes 32 bytes instead of 64 for ForkData root.
///         Bug B: _computeSigningRoot hashes 56 bytes instead of 64 for the amount subtree.
///
/// References:
///   - Ethereum consensus spec — ForkData:
///     https://github.com/ethereum/consensus-specs/blob/dev/specs/phase0/beacon-chain.md#forkdata
///   - Ethereum consensus spec — compute_domain:
///     https://github.com/ethereum/consensus-specs/blob/dev/specs/phase0/beacon-chain.md#compute_domain
///   - Ethereum consensus spec — DepositMessage:
///     https://github.com/ethereum/consensus-specs/blob/dev/specs/phase0/beacon-chain.md#depositmessage
///   - SSZ merkleization:
///     https://github.com/ethereum/consensus-specs/blob/dev/ssz/simple-serialize.md#merkleization
contract BLS12_381SSZTest is Test {
    BLS12_381SSZHarness internal harness;

    function setUp() public {
        harness = new BLS12_381SSZHarness();
    }

    // -----------------------------------------------------------------------
    // Bug A: computeDepositDomain — ForkData root uses 32 bytes instead of 64
    // -----------------------------------------------------------------------

    /// @notice sha256 of 32 bytes != sha256 of 64 bytes, proving the omitted
    ///         genesis_validators_root chunk changes the result.
    function test_bugA_forkDataRoot_32vs64bytes() public {
        bytes4 forkVersion = bytes4(0x00000000); // mainnet

        // Current (buggy): only 32 bytes — just the fork_version chunk
        bytes32 hash32 = sha256(abi.encodePacked(forkVersion, bytes28(0)));

        // Correct: 64 bytes — fork_version chunk + genesis_validators_root chunk
        bytes32 hash64 = sha256(abi.encodePacked(forkVersion, bytes28(0), bytes32(0)));

        assertTrue(
            hash32 != hash64,
            "BUG A: sha256(32 bytes) != sha256(64 bytes) - the missing genesis_validators_root chunk changes the ForkData root"
        );
    }

    /// @notice The current computeDepositDomain does NOT match the spec-correct domain.
    ///         Spec: domain = DOMAIN_DEPOSIT || hash_tree_root(ForkData)[0:28]
    ///         where hash_tree_root(ForkData) = sha256(forkVersion||28zeros || genesisValidatorsRoot)
    ///         and genesisValidatorsRoot = bytes32(0) for DOMAIN_DEPOSIT.
    function test_bugA_computeDepositDomain_doesNotMatchSpec() public {
        bytes4 forkVersion = bytes4(0x00000000); // mainnet genesis fork version

        // Spec-correct computation
        bytes32 correctForkDataRoot = sha256(abi.encodePacked(forkVersion, bytes28(0), bytes32(0)));
        bytes32 correctDomain = bytes32(BLS12_381.DEPOSIT_DOMAIN_TYPE) | (correctForkDataRoot >> 32);

        // Current (buggy) computation
        bytes32 buggyDomain = harness.computeDepositDomain(forkVersion);

        assertTrue(
            buggyDomain != correctDomain,
            "BUG A: computeDepositDomain produces wrong domain - hashes 32 bytes instead of 64 for ForkData"
        );

        // Log for visibility
        emit log_named_bytes32("Buggy domain  (32-byte ForkData hash)", buggyDomain);
        emit log_named_bytes32("Correct domain (64-byte ForkData hash)", correctDomain);
    }

    /// @notice Verify with a non-zero fork version too (e.g., Holesky 0x01017000).
    function test_bugA_computeDepositDomain_holeskyForkVersion() public {
        bytes4 forkVersion = bytes4(0x01017000); // Holesky

        bytes32 correctForkDataRoot = sha256(abi.encodePacked(forkVersion, bytes28(0), bytes32(0)));
        bytes32 correctDomain = bytes32(BLS12_381.DEPOSIT_DOMAIN_TYPE) | (correctForkDataRoot >> 32);

        bytes32 buggyDomain = harness.computeDepositDomain(forkVersion);

        assertTrue(
            buggyDomain != correctDomain,
            "BUG A: also fails for Holesky fork version"
        );
    }

    // -----------------------------------------------------------------------
    // Bug B: _computeSigningRoot — amount subtree uses 56 bytes instead of 64
    // -----------------------------------------------------------------------

    /// @notice sha256 of 56 bytes != sha256 of 64 bytes for the amount leaf + padding leaf.
    function test_bugB_amountChunk_56vs64bytes() public {
        uint256 amountGwei = 32_000_000_000; // 32 ETH in gwei
        bytes32 amountLE = bytes32(LibUint256.toLittleEndian64(amountGwei));

        // Current (buggy): 56 bytes
        bytes32 hash56 = sha256(abi.encodePacked(amountLE, bytes24(0)));

        // Correct: 64 bytes — amount chunk (32) + zero padding leaf (32)
        bytes32 hash64 = sha256(abi.encodePacked(amountLE, bytes32(0)));

        assertTrue(
            hash56 != hash64,
            "BUG B: sha256(56 bytes) != sha256(64 bytes) - the short padding changes the amount subtree hash"
        );
    }

    /// @notice The current _computeSigningRoot does NOT match the spec-correct signing root.
    ///         DepositMessage has 3 fields → SSZ pads to 4 leaves:
    ///           leaf0 = pubkeyRoot, leaf1 = withdrawalCredentials,
    ///           leaf2 = amount (8 LE bytes + 24 zeros), leaf3 = bytes32(0)
    ///         depositMessageRoot = sha256(sha256(leaf0||leaf1), sha256(leaf2||leaf3))
    ///         signingRoot = sha256(depositMessageRoot || domain)
    function test_bugB_computeSigningRoot_doesNotMatchSpec() public {
        // Known test inputs
        bytes memory pubkey = hex"a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1";
        uint256 amount = 32 ether;
        bytes32 wc = bytes32(uint256(0x010000000000000000000000CAFEBABE));
        bytes32 domain = bytes32(uint256(0x03000000));

        // Spec-correct computation
        uint256 amountGwei = amount / 1 gwei;
        bytes32 pubkeyRoot = sha256(abi.encodePacked(pubkey, bytes16(0)));
        bytes32 amountLE = bytes32(LibUint256.toLittleEndian64(amountGwei));

        bytes32 correctDepositMessageRoot = sha256(
            abi.encodePacked(
                sha256(abi.encodePacked(pubkeyRoot, wc)),
                sha256(abi.encodePacked(amountLE, bytes32(0))) // 64 bytes: amount chunk + zero leaf
            )
        );
        bytes32 correctSigningRoot = sha256(abi.encodePacked(correctDepositMessageRoot, domain));

        // Current (buggy) computation
        bytes32 buggySigningRoot = harness.computeSigningRoot(pubkey, amount, wc, domain);

        assertTrue(
            buggySigningRoot != correctSigningRoot,
            "BUG B: _computeSigningRoot produces wrong root - hashes 56 bytes instead of 64 for amount subtree"
        );

        emit log_named_bytes32("Buggy signing root  (56-byte amount hash)", buggySigningRoot);
        emit log_named_bytes32("Correct signing root (64-byte amount hash)", correctSigningRoot);
    }

    /// @notice Verify the bug with different amount values.
    function test_bugB_computeSigningRoot_variousAmounts() public {
        bytes memory pubkey = hex"b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2";
        bytes32 wc = bytes32(uint256(0x01));
        bytes32 domain = bytes32(uint256(0x03000000));

        uint256[3] memory amounts = [uint256(1 ether), uint256(32 ether), uint256(2048 ether)];

        for (uint256 i = 0; i < amounts.length; i++) {
            uint256 amountGwei = amounts[i] / 1 gwei;
            bytes32 pubkeyRoot = sha256(abi.encodePacked(pubkey, bytes16(0)));
            bytes32 amountLE = bytes32(LibUint256.toLittleEndian64(amountGwei));

            bytes32 correctRoot = sha256(
                abi.encodePacked(
                    sha256(abi.encodePacked(pubkeyRoot, wc)),
                    sha256(abi.encodePacked(amountLE, bytes32(0)))
                )
            );
            bytes32 correctSigningRoot = sha256(abi.encodePacked(correctRoot, domain));

            bytes32 buggySigningRoot = harness.computeSigningRoot(pubkey, amounts[i], wc, domain);

            assertTrue(
                buggySigningRoot != correctSigningRoot,
                "BUG B: signing root mismatch for all tested amounts"
            );
        }
    }
}
