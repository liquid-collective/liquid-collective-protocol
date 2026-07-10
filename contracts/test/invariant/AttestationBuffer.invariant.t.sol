// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "forge-std/Test.sol";

import "../../src/AttestationBuffer.sol";
import "./handlers/AttestationBufferHandler.sol";

/// @title AttestationBufferInvariantTest
/// @notice Invariants for the AttestationBuffer signature-verifying relay. The handler always submits
///         valid, self-signed attestations, so every submission succeeds.
contract AttestationBufferInvariantTest is Test {
    AttestationBuffer internal buffer;
    AttestationBufferHandler internal handler;

    bytes32 internal constant EIP712_DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 internal constant NAME_HASH = keccak256("DepositToConsensusLayerValidation");
    bytes32 internal constant VERSION_HASH = keccak256("1");

    function setUp() public {
        bytes32 domainSeparator = keccak256(
            abi.encode(EIP712_DOMAIN_TYPEHASH, NAME_HASH, VERSION_HASH, block.chainid, makeAddr("river"))
        );
        buffer = new AttestationBuffer(domainSeparator);
        handler = new AttestationBufferHandler(buffer, 0xA11CE, domainSeparator);

        targetContract(address(handler));

        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = AttestationBufferHandler.submit.selector;
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
    }

    /// @notice A1: lastAttestationIdx monotonically increases and equals the number of submissions.
    function invariant_indexEqualsSubmissions() public {
        assertEq(buffer.lastAttestationIdx(), handler.ghost_submissions(), "A1: lastAttestationIdx != submissions");
    }

    /// @notice A2: the buffer never holds ETH (it has no payable entry points).
    function invariant_neverHoldsEth() public {
        assertEq(address(buffer).balance, 0, "A2: buffer holds ETH");
    }
}
