//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "./interfaces/IAllowlist.1.sol";
import "./interfaces/IRiver.1.sol";
import "./interfaces/IRedeemManager.1.sol";
import "./interfaces/IProtocolVersion.sol";
import "./libraries/LibAllowlistMasks.sol";
import "./libraries/LibUint256.sol";
import "./Initializable.sol";
import "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";

import "./state/shared/RiverAddress.sol";
import "./state/redeemManager/RedeemQueue.1.sol";
import "./state/redeemManager/RedeemQueue.2.sol";
import "./state/redeemManager/WithdrawalStack.sol";
import "./state/redeemManager/BufferedExceedingEth.sol";
import "./state/redeemManager/RedeemDemand.sol";
import "./state/redeemManager/MaxRedeemableETHLockedStack.sol";
import "./state/redeemManager/NextLockHeight.sol";

/// @title Redeem Manager (v1)
/// @author Alluvial Finance Inc.
/// @notice This contract handles the redeem requests of all users
contract RedeemManagerV1 is Initializable, ReentrancyGuard, IRedeemManagerV1, IProtocolVersion {
    /// @notice Value returned when resolving a redeem request that is unsatisfied
    int64 internal constant RESOLVE_UNSATISFIED = -1;
    /// @notice Value returned when resolving a redeem request that is out of bounds
    int64 internal constant RESOLVE_OUT_OF_BOUNDS = -2;
    /// @notice Value returned when resolving a redeem request that is already claimed
    int64 internal constant RESOLVE_FULLY_CLAIMED = -3;

    /// @notice Status value returned when fully claiming a redeem request
    uint8 internal constant CLAIM_FULLY_CLAIMED = 0;
    /// @notice Status value returned when partially claiming a redeem request
    uint8 internal constant CLAIM_PARTIALLY_CLAIMED = 1;
    /// @notice Status value returned when a redeem request is already claimed and skipped during a claim
    uint8 internal constant CLAIM_SKIPPED = 2;

    modifier onlyRiver() {
        if (msg.sender != RiverAddress.get()) {
            revert LibErrors.Unauthorized(msg.sender);
        }
        _;
    }

    modifier onlyRedeemer() {
        {
            IRiverV1 river = _castedRiver();
            IAllowlistV1(river.getAllowlist()).onlyAllowed(msg.sender, LibAllowlistMasks.REDEEM_MASK);
        }
        _;
    }

    /// @notice Reverts if slashing containment mode is currently active
    /// @dev Makes an external view call to River. River must be initialized before any function
    ///      guarded by this modifier is callable; calls will revert with a non-contract error otherwise.
    modifier whenNotSlashingContainmentMode() {
        if (_castedRiver().getSlashingContainmentMode()) {
            revert SlashingContainmentModeEnabled();
        }
        _;
    }

    /// @inheritdoc IRedeemManagerV1
    function initializeRedeemManagerV1(address _river) external init(0) {
        RiverAddress.set(_river);
        emit SetRiver(_river);
    }

    function initializeRedeemManagerV1_2() external init(1) {
        _redeemQueueMigrationV1_2();
    }

    /// @inheritdoc IRedeemManagerV1
    /// @dev Bootstraps NextLockHeight to the current RedeemDemand so the first post-upgrade
    ///      lock event sits behind all pre-upgrade requests. MaxRedeemableETHLockedStack and
    ///      MaxRedeemableETHLockedDemand start empty by default storage initialization.
    function initializeRedeemManagerV1_3() external init(2) {
        NextLockHeight.set(RedeemDemand.get());
    }

    function _redeemQueueMigrationV1_2() internal {
        RedeemQueueV1.RedeemRequest[] memory oldQueue = RedeemQueueV1.get();
        uint256 oldQueueLen = oldQueue.length;
        RedeemQueueV2.RedeemRequest[] storage newQueue = RedeemQueueV2.get();

        // Migrate from v1 to v2
        for (uint256 i = 0; i < oldQueueLen; ++i) {
            newQueue[i] = RedeemQueueV2.RedeemRequest({
                amount: oldQueue[i].amount,
                maxRedeemableEth: oldQueue[i].maxRedeemableEth,
                recipient: oldQueue[i].recipient,
                height: oldQueue[i].height,
                initiator: oldQueue[i].recipient
            });
        }
    }

    /// @inheritdoc IRedeemManagerV1
    function getRiver() external view returns (address) {
        return RiverAddress.get();
    }

    /// @inheritdoc IRedeemManagerV1
    function getRedeemRequestCount() external view returns (uint256) {
        return RedeemQueueV2.get().length;
    }

    /// @inheritdoc IRedeemManagerV1
    function getRedeemRequestDetails(uint32 _redeemRequestId)
        external
        view
        returns (RedeemQueueV2.RedeemRequest memory)
    {
        return RedeemQueueV2.get()[_redeemRequestId];
    }

    /// @inheritdoc IRedeemManagerV1
    function getWithdrawalEventCount() external view returns (uint256) {
        return WithdrawalStack.get().length;
    }

    /// @inheritdoc IRedeemManagerV1
    function getWithdrawalEventDetails(uint32 _withdrawalEventId)
        external
        view
        returns (WithdrawalStack.WithdrawalEvent memory)
    {
        return WithdrawalStack.get()[_withdrawalEventId];
    }

    /// @inheritdoc IRedeemManagerV1
    function getBufferedExceedingEth() external view returns (uint256) {
        return BufferedExceedingEth.get();
    }

    /// @inheritdoc IRedeemManagerV1
    function getRedeemDemand() external view returns (uint256) {
        return RedeemDemand.get();
    }

    /// @inheritdoc IRedeemManagerV1
    function getMaxRedeemableETHLockedEventCount() external view returns (uint256) {
        return MaxRedeemableETHLockedStack.get().length;
    }

    /// @inheritdoc IRedeemManagerV1
    function getMaxRedeemableETHLockedEventDetails(uint32 _lockEventId)
        external
        view
        returns (MaxRedeemableETHLockedStack.MaxRedeemableETHLockedEvent memory)
    {
        return MaxRedeemableETHLockedStack.get()[_lockEventId];
    }

    /// @inheritdoc IRedeemManagerV1
    /// @dev Computed dynamically as `NextLockHeight - max(head, firstLockHeight)`. This represents
    ///      the LsETH currently covered by a lock event AND not yet consumed by a withdrawal event.
    ///      Computing rather than storing avoids positional ambiguity in the pre-upgrade tail case
    ///      where the lock region sits BEHIND the queue head (post-upgrade slice after pre-upgrade
    ///      requests).
    function getMaxRedeemableETHLockedDemand() external view returns (uint256) {
        return _maxRedeemableETHLockedDemand();
    }

    function _maxRedeemableETHLockedDemand() internal view returns (uint256) {
        uint256 next = NextLockHeight.get();
        uint256 head = _currentMatchingHead();
        if (next <= head) {
            return 0;
        }
        MaxRedeemableETHLockedStack.MaxRedeemableETHLockedEvent[] storage lockEvents =
            MaxRedeemableETHLockedStack.get();
        if (lockEvents.length == 0) {
            return 0;
        }
        uint256 firstHeight = lockEvents[0].height;
        if (head > firstHeight) {
            firstHeight = head;
        }
        if (next <= firstHeight) {
            return 0;
        }
        return next - firstHeight;
    }

    /// @inheritdoc IRedeemManagerV1
    function getNextLockHeight() external view returns (uint256) {
        return NextLockHeight.get();
    }

    /// @inheritdoc IRedeemManagerV1
    /// @dev Walks the MaxRedeemableETHLockedStack starting from the queue head, summing each
    ///      overlapping lock event's pro-rata `lockedEth`. For any gap (pre-upgrade tail or a
    ///      slice not yet locked), falls back to summing per-request `maxRedeemableEth` over
    ///      the gap range.
    function getEffectiveCapForDemand(uint256 _lsETHDemand) external view returns (uint256) {
        if (_lsETHDemand == 0) {
            return 0;
        }
        uint256 cursor = _currentMatchingHead();
        uint256 endTarget = cursor + _lsETHDemand;

        MaxRedeemableETHLockedStack.MaxRedeemableETHLockedEvent[] storage lockEvents =
            MaxRedeemableETHLockedStack.get();
        uint256 lockLen = lockEvents.length;
        uint256 lockIdx = 0;
        // skip lock events fully behind the cursor
        while (lockIdx < lockLen && lockEvents[lockIdx].height + lockEvents[lockIdx].amount <= cursor) {
            ++lockIdx;
        }

        uint256 cap;
        while (cursor < endTarget) {
            if (lockIdx == lockLen) {
                // no more lock events — remainder uses the per-request fallback
                cap += _aggregateUnlockedMaxRedeemableEth(cursor, endTarget - cursor);
                break;
            }
            MaxRedeemableETHLockedStack.MaxRedeemableETHLockedEvent storage e = lockEvents[lockIdx];
            if (e.height > cursor) {
                // gap before this lock event — fallback for the gap portion
                uint256 gapEnd = LibUint256.min(e.height, endTarget);
                cap += _aggregateUnlockedMaxRedeemableEth(cursor, gapEnd - cursor);
                cursor = gapEnd;
                if (cursor >= endTarget) {
                    break;
                }
            }
            // cursor is within [e.height, e.height + e.amount); contribute lock pro-rata
            uint256 overlapEnd = LibUint256.min(endTarget, e.height + e.amount);
            cap += ((overlapEnd - cursor) * e.lockedEth) / e.amount;
            cursor = overlapEnd;
            ++lockIdx;
        }
        return cap;
    }

    /// @inheritdoc IRedeemManagerV1
    function resolveRedeemRequests(uint32[] calldata _redeemRequestIds)
        external
        view
        returns (int64[] memory withdrawalEventIds)
    {
        withdrawalEventIds = new int64[](_redeemRequestIds.length);
        WithdrawalStack.WithdrawalEvent memory lastWithdrawalEvent;
        WithdrawalStack.WithdrawalEvent[] storage withdrawalEvents = WithdrawalStack.get();
        uint256 withdrawalEventsLength = withdrawalEvents.length;
        if (withdrawalEventsLength > 0) {
            unchecked {
                lastWithdrawalEvent = withdrawalEvents[withdrawalEventsLength - 1];
            }
        }
        for (uint256 idx = 0; idx < _redeemRequestIds.length; ++idx) {
            withdrawalEventIds[idx] = _resolveRedeemRequestId(_redeemRequestIds[idx], lastWithdrawalEvent);
        }
    }

    /// @inheritdoc IRedeemManagerV1
    function requestRedeem(uint256 _lsETHAmount, address _recipient, address _initiator)
        external
        onlyRiver
        returns (uint32 redeemRequestId)
    {
        return _requestRedeem(_lsETHAmount, _recipient, _initiator);
    }

    /// @inheritdoc IRedeemManagerV1
    function requestRedeem(uint256 _lsETHAmount, address _recipient)
        external
        whenNotSlashingContainmentMode
        onlyRedeemer
        returns (uint32 redeemRequestId)
    {
        IRiverV1 river = _castedRiver();
        if (IAllowlistV1(river.getAllowlist()).isDenied(_recipient)) {
            revert RecipientIsDenied();
        }
        return _requestRedeem(_lsETHAmount, _recipient, msg.sender);
    }

    /// @inheritdoc IRedeemManagerV1
    function requestRedeem(uint256 _lsETHAmount)
        external
        whenNotSlashingContainmentMode
        onlyRedeemer
        returns (uint32 redeemRequestId)
    {
        return _requestRedeem(_lsETHAmount, msg.sender, msg.sender);
    }

    /// @inheritdoc IRedeemManagerV1
    function claimRedeemRequests(
        uint32[] calldata redeemRequestIds,
        uint32[] calldata withdrawalEventIds,
        bool skipAlreadyClaimed,
        uint16 _depth
    ) external nonReentrant returns (uint8[] memory claimStatuses) {
        return _claimRedeemRequests(redeemRequestIds, withdrawalEventIds, skipAlreadyClaimed, _depth);
    }

    /// @inheritdoc IRedeemManagerV1
    function claimRedeemRequests(uint32[] calldata _redeemRequestIds, uint32[] calldata _withdrawalEventIds)
        external
        nonReentrant
        returns (uint8[] memory claimStatuses)
    {
        return _claimRedeemRequests(_redeemRequestIds, _withdrawalEventIds, true, type(uint16).max);
    }

    /// @inheritdoc IRedeemManagerV1
    function reportWithdraw(uint256 _lsETHWithdrawable) external payable onlyRiver {
        uint256 redeemDemand = RedeemDemand.get();
        if (_lsETHWithdrawable > redeemDemand) {
            revert WithdrawalExceedsRedeemDemand(_lsETHWithdrawable, redeemDemand);
        }
        WithdrawalStack.WithdrawalEvent[] storage withdrawalEvents = WithdrawalStack.get();
        uint32 withdrawalEventId = uint32(withdrawalEvents.length);
        uint256 height = 0;
        uint256 msgValue = msg.value;
        if (withdrawalEventId != 0) {
            WithdrawalStack.WithdrawalEvent memory previousWithdrawalEvent = withdrawalEvents[withdrawalEventId - 1];
            height = previousWithdrawalEvent.height + previousWithdrawalEvent.amount;
        }
        withdrawalEvents.push(
            WithdrawalStack.WithdrawalEvent({height: height, amount: _lsETHWithdrawable, withdrawnEth: msgValue})
        );
        unchecked {
            _setRedeemDemand(redeemDemand - _lsETHWithdrawable);
        }
        // Note: MaxRedeemableETHLockedDemand is a computed view (NextLockHeight - max(head, firstLockHeight)),
        // so it tracks the consumed portion of the locked region automatically as the head advances.
        emit ReportedWithdrawal(height, _lsETHWithdrawable, msgValue, withdrawalEventId);
    }

    /// @inheritdoc IRedeemManagerV1
    function lockMaxRedeemableETH(
        uint256 _lsETHToLock,
        uint256 _lockedEth,
        uint256 _fromFullExits,
        uint256 _fromPartialWithdrawals,
        uint256 _fromRebalancing
    ) external onlyRiver {
        if (_lsETHToLock == 0) {
            return;
        }
        // The end of the queue is at head + RedeemDemand. The end of the locked region is NextLockHeight.
        // A new lock cannot push the locked region past the queue end.
        uint256 head = _currentMatchingHead();
        uint256 queueEnd = head + RedeemDemand.get();
        uint256 nextLockHeight = NextLockHeight.get();
        if (nextLockHeight + _lsETHToLock > queueEnd) {
            uint256 unlockedHead = queueEnd > nextLockHeight ? queueEnd - nextLockHeight : 0;
            revert LockExceedsRedeemDemand(_lsETHToLock, unlockedHead);
        }

        MaxRedeemableETHLockedStack.MaxRedeemableETHLockedEvent[] storage lockEvents =
            MaxRedeemableETHLockedStack.get();
        uint32 lockEventId = uint32(lockEvents.length);
        lockEvents.push(
            MaxRedeemableETHLockedStack.MaxRedeemableETHLockedEvent({
                height: nextLockHeight,
                amount: _lsETHToLock,
                lockedEth: _lockedEth
            })
        );
        NextLockHeight.set(nextLockHeight + _lsETHToLock);

        emit MaxRedeemableETHLocked(
            lockEventId,
            nextLockHeight,
            _lsETHToLock,
            _lockedEth,
            _fromFullExits,
            _fromPartialWithdrawals,
            _fromRebalancing
        );
    }

    /// @inheritdoc IRedeemManagerV1
    function pullExceedingEth(uint256 _max) external onlyRiver {
        uint256 amountToSend = LibUint256.min(BufferedExceedingEth.get(), _max);
        if (amountToSend > 0) {
            BufferedExceedingEth.set(BufferedExceedingEth.get() - amountToSend);
            _castedRiver().sendRedeemManagerExceedingFunds{value: amountToSend}();
        }
    }

    /// @notice Internal utility to load and cast the River address
    /// @return The casted river address
    function _castedRiver() internal view returns (IRiverV1) {
        return IRiverV1(payable(RiverAddress.get()));
    }

    /// @notice Internal utility to verify if a redeem request and a withdrawal event are matching
    /// @param _redeemRequest The loaded redeem request
    /// @param _withdrawalEvent The load withdrawal event
    /// @return True if matching
    function _isMatch(
        RedeemQueueV2.RedeemRequest memory _redeemRequest,
        WithdrawalStack.WithdrawalEvent memory _withdrawalEvent
    ) internal pure returns (bool) {
        return (_redeemRequest.height < _withdrawalEvent.height + _withdrawalEvent.amount
                && _redeemRequest.height >= _withdrawalEvent.height);
    }

    /// @notice Internal utility to verify if a redeem request and a lock event are matching
    /// @param _redeemRequest The loaded redeem request
    /// @param _lockEvent The loaded lock event
    /// @return True if the request's current head falls within the lock event's range
    function _isMatchLock(
        RedeemQueueV2.RedeemRequest memory _redeemRequest,
        MaxRedeemableETHLockedStack.MaxRedeemableETHLockedEvent memory _lockEvent
    ) internal pure returns (bool) {
        return (_redeemRequest.height < _lockEvent.height + _lockEvent.amount
                && _redeemRequest.height >= _lockEvent.height);
    }

    /// @notice Dichotomic search for the lock event covering the current head of the given request
    /// @dev Returns -1 when no lock event covers the request's height (pre-upgrade slice, or
    ///      post-upgrade slice not yet locked). Lock events are appended monotonically with no
    ///      gaps, so the in-range case always finds a unique match.
    function _findMatchingLockEventId(RedeemQueueV2.RedeemRequest memory _redeemRequest)
        internal
        view
        returns (int64)
    {
        MaxRedeemableETHLockedStack.MaxRedeemableETHLockedEvent[] storage lockEvents =
            MaxRedeemableETHLockedStack.get();
        uint256 len = lockEvents.length;
        if (len == 0) {
            return -1;
        }
        int64 hi = int64(int256(len - 1));
        // before the first lock event → pre-upgrade slice
        if (_redeemRequest.height < lockEvents[0].height) {
            return -1;
        }
        {
            MaxRedeemableETHLockedStack.MaxRedeemableETHLockedEvent memory last = lockEvents[uint64(hi)];
            // beyond the last lock event → post-upgrade not yet locked
            if (_redeemRequest.height >= last.height + last.amount) {
                return -1;
            }
        }
        int64 lo = 0;
        while (lo <= hi) {
            int64 mid = (lo + hi) / 2;
            MaxRedeemableETHLockedStack.MaxRedeemableETHLockedEvent memory midEvent = lockEvents[uint64(mid)];
            if (midEvent.height + midEvent.amount <= _redeemRequest.height) {
                lo = mid + 1;
            } else if (midEvent.height > _redeemRequest.height) {
                hi = mid - 1;
            } else {
                return mid;
            }
        }
        return -1;
    }

    /// @notice Internal utility to perform a dichotomic search of the withdrawal event to use to claim the redeem request
    /// @param _redeemRequest The redeem request to resolve
    /// @return The matching withdrawal event
    function _performDichotomicResolution(RedeemQueueV2.RedeemRequest memory _redeemRequest)
        internal
        view
        returns (int64)
    {
        WithdrawalStack.WithdrawalEvent[] storage withdrawalEvents = WithdrawalStack.get();

        int64 max = int64(int256(WithdrawalStack.get().length - 1));

        if (_isMatch(_redeemRequest, withdrawalEvents[uint64(max)])) {
            return max;
        }

        int64 min = 0;

        if (_isMatch(_redeemRequest, withdrawalEvents[uint64(min)])) {
            return min;
        }

        // we start a dichotomic search between min and max
        while (min != max) {
            int64 mid = (min + max) / 2;

            // we identify and verify that the middle element is not matching
            WithdrawalStack.WithdrawalEvent memory midWithdrawalEvent = withdrawalEvents[uint64(mid)];
            if (_isMatch(_redeemRequest, midWithdrawalEvent)) {
                return mid;
            }

            // depending on the position of the middle element, we update max or min to get our min max range
            // closer to our redeem request position
            if (_redeemRequest.height < midWithdrawalEvent.height) {
                max = mid;
            } else {
                min = mid;
            }
        }
        return min;
    }

    /// @notice Internal utility to resolve a redeem request and retrieve its satisfying withdrawal event id, or identify possible errors
    /// @param _redeemRequestId The redeem request id
    /// @param _lastWithdrawalEvent The last withdrawal event loaded in memory
    /// @return withdrawalEventId The id of the withdrawal event matching the redeem request or error code
    function _resolveRedeemRequestId(
        uint32 _redeemRequestId,
        WithdrawalStack.WithdrawalEvent memory _lastWithdrawalEvent
    ) internal view returns (int64 withdrawalEventId) {
        RedeemQueueV2.RedeemRequest[] storage redeemRequests = RedeemQueueV2.get();
        // if the redeem request id is >= than the size of requests, we know it's out of bounds and doesn't exist
        if (_redeemRequestId >= redeemRequests.length) {
            return RESOLVE_OUT_OF_BOUNDS;
        }
        RedeemQueueV2.RedeemRequest memory redeemRequest = redeemRequests[_redeemRequestId];
        // if the redeem request remaining amount is 0, we know that the request has been entirely claimed
        if (redeemRequest.amount == 0) {
            return RESOLVE_FULLY_CLAIMED;
        }
        // if there are no existing withdrawal events or if the height of the redeem request is higher than the height and
        // amount of the last withdrawal element, we know that the redeem request is not yet satisfied
        if (
            WithdrawalStack.get().length == 0
                || (_lastWithdrawalEvent.height + _lastWithdrawalEvent.amount) <= redeemRequest.height
        ) {
            return RESOLVE_UNSATISFIED;
        }
        // we know for sure that the redeem request has funds yet to be claimed and there is a withdrawal event we need to identify
        // that would allow the user to claim the redeem request
        return _performDichotomicResolution(redeemRequest);
    }

    /// @notice Perform a new redeem request for the specified recipient
    /// @param _lsETHAmount The amount of LsETH to redeem
    /// @param _recipient The recipient owning the request
    /// @param _initiator The initiator of the request
    /// @return redeemRequestId The id of the newly created redeem request
    function _requestRedeem(uint256 _lsETHAmount, address _recipient, address _initiator)
        internal
        returns (uint32 redeemRequestId)
    {
        LibSanitize._notZeroAddress(_recipient);
        if (_lsETHAmount == 0) {
            revert InvalidZeroAmount();
        }
        if (!_castedRiver().transferFrom(msg.sender, address(this), _lsETHAmount)) {
            revert TransferError();
        }
        RedeemQueueV2.RedeemRequest[] storage redeemRequests = RedeemQueueV2.get();
        redeemRequestId = uint32(redeemRequests.length);
        uint256 height = 0;
        if (redeemRequestId != 0) {
            RedeemQueueV2.RedeemRequest memory previousRedeemRequest = redeemRequests[redeemRequestId - 1];
            height = previousRedeemRequest.height + previousRedeemRequest.amount;
        }

        uint256 maxRedeemableEth = _castedRiver().underlyingBalanceFromShares(_lsETHAmount);

        redeemRequests.push(
            RedeemQueueV2.RedeemRequest({
                height: height,
                amount: _lsETHAmount,
                recipient: _recipient,
                initiator: _initiator,
                maxRedeemableEth: maxRedeemableEth
            })
        );

        _setRedeemDemand(RedeemDemand.get() + _lsETHAmount);

        emit RequestedRedeem(_recipient, height, _lsETHAmount, maxRedeemableEth, redeemRequestId);
    }

    /// @notice Internal structure used to optimize stack usage in _claimRedeemRequest
    struct ClaimRedeemRequestParameters {
        /// @custom:attribute The structure of the redeem request to claim
        RedeemQueueV2.RedeemRequest redeemRequest;
        /// @custom:attribute The structure of the withdrawal event to use to claim the redeem request
        WithdrawalStack.WithdrawalEvent withdrawalEvent;
        /// @custom:attribute The structure of the lock event covering the current head (if any)
        MaxRedeemableETHLockedStack.MaxRedeemableETHLockedEvent lockEvent;
        /// @custom:attribute The id of the redeem request to claim
        uint32 redeemRequestId;
        /// @custom:attribute The id of the withdrawal event to use to claim the redeem request
        uint32 withdrawalEventId;
        /// @custom:attribute The id of the lock event covering the current head (only valid when hasLockEvent is true)
        uint32 lockEventId;
        /// @custom:attribute The count of withdrawal events
        uint32 withdrawalEventCount;
        /// @custom:attribute The count of lock events
        uint32 lockEventCount;
        /// @custom:attribute True when a lock event covers the request's current head
        bool hasLockEvent;
        /// @custom:attribute The current depth of the recursive call
        uint16 depth;
        /// @custom:attribute The amount of LsETH redeemed/matched, needs to be reset to 0 for each call/before calling the recursive function
        uint256 lsETHAmount;
        /// @custom:attribute The amount of eth redeemed/matched, needs to be rest to 0 for each call/before calling the recursive function
        uint256 ethAmount;
    }

    /// @notice Internal structure used to optimize stack usage in _claimRedeemRequest
    struct ClaimRedeemRequestInternalVariables {
        /// @custom:attribute The eth amount claimed by the user
        uint256 ethAmount;
        /// @custom:attribute The amount of LsETH matched during this step
        uint256 matchingAmount;
        /// @custom:attribute The amount of eth redirected to the exceeding eth buffer
        uint256 exceedingEthAmount;
    }

    /// @notice Internal utility to save a redeem request to storage
    /// @param _params The parameters of the claim redeem request call
    function _saveRedeemRequest(ClaimRedeemRequestParameters memory _params) internal {
        RedeemQueueV2.RedeemRequest[] storage redeemRequests = RedeemQueueV2.get();
        redeemRequests[_params.redeemRequestId].height = _params.redeemRequest.height;
        redeemRequests[_params.redeemRequestId].amount = _params.redeemRequest.amount;
        redeemRequests[_params.redeemRequestId].maxRedeemableEth = _params.redeemRequest.maxRedeemableEth;
    }

    /// @notice Internal utility to claim a redeem request if possible
    /// @dev Will call itself recursively if the redeem request spans multiple withdrawal or lock events.
    ///      Each iteration processes the largest sub-slice bounded by three end positions:
    ///        (a) the request's own end,
    ///        (b) the current withdrawal event's end,
    ///        (c) the current lock event's end (if a lock event covers the head).
    ///      Cap semantics use override-not-min: when a lock event covers the slice, its pro-rata
    ///      `lockedEth` is the effective cap. Otherwise (pre-upgrade slice, or post-upgrade slice
    ///      not yet locked) the per-request `maxRedeemableEth` pro-rata is the effective cap.
    /// @param _params The parameters of the claim redeem request call
    function _claimRedeemRequest(ClaimRedeemRequestParameters memory _params) internal {
        ClaimRedeemRequestInternalVariables memory vars;
        bool reachedWithdrawalEnd;
        bool reachedLockEnd;
        {
            uint256 withdrawalEventEndPosition = _params.withdrawalEvent.height + _params.withdrawalEvent.amount;
            uint256 withdrawalRemaining = withdrawalEventEndPosition - _params.redeemRequest.height;

            // bound matchingAmount by the request's remaining amount AND the withdrawal event's end
            vars.matchingAmount = LibUint256.min(_params.redeemRequest.amount, withdrawalRemaining);

            // if a lock event covers the request's current head, also bound by the lock event's end
            uint256 lockRemaining;
            if (_params.hasLockEvent) {
                uint256 lockEventEndPosition = _params.lockEvent.height + _params.lockEvent.amount;
                lockRemaining = lockEventEndPosition - _params.redeemRequest.height;
                if (lockRemaining < vars.matchingAmount) {
                    vars.matchingAmount = lockRemaining;
                }
            }

            // pro-rata ETH from the withdrawal event
            vars.ethAmount =
                (vars.matchingAmount * _params.withdrawalEvent.withdrawnEth) / _params.withdrawalEvent.amount;

            // effective cap: lock event overrides per-request maxRedeemableEth when present
            uint256 effectiveCap;
            if (_params.hasLockEvent) {
                effectiveCap =
                    (vars.matchingAmount * _params.lockEvent.lockedEth) / _params.lockEvent.amount;
            } else {
                effectiveCap =
                    (vars.matchingAmount * _params.redeemRequest.maxRedeemableEth) / _params.redeemRequest.amount;
            }

            if (effectiveCap < vars.ethAmount) {
                unchecked {
                    vars.exceedingEthAmount = vars.ethAmount - effectiveCap;
                }
                BufferedExceedingEth.set(BufferedExceedingEth.get() + vars.exceedingEthAmount);
                vars.ethAmount = effectiveCap;
            }

            // height and amount are updated to reflect the amount that was matched.
            // invariant: oldRequest.height + oldRequest.amount == newRequest.height + newRequest.amount
            _params.redeemRequest.height += vars.matchingAmount;
            _params.redeemRequest.amount -= vars.matchingAmount;
            // For lock-covered slices the lock event is the active cap; do not drain per-request
            // maxRedeemableEth (it remains as the fallback for any non-lock-covered tail).
            // For non-lock-covered slices, preserve existing semantics — decrement by the paid amount.
            if (!_params.hasLockEvent) {
                _params.redeemRequest.maxRedeemableEth -= vars.ethAmount;
            }

            _params.lsETHAmount += vars.matchingAmount;
            _params.ethAmount += vars.ethAmount;

            // track which boundaries we hit so the recursion can advance the right stack(s)
            reachedWithdrawalEnd = vars.matchingAmount == withdrawalRemaining;
            reachedLockEnd = _params.hasLockEvent && vars.matchingAmount == lockRemaining;

            emit SatisfiedRedeemRequest(
                _params.redeemRequestId,
                _params.withdrawalEventId,
                vars.matchingAmount,
                vars.ethAmount,
                _params.redeemRequest.amount,
                vars.exceedingEthAmount
            );
        }

        // recurse if there's more of the request to claim and we still have depth budget
        if (_params.redeemRequest.amount > 0 && _params.depth > 0) {
            bool advanced = false;

            // advance the withdrawal event if we hit its boundary
            if (reachedWithdrawalEnd && _params.withdrawalEventId + 1 < _params.withdrawalEventCount) {
                WithdrawalStack.WithdrawalEvent[] storage withdrawalEvents = WithdrawalStack.get();
                ++_params.withdrawalEventId;
                _params.withdrawalEvent = withdrawalEvents[_params.withdrawalEventId];
                advanced = true;
            }

            // advance the lock event if we hit its boundary
            if (reachedLockEnd) {
                if (_params.lockEventId + 1 < _params.lockEventCount) {
                    MaxRedeemableETHLockedStack.MaxRedeemableETHLockedEvent[] storage lockEvents =
                        MaxRedeemableETHLockedStack.get();
                    MaxRedeemableETHLockedStack.MaxRedeemableETHLockedEvent memory nextLock =
                        lockEvents[_params.lockEventId + 1];
                    // The next lock event covers the new head only if its height matches (no gaps within
                    // post-upgrade lock coverage). If not, we've fallen off the lock-covered region.
                    if (nextLock.height == _params.redeemRequest.height) {
                        ++_params.lockEventId;
                        _params.lockEvent = nextLock;
                        // hasLockEvent stays true
                    } else {
                        _params.hasLockEvent = false;
                    }
                } else {
                    _params.hasLockEvent = false;
                }
                advanced = true;
            }

            // if a lock event covers the new head but params doesn't reflect it yet (e.g., we crossed
            // from pre-upgrade unlocked region into a lock-covered region), pick it up. This is the
            // mirror of the boundary above and handles requests that start before any lock event and
            // continue into one.
            if (!_params.hasLockEvent) {
                int64 nextLockId = _findMatchingLockEventId(_params.redeemRequest);
                if (nextLockId >= 0) {
                    MaxRedeemableETHLockedStack.MaxRedeemableETHLockedEvent[] storage lockEvents =
                        MaxRedeemableETHLockedStack.get();
                    _params.lockEventId = uint32(uint64(nextLockId));
                    _params.lockEvent = lockEvents[_params.lockEventId];
                    _params.hasLockEvent = true;
                    advanced = true;
                }
            }

            if (advanced) {
                --_params.depth;
                _claimRedeemRequest(_params);
                return;
            }
        }

        // exit: either fully claimed, depth exhausted, or no further withdrawal event to advance to
        _saveRedeemRequest(_params);
    }

    /// @notice Internal utility to claim several redeem requests at once
    /// @param _redeemRequestIds The list of redeem requests to claim
    /// @param _withdrawalEventIds The list of withdrawal events to use for each redeem request. Should have the same length.
    /// @param _skipAlreadyClaimed True if the system should skip redeem requests already claimed, otherwise will revert
    /// @param _depth The depth of the recursion to use when claiming a redeem request
    /// @return claimStatuses The claim statuses for each redeem request
    function _claimRedeemRequests(
        uint32[] calldata _redeemRequestIds,
        uint32[] calldata _withdrawalEventIds,
        bool _skipAlreadyClaimed,
        uint16 _depth
    ) internal returns (uint8[] memory claimStatuses) {
        uint256 redeemRequestIdsLength = _redeemRequestIds.length;
        if (redeemRequestIdsLength != _withdrawalEventIds.length) {
            revert IncompatibleArrayLengths();
        }
        claimStatuses = new uint8[](redeemRequestIdsLength);

        RedeemQueueV2.RedeemRequest[] storage redeemRequests = RedeemQueueV2.get();
        WithdrawalStack.WithdrawalEvent[] storage withdrawalEvents = WithdrawalStack.get();
        MaxRedeemableETHLockedStack.MaxRedeemableETHLockedEvent[] storage lockEvents =
            MaxRedeemableETHLockedStack.get();

        ClaimRedeemRequestParameters memory params;
        params.withdrawalEventCount = uint32(withdrawalEvents.length);
        params.lockEventCount = uint32(lockEvents.length);
        uint32 redeemRequestCount = uint32(redeemRequests.length);

        IAllowlistV1 allowList = IAllowlistV1(_castedRiver().getAllowlist());

        for (uint256 idx = 0; idx < redeemRequestIdsLength; ++idx) {
            // both ids are loaded into params
            params.redeemRequestId = _redeemRequestIds[idx];
            params.withdrawalEventId = _withdrawalEventIds[idx];

            // we start by checking that the id is not out of bounds for the redeem requests
            if (params.redeemRequestId >= redeemRequestCount) {
                revert RedeemRequestOutOfBounds(params.redeemRequestId);
            }

            // we check that the withdrawal event id is not out of bounds
            if (params.withdrawalEventId >= params.withdrawalEventCount) {
                revert WithdrawalEventOutOfBounds(params.withdrawalEventId);
            }

            // we load the redeem request in memory
            params.redeemRequest = redeemRequests[_redeemRequestIds[idx]];

            if (allowList.isDenied(params.redeemRequest.recipient)) {
                revert ClaimRecipientIsDenied();
            }
            if (allowList.isDenied(params.redeemRequest.initiator)) {
                revert ClaimInitiatorIsDenied();
            }

            // we check that the redeem request is not already claimed
            if (params.redeemRequest.amount == 0) {
                if (_skipAlreadyClaimed) {
                    claimStatuses[idx] = CLAIM_SKIPPED;
                    continue;
                }
                revert RedeemRequestAlreadyClaimed(params.redeemRequestId);
            }

            // we load the withdrawal event in memory
            params.withdrawalEvent = withdrawalEvents[_withdrawalEventIds[idx]];

            // now that both entities are loaded in memory, we verify that they indeed match, otherwise we revert
            if (!_isMatch(params.redeemRequest, params.withdrawalEvent)) {
                revert DoesNotMatch(params.redeemRequestId, params.withdrawalEventId);
            }

            // resolve the lock event covering the request's current head, if any. Pre-upgrade requests
            // and post-upgrade requests claimed before their lock arrived will not have one — fallback
            // to per-request maxRedeemableEth in _claimRedeemRequest.
            {
                int64 lockEventId = _findMatchingLockEventId(params.redeemRequest);
                if (lockEventId >= 0) {
                    params.lockEventId = uint32(uint64(lockEventId));
                    params.lockEvent = lockEvents[params.lockEventId];
                    params.hasLockEvent = true;
                } else {
                    params.hasLockEvent = false;
                }
            }

            params.depth = _depth;
            params.ethAmount = 0;
            params.lsETHAmount = 0;

            _claimRedeemRequest(params);

            claimStatuses[idx] = params.redeemRequest.amount == 0 ? CLAIM_FULLY_CLAIMED : CLAIM_PARTIALLY_CLAIMED;

            {
                (bool success, bytes memory rdata) = params.redeemRequest.recipient.call{value: params.ethAmount}("");
                if (!success) {
                    revert ClaimRedeemFailed(params.redeemRequest.recipient, rdata);
                }
            }
            emit ClaimedRedeemRequest(
                _redeemRequestIds[idx],
                params.redeemRequest.recipient,
                params.ethAmount,
                params.lsETHAmount,
                params.redeemRequest.amount
            );
        }
    }

    /// @notice Internal utility to set the redeem demand
    /// @param _newValue The new value to set
    function _setRedeemDemand(uint256 _newValue) internal {
        emit SetRedeemDemand(RedeemDemand.get(), _newValue);
        RedeemDemand.set(_newValue);
    }

    /// @notice The current cumulative LsETH position fully matched by appended WithdrawalEvents
    /// @return The end position of the last WithdrawalEvent, or 0 if none
    function _currentMatchingHead() internal view returns (uint256) {
        WithdrawalStack.WithdrawalEvent[] storage withdrawalEvents = WithdrawalStack.get();
        uint256 len = withdrawalEvents.length;
        if (len == 0) {
            return 0;
        }
        WithdrawalStack.WithdrawalEvent storage last = withdrawalEvents[len - 1];
        return last.height + last.amount;
    }

    /// @notice Sums per-request maxRedeemableEth contributions covering [startHeight, startHeight + amount)
    /// @dev Used as a fallback by getEffectiveCapForDemand for queue ranges not yet covered by a lock event
    ///      (pre-upgrade tail, or post-upgrade slices reportWithdraw'd before their lock arrived).
    function _aggregateUnlockedMaxRedeemableEth(uint256 startHeight, uint256 amount)
        internal
        view
        returns (uint256)
    {
        RedeemQueueV2.RedeemRequest[] storage requests = RedeemQueueV2.get();
        uint256 len = requests.length;
        if (len == 0 || amount == 0) {
            return 0;
        }

        uint256 cap;
        uint256 cursor = startHeight;
        uint256 endTarget = startHeight + amount;

        for (uint256 i = 0; i < len; ++i) {
            RedeemQueueV2.RedeemRequest storage r = requests[i];
            // fully-claimed requests have amount == 0; their range is empty, skip
            if (r.amount == 0) {
                continue;
            }
            uint256 rEnd = r.height + r.amount;
            if (rEnd <= cursor) {
                continue;
            }
            if (r.height >= endTarget) {
                break;
            }
            uint256 overlapStart = LibUint256.max(cursor, r.height);
            uint256 overlapEnd = LibUint256.min(endTarget, rEnd);
            uint256 overlap = overlapEnd - overlapStart;
            cap += (overlap * r.maxRedeemableEth) / r.amount;
            cursor = overlapEnd;
            if (cursor >= endTarget) {
                break;
            }
        }
        return cap;
    }

    function version() external pure returns (string memory) {
        return "1.4.0";
    }
}
