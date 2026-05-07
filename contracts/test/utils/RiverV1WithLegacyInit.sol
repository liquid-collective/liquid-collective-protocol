// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../src/River.1.sol";

/// @title RiverV1WithLegacyInit (test-only)
/// @notice Test base that adds back the v1.0/v1.1/v1.2 initializers to RiverV1.
///         Production RiverV1 only ships `initRiverV1_3` because the older
///         versions can never be re-run on the upgraded mainnet proxy (their
///         `init(N)` modifier reverts once the version counter advances). The
///         older bodies remain useful in tests for bootstrapping fresh River
///         instances from genesis state.
/// @dev Code is identical to the bodies that previously lived in
///      contracts/src/River.1.sol — kept in lockstep with the historical mainnet
///      initialization sequence.
abstract contract RiverV1WithLegacyInit is RiverV1 {
    function initRiverV1(
        address _depositContractAddress,
        address _elFeeRecipientAddress,
        bytes32 _withdrawalCredentials,
        address _oracleAddress,
        address _systemAdministratorAddress,
        address _allowlistAddress,
        address _operatorRegistryAddress,
        address _collectorAddress,
        uint256 _globalFee
    ) external init(0) {
        _setAdmin(_systemAdministratorAddress);

        CollectorAddress.set(_collectorAddress);
        emit SetCollector(_collectorAddress);

        GlobalFee.set(_globalFee);
        emit SetGlobalFee(_globalFee);

        ELFeeRecipientAddress.set(_elFeeRecipientAddress);
        emit SetELFeeRecipient(_elFeeRecipientAddress);

        AllowlistAddress.set(_allowlistAddress);
        emit SetAllowlist(_allowlistAddress);

        OperatorsRegistryAddress.set(_operatorRegistryAddress);
        emit SetOperatorsRegistry(_operatorRegistryAddress);

        ConsensusLayerDepositManagerV1.initConsensusLayerDepositManagerV1_2(
            _depositContractAddress, _withdrawalCredentials
        );

        OracleManagerV1.initOracleManagerV1(_oracleAddress);
    }

    function initRiverV1_1(
        address _redeemManager,
        uint64 _epochsPerFrame,
        uint64 _slotsPerEpoch,
        uint64 _secondsPerSlot,
        uint64 _genesisTime,
        uint64 _epochsToAssumedFinality,
        uint256 _annualAprUpperBound,
        uint256 _relativeLowerBound,
        uint128 _minDailyNetCommittableAmount_,
        uint128 _maxDailyRelativeCommittableAmount_
    ) external init(1) {
        RedeemManagerAddress.set(_redeemManager);
        emit SetRedeemManager(_redeemManager);

        _setDailyCommittableLimits(
            DailyCommittableLimits.DailyCommittableLimitsStruct({
                minDailyNetCommittableAmount: _minDailyNetCommittableAmount_,
                maxDailyRelativeCommittableAmount: _maxDailyRelativeCommittableAmount_
            })
        );

        initOracleManagerV1_1(
            _epochsPerFrame,
            _slotsPerEpoch,
            _secondsPerSlot,
            _genesisTime,
            _epochsToAssumedFinality,
            _annualAprUpperBound,
            _relativeLowerBound
        );

        _approve(address(this), _redeemManager, type(uint256).max);
    }

    function initRiverV1_2() external init(2) {
        // force committed balance to a multiple of 32 ETH and
        // move extra funds back to the deposit buffer
        uint256 dustToUncommit = CommittedBalance.get() % DEPOSIT_SIZE;
        unchecked {
            _setCommittedBalance(CommittedBalance.get() - dustToUncommit);
            _setBalanceToDeposit(BalanceToDeposit.get() + dustToUncommit);
        }
    }
}
