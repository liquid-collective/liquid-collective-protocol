// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../src/interfaces/IDepositDataBuffer.sol";
import "../../src/libraries/BLS12_381.sol";

/// @title DepositDataBufferFixtures
/// @notice Shared deterministic builders for DepositDataBuffer test suites (unit, fuzz, invariant),
///         so the pubkey/signature/deposit/top-up/batch fixtures are defined once. Amounts are
///         non-zero and gwei-aligned (bounded by `seed % 1 gwei` so arbitrarily large fuzz seeds
///         never overflow), satisfying the buffer's submit-time validation.
abstract contract DepositDataBufferFixtures {
    function _pubkey(uint256 seed) internal pure returns (bytes memory) {
        return abi.encodePacked(sha256(abi.encode("pubkey", seed)), bytes16(0));
    }

    function _signature(uint256 seed) internal pure returns (bytes memory) {
        return abi.encodePacked(sha256(abi.encode("sig", seed)), sha256(abi.encode("sig2", seed)), bytes32(0));
    }

    function _deposit(uint256 seed) internal pure returns (IDepositDataBuffer.Deposit memory) {
        BLS12_381.DepositY memory depositY;
        return IDepositDataBuffer.Deposit({
            pubkey: _pubkey(seed),
            signature: _signature(seed),
            amount: 32 ether + (seed % 1 gwei) * 1 gwei,
            operatorIdx: seed % 5,
            depositY: depositY
        });
    }

    function _topUp(uint256 seed) internal pure returns (IDepositDataBuffer.TopUp memory) {
        return IDepositDataBuffer.TopUp({
            pubkey: _pubkey(seed), amount: 1 ether + (seed % 1 gwei) * 1 gwei, operatorIdx: seed % 5
        });
    }

    /// @dev A deposits-only batch of `count` initial deposits seeded from 0.
    function _batch(uint256 count) internal pure returns (IDepositDataBuffer.DepositObject memory batch) {
        return _batch(count, 0);
    }

    /// @dev A deposits-only batch of `count` initial deposits seeded from `seedBase`.
    function _batch(uint256 count, uint256 seedBase)
        internal
        pure
        returns (IDepositDataBuffer.DepositObject memory batch)
    {
        batch.deposits = new IDepositDataBuffer.Deposit[](count);
        for (uint256 i = 0; i < count; i++) {
            batch.deposits[i] = _deposit(seedBase + i);
        }
    }
}
