//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "./interfaces/IOperatorRegistry.1.sol";
import "./interfaces/IRiver.1.sol";
import "./interfaces/components/IConsensusLayerDepositManager.1.sol";
import "./interfaces/IProtocolVersion.sol";

import "./libraries/LibUint256.sol";

import "./Initializable.sol";
import "./Administrable.sol";

import "./state/operatorsRegistry/Operators.1.sol";
import "./state/operatorsRegistry/Operators.2.sol";
import "./state/operatorsRegistry/Operators.3.sol";
import "./state/operatorsRegistry/ValidatorKeys.sol";
import "./state/operatorsRegistry/TotalValidatorExitsRequested.sol";
import "./state/operatorsRegistry/CurrentValidatorExitsDemand.sol";
import "./state/operatorsRegistry/TotalExitsRequested.sol";
import "./state/operatorsRegistry/CurrentExitDemand.sol";
import "./state/shared/RiverAddress.sol";

import "./state/migration/OperatorsRegistry_FundedKeyEventRebroadcasting_KeyIndex.sol";
import "./state/migration/OperatorsRegistry_FundedKeyEventRebroadcasting_OperatorIndex.sol";

/// @title Operators Registry (v1)
/// @author Alluvial Finance Inc.
/// @notice This contract handles the list of operators and their balance tracking
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

    /// @notice Migration from count-based to ETH-based operator tracking
    function initOperatorsRegistryV2() external init(2) {
        // Migrate exit demand from count to ETH
        CurrentExitDemand.set(CurrentValidatorExitsDemand.get() * 32 ether);
        TotalExitsRequested.set(TotalValidatorExitsRequested.get() * 32 ether);

        // Migrate per-operator balances from V2 to V3
        uint256 operatorCount = OperatorsV2.getCount();
        for (uint256 i = 0; i < operatorCount; ++i) {
            OperatorsV2.Operator storage v2Op = OperatorsV2.get(i);
            OperatorsV3.Operator memory v3Op = OperatorsV3.Operator({
                fundedBalance: uint256(v2Op.funded) * 32 ether,
                requestedExitBalance: uint256(v2Op.requestedExits) * 32 ether,
                active: v2Op.active,
                name: v2Op.name,
                operator: v2Op.operator
            });
            OperatorsV3.push(v3Op);
        }

        // Migrate stopped validator counts to stopped balances
        uint32[] storage stoppedCounts = OperatorsV2.getStoppedValidators();
        if (stoppedCounts.length > 0) {
            uint256[] memory stoppedBalances = new uint256[](stoppedCounts.length);
            for (uint256 i = 0; i < stoppedCounts.length; ++i) {
                stoppedBalances[i] = uint256(stoppedCounts[i]) * 32 ether;
            }
            OperatorsV3.setRawStoppedBalances(stoppedBalances);
        }
    }

    /// @notice Prevent unauthorized calls
    modifier onlyRiver() virtual {
        if (msg.sender != RiverAddress.get()) {
            revert LibErrors.Unauthorized(msg.sender);
        }
        _;
    }

    /// @notice Prevents anyone except the admin or the given operator to make the call
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
    function getOperator(uint256 _index) external view returns (OperatorsV2.Operator memory) {
        // Return V2 format for backwards compatibility
        OperatorsV3.Operator storage v3Op = OperatorsV3.get(_index);
        return OperatorsV2.Operator({
            limit: 0,
            funded: 0,
            requestedExits: 0,
            keys: 0,
            latestKeysEditBlockNumber: 0,
            active: v3Op.active,
            name: v3Op.name,
            operator: v3Op.operator
        });
    }

    /// @inheritdoc IOperatorsRegistryV1
    function getOperatorCount() external view returns (uint256) {
        return OperatorsV3.getCount();
    }

    /// @notice Retrieve the stopped balance for an operator
    /// @param _idx The operator index
    /// @return The stopped balance of the operator
    function getOperatorStoppedBalance(uint256 _idx) external view returns (uint256) {
        return OperatorsV3._getStoppedBalanceAtIndex(OperatorsV3.getStoppedBalances(), _idx);
    }

    /// @notice Retrieve the total stopped balance
    /// @return The total stopped balance
    function getTotalStoppedBalance() external view returns (uint256) {
        return _getTotalStoppedBalance();
    }

    /// @notice Retrieve the total exits requested (ETH)
    /// @return The total exits requested in ETH
    function getTotalExitsRequested() external view returns (uint256) {
        return TotalExitsRequested.get();
    }

    /// @notice Retrieve the current exit demand (ETH)
    /// @return The current exit demand in ETH
    function getCurrentExitDemand() external view returns (uint256) {
        return CurrentExitDemand.get();
    }

    /// @notice Retrieve the total stopped and requested exit balances
    /// @return totalStopped The total stopped balance
    /// @return totalRequestedExits The total requested exit balance (requested + demand)
    function getStoppedAndRequestedExitBalances() external view returns (uint256, uint256) {
        return (_getTotalStoppedBalance(), TotalExitsRequested.get() + CurrentExitDemand.get());
    }

    /// @inheritdoc IOperatorsRegistryV1
    function listActiveOperators() external view returns (OperatorsV2.Operator[] memory) {
        // Return empty array - callers should use V3 operators
        return new OperatorsV2.Operator[](0);
    }

    /// @notice Report stopped balances from the oracle
    /// @param _stoppedBalances The stopped balances per operator (index 0 = total)
    /// @param _depositedBalance The current deposited balance
    function reportStoppedBalances(uint256[] calldata _stoppedBalances, uint256 _depositedBalance) external onlyRiver {
        _setStoppedBalances(_stoppedBalances, _depositedBalance);
    }

    /// @notice Report a funded balance increase for an operator after a deposit
    /// @param _operatorIndex The operator index
    /// @param _amount The deposit amount in ETH
    function reportFundedBalance(uint256 _operatorIndex, uint256 _amount) external onlyRiver {
        OperatorsV3.Operator storage operator = OperatorsV3.get(_operatorIndex);
        operator.fundedBalance += _amount;
    }

    /// @inheritdoc IOperatorsRegistryV1
    function addOperator(string calldata _name, address _operator) external onlyAdmin returns (uint256) {
        OperatorsV3.Operator memory newOperator = OperatorsV3.Operator({
            fundedBalance: 0,
            requestedExitBalance: 0,
            active: true,
            name: _name,
            operator: _operator
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

    /// @notice Request validator exits using ETH-denominated allocations
    /// @param _allocations The exit allocations with operator index and exit balance
    function requestExits(ExitAllocation[] calldata _allocations) external {
        if (msg.sender != IConsensusLayerDepositManagerV1(RiverAddress.get()).getKeeper()) {
            revert IConsensusLayerDepositManagerV1.OnlyKeeper();
        }

        uint256 currentExitDemand = CurrentExitDemand.get();
        if (currentExitDemand == 0) {
            revert NoExitRequestsToPerform();
        }

        uint256 allocationsLength = _allocations.length;
        if (allocationsLength == 0) {
            revert InvalidEmptyArray();
        }

        uint256 requestedExitAmount = 0;

        for (uint256 i = 0; i < allocationsLength; ++i) {
            uint256 operatorIndex = _allocations[i].operatorIndex;
            uint256 exitBalance = _allocations[i].exitBalance;

            if (exitBalance == 0) {
                revert AllocationWithZeroValidatorCount();
            }
            if (i > 0 && !(operatorIndex > _allocations[i - 1].operatorIndex)) {
                revert UnorderedOperatorList();
            }

            requestedExitAmount += exitBalance;

            OperatorsV3.Operator storage operator = OperatorsV3.get(operatorIndex);
            if (!operator.active) {
                revert InactiveOperator(operatorIndex);
            }
            uint256 availableBalance = operator.fundedBalance - operator.requestedExitBalance;
            if (exitBalance > availableBalance) {
                revert ExitsRequestedExceedAvailableFundedCount(operatorIndex, exitBalance, availableBalance);
            }
            operator.requestedExitBalance += exitBalance;
            emit RequestedValidatorExits(operatorIndex, operator.requestedExitBalance);
        }

        if (requestedExitAmount > currentExitDemand) {
            revert ExitsRequestedExceedDemand(requestedExitAmount, currentExitDemand);
        }

        uint256 savedCurrentExitDemand = currentExitDemand;
        currentExitDemand -= requestedExitAmount;

        uint256 totalExitsRequestedValue = TotalExitsRequested.get();
        _setTotalExitsRequested(totalExitsRequestedValue, totalExitsRequestedValue + requestedExitAmount);
        _setCurrentExitDemand(savedCurrentExitDemand, currentExitDemand);
    }

    /// @notice Increase the exit demand (ETH-denominated)
    /// @param _amount The amount of ETH to demand exits for
    /// @param _depositedBalance The current deposited balance
    function demandExits(uint256 _amount, uint256 _depositedBalance) external onlyRiver {
        uint256 currentExitDemand = CurrentExitDemand.get();
        uint256 totalExitsRequested = TotalExitsRequested.get();
        _amount = LibUint256.min(
            _amount, _depositedBalance - (totalExitsRequested + currentExitDemand)
        );
        if (_amount > 0) {
            _setCurrentExitDemand(currentExitDemand, currentExitDemand + _amount);
        }
    }

    /// @notice Internal utility to retrieve the total stopped balance
    /// @return The total stopped balance
    function _getTotalStoppedBalance() internal view returns (uint256) {
        uint256[] storage stoppedBalances = OperatorsV3.getStoppedBalances();
        if (stoppedBalances.length == 0) {
            return 0;
        }
        return stoppedBalances[0];
    }

    /// @notice Internal utility to set the current exit demand
    /// @param _currentValue The current value
    /// @param _newValue The new value
    function _setCurrentExitDemand(uint256 _currentValue, uint256 _newValue) internal {
        CurrentExitDemand.set(_newValue);
        emit SetCurrentValidatorExitsDemand(_currentValue, _newValue);
    }

    /// @notice Internal utility to set the total exits requested
    /// @param _currentValue The current value
    /// @param _newValue The new value
    function _setTotalExitsRequested(uint256 _currentValue, uint256 _newValue) internal {
        TotalExitsRequested.set(_newValue);
        emit SetTotalValidatorExitsRequested(_currentValue, _newValue);
    }

    /// @notice Internal structure for _setStoppedBalances variables
    struct SetStoppedBalancesVars {
        uint256 stoppedBalancesLength;
        uint256[] currentStoppedBalances;
        uint256 currentStoppedBalancesLength;
        uint256 totalStoppedBalance;
        uint256 count;
        uint256 currentExitDemand;
        uint256 cachedCurrentExitDemand;
        uint256 totalRequestedExits;
        uint256 cachedTotalRequestedExits;
    }

    /// @notice Internal utility to set the stopped balances array after sanity checks
    /// @param _stoppedBalances The stopped balances per operator + total in index 0
    /// @param _depositedBalance The current deposited balance
    function _setStoppedBalances(uint256[] calldata _stoppedBalances, uint256 _depositedBalance) internal {
        SetStoppedBalancesVars memory vars;
        vars.stoppedBalancesLength = _stoppedBalances.length;
        if (vars.stoppedBalancesLength == 0) {
            revert InvalidEmptyStoppedValidatorCountsArray();
        }

        OperatorsV3.Operator[] storage operators = OperatorsV3.getAll();

        if (vars.stoppedBalancesLength - 1 > operators.length) {
            revert StoppedValidatorCountsTooHigh();
        }

        vars.currentStoppedBalances = OperatorsV3.getStoppedBalances();
        vars.currentStoppedBalancesLength = vars.currentStoppedBalances.length;

        if (vars.stoppedBalancesLength < vars.currentStoppedBalancesLength) {
            revert StoppedValidatorCountArrayShrinking();
        }

        vars.totalStoppedBalance = _stoppedBalances[0];
        vars.count = 0;

        vars.currentExitDemand = CurrentExitDemand.get();
        vars.cachedCurrentExitDemand = vars.currentExitDemand;
        vars.totalRequestedExits = TotalExitsRequested.get();
        vars.cachedTotalRequestedExits = vars.totalRequestedExits;

        uint256 idx = 1;
        uint256 unsolicitedExitsSum;
        for (; idx < vars.currentStoppedBalancesLength; ++idx) {
            if (_stoppedBalances[idx] < vars.currentStoppedBalances[idx]) {
                revert StoppedValidatorCountsDecreased();
            }

            if (_stoppedBalances[idx] > operators[idx - 1].fundedBalance) {
                revert StoppedValidatorCountAboveFundedCount(idx - 1, 0, 0);
            }

            if (_stoppedBalances[idx] > operators[idx - 1].requestedExitBalance) {
                unsolicitedExitsSum += _stoppedBalances[idx] - operators[idx - 1].requestedExitBalance;
                operators[idx - 1].requestedExitBalance = _stoppedBalances[idx];
            }

            vars.count += _stoppedBalances[idx];
        }

        for (; idx < vars.stoppedBalancesLength; ++idx) {
            if (_stoppedBalances[idx] > operators[idx - 1].fundedBalance) {
                revert StoppedValidatorCountAboveFundedCount(idx - 1, 0, 0);
            }

            if (_stoppedBalances[idx] > operators[idx - 1].requestedExitBalance) {
                unsolicitedExitsSum += _stoppedBalances[idx] - operators[idx - 1].requestedExitBalance;
                operators[idx - 1].requestedExitBalance = _stoppedBalances[idx];
            }

            vars.count += _stoppedBalances[idx];
        }

        vars.totalRequestedExits += unsolicitedExitsSum;
        vars.currentExitDemand -= LibUint256.min(unsolicitedExitsSum, vars.currentExitDemand);

        if (vars.totalRequestedExits != vars.cachedTotalRequestedExits) {
            _setTotalExitsRequested(vars.cachedTotalRequestedExits, vars.totalRequestedExits);
        }

        if (vars.currentExitDemand != vars.cachedCurrentExitDemand) {
            _setCurrentExitDemand(vars.cachedCurrentExitDemand, vars.currentExitDemand);
        }

        if (vars.totalStoppedBalance != vars.count) {
            revert InvalidStoppedValidatorCountsSum();
        }
        if (vars.totalStoppedBalance > _depositedBalance) {
            revert StoppedValidatorCountsTooHigh();
        }
        OperatorsV3.setRawStoppedBalances(_stoppedBalances);
    }

    // ============================================================
    // DEPRECATED V2 STUBS - kept for interface compatibility
    // ============================================================

    /// @inheritdoc IOperatorsRegistryV1
    function getOperatorStoppedValidatorCount(uint256) external pure returns (uint32) {
        return 0;
    }

    /// @inheritdoc IOperatorsRegistryV1
    function getTotalStoppedValidatorCount() external pure returns (uint32) {
        return 0;
    }

    /// @inheritdoc IOperatorsRegistryV1
    function getTotalValidatorExitsRequested() external view returns (uint256) {
        return TotalValidatorExitsRequested.get();
    }

    /// @inheritdoc IOperatorsRegistryV1
    function getCurrentValidatorExitsDemand() external view returns (uint256) {
        return CurrentValidatorExitsDemand.get();
    }

    /// @inheritdoc IOperatorsRegistryV1
    function getStoppedAndRequestedExitCounts() external pure returns (uint32, uint256) {
        return (0, 0);
    }

    /// @inheritdoc IOperatorsRegistryV1
    function getStoppedValidatorCountPerOperator() external pure returns (uint32[] memory) {
        return new uint32[](0);
    }

    /// @inheritdoc IOperatorsRegistryV1
    function getValidator(uint256, uint256)
        external
        pure
        returns (bytes memory publicKey, bytes memory signature, bool funded)
    {
        return (new bytes(0), new bytes(0), false);
    }

    /// @inheritdoc IOperatorsRegistryV1
    function getNextValidatorsToDepositFromActiveOperators(OperatorAllocation[] memory)
        external
        pure
        returns (bytes[] memory publicKeys, bytes[] memory signatures)
    {
        return (new bytes[](0), new bytes[](0));
    }

    /// @inheritdoc IOperatorsRegistryV1
    function reportStoppedValidatorCounts(uint32[] calldata, uint256) external view onlyRiver {
        revert("DEPRECATED: use reportStoppedBalances");
    }

    /// @inheritdoc IOperatorsRegistryV1
    function setOperatorLimits(uint256[] calldata, uint32[] calldata, uint256) external onlyAdmin {
        revert("DEPRECATED: operator limits removed");
    }

    /// @inheritdoc IOperatorsRegistryV1
    function addValidators(uint256, uint32, bytes calldata) external pure {
        revert("DEPRECATED: validator keys managed off-chain");
    }

    /// @inheritdoc IOperatorsRegistryV1
    function removeValidators(uint256, uint256[] calldata) external pure {
        revert("DEPRECATED: validator keys managed off-chain");
    }

    /// @inheritdoc IOperatorsRegistryV1
    function pickNextValidatorsToDeposit(OperatorAllocation[] calldata)
        external
        pure
        returns (bytes[] memory, bytes[] memory)
    {
        revert("DEPRECATED: use depositToConsensusLayer");
    }

    /// @inheritdoc IOperatorsRegistryV1
    function requestValidatorExits(OperatorAllocation[] calldata) external pure {
        revert("DEPRECATED: use requestExits");
    }

    /// @inheritdoc IOperatorsRegistryV1
    function demandValidatorExits(uint256, uint256) external pure {
        revert("DEPRECATED: use demandExits");
    }

    /// @inheritdoc IProtocolVersion
    function version() external pure returns (string memory) {
        return "1.2.1";
    }
}
