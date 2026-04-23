//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../state/operatorsRegistry/Operators.3.sol";

/// @title Operators Registry Interface (v1)
/// @author Alluvial Finance Inc.
/// @notice This interface exposes methods to handle the list of operators
interface IOperatorsRegistryV1 {
    /// @notice Structure representing a validator deposit
    /// @param operatorIndex The index of the operator
    /// @param pubkey The BLS public key of the validator
    /// @param signature The BLS signature of the validator
    /// @param depositAmount The deposit amount in ETH
    struct ValidatorDeposit {
        uint256 operatorIndex;
        bytes pubkey; // 48 bytes
        bytes signature; // 96 bytes
        uint256 depositAmount; // deposit amount in wei (currently exactly 32 ETH)
    }

    /// @notice Structure representing an operator allocation for exit requests
    /// @param operatorIndex The index of the operator
    /// @param validatorCount The number of validators
    struct OperatorAllocation {
        uint256 operatorIndex;
        uint256 validatorCount;
    }

    /// @notice A new operator has been added to the registry
    /// @param index The operator index
    /// @param name The operator display name
    /// @param operatorAddress The operator address
    event AddedOperator(uint256 indexed index, string name, address indexed operatorAddress);

    /// @notice The operator status has been changed
    /// @param index The operator index
    /// @param active True if the operator is active
    event SetOperatorStatus(uint256 indexed index, bool active);

    /// @notice The operator stopped validator count has been changed
    /// @param index The operator index
    /// @param newStoppedValidatorCount The new stopped validator count
    event SetOperatorStoppedValidatorCount(uint256 indexed index, uint256 newStoppedValidatorCount);

    /// @notice The operator address has been changed
    /// @param index The operator index
    /// @param newOperatorAddress The new operator address
    event SetOperatorAddress(uint256 indexed index, address indexed newOperatorAddress);

    /// @notice The operator display name has been changed
    /// @param index The operator index
    /// @param newName The new display name
    event SetOperatorName(uint256 indexed index, string newName);

    /// @notice The stored river address has been changed
    /// @param river The new river address
    event SetRiver(address indexed river);

    /// @notice The stopped validator array has been changed
    /// @notice A validator is considered stopped if exiting, exited or slashed
    /// @notice This event is emitted when the oracle reports new stopped validators counts
    /// @param stoppedValidatorCounts The new stopped validator counts
    event UpdatedStoppedValidators(uint32[] stoppedValidatorCounts);

    /// @notice The funded validator keys of an operator have been updated
    /// @param index The operator index
    /// @param publicKeys The list of funded public keys
    /// @param deferred Whether the event was emitted as part of a deferred (migration) process
    event FundedValidatorKeys(uint256 indexed index, bytes[] publicKeys, bool deferred);

    /// @notice The requested exit count has been updated
    /// @param index The operator index
    /// @param count The count of requested exits
    event RequestedValidatorExits(uint256 indexed index, uint256 count);

    /// @notice The exit request demand has been updated
    /// @param previousValidatorExitsDemand The previous exit request demand
    /// @param nextValidatorExitsDemand The new exit request demand
    event SetCurrentValidatorExitsDemand(uint256 previousValidatorExitsDemand, uint256 nextValidatorExitsDemand);

    /// @notice The total requested exit has been updated
    /// @param previousTotalValidatorExitsRequested The previous total requested exit
    /// @param newTotalValidatorExitsRequested The new total requested exit
    event SetTotalValidatorExitsRequested(
        uint256 previousTotalValidatorExitsRequested, uint256 newTotalValidatorExitsRequested
    );

    /// @notice The requested exit count has been updated to fill the gap with the reported stopped count
    /// @param index The operator index
    /// @param oldRequestedExits The old requested exit count
    /// @param newRequestedExits The new requested exit count
    event UpdatedRequestedValidatorExitsUponStopped(
        uint256 indexed index, uint32 oldRequestedExits, uint32 newRequestedExits
    );

    /// @notice The calling operator is inactive
    /// @param index The operator index
    error InactiveOperator(uint256 index);

    /// @notice The provided operator and limits array are empty
    error InvalidEmptyArray();

    /// @notice The provided list of operators is not in increasing order
    error UnorderedOperatorList();

    /// @notice Thrown when an operator ignored the required number of requested exits
    /// @param operatorIndex The operator index
    error OperatorIgnoredExitRequests(uint256 operatorIndex);

    /// @notice Thrown when an allocation with zero validator count is provided
    error AllocationWithZeroValidatorCount();

    /// @notice Thrown when an invalid empty stopped validator array is provided
    error InvalidEmptyStoppedValidatorCountsArray();

    /// @notice Thrown when the sum of stopped validators is invalid
    error InvalidStoppedValidatorCountsSum();

    /// @notice Thrown when an element in the stopped validator array is decreasing
    error StoppedValidatorCountsDecreased();

    /// @notice Thrown when the number of elements in the array is too high compared to operator count
    error StoppedValidatorCountsTooHigh();

    /// @notice Thrown when no exit requests can be performed
    error NoExitRequestsToPerform();

    /// @notice The provided stopped validator count array is shrinking
    error StoppedValidatorCountArrayShrinking();

    /// @notice The provided stopped validator count of an operator is above its funded validator count
    error StoppedValidatorCountAboveFundedCount(uint256 operatorIndex, uint32 stoppedCount, uint32 fundedCount);

    /// @notice The provided exit requests exceed the available funded validator count of the operator
    /// @param operatorIndex The operator index
    /// @param requested The requested count
    /// @param available The available count
    error ExitsRequestedExceedAvailableFundedCount(uint256 operatorIndex, uint256 requested, uint256 available);

    /// @notice The provided exit requests exceed the current exit request demand
    /// @param requested The requested count
    /// @param demand The demand count
    error ExitsRequestedExceedDemand(uint256 requested, uint256 demand);

    /// @notice Initializes the operators registry
    /// @param _admin Admin in charge of managing operators
    /// @param _river Address of River system
    function initOperatorsRegistryV1(address _admin, address _river) external;

    /// @notice Initializes the operators registry for V1_1
    function initOperatorsRegistryV1_1() external;

    /// @notice Migrates operators from V2 to V3 storage, dropping key-management fields
    function initOperatorsRegistryV1_2() external;

    /// @notice Retrieve the River address
    /// @return The address of River
    function getRiver() external view returns (address);

    /// @notice Get operator details
    /// @param _index The index of the operator
    /// @return The details of the operator
    function getOperator(uint256 _index) external view returns (OperatorsV3.Operator memory);

    /// @notice Get operator count
    /// @return The operator count
    function getOperatorCount() external view returns (uint256);

    /// @notice Retrieve the stopped validator count for an operator index
    /// @param _idx The index of the operator
    /// @return The stopped validator count of the operator
    function getOperatorStoppedValidatorCount(uint256 _idx) external view returns (uint32);

    /// @notice Retrieve the total stopped validator count
    /// @return The total stopped validator count
    function getTotalStoppedValidatorCount() external view returns (uint32);

    /// @notice Retrieve the total requested exit count
    /// @notice This value is the amount of exit requests that have been performed, emitting an event for operators to catch
    /// @return The total requested exit count
    function getTotalValidatorExitsRequested() external view returns (uint256);

    /// @notice Get the current exit request demand waiting to be triggered
    /// @notice This value is the amount of exit requests that are demanded and not yet performed by the contract
    /// @return The current exit request demand
    function getCurrentValidatorExitsDemand() external view returns (uint256);

    /// @notice Retrieve the total stopped and requested exit count
    /// @return The total stopped count
    /// @return The total requested exit count
    function getStoppedAndRequestedExitCounts() external view returns (uint32, uint256);

    /// @notice Retrieve the raw stopped validators array from storage
    /// @return The stopped validator array
    function getStoppedValidatorCountPerOperator() external view returns (uint32[] memory);

    /// @notice Retrieve the active operator set
    /// @return The list of active operators and their details
    function listActiveOperators() external view returns (OperatorsV3.Operator[] memory);

    /// @notice Allows river to override the stopped validators array
    /// @notice This actions happens during the Oracle report processing
    /// @param _stoppedValidatorCounts The new stopped validators array
    /// @param _depositedValidatorCount The total deposited validator count
    function reportStoppedValidatorCounts(uint32[] calldata _stoppedValidatorCounts, uint256 _depositedValidatorCount)
        external;

    /// @notice Adds an operator to the registry
    /// @dev Only callable by the administrator
    /// @param _name The name identifying the operator
    /// @param _operator The address representing the operator, receiving the rewards
    /// @return The index of the new operator
    function addOperator(string calldata _name, address _operator) external returns (uint256);

    /// @notice Changes the operator address of an operator
    /// @dev Only callable by the administrator or the previous operator address
    /// @param _index The operator index
    /// @param _newOperatorAddress The new address of the operator
    function setOperatorAddress(uint256 _index, address _newOperatorAddress) external;

    /// @notice Changes the operator name
    /// @dev Only callable by the administrator or the operator
    /// @param _index The operator index
    /// @param _newName The new operator name
    function setOperatorName(uint256 _index, string calldata _newName) external;

    /// @notice Changes the operator status
    /// @dev Only callable by the administrator
    /// @param _index The operator index
    /// @param _newStatus The new status of the operator
    function setOperatorStatus(uint256 _index, bool _newStatus) external;

    /// @notice Process explicit per-operator exit allocations and update operator requestedExits
    /// @dev Only callable by the keeper address returned by the River contract's getKeeper()
    /// @dev The allocations must be sorted by operator index in strictly ascending order with no duplicates
    /// @dev Each allocation's validatorCount must be non-zero and not exceed the operator's available funded-but-not-yet-exited validators
    /// @dev The total requested exits across all allocations must not exceed the current validator exit demand
    /// @dev Reverts with InvalidEmptyArray if _allocations is empty
    /// @dev Reverts with AllocationWithZeroValidatorCount if any allocation has a zero validator count
    /// @dev Reverts with UnorderedOperatorList if operator indexes are not strictly ascending
    /// @dev Reverts with InactiveOperator if a referenced operator is inactive
    /// @dev Reverts with ExitsRequestedExceedAvailableFundedCount if count exceeds funded minus requestedExits for an operator
    /// @dev Reverts with ExitsRequestedExceedDemand if total exits requested exceed the current demand
    /// @dev Reverts with NoExitRequestsToPerform if there is no pending exit demand
    /// @param _allocations The proposed per-operator exit allocations, sorted by operator index
    function requestValidatorExits(OperatorAllocation[] calldata _allocations) external;

    /// @notice Increment the funded validator count for an operator
    /// @dev Only callable by the River contract. Called once per distinct operator during deposit.
    /// @param _operatorIndex The operator index
    /// @param _publicKeys The public keys of the newly funded validators
    function incrementFundedValidators(uint256 _operatorIndex, bytes[] calldata _publicKeys) external;

    /// @notice Increases the exit request demand
    /// @dev This method is only callable by the river contract, and to actually forward the information to the node operators via event emission, the unprotected requestValidatorExits method must be called
    /// @param _count The amount of exit requests to add to the demand
    /// @param _depositedValidatorCount The total deposited validator count
    function demandValidatorExits(uint256 _count, uint256 _depositedValidatorCount) external;
}
