//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "./interfaces/IOperatorRegistry.1.sol";
import "./interfaces/IRiver.1.sol";
import "./interfaces/IProtocolVersion.sol";

import "./libraries/LibUint256.sol";

import "./Initializable.sol";
import "./Administrable.sol";

import "./state/operatorsRegistry/Operators.2.sol";
import "./state/operatorsRegistry/Operators.3.sol";
import "./state/operatorsRegistry/TotalETHExitsRequested.sol";
import "./state/operatorsRegistry/CurrentETHExitsDemand.sol";
import "./state/operatorsRegistry/TotalValidatorExitsRequested.sol";
import "./state/operatorsRegistry/CurrentValidatorExitsDemand.sol";
import "./state/shared/RiverAddress.sol";

/// @title Operators Registry (v1)
/// @author Alluvial Finance Inc.
/// @notice This contract handles the list of operators and their keys
/// @dev Operator index is the position in the operators array. Operators are only
/// @dev added, never removed, so the operator at index i is always the one at
/// @dev array position i and indices are stable over time.
contract OperatorsRegistryV1 is IOperatorsRegistryV1, Initializable, Administrable, IProtocolVersion {
    uint256 private constant DEPOSIT_SIZE = 32 ether;

    uint256 private constant MIN_ETH_AMOUNT = 1 ether;

    /// @inheritdoc IOperatorsRegistryV1
    function initOperatorsRegistryV1(address _admin, address _river) external init(0) {
        _setAdmin(_admin);
        RiverAddress.set(_river);
        emit SetRiver(_river);
    }

    /// @inheritdoc IOperatorsRegistryV1
    function initOperatorsRegistryV1_2() external init(2) {
        _migrateOperators_V2_3();

        CurrentETHExitsDemand.set(CurrentValidatorExitsDemand.get() * DEPOSIT_SIZE);
        TotalETHExitsRequested.set(TotalValidatorExitsRequested.get() * DEPOSIT_SIZE);
    }

    /// @notice Internal utility to migrate the operators from V2 to V3 format
    function _migrateOperators_V2_3() internal {
        uint256 opCount = OperatorsV2.getCount();
        for (uint256 idx = 0; idx < opCount; ++idx) {
            OperatorsV2.Operator memory operator = OperatorsV2.get(idx);
            OperatorsV3.push(
                OperatorsV3.Operator({
                    funded: operator.funded * DEPOSIT_SIZE,
                    requestedExits: operator.requestedExits * DEPOSIT_SIZE,
                    active: operator.active,
                    name: operator.name,
                    operator: operator.operator,
                    activeCLETH: 0 // This is ok to set 0 here because it will be updated via the oracle report before it gets used
                })
            );
        }

        uint32[] memory stoppedValidators = OperatorsV2.getStoppedValidators();
        // Ensure the array has at least opCount + 1 entries (sum + one per operator) so that
        // getExitedETHPerOperator() always returns an array of length opCount after stripping the sum.
        uint256 exitedETHLength = opCount + 1;
        if (stoppedValidators.length > exitedETHLength) {
            exitedETHLength = stoppedValidators.length;
        }
        uint256[] memory exitedETH = new uint256[](exitedETHLength);

        for (uint256 idx = 0; idx < stoppedValidators.length; ++idx) {
            exitedETH[idx] = stoppedValidators[idx] * DEPOSIT_SIZE;
        }
        OperatorsV3.setRawExitedETH(exitedETH);
    }

    /// @notice Prevent unauthorized calls
    modifier onlyRiver() virtual {
        if (msg.sender != RiverAddress.get()) {
            revert LibErrors.Unauthorized(msg.sender);
        }
        _;
    }

    /// @notice Prevents anyone except the admin or the given operator to make the call. Also checks if operator is active
    /// @notice The admin is able to call this method on behalf of any operator, even if inactive
    /// @param _index The index identifying the operator
    modifier onlyOperatorOrAdmin(uint256 _index) {
        if (msg.sender == _getAdmin()) {
            _;
            return;
        }
        OperatorsV3.Operator storage operator = OperatorsV3.get(_index);
        if (!operator.active) {
            revert InactiveOperator(_index);
        }
        if (msg.sender != operator.operator) {
            revert LibErrors.Unauthorized(msg.sender);
        }
        _;
    }

    /// @inheritdoc IOperatorsRegistryV1
    function getRiver() external view returns (address) {
        return RiverAddress.get();
    }

    /// @inheritdoc IOperatorsRegistryV1
    function getOperator(uint256 _index) external view returns (OperatorsV3.Operator memory) {
        return OperatorsV3.get(_index);
    }

    /// @inheritdoc IOperatorsRegistryV1
    function getTotalETHExitsRequested() external view returns (uint256) {
        return TotalETHExitsRequested.get();
    }

    /// @inheritdoc IOperatorsRegistryV1
    function getCurrentETHExitsDemand() external view returns (uint256) {
        return CurrentETHExitsDemand.get();
    }

    /// @inheritdoc IOperatorsRegistryV1
    function getExitedETHAndRequestedExitAmounts() external view returns (uint256, uint256) {
        return (_getTotalExitedETH(), TotalETHExitsRequested.get() + CurrentETHExitsDemand.get());
    }

    /// @inheritdoc IOperatorsRegistryV1
    function getOperatorCount() external view returns (uint256) {
        return OperatorsV3.getCount();
    }

    /// @inheritdoc IOperatorsRegistryV1
    function getExitedETHPerOperator() external view returns (uint256[] memory) {
        uint256[] memory exitedETH = OperatorsV3.getExitedETH();
        uint256 listLength = exitedETH.length;
        if (listLength > 0) {
            assembly {
                // no need to use free memory pointer as we reuse the same memory range

                // erase previous word storing length
                mstore(exitedETH, 0)

                // move memory pointer up by a word
                exitedETH := add(exitedETH, 0x20)

                // store updated length at new memory pointer location
                mstore(exitedETH, sub(listLength, 1))
            }
        }
        return exitedETH;
    }

    /// @inheritdoc IOperatorsRegistryV1
    function listActiveOperators() external view returns (OperatorsV3.Operator[] memory) {
        return OperatorsV3.getAllActive();
    }

    /// @inheritdoc IOperatorsRegistryV1
    function incrementFundedETH(uint256[] calldata _fundedETH, bytes[][] calldata _publicKeys) external onlyRiver {
        uint256 fundedETHLength = _fundedETH.length;
        if (fundedETHLength == 0) {
            revert InvalidEmptyArray();
        }
        for (uint256 idx = 0; idx < fundedETHLength; ++idx) {
            // We have this check to avoid unnecessary storage reads for operators with no funded ETH
            if (_fundedETH[idx] == 0) {
                continue;
            }
            OperatorsV3.Operator storage operator = OperatorsV3.get(idx);
            if (!operator.active) {
                revert InactiveOperator(idx);
            }
            if (operator.requestedExits > OperatorsV3.getExitedETH(idx)) {
                revert OperatorIgnoredExitRequests(idx);
            }
            operator.funded += _fundedETH[idx];
            emit FundedValidatorKeys(idx, _publicKeys[idx], false);
        }
    }

    /// @inheritdoc IOperatorsRegistryV1
    function reportCLETH(uint256[] calldata _activeCLETH) external onlyRiver {
        uint256 activeCLETHLength = _activeCLETH.length;
        if (activeCLETHLength == 0) {
            revert InvalidEmptyArray();
        }
        if (activeCLETHLength != OperatorsV3.getCount()) {
            revert InvalidActiveCLETHArrayLength();
        }
        for (uint256 idx = 0; idx < activeCLETHLength; ++idx) {
            OperatorsV3.Operator storage operator = OperatorsV3.get(idx);
            operator.activeCLETH = _activeCLETH[idx];
        }
        emit UpdatedActiveCLETH(_activeCLETH);
    }

    /// @inheritdoc IOperatorsRegistryV1
    function reportExitedETH(uint256[] calldata _exitedETH, uint256 _totalDepositedETH) external onlyRiver {
        _setExitedETH(_exitedETH, _totalDepositedETH);
    }

    /// @inheritdoc IOperatorsRegistryV1
    function addOperator(string calldata _name, address _operator) external onlyAdmin returns (uint256) {
        OperatorsV3.Operator memory newOperator = OperatorsV3.Operator({
            active: true, operator: _operator, name: _name, funded: 0, requestedExits: 0, activeCLETH: 0
        });

        uint256 operatorIndex = OperatorsV3.push(newOperator) - 1;

        emit AddedOperator(operatorIndex, _name, _operator);
        return operatorIndex;
    }

    /// @inheritdoc IOperatorsRegistryV1
    function setOperatorAddress(uint256 _index, address _newOperatorAddress) external onlyOperatorOrAdmin(_index) {
        LibSanitize._notZeroAddress(_newOperatorAddress);
        OperatorsV3.Operator storage operator = OperatorsV3.get(_index);

        operator.operator = _newOperatorAddress;

        emit SetOperatorAddress(_index, _newOperatorAddress);
    }

    /// @inheritdoc IOperatorsRegistryV1
    function setOperatorName(uint256 _index, string calldata _newName) external onlyOperatorOrAdmin(_index) {
        LibSanitize._notEmptyString(_newName);
        OperatorsV3.Operator storage operator = OperatorsV3.get(_index);
        operator.name = _newName;

        emit SetOperatorName(_index, _newName);
    }

    /// @inheritdoc IOperatorsRegistryV1
    function setOperatorStatus(uint256 _index, bool _newStatus) external onlyAdmin {
        OperatorsV3.Operator storage operator = OperatorsV3.get(_index);
        operator.active = _newStatus;

        emit SetOperatorStatus(_index, _newStatus);
    }

    /// @inheritdoc IOperatorsRegistryV1
    function requestETHExits(ExitETHAllocation[] calldata _allocations) external {
        if (msg.sender != IConsensusLayerDepositManagerV1(RiverAddress.get()).getKeeper()) {
            revert IConsensusLayerDepositManagerV1.OnlyKeeper();
        }

        uint256 currentETHExitsDemand = CurrentETHExitsDemand.get();
        if (currentETHExitsDemand == 0) {
            revert NoExitRequestsToPerform();
        }

        uint256 allocationsLength = _allocations.length;
        if (allocationsLength == 0) {
            revert InvalidEmptyArray();
        }

        uint256 requestedETHAmount = 0;

        // Check that the exits requested do not exceed the funded ETH amount of the operator
        for (uint256 i = 0; i < allocationsLength; ++i) {
            uint256 operatorIndex = _allocations[i].operatorIndex;
            uint256 ethAmount = _allocations[i].ethAmount;

            if (ethAmount < MIN_ETH_AMOUNT) {
                revert AllocationWithIncorrectAmount(ethAmount);
            }
            if (i > 0 && !(operatorIndex > _allocations[i - 1].operatorIndex)) {
                revert UnorderedOperatorList();
            }

            requestedETHAmount += ethAmount;

            OperatorsV3.Operator storage operator = OperatorsV3.get(operatorIndex);
            if (!operator.active) {
                revert InactiveOperator(operatorIndex);
            }

            uint256 opRequestedExits = operator.requestedExits;
            uint256 opPendingExits = opRequestedExits - OperatorsV3.getExitedETH(operatorIndex);
            uint256 available = operator.activeCLETH > opPendingExits ? operator.activeCLETH - opPendingExits : 0;
            if (ethAmount > available) {
                // Operator has insufficient available ETH
                revert ExitsRequestedExceedAvailableFundedAmount(operatorIndex, ethAmount, available);
            }

            opRequestedExits += ethAmount;
            operator.requestedExits = opRequestedExits;
            emit RequestedETHExits(operatorIndex, opRequestedExits);
        }

        // Check that the exits requested do not exceed the current ETH exits demand
        if (requestedETHAmount > currentETHExitsDemand) {
            revert ExitsRequestedExceedExitDemand(requestedETHAmount, currentETHExitsDemand);
        }

        uint256 totalETHExitsRequested = TotalETHExitsRequested.get();
        _setTotalETHExitsRequested(totalETHExitsRequested, totalETHExitsRequested + requestedETHAmount);
        _setCurrentETHExitsDemand(currentETHExitsDemand, currentETHExitsDemand - requestedETHAmount);
    }

    /// @inheritdoc IOperatorsRegistryV1
    function demandETHExits(uint256 _exitAmountToRequest, uint256 _totalAvailableCLETH) external onlyRiver {
        uint256 currentETHExitsDemand = CurrentETHExitsDemand.get();
        uint256 availableCLETHAfterCurrentETHExitsDemand =
            _totalAvailableCLETH > currentETHExitsDemand ? _totalAvailableCLETH - currentETHExitsDemand : 0;
        // capping the new exit demand so total "requested + demanded" never exceeds deposited ETH(wei)
        _exitAmountToRequest = LibUint256.min(_exitAmountToRequest, availableCLETHAfterCurrentETHExitsDemand);
        if (_exitAmountToRequest > 0) {
            _setCurrentETHExitsDemand(currentETHExitsDemand, currentETHExitsDemand + _exitAmountToRequest);
        }
    }

    /// @notice Internal utility to retrieve the total exited ETH
    /// @return The total exited ETH
    function _getTotalExitedETH() internal view returns (uint256) {
        uint256[] storage exitedETH = OperatorsV3.getExitedETH();
        if (exitedETH.length == 0) {
            return 0;
        }
        return exitedETH[0];
    }

    /// @notice Internal utility to set the current ETH exits demand
    /// @param _currentValue The current value
    /// @param _newValue The new value
    function _setCurrentETHExitsDemand(uint256 _currentValue, uint256 _newValue) internal {
        CurrentETHExitsDemand.set(_newValue);
        emit SetCurrentETHExitsDemand(_currentValue, _newValue);
    }

    /// @notice Internal structure to hold variables for the _setExitedETH method
    /// @param exitedETHLength The length of the exited ETH array that was passed
    /// @param currentExitedETH The current exited ETH array that is stored in storage
    /// @param currentExitedETHLength The length of the currentExitedETH array
    /// @param totalExitedETH The total exited ETH, derived from the first element of the exitedETH array that was passed
    /// @param amountOfExitedETH The amount of exited ETH
    /// @param currentETHExitsDemand The current ETH exits demand stored in storage
    /// @param cachedCurrentETHExitsDemand The cached current ETH exits demand, used to check if the value has changed
    /// @param totalETHExitsRequested The total ETH exits requested stored in storage
    /// @param cachedTotalETHExitsRequested The cached total ETH exits requested, used to check if the value has changed
    struct SetExitedETHInternalVars {
        uint256 exitedETHLength;
        uint256[] currentExitedETH;
        uint256 currentExitedETHLength;
        uint256 totalExitedETH;
        uint256 amountOfExitedETH;
        uint256 currentETHExitsDemand;
        uint256 cachedCurrentETHExitsDemand;
        uint256 totalETHExitsRequested;
        uint256 cachedTotalETHExitsRequested;
    }

    /// @notice Internal utility to set the exited ETH array
    /// @dev Please note that we rely on the Oracle to report the correct exitedETH array.
    /// @param _exitedETH The new exited ETH(wei) array per operator
    /// @param _totalDepositedETH The total deposited ETH(wei)
    function _setExitedETH(uint256[] calldata _exitedETH, uint256 _totalDepositedETH) internal {
        SetExitedETHInternalVars memory vars;
        // we check that the array is not empty
        vars.exitedETHLength = _exitedETH.length;
        if (vars.exitedETHLength == 0) {
            revert InvalidEmptyArray();
        }

        OperatorsV3.Operator[] storage operators = OperatorsV3.getAll();

        // we check that the cells containing operator exited values are no more than the current operator count
        if (vars.exitedETHLength - 1 > operators.length) {
            revert ExitedETHArrayLengthExceedsOperatorCount();
        }

        vars.currentExitedETH = OperatorsV3.getExitedETH();
        vars.currentExitedETHLength = vars.currentExitedETH.length;

        // we check that the number of exited values is not decreasing
        if (vars.exitedETHLength < vars.currentExitedETHLength) {
            revert ExitedETHArrayShrinking();
        }

        vars.totalExitedETH = _exitedETH[0];
        vars.amountOfExitedETH = 0;

        // create value to track unsolicited exits (e.g. to cover cases when Node Operator exit ETH without being requested to)
        vars.currentETHExitsDemand = CurrentETHExitsDemand.get();
        vars.cachedCurrentETHExitsDemand = vars.currentETHExitsDemand;
        vars.totalETHExitsRequested = TotalETHExitsRequested.get();
        vars.cachedTotalETHExitsRequested = vars.totalETHExitsRequested;

        uint256 idx = 1;
        uint256 unsolicitedExitsSum;
        for (; idx < vars.exitedETHLength; ++idx) {
            // we check that the amount of exited ETH is not decreasing for existing operators
            if (idx < vars.currentExitedETHLength && _exitedETH[idx] < vars.currentExitedETH[idx]) {
                revert ExitedETHPerOperatorDecreased();
            }

            // if the reported exited ETH for this operator is greater than its recorded requestedExits,
            // treat the difference as unsolicited exits and set requestedExits to the reported exited ETH.
            uint256 opRequestedExits = operators[idx - 1].requestedExits;
            if (_exitedETH[idx] > opRequestedExits) {
                emit UpdatedRequestedETHExitsUponStopped(idx - 1, opRequestedExits, _exitedETH[idx]);
                unsolicitedExitsSum += _exitedETH[idx] - opRequestedExits;
                operators[idx - 1].requestedExits = _exitedETH[idx];
            }
            emit SetOperatorExitedETH(idx - 1, _exitedETH[idx]);

            // we recompute the total to ensure it's not an invalid sum
            vars.amountOfExitedETH += _exitedETH[idx];
        }

        vars.totalETHExitsRequested += unsolicitedExitsSum;
        // we decrease the demand, considering unsolicited exits as if they were answering the demand
        vars.currentETHExitsDemand -= LibUint256.min(unsolicitedExitsSum, vars.currentETHExitsDemand);

        if (vars.totalETHExitsRequested != vars.cachedTotalETHExitsRequested) {
            _setTotalETHExitsRequested(vars.cachedTotalETHExitsRequested, vars.totalETHExitsRequested);
        }

        if (vars.currentETHExitsDemand != vars.cachedCurrentETHExitsDemand) {
            _setCurrentETHExitsDemand(vars.cachedCurrentETHExitsDemand, vars.currentETHExitsDemand);
        }

        // we check that the total is matching the sum of the individual values
        if (vars.totalExitedETH != vars.amountOfExitedETH) {
            revert ExitedETHSumMismatch();
        }
        // we check that the total is not higher than the current deposited ETH
        if (vars.totalExitedETH > _totalDepositedETH) {
            revert ExitedETHExceedsDepositedETH();
        }

        OperatorsV3.setRawExitedETH(_exitedETH);
        emit UpdatedExitedETH(_exitedETH);
    }

    /// @notice Internal utility to set the total ETH exits requested by the system
    /// @param _currentValue The current value of the total ETH exits requested
    /// @param _newValue The new value of the total ETH exits requested
    function _setTotalETHExitsRequested(uint256 _currentValue, uint256 _newValue) internal {
        TotalETHExitsRequested.set(_newValue);
        emit SetTotalETHExitsRequested(_currentValue, _newValue);
    }

    /// @inheritdoc IProtocolVersion
    function version() external pure returns (string memory) {
        return "1.3.0";
    }
}
