//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "./interfaces/IOperatorRegistry.1.sol";
import "./interfaces/IRiver.1.sol";
import "./interfaces/IProtocolVersion.sol";

import "./libraries/LibUint256.sol";

import "./Initializable.sol";
import "./Administrable.sol";

import "./state/operatorsRegistry/Operators.1.sol";
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
    /// @inheritdoc IOperatorsRegistryV1
    function initOperatorsRegistryV1(address _admin, address _river) external init(0) {
        _setAdmin(_admin);
        RiverAddress.set(_river);
        emit SetRiver(_river);
    }

    /// @notice Internal migration utility to migrate all operators to OperatorsV2 format
    function _migrateOperators_V1_1() internal {
        uint256 opCount = OperatorsV1.getCount();

        for (uint256 idx = 0; idx < opCount; ++idx) {
            OperatorsV1.Operator memory oldOperatorValue = OperatorsV1.get(idx);

            OperatorsV2.push(
                OperatorsV2.Operator({
                    limit: uint32(oldOperatorValue.limit),
                    funded: uint32(oldOperatorValue.funded),
                    requestedExits: 0,
                    keys: uint32(oldOperatorValue.keys),
                    latestKeysEditBlockNumber: uint64(oldOperatorValue.latestKeysEditBlockNumber),
                    active: oldOperatorValue.active,
                    name: oldOperatorValue.name,
                    operator: oldOperatorValue.operator
                })
            );
        }
    }

    /// @inheritdoc IOperatorsRegistryV1
    function initOperatorsRegistryV1_1() external init(1) {
        _migrateOperators_V1_1();
    }

    /// @inheritdoc IOperatorsRegistryV1
    function initOperatorsRegistryV1_2() external init(2) {
        _migrateOperators_V2_3();

        CurrentETHExitsDemand.set(CurrentValidatorExitsDemand.get() * 32 ether);
        TotalETHExitsRequested.set(TotalValidatorExitsRequested.get() * 32 ether);

        uint32[] memory stoppedValidators = OperatorsV2.getStoppedValidators();
        uint256[] memory exitedETH = new uint256[](stoppedValidators.length);
        for (uint256 idx = 0; idx < stoppedValidators.length; ++idx) {
            exitedETH[idx] = stoppedValidators[idx] * 32 ether;
        }
        OperatorsV3.setRawExitedETH(exitedETH);
    }

    /// @notice Internal utility to migrate the operators from V2 to V3 format
    function _migrateOperators_V2_3() internal {
        uint256 opCount = OperatorsV2.getCount();
        for (uint256 idx = 0; idx < opCount; ++idx) {
            OperatorsV2.Operator memory operator = OperatorsV2.get(idx);
            OperatorsV3.push(OperatorsV3.Operator({
                funded: operator.funded * 32 ether,
                requestedExits: operator.requestedExits * 32 ether,
                active: operator.active,
                name: operator.name,
                operator: operator.operator
            }));
        }
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
        uint256[] memory rawExitedETH = OperatorsV3.getExitedETH();
        uint256 listLength = rawExitedETH.length;
        if (listLength > 0) {
            assembly {
                // no need to use free memory pointer as we reuse the same memory range

                // erase previous word storing length
                mstore(rawExitedETH, 0)

                // move memory pointer up by a word
                rawExitedETH := add(rawExitedETH, 0x20)

                // store updated length at new memory pointer location
                mstore(rawExitedETH, sub(listLength, 1))
            }
        }
        return rawExitedETH;
    }

    /// @inheritdoc IOperatorsRegistryV1
    function listActiveOperators() external view returns (OperatorsV3.Operator[] memory) {
        return OperatorsV3.getAllActive();
    }

    /// @inheritdoc IOperatorsRegistryV1
    function incrementFundedETH(uint256[] calldata _fundedETH) external onlyRiver {
        uint256 fundedETHLength = _fundedETH.length;
        if (fundedETHLength == 0) {
            revert InvalidEmptyArray();
        }
        if (fundedETHLength != OperatorsV3.getCount()) {
            revert InvalidFundedETHLength();
        }
        for (uint256 idx = 0; idx < fundedETHLength; ++idx) {
            OperatorsV3.Operator storage operator = OperatorsV3.get(idx);
            operator.funded += _fundedETH[idx];
        }
    }

    /// @inheritdoc IOperatorsRegistryV1
    function reportExitedETH(uint256[] calldata _exitedETH, uint256 _totalDepositedETH) external onlyRiver {
        _setExitedETH(_exitedETH, _totalDepositedETH);
    }

    /// @inheritdoc IOperatorsRegistryV1
    function addOperator(string calldata _name, address _operator) external onlyAdmin returns (uint256) {
        OperatorsV3.Operator memory newOperator =
            OperatorsV3.Operator({active: true, operator: _operator, name: _name, funded: 0, requestedExits: 0});

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
    function requestValidatorExits(ExitETHAllocation[] calldata _allocations) external {
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

        // Check that the exits requested do not exceed the funded ETH count of the operator
        for (uint256 i = 0; i < allocationsLength; ++i) {
            uint256 operatorIndex = _allocations[i].operatorIndex;
            uint256 ethAmount = _allocations[i].ethAmount;

            if (ethAmount == 0) {
                revert AllocationWithZeroETHAmount();
            }
            if (i > 0 && !(operatorIndex > _allocations[i - 1].operatorIndex)) {
                revert UnorderedOperatorList();
            }

            requestedETHAmount += ethAmount;

            OperatorsV3.Operator storage operator = OperatorsV3.get(operatorIndex);
            if (!operator.active) {
                revert InactiveOperator(operatorIndex);
            }
            if (ethAmount > (operator.funded - operator.requestedExits)) {
                // Operator has insufficient available ETH
                revert ExitsRequestedExceedAvailableFundedCount(
                    operatorIndex, ethAmount, operator.funded - operator.requestedExits
                );
            }
            // Operator has sufficient ETH
            operator.requestedExits += ethAmount;
            emit RequestedETHExits(operatorIndex, operator.requestedExits);
        }

        // Check that the exits requested do not exceed the current ETH exits demand
        if (requestedETHAmount > currentETHExitsDemand) {
            revert ExitsRequestedExceedDemand(requestedETHAmount, currentETHExitsDemand);
        }

        uint256 savedCurrentETHExitsDemand = currentETHExitsDemand;
        currentETHExitsDemand -= requestedETHAmount;

        uint256 totalETHExitsRequested = TotalETHExitsRequested.get();
        _setTotalETHExitsRequested(totalETHExitsRequested, totalETHExitsRequested + requestedETHAmount);
        _setCurrentETHExitsDemand(savedCurrentETHExitsDemand, currentETHExitsDemand);
    }

    /// @inheritdoc IOperatorsRegistryV1
    function demandETHExits(uint256 _exitAmountToRequest, uint256 _totalDepositedETH) external onlyRiver {
        uint256 currentETHExitsDemand = CurrentETHExitsDemand.get();
        uint256 totalETHExitsRequested = TotalETHExitsRequested.get();
        if (_totalDepositedETH < (totalETHExitsRequested + currentETHExitsDemand)) {
            revert ExitedETHTooHigh();
        }
        _exitAmountToRequest = LibUint256.min(
            _exitAmountToRequest, _totalDepositedETH - (totalETHExitsRequested + currentETHExitsDemand)
        );
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
    struct SetExitedETHInternalVars {
        uint256 exitedETHLength;
        uint256[] currentExitedETH;
        uint256 currentExitedETHLength;
        uint256 totalExitedETH;
        uint256 amountOfExitedETH;
        uint256 currentETHExitsDemand;
        uint256 cachedCurrentETHExitsDemand;
        uint256 totalRequestedETHExits;
        uint256 cachedTotalRequestedETHExits;
    }

    function _setExitedETH(uint256[] calldata _exitedETH, uint256 _totalDepositedETH) internal {
        SetExitedETHInternalVars memory vars;
        // we check that the array is not empty
        vars.exitedETHLength = _exitedETH.length;
        if (vars.exitedETHLength == 0) {
            revert InvalidEmptyArray();
        }

        OperatorsV3.Operator[] storage operators = OperatorsV3.getAll();

        // we check that the cells containing operator stopped values are no more than the current operator count
        if (vars.exitedETHLength - 1 > operators.length) {
            revert ExitedETHCountTooHigh();
        }

        vars.currentExitedETH = OperatorsV3.getExitedETH();
        vars.currentExitedETHLength = vars.currentExitedETH.length;

        // we check that the number of stopped values is not decreasing
        if (vars.exitedETHLength < vars.currentExitedETHLength) {
            revert ExitedETHArrayShrinking();
        }

        vars.totalExitedETH = _exitedETH[0];
        vars.amountOfExitedETH = 0;

        // create value to track unsolicited exits (e.g. to cover cases when Node Operator exit ETH without being requested to)
        vars.currentETHExitsDemand = CurrentETHExitsDemand.get();
        vars.cachedCurrentETHExitsDemand = vars.currentETHExitsDemand;
        vars.totalRequestedETHExits = TotalETHExitsRequested.get();
        vars.cachedTotalRequestedETHExits = vars.totalRequestedETHExits;

        uint256 idx = 1;
        uint256 unsolicitedExitsSum;
        for (; idx < vars.currentExitedETHLength; ++idx) {
            // if the previous array was long enough, we check that the values are not decreasing
            if (_exitedETH[idx] < vars.currentExitedETH[idx]) {
                revert ExitedETHArrayDecreased();
            }

            // we check that the amount of exited ETH is not above the funded ETH of an operator
            if (_exitedETH[idx] > operators[idx - 1].funded) {
                revert ExitedETHAboveFundedETH(
                    idx - 1, _exitedETH[idx], operators[idx - 1].funded
                );
            }

            // if the reported exited ETH for this operator is greater than its recorded requestedExits,
            // treat the difference as unsolicited exits and set requestedExits to the reported exited ETH.
            if (_exitedETH[idx] > operators[idx - 1].requestedExits) {
                emit UpdatedRequestedETHExitsUponStopped(
                    idx - 1, operators[idx - 1].requestedExits, _exitedETH[idx]
                );
                unsolicitedExitsSum += _exitedETH[idx] - operators[idx - 1].requestedExits;
                operators[idx - 1].requestedExits = _exitedETH[idx];
            }
            emit SetOperatorExitedETH(idx - 1, _exitedETH[idx]);

            // we recompute the total to ensure it's not an invalid sum
            vars.amountOfExitedETH += _exitedETH[idx];
        }

        // In case of a new operator we do not check against the current exited ETH (would revert OOB)
        for (; idx < vars.exitedETHLength; ++idx) {
            // we check that the amount of exited ETH is not above the funded ETH of an operator
            if (_exitedETH[idx] > operators[idx - 1].funded) {
                revert ExitedETHAboveFundedETH(
                    idx - 1, _exitedETH[idx], operators[idx - 1].funded
                );
            }

            // if the reported exited ETH for this operator is greater than its recorded requestedExits,
            // treat the difference as unsolicited exits and set requestedExits to the reported exited ETH.
            if (_exitedETH[idx] > operators[idx - 1].requestedExits) {
                emit UpdatedRequestedETHExitsUponStopped(
                    idx - 1, operators[idx - 1].requestedExits, _exitedETH[idx]
                );
                unsolicitedExitsSum += _exitedETH[idx] - operators[idx - 1].requestedExits;
                operators[idx - 1].requestedExits = _exitedETH[idx];
            }
            emit SetOperatorExitedETH(idx - 1, _exitedETH[idx]);

            // we recompute the total to ensure it's not an invalid sum
            vars.amountOfExitedETH += _exitedETH[idx];
        }

        vars.totalRequestedETHExits += unsolicitedExitsSum;
        // we decrease the demand, considering unsolicited exits as if they were answering the demand
        vars.currentETHExitsDemand -= LibUint256.min(unsolicitedExitsSum, vars.currentETHExitsDemand);

        if (vars.totalRequestedETHExits != vars.cachedTotalRequestedETHExits) {
            _setTotalETHExitsRequested(vars.cachedTotalRequestedETHExits, vars.totalRequestedETHExits);
        }

        if (vars.currentETHExitsDemand != vars.cachedCurrentETHExitsDemand) {
            _setCurrentETHExitsDemand(vars.cachedCurrentETHExitsDemand, vars.currentETHExitsDemand);
        }

        // we check that the total is matching the sum of the individual values
        if (vars.totalExitedETH != vars.amountOfExitedETH) {
            revert InvalidExitedETHSum();
        }
        // we check that the total is not higher than the current deposited ETH
        if (vars.totalExitedETH > _totalDepositedETH) {
            revert ExitedETHTooHigh();
        }

        // we set the exited ETH
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
        return "1.2.1";
    }
}
