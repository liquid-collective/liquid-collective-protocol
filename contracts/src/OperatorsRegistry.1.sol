//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "./interfaces/IOperatorRegistry.1.sol";
import "./interfaces/IRiver.1.sol";
import "./interfaces/IProtocolVersion.sol";
import "./interfaces/IWithdraw.1.sol";

import "./libraries/LibUint256.sol";

import "./Initializable.sol";
import "./Administrable.sol";

import "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";

import "./state/operatorsRegistry/Operators.2.sol";
import "./state/operatorsRegistry/Operators.3.sol";
import "./state/operatorsRegistry/ValidatorKeys.sol";
import "./state/operatorsRegistry/TotalETHExitsRequested.sol";
import "./state/operatorsRegistry/CurrentETHExitsDemand.sol";
import "./state/operatorsRegistry/TotalValidatorExitsRequested.sol";
import "./state/operatorsRegistry/CurrentValidatorExitsDemand.sol";
import "./state/operatorsRegistry/WithdrawAddress.sol";
import "./state/shared/RiverAddress.sol";

/// @title Operators Registry (v1)
/// @author Alluvial Finance Inc.
/// @notice This contract handles the list of operators and their keys
/// @dev Operator index is the position in the operators array. Operators are only
/// @dev added, never removed, so the operator at index i is always the one at
/// @dev array position i and indices are stable over time.
contract OperatorsRegistryV1 is IOperatorsRegistryV1, Initializable, Administrable, ReentrancyGuard, IProtocolVersion {
    uint256 private constant DEPOSIT_SIZE = 32 ether;

    uint256 private constant MIN_ETH_AMOUNT = 1 ether;

    // The maximum effective validator balance (MaxEB) under EIP-7251. A full exit's reserved amount
    // (the projected total balance) cannot exceed this.
    uint64 private constant MAX_EL_EXIT_AMOUNT_GWEI = 2_048_000_000_000; // 2048 ETH

    // The minimum balance an active validator must retain (the activation floor). A full exit's reserved
    // projected balance cannot realistically be below this for an active validator.
    uint64 private constant MIN_VALIDATOR_BALANCE_GWEI = 32_000_000_000; // 32 ETH

    // A partial withdrawal cannot drop a validator below the activation floor, so the most it can wire
    // (and reserve) is MaxEB minus the 32 ETH floor.
    uint64 private constant MAX_PARTIAL_EL_EXIT_AMOUNT_GWEI = 2_016_000_000_000; // 2048 - 32 ETH

    /// @inheritdoc IOperatorsRegistryV1
    function initOperatorsRegistryV1(address _admin, address _river) external init(0) {
        _setAdmin(_admin);
        RiverAddress.set(_river);
        emit SetRiver(_river);
    }

    /// @inheritdoc IOperatorsRegistryV1
    function initOperatorsRegistryV1_2(address _withdrawAddress) external init(2) {
        _migrateOperators_V2_3();

        WithdrawAddress.set(_withdrawAddress);
        CurrentETHExitsDemand.set(CurrentValidatorExitsDemand.get() * DEPOSIT_SIZE);
        TotalETHExitsRequested.set(TotalValidatorExitsRequested.get() * DEPOSIT_SIZE);
    }

    /// @notice Internal utility to migrate the operators from V2 to V3 format
    function _migrateOperators_V2_3() internal {
        uint256 opCount = OperatorsV2.getCount();
        for (uint256 idx = 0; idx < opCount; ++idx) {
            OperatorsV2.Operator memory operatorV2 = OperatorsV2.get(idx);
            uint256 fundedETH = operatorV2.funded * DEPOSIT_SIZE;
            uint256 requestedExitsETH = operatorV2.requestedExits * DEPOSIT_SIZE;
            if (fundedETH < requestedExitsETH) {
                revert InvalidOperatorState(idx, fundedETH, requestedExitsETH);
            }
            OperatorsV3.push(
                OperatorsV3.Operator({
                    funded: fundedETH,
                    requestedExits: requestedExitsETH,
                    active: operatorV2.active,
                    name: operatorV2.name,
                    operator: operatorV2.operator,
                    // activeCLETH starts at 0 and is only populated by the first post-upgrade oracle
                    // report (OracleManager._reportCLETH). UNTIL that report lands, requestETHExits caps
                    // each operator's allocation by activeCLETH, so `available == 0` and any non-zero exit
                    // allocation reverts with ExitsRequestedExceedAvailableActiveCLAmount — even though
                    // CurrentETHExitsDemand / TotalETHExitsRequested are carried over non-zero from V2.
                    // A fresh oracle report MUST land immediately after initOperatorsRegistryV1_2, with
                    // the redemption queue paused to cover the gap.
                    activeCLETH: 0
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
    modifier onlyRiver() {
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
    function getExitedAndRequestedETHExits() external view returns (uint256, uint256) {
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
            assembly ("memory-safe") {
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
    function getPrePectraFundedValidatorCount(uint256 operatorIndex) external view returns (uint256) {
        return OperatorsV2.get(operatorIndex).funded;
    }

    /// @inheritdoc IOperatorsRegistryV1
    function getPrePectraValidatorPubkeys(uint256 operatorIndex, uint256 startIndex, uint256 stopIndex)
        external
        view
        returns (bytes[] memory publicKeys)
    {
        OperatorsV2.Operator storage op = OperatorsV2.get(operatorIndex);
        if (stopIndex > op.funded) revert PrePectraRangeExceedsFunded(operatorIndex, stopIndex);
        if (startIndex >= stopIndex) revert InvalidPrePectraRange(operatorIndex, startIndex, stopIndex);
        (publicKeys,) = ValidatorKeys.getKeys(operatorIndex, startIndex, stopIndex - startIndex);
    }

    /// @inheritdoc IOperatorsRegistryV1
    function incrementFundedETH(OperatorFundingDelta[] calldata _deltas) external onlyRiver {
        uint256 len = _deltas.length;
        if (len == 0) {
            revert InvalidEmptyArray();
        }

        uint256 operatorCount = OperatorsV3.getCount();
        // indices are strictly ascending and bounded by operatorCount, so there can be at
        // most one delta per operator.
        if (len > operatorCount) {
            revert FundedETHArrayLengthExceedsOperatorCount();
        }

        uint256 lastIndex;
        for (uint256 i = 0; i < len; ++i) {
            OperatorFundingDelta calldata delta = _deltas[i];
            uint256 operatorIndex = delta.operatorIndex;

            if (operatorIndex >= operatorCount) {
                revert InvalidOperatorIndex(operatorIndex, operatorCount);
            }
            if (i != 0 && operatorIndex <= lastIndex) {
                revert OperatorIndicesUnsortedOrDuplicate(operatorIndex);
            }
            lastIndex = operatorIndex;

            OperatorsV3.Operator storage operator = OperatorsV3.get(operatorIndex);
            if (!operator.active) {
                revert InactiveOperator(operatorIndex);
            }

            uint256 exitedETH = OperatorsV3.getExitedETH(operatorIndex);
            if (operator.requestedExits > exitedETH) {
                emit FundedOperatorWithPendingExits(operatorIndex, operator.requestedExits, exitedETH);
            }

            // Defense-in-depth: enforce the per-class pubkey/amount alignment that
            // `LibFundingDeltas.build` already guarantees, so the registry never emits an event
            // whose pubkeys and amounts disagree on length (which would silently break indexers).
            if (delta.depositPubkeys.length != delta.depositAmounts.length) {
                revert MisalignedDeltaArrays(operatorIndex, delta.depositPubkeys.length, delta.depositAmounts.length);
            }
            if (delta.topUpPubkeys.length != delta.topUpAmounts.length) {
                revert MisalignedDeltaArrays(operatorIndex, delta.topUpPubkeys.length, delta.topUpAmounts.length);
            }

            // Trusts delta.fundedETH == sum(deposit+topUp amounts) by construction (LibFundingDeltas.build).
            // Revisit this assumption if any non-builder call path can reach here — see the NatSpec @dev.
            operator.funded += delta.fundedETH;
            // Emit initial-deposit pubkeys and top-up pubkeys on separate events so off-chain
            // indexers do not conflate a top-up (existing key, additional ETH) with a brand-new
            // validator key. Both events carry per-key amounts under Pectra's variable deposit
            // sizes (1–2048 ETH).
            if (delta.depositPubkeys.length > 0) {
                emit Deposits(operatorIndex, delta.depositPubkeys, delta.depositAmounts);
            }
            if (delta.topUpPubkeys.length > 0) {
                emit TopUps(operatorIndex, delta.topUpPubkeys, delta.topUpAmounts);
            }
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
    function reportExitedETH(uint256[] calldata _exitedETH) external onlyRiver {
        _setExitedETH(_exitedETH);
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
    function requestETHExits(
        ExitETHAllocation[] calldata _allocations,
        ELExitETHAllocation[] calldata _elAllocations,
        uint256 _maxFeePerWithdrawal
    ) external payable nonReentrant {
        if (msg.sender != IConsensusLayerDepositManagerV1(RiverAddress.get()).getKeeper()) {
            revert IConsensusLayerDepositManagerV1.OnlyKeeper();
        }

        uint256 currentETHExitsDemand = CurrentETHExitsDemand.get();
        if (currentETHExitsDemand == 0) {
            revert NoExitRequestsToPerform();
        }

        if (_allocations.length == 0 && _elAllocations.length == 0) {
            revert InvalidEmptyArray();
        }

        uint256 requestedETHAmount = _requestCLETHExits(_allocations);
        uint256 remainingETHExitsDemand =
            requestedETHAmount >= currentETHExitsDemand ? 0 : currentETHExitsDemand - requestedETHAmount;
        (uint256 elRequestedETHAmount, uint256 totalFeePaid) =
            _requestELETHExits(_elAllocations, _maxFeePerWithdrawal, remainingETHExitsDemand);
        requestedETHAmount += elRequestedETHAmount;

        // Check that the exits requested do not exceed the current ETH exits demand
        if (requestedETHAmount > currentETHExitsDemand) {
            revert ExitsRequestedExceedExitDemand(requestedETHAmount, currentETHExitsDemand);
        }
        if (totalFeePaid < msg.value) {
            uint256 excess = msg.value - totalFeePaid;
            (bool ok,) = msg.sender.call{value: excess}("");
            if (!ok) {
                revert UnsentRefund(msg.sender, excess);
            }
        }

        uint256 totalETHExitsRequested = TotalETHExitsRequested.get();
        _setTotalETHExitsRequested(totalETHExitsRequested, totalETHExitsRequested + requestedETHAmount);
        _setCurrentETHExitsDemand(currentETHExitsDemand, currentETHExitsDemand - requestedETHAmount);
    }

    /// @notice Reserves full ETH exits per operator via CL and returns the total requested amount.
    function _requestCLETHExits(ExitETHAllocation[] calldata _allocations)
        private
        returns (uint256 requestedETHAmount)
    {
        for (uint256 i = 0; i < _allocations.length; ++i) {
            uint256 operatorIndex = _allocations[i].operatorIndex;
            uint256 ethAmount = _allocations[i].ethAmount;

            if (ethAmount < MIN_ETH_AMOUNT) {
                revert AllocationWithIncorrectAmount(ethAmount);
            }
            if (i > 0 && operatorIndex <= _allocations[i - 1].operatorIndex) {
                revert UnorderedOperatorList();
            }

            OperatorsV3.Operator storage operator = OperatorsV3.get(operatorIndex);
            if (!operator.active) {
                revert InactiveOperator(operatorIndex);
            }

            _reserveOperatorExit(operator, operatorIndex, ethAmount, false);
            requestedETHAmount += ethAmount;
            emit RequestedETHExits(operatorIndex, operator.requestedExits);
        }
    }

    /// @notice Requests partial/full ETH exits through Withdrawal Contract and returns the total requested amount.
    function _requestELETHExits(
        ELExitETHAllocation[] calldata _elAllocations,
        uint256 _maxFeePerWithdrawal,
        uint256 _remainingETHExitsDemand
    ) private returns (uint256 requestedETHAmount, uint256 totalFeePaid) {
        if (_elAllocations.length == 0) {
            return (0, 0);
        }

        IWithdrawV1 withdraw = IWithdrawV1(WithdrawAddress.get());

        for (uint256 i = 0; i < _elAllocations.length; ++i) {
            if (i > 0 && _elAllocations[i].operatorIndex <= _elAllocations[i - 1].operatorIndex) {
                revert UnorderedOperatorList();
            }

            (uint256 elExitAmount, uint256 feePaid) =
                _requestOperatorELETHExits(withdraw, _elAllocations[i], _maxFeePerWithdrawal);
            requestedETHAmount += elExitAmount;
            totalFeePaid += feePaid;
        }
        if (requestedETHAmount > _remainingETHExitsDemand) {
            revert ExitsGreaterThanExitDemand(requestedETHAmount, _remainingETHExitsDemand);
        }
    }

    /// @notice Validates a single operator's EL exit allocation, reserves it, triggers the withdrawal and emits.
    /// @return elExitAmount The total reserved exit amount (wei) for this operator
    /// @return feePaid The withdrawal fee paid for this operator
    function _requestOperatorELETHExits(
        IWithdrawV1 _withdraw,
        ELExitETHAllocation calldata _operatorAllocation,
        uint256 _maxFeePerWithdrawal
    ) private returns (uint256 elExitAmount, uint256 feePaid) {
        uint256 operatorIndex = _operatorAllocation.operatorIndex;

        if (
            _operatorAllocation.pubkeys.length != _operatorAllocation.withdrawalAmounts.length
                || _operatorAllocation.pubkeys.length != _operatorAllocation.reservedExitAmounts.length
        ) {
            revert InvalidELExitETHAllocationLength();
        }

        OperatorsV3.Operator storage operator = OperatorsV3.get(operatorIndex);
        if (!operator.active) {
            revert InactiveOperator(operatorIndex);
        }

        for (uint256 j = 0; j < _operatorAllocation.reservedExitAmounts.length; ++j) {
            uint64 withdrawalAmount = _operatorAllocation.withdrawalAmounts[j];
            uint64 reservedExitAmount = _operatorAllocation.reservedExitAmounts[j];
            // The reserved amount feeds the per-operator headroom cap, so it must always sit within the
            // bound that matches the kind of exit. The bound differs for full vs partial exits.
            if (withdrawalAmount == 0) {
                // A zero wire amount denotes a full exit. Its reserved value is keeper-supplied accounting
                // data (typically the projected balance) and is not validated against the real balance here,
                // but for an active validator it lies within [32 ETH activation floor, 2048 ETH MaxEB].
                if (reservedExitAmount < MIN_VALIDATOR_BALANCE_GWEI || reservedExitAmount > MAX_EL_EXIT_AMOUNT_GWEI) {
                    revert InvalidELExitETHAllocationAmount(operatorIndex, withdrawalAmount, reservedExitAmount);
                }
            } else {
                // A non-zero wire amount denotes a partial exit. It cannot drop the validator below the
                // 32 ETH activation floor, so the wire value is bounded by MaxEB - 32 ETH, and it must
                // reserve exactly what it withdraws.
                if (reservedExitAmount == 0 || reservedExitAmount > MAX_PARTIAL_EL_EXIT_AMOUNT_GWEI) {
                    revert InvalidELExitETHAllocationAmount(operatorIndex, withdrawalAmount, reservedExitAmount);
                }
                if (withdrawalAmount != reservedExitAmount) {
                    revert ELExitReservedWithdrawalMismatch(operatorIndex, withdrawalAmount, reservedExitAmount);
                }
            }
            elExitAmount += uint256(reservedExitAmount) * 1 gwei;
        }

        _reserveOperatorExit(operator, operatorIndex, elExitAmount, true);

        feePaid = _maxFeePerWithdrawal * _operatorAllocation.pubkeys.length;
        _withdraw.withdraw{value: feePaid}(
            _operatorAllocation.pubkeys, _operatorAllocation.withdrawalAmounts, _maxFeePerWithdrawal, msg.sender
        );
        emit RequestedELETHExits(
            operatorIndex,
            _operatorAllocation.pubkeys,
            _operatorAllocation.withdrawalAmounts,
            _operatorAllocation.reservedExitAmounts
        );
    }

    /// @notice Internal utility to reserve an exit against an operator's available ETH.
    /// @dev Performs the available-ETH check and updates the operator's `requestedExits`.
    /// @dev Reverts with the EL- or full-exit specific error depending on `_isEL`.
    /// @param _operator Storage reference to the operator whose exit is being reserved
    /// @param _operatorIndex The operator index (used in revert data)
    /// @param _amount The ETH(wei) amount to reserve
    /// @param _isEL true for EL exits, false for CL exits
    function _reserveOperatorExit(
        OperatorsV3.Operator storage _operator,
        uint256 _operatorIndex,
        uint256 _amount,
        bool _isEL
    ) private {
        uint256 available = _getOperatorAvailableExitETH(_operator, _operatorIndex);
        if (_amount > available) {
            if (_isEL) {
                revert ELExitsRequestedExceedAvailableActiveCLAmount(_operatorIndex, _amount, available);
            }
            revert ExitsRequestedExceedAvailableActiveCLAmount(_operatorIndex, _amount, available);
        }
        _operator.requestedExits += _amount;
    }

    function _getOperatorAvailableExitETH(OperatorsV3.Operator storage _operator, uint256 _operatorIndex)
        private
        view
        returns (uint256)
    {
        uint256 opPendingExits = _operator.requestedExits - OperatorsV3.getExitedETH(_operatorIndex);
        return _operator.activeCLETH > opPendingExits ? _operator.activeCLETH - opPendingExits : 0;
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
    function _setExitedETH(uint256[] calldata _exitedETH) internal {
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
        // we decrease the demand, considering unsolicited exits as if they were answering the demand.
        // we use min as the demand can't go below 0 & unsolicitedExitsSum can be greater than the demand
        // hence the term "unsolicited exits"
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
