//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../state/operatorsRegistry/Operators.3.sol";
import "./IWithdraw.1.sol";

/// @title Operators Registry Interface (v1)
/// @author Alluvial Finance Inc.
/// @notice This interface exposes methods to handle the list of operators
interface IOperatorsRegistryV1 {
    /// @notice Structure representing a validator deposit
    /// @param operatorIndex The index of the operator
    /// @param pubkey The BLS public key of the validator
    /// @param signature The BLS signature of the validator
    /// @param depositAmount The deposit amount in ETH(wei)
    struct ValidatorDeposit {
        uint256 operatorIndex;
        bytes pubkey; // 48 bytes
        bytes signature; // 96 bytes
        uint256 depositAmount; // deposit amount in ETH(wei)
    }

    /// @notice Structure representing an operator allocation for exits
    /// @param operatorIndex The index of the operator
    /// @param ethAmount The amount of ETH(wei) to exit for this operator
    struct ExitETHAllocation {
        uint256 operatorIndex;
        uint256 ethAmount;
    }

    /// @notice Structure representing the release of a stuck exit reservation for an operator
    /// @dev Same shape as `ExitETHAllocation`, kept separate so the release path can evolve
    ///      (e.g. an oracle-reported cumulative variant) without perturbing the reserve path.
    /// @param operatorIndex The index of the operator whose reservation is being released
    /// @param ethAmount The amount of reserved ETH(wei) to release. Clamped on-chain to the operator's
    ///                  outstanding reservation (`requestedExits - exitedETH`), so a stale value is safe.
    struct ExitReleaseAllocation {
        uint256 operatorIndex;
        uint256 ethAmount;
    }

    /// @notice Structure representing an EL exit allocation for exits
    /// @param operatorIndex The index of the operator
    /// @param pubkeys The pubkeys through which the EL exits were requested
    /// @param withdrawalAmounts The wire amount (gwei) sent to the EIP-7002 withdrawal predeploy per pubkey.
    ///                          0 signals a full exit; any non-zero value is a partial withdrawal.
    /// @param reservedExitAmounts The accounting amount (gwei) reserved against the operator's exit headroom
    ///                            per pubkey. Always set: for partial exits it equals the matching
    ///                            withdrawalAmounts[i]; for full exits it should be the keeper-supplied projected balance (not validated on-chain).
    struct ELExitETHAllocation {
        uint256 operatorIndex;
        bytes[] pubkeys; // 48 bytes
        uint64[] withdrawalAmounts; // gwei, wire value to the predeploy; 0 == full exit
        uint64[] reservedExitAmounts; // gwei, accounting value reserved against headroom; always set
    }

    /// @notice Structure representing exits requested via internal validator consolidation
    /// @param ethPerOperator Per-operator reserved exit ETH(wei), reserved against each operator's exit
    ///                       headroom exactly like CL exits. operatorIndex is keeper-supplied and trusted
    ///                       (there is no on-chain pubkey->operator mapping post-Pectra), mirroring EL exits.
    /// @param consolidationRequests The raw source->target consolidation requests dispatched to Withdraw
    struct ExitsViaConsolidationAllocation {
        ExitETHAllocation[] ethPerOperator;
        IWithdrawV1.ConsolidationRequest[] consolidationRequests;
    }

    /// @notice Structure representing a per-operator funded ETH update
    /// @param operatorIndex The index of the operator receiving the funded ETH
    /// @param fundedETH The amount of ETH(wei) being added to the operator's funded total
    /// @param depositPubkeys The validator public keys funded with an initial deposit for this
    ///                      operator in this batch. Top-up pubkeys are NOT included here so
    ///                      indexers can treat each entry as a brand-new validator key.
    /// @param depositAmounts The per-initial-deposit amount in ETH(wei), aligned 1:1 with
    ///                       depositPubkeys.
    /// @param topUpPubkeys The validator public keys that received a top-up for this operator
    ///                        in this batch (pre-existing keys — not new validators).
    /// @param topUpAmounts The per-top-up amount in ETH(wei), aligned 1:1 with topUpPubkeys.
    struct OperatorFundingDelta {
        uint256 operatorIndex;
        uint256 fundedETH;
        bytes[] depositPubkeys;
        uint256[] depositAmounts;
        bytes[] topUpPubkeys;
        uint256[] topUpAmounts;
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

    /// @notice The amount of ETH(wei) that has been requested to be exited via CL
    /// @param index The operator index
    /// @param amount The amount of requested exits in ETH(wei)
    event RequestedETHExits(uint256 indexed index, uint256 amount);

    /// @notice The amount of ETH(wei) that has been requested to be exited via internal consolidation
    /// @param index The operator index
    /// @param amount The operator's cumulative requested exits in ETH(wei) after this reservation
    event RequestedETHExitsViaConsolidation(uint256 indexed index, uint256 amount);

    /// @notice The amount of ETH(gwei) that has been requested to be exited per pubkey via EL
    /// @param index The operator index
    /// @param pubkeys The pubkeys through which the EL exits were requested
    /// @param withdrawalAmounts The wire amount (gwei) sent to the predeploy per pubkey (0 for full exits)
    /// @param reservedExitAmounts The accounting amount (gwei) reserved against headroom per pubkey
    event RequestedELETHExits(
        uint256 indexed index, bytes[] pubkeys, uint64[] withdrawalAmounts, uint64[] reservedExitAmounts
    );

    /// @notice A stuck exit reservation has been released for an operator, moving it back into exit demand
    /// @param index The operator index
    /// @param releasedAmount The ETH(wei) amount actually released, after clamping to the outstanding
    ///                       reservation. Carried explicitly so a clamp is visible off-chain.
    /// @param requestedExits The operator's cumulative requested exits in ETH(wei) after the release
    event ReleasedETHExits(uint256 indexed index, uint256 releasedAmount, uint256 requestedExits);

    /// @notice A batch of stuck exit reservations has been released
    /// @param totalReleased The total ETH(wei) released across all operators in the batch
    /// @param viaConsolidationETH The subset of `totalReleased` that had been reserved via internal
    ///                            consolidation, removed from the exit consolidation buffer
    event ReleasedExitRequests(uint256 totalReleased, uint256 viaConsolidationETH);

    /// @notice The exit request demand has been updated
    /// @param previousETHExitsDemand The previous exit request demand in ETH(wei)
    /// @param nextETHExitsDemand The new exit request demand in ETH(wei)
    event SetCurrentETHExitsDemand(uint256 previousETHExitsDemand, uint256 nextETHExitsDemand);

    /// @notice The total requested exit has been updated
    /// @param previousTotalETHExitsRequested The previous total requested exit in ETH(wei)
    /// @param newTotalETHExitsRequested The new total requested exit in ETH(wei)
    event SetTotalETHExitsRequested(uint256 previousTotalETHExitsRequested, uint256 newTotalETHExitsRequested);

    /// @notice The requested ETH amount has been updated to fill the gap with the reported exited ETH amount
    /// @param index The operator index
    /// @param oldRequestedETHAmount The old requested ETH(wei) amount
    /// @param newRequestedETHAmount The new requested ETH(wei) amount
    event UpdatedRequestedETHExitsUponStopped(
        uint256 indexed index, uint256 oldRequestedETHAmount, uint256 newRequestedETHAmount
    );

    /// @notice The operator exited ETH has been set
    /// @param index The operator index
    /// @param exitedETH The exited ETH(wei)
    event SetOperatorExitedETH(uint256 indexed index, uint256 exitedETH);

    /// @notice The exited ETH have been updated
    /// @param exitedETH The exited ETH(wei) per operator
    event UpdatedExitedETH(uint256[] exitedETH);

    /// @notice The active ETH on CL have been updated
    /// @param activeCLETH The active ETH(wei) on CL per operator
    event UpdatedActiveCLETH(uint256[] activeCLETH);

    /// @notice One or more validator keys received an initial deposit in this batch.
    /// @dev Post-Pectra: this event covers initial-deposit pubkeys only. Top-up pubkeys are
    ///      not new validators and are emitted via the dedicated `TopUps` event instead, so
    ///      indexers that treat each `pubkeys[]` entry as a new validator key do not
    ///      over-count. The legacy `deferred` flag has been dropped — the
    ///      `forceFundedValidatorKeysEventEmission` migration that produced replayed events
    ///      completed on mainnet and was removed, so no synthetic emissions remain.
    /// @param index The operator index
    /// @param pubkeys BLS public keys that received an initial deposit
    /// @param amounts The per-key initial-deposit amount in ETH(wei), aligned 1:1 with pubkeys
    event Deposits(uint256 indexed index, bytes[] pubkeys, uint256[] amounts);

    /// @notice One or more existing validator keys received a top-up deposit in this batch.
    /// @dev Additive event introduced post-Pectra. Top-ups credit additional ETH to an existing
    ///      validator key (1–2048 ETH range), so they must not be reported via
    ///      `Deposits` (which carries new-validator semantics). Amounts are included
    ///      because under Pectra the deposit size is variable and consumers cannot derive it
    ///      from the event alone.
    /// @param index The operator index
    /// @param pubkeys BLS public keys that received a top-up
    /// @param amounts The per-key top-up amount in ETH(wei), aligned 1:1 with pubkeys
    event TopUps(uint256 indexed index, bytes[] pubkeys, uint256[] amounts);

    /// @notice An operator was funded while it still had unfulfilled exit requests.
    /// @param index The operator index
    /// @param requestedExits The cumulative amount of exits requested for the operator
    /// @param exitedETH The cumulative amount of exited ETH(wei) reported for the operator
    event FundedOperatorWithPendingExits(uint256 indexed index, uint256 requestedExits, uint256 exitedETH);

    /// @notice The exit consolidation buffer has been set
    /// @param oldValue The old exit consolidation buffer
    /// @param newValue The new exit consolidation buffer
    event SetExitConsolidationBuffer(uint256 indexed oldValue, uint256 indexed newValue);

    /// @notice The calling operator is inactive
    /// @param index The operator index
    error InactiveOperator(uint256 index);

    /// @notice The provided operator and limits array are empty
    error InvalidEmptyArray();

    /// @notice The provided list of operators is not in increasing order
    error UnorderedOperatorList();

    /// @notice Thrown when the sum of exited ETH is invalid
    error ExitedETHSumMismatch();

    /// @notice Thrown when the number of exited ETH is too high compared to operator count
    error ExitedETHArrayLengthExceedsOperatorCount();

    /// @notice Thrown when the funding-delta array is longer than the operator count, which is
    ///         impossible for a well-formed input: operator indices are unique and strictly ascending,
    ///         so there is at most one delta per operator. The array is sparse — operators with no
    ///         deposits or top-ups in the batch are omitted — so its length can never exceed the
    ///         operator count.
    error FundedETHArrayLengthExceedsOperatorCount();

    /// @notice Thrown when no exit requests can be performed
    error NoExitRequestsToPerform();

    /// @notice The provided exited ETH array is shrinking
    error ExitedETHArrayShrinking();

    /// @notice Thrown when the exited ETH for an operator has decreased compared to the previous report
    error ExitedETHPerOperatorDecreased();

    /// @notice The provided exit requests exceed the operator's available active CL ETH (active CL ETH minus pending exits)
    /// @param operatorIndex The operator index
    /// @param requested The requested ETH(wei) amount
    /// @param available The available ETH(wei) amount
    error ExitsRequestedExceedAvailableActiveCLAmount(uint256 operatorIndex, uint256 requested, uint256 available);

    /// @notice The provided EL exit requests exceed the operator's available active CL ETH (active CL ETH minus pending exits)
    /// @param operatorIndex The operator index
    /// @param requested The requested ETH(wei) amount
    /// @param available The available ETH(wei) amount
    error ELExitsRequestedExceedAvailableActiveCLAmount(uint256 operatorIndex, uint256 requested, uint256 available);

    /// @notice The provided exit requests exceed the current exit request demand
    /// @param requestedETHAmount The requested ETH(wei) amount
    /// @param currentETHExitsDemand The current ETH(wei) exits demand
    error ExitsRequestedExceedExitDemand(uint256 requestedETHAmount, uint256 currentETHExitsDemand);

    /// @notice Thrown when an allocation with an incorrect ETH amount is provided
    /// @param ethAmount The incorrect ETH(wei) amount
    error AllocationWithIncorrectAmount(uint256 ethAmount);

    /// @notice Thrown when an EL exit allocation's reserved amount falls outside the bounds for its exit kind.
    ///         Full exits (withdrawalAmount == 0) must reserve within [32 ETH, 2048 ETH]; partial exits
    ///         (withdrawalAmount != 0) must reserve within (0, 2016 ETH] (MaxEB minus the 32 ETH floor).
    /// @param operatorIndex The operator index
    /// @param withdrawalAmount The wire amount (gwei) for this pubkey (0 for full exits)
    /// @param reservedExitAmount The reserved accounting amount (gwei) for this pubkey
    error InvalidELExitETHAllocationAmount(uint256 operatorIndex, uint64 withdrawalAmount, uint64 reservedExitAmount);

    /// @notice Thrown when a partial EL exit's wire amount does not match its reserved accounting amount.
    ///         Partial exits (withdrawalAmount != 0) must wire exactly what they reserve; only full exits
    ///         (withdrawalAmount == 0) are allowed to differ from the reserved (keeper-supplied) accounting amount.
    /// @param operatorIndex The operator index
    /// @param withdrawalAmount The wire amount (gwei) for this pubkey
    /// @param reservedExitAmount The reserved accounting amount (gwei) for this pubkey
    error ELExitReservedWithdrawalMismatch(uint256 operatorIndex, uint64 withdrawalAmount, uint64 reservedExitAmount);

    /// @notice Thrown when the provided active CL ETH array length does not match the operator count
    error InvalidActiveCLETHArrayLength();

    /// @notice Thrown when the operator state is invalid
    /// @param index The operator index
    /// @param funded The funded ETH(wei) amount
    /// @param requestedExits The requested ETH(wei) amount
    error InvalidOperatorState(uint256 index, uint256 funded, uint256 requestedExits);
    /// @notice Thrown when a delta references an operator index outside the registered range
    /// @param operatorIndex The offending operator index
    /// @param operatorCount The current number of registered operators
    error InvalidOperatorIndex(uint256 operatorIndex, uint256 operatorCount);

    /// @notice Thrown when deltas are not provided in strictly ascending operator-index order
    /// @param operatorIndex The offending operator index (equal to or below the previous index)
    error OperatorIndicesUnsortedOrDuplicate(uint256 operatorIndex);

    /// @notice Thrown when a funding delta's per-class pubkey and amount arrays disagree on length.
    ///         Aligned arrays are an invariant of `LibFundingDeltas.build`; this check makes the
    ///         invariant explicit at the registry boundary so a malformed delta cannot cause the
    ///         registry to emit an event whose pubkeys and amounts do not line up.
    /// @param operatorIndex The offending operator index
    /// @param pubkeysLength The length of the pubkeys array
    /// @param amountsLength The length of the amounts array
    error MisalignedDeltaArrays(uint256 operatorIndex, uint256 pubkeysLength, uint256 amountsLength);

    /// @notice Thrown when the excess fee is not refunded
    /// @param sender The sender of the transaction
    /// @param excess The excess fee
    error UnsentRefund(address sender, uint256 excess);

    /// @notice Thrown when an EL exit allocation has mismatched pubkeys/withdrawalAmounts/reservedExitAmounts lengths
    error InvalidELExitETHAllocationLength();

    /// @notice Thrown when the total EL exit amount requested is greater than the remaining exit demand
    /// @param elExitAmount The total EL exit amount requested (sum of all EL allocations)
    /// @param remainingETHExitsDemand The remaining exit demand
    error ExitsGreaterThanExitDemand(uint256 elExitAmount, uint256 remainingETHExitsDemand);

    /// @notice Thrown when the consolidation subset of a release exceeds the total amount released.
    ///         `viaConsolidation` is by definition a subset of the release, exactly as
    ///         `totalExitViaConsolidationETH` is a subset of `validatorsExitedBalance`.
    /// @param viaConsolidation The claimed consolidation-reserved portion of the release
    /// @param totalReleased The total ETH(wei) actually released
    error ReleasedConsolidationExceedsRelease(uint256 viaConsolidation, uint256 totalReleased);

    /// @notice Thrown when the pre-Pectra range exceeds the funded validator count
    /// @param operatorIndex The operator index
    /// @param stopIndex The exclusive stop key index
    error PrePectraRangeExceedsFunded(uint256 operatorIndex, uint256 stopIndex);

    /// @notice Thrown when the pre-Pectra range is invalid
    /// @param operatorIndex The operator index
    /// @param startIndex The first key index
    /// @param stopIndex The exclusive stop key index
    error InvalidPrePectraRange(uint256 operatorIndex, uint256 startIndex, uint256 stopIndex);

    /// @notice Initializes the operators registry
    /// @param _admin Admin in charge of managing operators
    /// @param _river Address of River system
    function initOperatorsRegistryV1(address _admin, address _river) external;

    /// @notice Initializes the operators registry for V1_1, migrating operators from V1 to V2 storage
    function initOperatorsRegistryV1_1() external;

    /// @notice Migrates operators from V2 to V3 storage, dropping key-management fields
    /// @dev    Migrated operators start with `activeCLETH == 0`, which is only populated by the first
    ///         post-upgrade oracle report. Since `requestETHExits` caps each operator's allocation by
    ///         `activeCLETH`, no validator exits can be requested between this call and that first
    ///         report — even though `CurrentETHExitsDemand` / `TotalETHExitsRequested` are already
    ///         non-zero (carried over from V2). OPERATIONAL REQUIREMENT: a fresh oracle report MUST
    ///         land immediately after this call, and the redemption queue MUST be paused over the
    ///         gap.
    /// @param _withdrawAddress The address of the Withdrawal contract
    function initOperatorsRegistryV1_2(address _withdrawAddress) external;

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
    /// @return The total requested exit amount in ETH(wei)
    function getTotalETHExitsRequested() external view returns (uint256);

    /// @notice Get the current exit request demand waiting to be triggered
    /// @notice This value is the amount of exit requests that are demanded and not yet performed by the contract
    /// @return The current exit request demand in ETH(wei)
    function getCurrentETHExitsDemand() external view returns (uint256);

    /// @notice Retrieve the total exited ETH and total requested ETH exits
    /// @return The total exited ETH(wei)
    /// @return The total requested ETH exits (includes total requested exits and current exit demand)
    function getExitedAndRequestedETHExits() external view returns (uint256, uint256);

    /// @notice Retrieve the raw exited ETH array from storage
    /// @return The exited ETH(wei) array per operator
    function getExitedETHPerOperator() external view returns (uint256[] memory);

    /// @notice Retrieve the cumulative released exit reservations per operator
    /// @dev Cumulative and monotonically increasing; the array grows lazily, so it can be shorter than
    ///      the operator count when the trailing operators have never had a reservation released.
    /// @return The released ETH(wei) array per operator
    function getReleasedETHPerOperator() external view returns (uint256[] memory);

    /// @notice Retrieve the active operator set
    /// @return The list of active operators and their details
    function listActiveOperators() external view returns (OperatorsV3.Operator[] memory);

    /// @notice Retrieve the pre-Pectra funded validator count for an operator from legacy V2 storage.
    /// @param operatorIndex The operator index
    /// @return The legacy funded validator count
    function getPrePectraFundedValidatorCount(uint256 operatorIndex) external view returns (uint256);

    /// @notice Retrieve pre-Pectra validator pubkeys from legacy ValidatorKeys storage.
    /// @dev `stopIndex` is exclusive; returns pubkeys for indexes [startIndex, stopIndex).
    /// @param operatorIndex The operator index
    /// @param startIndex The first key index to read
    /// @param stopIndex The exclusive stop key index
    /// @return publicKeys The legacy validator pubkeys in the requested range
    function getPrePectraValidatorPubkeys(uint256 operatorIndex, uint256 startIndex, uint256 stopIndex)
        external
        view
        returns (bytes[] memory publicKeys);

    /// @notice Updates the funded ETH for the node operators referenced in the provided deltas
    /// @dev Deltas must be sorted by operatorIndex in strictly ascending order with no duplicates
    /// @dev Reverts with InvalidEmptyArray when the deltas array is empty
    /// @dev Reverts with InvalidOperatorIndex when a delta references an operator outside the registered range
    /// @dev Reverts with OperatorIndicesUnsortedOrDuplicate when deltas are not strictly ascending
    /// @dev Reverts with InactiveOperator when a referenced operator is inactive
    /// @dev `delta.fundedETH` is trusted to equal `sum(depositAmounts) + sum(topUpAmounts)` and is NOT
    ///      re-derived on-chain. This holds by construction: the only path that builds these deltas is
    ///      `LibFundingDeltas.build` (reached via River's `_incrementFundedETH`), which computes
    ///      `fundedETH` and the per-key deposit/top-up amounts from the same source, so an explicit sum
    ///      check would only add O(n) gas for a condition that cannot fail. If a future
    ///      change lets deltas NOT produced by `LibFundingDeltas.build` reach this function, this
    ///      invariant must be re-validated here (e.g. reinstate a `fundedETH == sum(amounts)` assertion)
    ///      before the `operator.funded += delta.fundedETH` mutation can be trusted.
    /// @param _deltas The per-operator funded ETH updates
    function incrementFundedETH(OperatorFundingDelta[] calldata _deltas) external;

    /// @notice Updates the active CL ETH for each node operator in the Operators Registry
    /// @dev We assume that the oracle would report the correct active CL ETH amounts for each operator.
    ///      The trust lies in the assumption that the quorum of oracle members cannot be compromised.
    /// @param _activeCLETH The array of active ETH(wei) amounts per operator
    function reportCLETH(uint256[] calldata _activeCLETH) external;

    /// @notice Allows river to override the exited ETH array
    /// @notice This actions happens during the Oracle report processing
    /// @param _exitedETH The new exited ETH(wei) array per operator
    function reportExitedETH(uint256[] calldata _exitedETH) external;

    /// @notice Allows river to adjust the buffer for ETH exited via consolidation
    /// @param _exitedAmount The amount that was reported
    function reportExitViaConsolidation(uint256 _exitedAmount) external;

    /// @notice Retrieve the amount of ETH(wei) expected to be received via consolidation exits
    /// @return The current exit consolidation buffer
    function getExitConsolidationBuffer() external view returns (uint256);

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
    /// @dev Each allocation's ethAmount must be at least 1 ether and not exceed the operator's available active CL ETH (active CL ETH minus pending exits)
    /// @dev The total requested exits across all allocations must not exceed the current ETH exit demand
    /// @dev Reverts with InvalidEmptyArray if _allocations is empty
    /// @dev Reverts with AllocationWithIncorrectAmount if any allocation has an ETH amount less than 1 ether
    /// @dev Reverts with UnorderedOperatorList if operator indexes are not strictly ascending
    /// @dev Reverts with InactiveOperator if a referenced operator is inactive
    /// @dev Reverts with ExitsRequestedExceedAvailableActiveCLAmount if an allocation's ETH amount exceeds the operator's active CL ETH minus pending exits (requestedExits - exitedETH)
    /// @dev Reverts with ExitsRequestedExceedExitDemand if total exits requested exceed the current demand
    /// @dev Reverts with NoExitRequestsToPerform if there is no pending exit demand
    /// @dev Reverts with SlashingContainmentModeEnabled while River is in slashing containment mode: no new
    ///      exits may be dispatched to the consensus layer during a slashing event, including demand that
    ///      predates the containment. Releasing stuck reservations (`releaseExitRequests`) stays available
    ///      during containment — state is restored, dispatch is not.
    /// @param _allocations The proposed per-operator exit ETH allocations, sorted by operator index
    /// @param _elAllocations The proposed per-operator per-pubkey EL exit ETH allocations, sorted by operator index
    /// @param _exitViaConsolidationAllocation Exits via internal consolidation: per-operator reserved ETH
    ///        (`ethPerOperator`) plus the raw consolidation requests dispatched to Withdraw
    /// @param _maxFeePerWithdrawal The maximum fee for per withdrawal request
    /// @param _maxFeePerConsolidation The maximum fee for per consolidation request
    function requestETHExits(
        ExitETHAllocation[] calldata _allocations,
        ELExitETHAllocation[] calldata _elAllocations,
        ExitsViaConsolidationAllocation calldata _exitViaConsolidationAllocation,
        uint256 _maxFeePerWithdrawal,
        uint256 _maxFeePerConsolidation
    ) external payable;

    /// @notice Releases exit reservations that the consensus layer silently dropped, moving them back
    ///         into the dispatchable exit demand so the keeper can request them again.
    /// @dev Only callable by the administrator (the governance timelock).
    /// @dev A release is the exact inverse of a reservation: `operator.requestedExits` and
    ///      `TotalETHExitsRequested` go down while `CurrentETHExitsDemand` goes up by the same amount.
    ///      `TotalETHExitsRequested + CurrentETHExitsDemand` — the sum the redeem formula reads through
    ///      `getExitedAndRequestedETHExits` as `preExitingBalance` — is therefore invariant, so a release
    ///      can never let the protocol over-request exits. What it restores is dispatchability: the ETH
    ///      moves from "already sent to a consensus layer that dropped it" back to "the keeper may send it
    ///      again", along with the operator's per-operator exit headroom.
    /// @dev Deliberately NOT rate-limited. Every release is bounded per operator by that operator's
    ///      outstanding reservation (it cannot conjure capacity), it is sum-invariant (it cannot inflate
    ///      what the redeem formula sees), an over-eager release self-corrects — if the exit lands later,
    ///      `reportExitedETH` raises `requestedExits` back and re-consumes the demand, at a cost of
    ///      over-exiting (lost yield) rather than corrupted state — and the governance timelock on the
    ///      admin is itself the rate limit. A separate per-period cap would only add a way for the
    ///      break-glass to be too small during a live incident.
    /// @dev Amounts are clamped to each operator's outstanding reservation rather than reverting, so a
    ///      slightly stale input is safe and a release can never be applied twice. This is also what will
    ///      make a future oracle-reported release path idempotent against an admin release issued during
    ///      the same incident.
    /// @dev No `active` check: an inactive operator holding a stuck reservation is precisely the case that
    ///      needs unwinding.
    /// @dev FORWARD COMPATIBILITY — a future oracle-reported release path (which detects drops from the
    ///      beacon state off-chain) will add cumulative `releasedExitsETHPerOperator` /
    ///      `totalReleasedExitViaConsolidationETH` fields to the consensus layer report, convert them to
    ///      per-operator deltas via `max(0, reported[i] - OperatorsV3.getReleasedETH(i))` — clamping,
    ///      never reverting when the report is behind the accumulator — and feed the same internal
    ///      helper. The cumulative accumulator written here (`OperatorsV3.addReleasedETH`, laid out
    ///      `[sum, op0, op1, ...]` exactly like `exitedETH`) is what makes that a drop-in with no state
    ///      reshaping and no double application.
    /// @dev Reverts with InvalidEmptyArray if _allocations is empty
    /// @dev Reverts with InvalidOperatorIndex if an allocation references an operator outside the range
    /// @dev Reverts with UnorderedOperatorList if operator indexes are not strictly ascending
    /// @dev Reverts with ReleasedConsolidationExceedsRelease if _viaConsolidationETH exceeds the total released
    /// @param _allocations The per-operator amounts to release, sorted by operator index in strictly
    ///        ascending order with no duplicates
    /// @param _viaConsolidationETH The subset of the released amount that had been reserved via internal
    ///        consolidation, decremented from the exit consolidation buffer
    function releaseExitRequests(ExitReleaseAllocation[] calldata _allocations, uint256 _viaConsolidationETH) external;

    /// @notice Increases the exit request demand
    /// @dev This method is only callable by the river contract, and to actually forward the information to the node operators via event emission, the requestETHExits method must be called
    /// @dev Due to autocompounding we cannot rely on the total deposited ETH, but on the total available ETH on CL
    /// @param _exitAmountToRequest The amount of exit requests to add to the demand
    /// @param _totalAvailableCLETH The total available ETH(wei) on the consensus layer which includes the InFlightDeposit amount and excludes the exiting balance
    /// @dev This method is only callable by the river contract
    function demandETHExits(uint256 _exitAmountToRequest, uint256 _totalAvailableCLETH) external;
}
