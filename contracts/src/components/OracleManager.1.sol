//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../state/OracleAddress.sol";
import "../state/LastOracleRoundId.sol";
import "../state/BeaconValidatorBalanceSum.sol";
import "../state/BeaconValidatorCount.sol";
import "../state/DepositedValidatorCount.sol";
import "../libraries/Errors.sol";

/// @title Oracle Manager (v1)
/// @author Iulian Rotaru
/// @notice This contract handles the inputs provided by the oracle
abstract contract OracleManagerV1 {
    event BeaconDataUpdate(
        uint256 validatorCount,
        uint256 validatorBalanceSum,
        bytes32 roundId
    );

    error InvalidValidatorCountReport(
        uint256 _providedValidatorCount,
        uint256 _depositedValidatorCount
    );

    /// @notice Initializes the oracle address storage variable
    /// @param _oracleAddress Oracle address, allowed to send validator count and balance sum
    function oracleManagerInitializeV1(address _oracleAddress) internal {
        OracleAddress.set(_oracleAddress);
    }

    /// @notice Handler called if the delta between the last and new validator balance sum is positive
    /// @dev Must be overriden
    /// @param _profits The positive increase in the validator balance sum (staking rewards)
    function _onEarnings(uint256 _profits) internal virtual;

    /// @notice Sets the validator count and validator balance sum reported by the oracle
    /// @dev Can only be called by the oracle address
    /// @param _validatorCount The number of active validators on the consensus layer
    /// @param _validatorBalanceSum The validator balance sum of the active validators on the consensus layer
    /// @param _roundId An identifier for this update
    function setBeaconData(
        uint256 _validatorCount,
        uint256 _validatorBalanceSum,
        bytes32 _roundId
    ) external {
        if (msg.sender != OracleAddress.get()) {
            revert Errors.Unauthorized(msg.sender);
        }

        if (_validatorCount > DepositedValidatorCount.get()) {
            revert InvalidValidatorCountReport(
                _validatorCount,
                DepositedValidatorCount.get()
            );
        }

        uint256 previousValidatorBalanceSum = BeaconValidatorBalanceSum.get();
        uint256 newValidators = _validatorCount - BeaconValidatorCount.get();

        if (previousValidatorBalanceSum < _validatorBalanceSum) {
            _onEarnings(
                _validatorBalanceSum -
                    previousValidatorBalanceSum -
                    newValidators *
                    32 ether
            );
        }

        BeaconValidatorBalanceSum.set(_validatorBalanceSum);
        BeaconValidatorCount.set(_validatorCount);
        LastOracleRoundId.set(_roundId);

        emit BeaconDataUpdate(_validatorCount, _validatorBalanceSum, _roundId);
    }
}
