//SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.20;

import "forge-std/Test.sol";

import "../../src/River.1.sol";
import "../../src/state/river/DailyCommittableLimits.sol";
import "../../src/state/river/LastConsensusLayerReport.sol";
import "../../src/state/shared/RiverAddress.sol";

/// @title Integration Test Helpers
/// @author Alluvial Finance Inc.
/// @notice Helper Functions that are reused throughout the integration tests
contract IntegrationTestHelpers is Test {
    /// @notice Mocks the daily committable limit for the River contract
    function mockDailyCommittableLimit(
        address riverProxy,
        uint128 maxDailyRelativeCommittable,
        uint128 minDailyNetCommittableAmount
    ) internal {
        bytes32 baseSlot = DailyCommittableLimits.DAILY_COMMITTABLE_LIMITS_SLOT;
        bytes32 packedValues =
            bytes32((uint256(minDailyNetCommittableAmount) << 128) | uint256(maxDailyRelativeCommittable));
        vm.store(address(riverProxy), baseSlot, packedValues);
    }

    /// @notice Mocks the contract state such that the epoch is valid
    function mockValidEpoch(
        address riverProxy,
        uint256 initBlockTimestamp,
        uint256 _frame,
        IOracleManagerV1.ConsensusLayerReport memory clr
    ) internal {
        // set the current epoch
        uint256 blockTimestamp = initBlockTimestamp + _frame;
        vm.warp(blockTimestamp);
        uint256 expectedEpoch = RiverV1(payable(address(riverProxy))).getExpectedEpochId();
        // set valid epoch
        clr.epoch = expectedEpoch;
        // set the storage for the LastConsensusLayerReport.get().epoch
        bytes32 storageSlot = LastConsensusLayerReport.LAST_CONSENSUS_LAYER_REPORT_SLOT;
        uint256 mockLastCLEpoch = clr.epoch - 1;
        vm.store(address(riverProxy), storageSlot, bytes32(mockLastCLEpoch));
    }

    /// @notice Mocks the withdrawal river address to pull CL funds
    function mockWithdrawalRiverAddress(address withdraw, address riverProxy) internal {
        bytes32 second_storageSlot = RiverAddress.RIVER_ADDRESS_SLOT;
        vm.store(address(withdraw), second_storageSlot, bytes32(uint256(uint160(address(riverProxy)))));
    }

    /// @notice Mocks the previous report balances
    function mockPreviousValidatorReportBalances(
        address riverProxy,
        uint256 preReportValidatorsBalance,
        uint256 preReportSkimmedBalance,
        uint256 preReportValidatorsCount
    ) internal {
        bytes32 baseSlot = LastConsensusLayerReport.LAST_CONSENSUS_LAYER_REPORT_SLOT;
        bytes32 validatorsBalanceSlot = bytes32(uint256(baseSlot) + 1);
        bytes32 validatorsSkimmedBalanceSlot = bytes32(uint256(baseSlot) + 2);
        bytes32 validatorsCountSlot = bytes32(uint256(baseSlot) + 5);
        uint256 mockValidatorsBalance = preReportValidatorsBalance;
        uint256 mockValidatorsSkimmedBalance = preReportSkimmedBalance;
        vm.store(riverProxy, validatorsBalanceSlot, bytes32(mockValidatorsBalance));
        vm.store(riverProxy, validatorsSkimmedBalanceSlot, bytes32(mockValidatorsSkimmedBalance));
        vm.store(riverProxy, validatorsCountSlot, bytes32(uint256(preReportValidatorsCount)));
    }
}
