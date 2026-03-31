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

    /// @notice Structure representing an operator allocation for exits
    /// @param operatorIndex The index of the operator
    /// @param ethAmount The amount of ETH to exit for this operator
    struct ExitETHAllocation {
        uint256 operatorIndex;
        uint256 ethAmount;
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

    /// @notice The requested ETH amount has been updated
    /// @param index The operator index
    /// @param amount The amount of requested exits in ETH
    event RequestedETHExits(uint256 indexed index, uint256 amount);

    /// @notice The exit request demand has been updated
    /// @param previousETHExitsDemand The previous exit request demand
    /// @param nextETHExitsDemand The new exit request demand
    event SetCurrentETHExitsDemand(uint256 previousETHExitsDemand, uint256 nextETHExitsDemand);

    /// @notice The total requested exit has been updated
    /// @param previousTotalETHExitsRequested The previous total requested exit
    /// @param newTotalETHExitsRequested The new total requested exit
    event SetTotalETHExitsRequested(uint256 previousTotalETHExitsRequested, uint256 newTotalETHExitsRequested);

    /// @notice The requested ETH amount has been updated to fill the gap with the reported exited ETH amount
    /// @param index The operator index
    /// @param oldRequestedETHAmount The old requested ETH amount
    /// @param newRequestedETHAmount The new requested ETH amount
    event UpdatedRequestedETHExitsUponStopped(
        uint256 indexed index, uint256 oldRequestedETHAmount, uint256 newRequestedETHAmount
    );

    /// @notice The operator exited ETH has been set
    /// @param operatorIndex The operator index
    /// @param exitedETH The exited ETH
    event SetOperatorExitedETH(uint256 operatorIndex, uint256 exitedETH);

    /// @notice The exited ETH have been updated
    /// @param exitedETH The exited ETH
    event UpdatedExitedETH(uint256[] exitedETH);

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

    /// @notice Thrown when the sum of exited ETH is invalid
    error ExitedETHSumMismatch();

    /// @notice Thrown when an element in the exited ETH array is decreasing
    error ExitedETHPerOperatorDecreased();

    /// @notice Thrown when the amount of exited ETH is too high compared to the operator's funded ETH amount
    error DemandedETHExitsExceedsDepositedETH();

    /// @notice Thrown when the amount of exited ETH is too high compared to the total deposited ETH
    error ExitedETHExceedsDeposited();

    /// @notice Thrown when the number of exited ETH is too high compared to operator count
    error ExitedETHArrayLengthExceedsOperatorCount();

    /// @notice Thrown when no exit requests can be performed
    error NoExitRequestsToPerform();

    /// @notice The provided exited ETH array is shrinking
    error ExitedETHArrayShrinking();

    /// @notice The provided exit requests exceed the available funded ETH amount of the operator
    /// @param operatorIndex The operator index
    /// @param requested The requested ETH amount
    /// @param available The available ETH amount
    error ExitsRequestedExceedAvailableFundedAmount(uint256 operatorIndex, uint256 requested, uint256 available);

    /// @notice The provided exit requests exceed the current exit request demand
    /// @param requestedETHAmount The requested ETH amount
    /// @param currentETHExitsDemand The current ETH exits demand
    error ExitsRequestedExceedDemand(uint256 requestedETHAmount, uint256 currentETHExitsDemand);

    /// @notice The provided exited ETH is above the funded ETH of the operator
    /// @param operatorIndex The operator index
    /// @param exitedETH The exited ETH
    /// @param fundedETH The funded ETH
    error ExitedETHExceedsFundedETH(uint256 operatorIndex, uint256 exitedETH, uint256 fundedETH);

    /// @notice Thrown when an allocation with zero ETH amount is provided
    error AllocationWithZeroETHAmount();

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

    /// @notice Retrieve the total requested exit amount in ETH
    /// @notice This value is the amount of exit requests that have been performed, emitting an event for operators to catch
    /// @return The total requested exit amount in ETH
    function getTotalETHExitsRequested() external view returns (uint256);

    /// @notice Get the current exit request demand waiting to be triggered
    /// @notice This value is the amount of exit requests that are demanded and not yet performed by the contract
    /// @return The current exit request demand
    function getCurrentETHExitsDemand() external view returns (uint256);

    /// @notice Retrieve the total exited ETH and requested exit amount
    /// @return The total exited ETH
    /// @return The total requested exit amount (includes total requested exits and current exit demand)
    function getExitedETHAndRequestedExitAmounts() external view returns (uint256, uint256);

    /// @notice Retrieve the raw exited ETH array from storage
    /// @return The exited ETH array
    function getExitedETHPerOperator() external view returns (uint256[] memory);

    /// @notice Retrieve the active operator set
    /// @return The list of active operators and their details
    function listActiveOperators() external view returns (OperatorsV3.Operator[] memory);

    /// @notice Increments the funded ETH for the operators
    /// @param _fundedETH The array of funded ETH amounts
    function incrementFundedETH(uint256[] calldata _fundedETH) external;

    /// @notice Allows river to override the exited ETH array
    /// @notice This actions happens during the Oracle report processing
    /// @param _exitedETH The new exited ETH array
    /// @param _totalDepositedETH The total deposited ETH
    function reportExitedETH(uint256[] calldata _exitedETH, uint256 _totalDepositedETH) external;

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
    /// @dev Each allocation's ethAmount must be non-zero and not exceed the operator's available funded-but-not-yet-exited ETH amount
    /// @dev The total requested exits across all allocations must not exceed the current ETH exit demand
    /// @dev Reverts with InvalidEmptyArray if _allocations is empty
    /// @dev Reverts with AllocationWithZeroETHAmount if any allocation has a zero ETH amount
    /// @dev Reverts with UnorderedOperatorList if operator indexes are not strictly ascending
    /// @dev Reverts with InactiveOperator if a referenced operator is inactive
    /// @dev Reverts with ExitsRequestedExceedAvailableFundedAmount if count exceeds funded minus requestedExits for an operator
    /// @dev Reverts with ExitsRequestedExceedDemand if total exits requested exceed the current demand
    /// @dev Reverts with NoExitRequestsToPerform if there is no pending exit demand
    /// @param _allocations The proposed per-operator exit ETH allocations, sorted by operator index
    function requestValidatorExits(ExitETHAllocation[] calldata _allocations) external;

    /// @notice Increases the exit request demand
    /// @dev This method is only callable by the river contract, and to actually forward the information to the node operators via event emission, the requestValidatorExits method must be called
    /// @param _exitAmountToRequest The amount of exit requests to add to the demand
    /// @param _totalDepositedETH The total deposited ETH
    function demandETHExits(uint256 _exitAmountToRequest, uint256 _totalDepositedETH) external;
}
