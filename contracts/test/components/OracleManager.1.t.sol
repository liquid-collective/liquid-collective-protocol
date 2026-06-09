//SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.34;

import "forge-std/Test.sol";

import "../utils/UserFactory.sol";
import "../utils/LibImplementationUnbricker.sol";

import "../../src/components/OracleManager.1.sol";
import "../../src/libraries/LibUint256.sol";
import "../../src/state/shared/AdministratorAddress.sol";
import "../../src/state/river/DepositedValidatorCount.sol";
import "../../src/state/river/ConsolidationBuffer.sol";

contract OracleManagerV1ExposeInitializer is OracleManagerV1 {
    event Internal_SetConsolidationBuffer(uint256 oldValue, uint256 newValue);

    function _setConsolidationBuffer(uint256 _oldConsolidationBuffer, uint256 _newConsolidationBuffer)
        internal
        override
    {
        emit Internal_SetConsolidationBuffer(_oldConsolidationBuffer, _newConsolidationBuffer);
        // Persist like RiverV1 does so buffer changes are observable in storage and in _assetBalance.
        ConsolidationBuffer.set(_newConsolidationBuffer);
    }

    function supersedeReportedBalanceSum(uint256 amount) external {
        LastConsensusLayerReport.get().validatorsBalance = amount;
    }

    function supersedeReportedValidatorCount(uint256 amount) external {
        LastConsensusLayerReport.get().validatorsCount = uint32(amount);
    }

    function supersedeTotalConsolidationsAmountReported(uint256 amount) external {
        LastConsensusLayerReport.get().totalExternalConsolidationsAmountReported = amount;
    }

    function supersedeDepositedValidatorCount(uint256 amount) external {
        DepositedValidatorCount.set(amount);
    }

    function _getRiverAdmin() internal view override returns (address) {
        return AdministratorAddress.get();
    }

    constructor(
        address oracle,
        address admin,
        uint64 epochsPerFrame,
        uint64 slotsPerEpoch,
        uint64 secondsPerSlot,
        uint64 genesisTime,
        uint64 epochsToAssumedFinality,
        uint256 annualAprUpperBound,
        uint256 relativeLowerBound
    ) {
        AdministratorAddress.set(admin);
        initOracleManagerV1(oracle);
        initOracleManagerV1_1(
            epochsPerFrame,
            slotsPerEpoch,
            secondsPerSlot,
            genesisTime,
            epochsToAssumedFinality,
            annualAprUpperBound,
            relativeLowerBound
        );
    }

    // internal hooks

    uint256 amountToRedeem;
    uint256 amountToDeposit;

    event Internal_OnEarnings(uint256 amount);

    function _onEarnings(uint256 amount) internal override {
        emit Internal_OnEarnings(amount);
    }

    uint256 public elFeesAvailable;

    function sudoSetElFeesAvailable(uint256 newValue) external {
        elFeesAvailable = newValue;
    }

    event Internal_PullELFees(uint256 _max, uint256 _returned);

    function _pullELFees(uint256 _max) internal override returns (uint256 result) {
        result = LibUint256.min(elFeesAvailable, _max);
        amountToDeposit += result;
        emit Internal_PullELFees(_max, result);
    }

    uint256 public coverageFundAvailable;

    function sudoSetCoverageFundAvailable(uint256 newValue) external {
        coverageFundAvailable = newValue;
    }

    event Internal_PullCoverageFunds(uint256 _max, uint256 _returned);

    function _pullCoverageFunds(uint256 _max) internal override returns (uint256 result) {
        result = LibUint256.min(coverageFundAvailable, _max);
        amountToDeposit += result;
        emit Internal_PullCoverageFunds(_max, result);
    }

    uint256 public consolidationCoverageFundAvailable;

    function sudoSetConsolidationCoverageFundAvailable(uint256 newValue) external {
        consolidationCoverageFundAvailable = newValue;
    }

    event Internal_PullConsolidationCoverageFunds(uint256 _max, uint256 _returned);

    function _pullConsolidationCoverageFunds(uint256 _max) internal override returns (uint256 result) {
        result = LibUint256.min(consolidationCoverageFundAvailable, _max);
        amountToDeposit += result;
        emit Internal_PullConsolidationCoverageFunds(_max, result);
    }

    function _assetBalance() internal view override returns (uint256 result) {
        // Mirror RiverV1._assetBalance by including the consolidation buffer in the total underlying.
        result = (DepositedValidatorCount.get() - LastConsensusLayerReport.get().validatorsCount) * 32 ether
            + LastConsensusLayerReport.get().validatorsBalance + amountToDeposit + amountToRedeem
            + ConsolidationBuffer.get();
    }

    function debug_getTotalUnderlyingBalance() external view returns (uint256) {
        return _assetBalance();
    }

    uint256 public redeemDemand;

    function sudoSetRedeemDemand(uint256 newValue) external {
        redeemDemand = newValue;
    }

    event Internal_ReportWithdrawToRedeemManager(uint256 currentAmountToRedeem);

    function _reportWithdrawToRedeemManager() internal override {
        emit Internal_ReportWithdrawToRedeemManager(amountToRedeem);
        uint256 amountToUse = LibUint256.min(amountToRedeem, redeemDemand);
        amountToRedeem -= amountToUse;
        redeemDemand -= amountToUse;
    }

    event Internal_PullCLFunds(uint256 skimmedEthAmount, uint256 exitedEthAmount);

    function _pullCLFunds(uint256 skimmedEthAmount, uint256 exitedEthAmount) internal override {
        amountToDeposit += skimmedEthAmount;
        amountToRedeem += exitedEthAmount;
        emit Internal_PullCLFunds(skimmedEthAmount, exitedEthAmount);
    }

    uint256 public exceedingEth;

    function sudoSetExceedingEth(uint256 newValue) external {
        exceedingEth = newValue;
    }

    event Internal_PullRedeemManagerExceedingEth(uint256 max, uint256 result);

    function _pullRedeemManagerExceedingEth(uint256 max) internal override returns (uint256 result) {
        result = LibUint256.min(max, exceedingEth);
        emit Internal_PullRedeemManagerExceedingEth(max, result);
        amountToDeposit += result;
    }

    event Internal_SetReportedExitedETH(uint256[] exitedETHPerOperator);
    event Internal_ReportCLETH(uint256[] activeCLETHPerOperator);

    event Internal_RequestExitsBasedOnRedeemDemandAfterRebalancings(
        uint256 exitingBalance, bool depositToRedeemRebalancingAllowed, uint256 exitCountRequest
    );

    function _requestExitsBasedOnRedeemDemandAfterRebalancings(
        uint256 exitingBalance,
        uint256[] memory exitedETHPerOperator,
        uint256 totalAvailableCLETH,
        bool depositToRedeemRebalancingAllowed,
        bool slashingContainmentModeEnabled
    ) internal override {
        uint256 exitCount = 0;

        emit Internal_SetReportedExitedETH(exitedETHPerOperator);

        if (slashingContainmentModeEnabled) {
            return;
        }

        if (redeemDemand > amountToRedeem + exitingBalance) {
            exitCount = LibUint256.ceil((redeemDemand - (amountToRedeem + exitingBalance)), 32 ether);
        }
        emit Internal_RequestExitsBasedOnRedeemDemandAfterRebalancings(
            exitingBalance, depositToRedeemRebalancingAllowed, exitCount
        );
    }

    function _reportCLETH(uint256[] memory _activeCLETH) internal override {
        emit Internal_ReportCLETH(_activeCLETH);
    }

    event Internal_CommitBalanceToDeposit(uint256 period, uint256 depositBalance);

    function _commitBalanceToDeposit(uint256 period, bool slashingContainmentModeEnabled) internal override {
        emit Internal_CommitBalanceToDeposit(period, amountToDeposit);
    }

    event Internal_SkimExcessBalanceToRedeem(uint256 balanceToDeposit, uint256 balanceToRedeem);

    function _skimExcessBalanceToRedeem() internal override {
        emit Internal_SkimExcessBalanceToRedeem(amountToDeposit, amountToRedeem);
        amountToDeposit += amountToRedeem;
        amountToRedeem = 0;
    }
}

contract OracleManagerV1Tests is Test {
    UserFactory internal uf = new UserFactory();

    address internal oracle;
    address internal admin;

    OracleManagerV1 internal oracleManager;

    event SetOracle(address indexed oracleAddress);

    uint64 internal constant epochsPerFrame = 225;
    uint64 internal constant slotsPerEpoch = 32;
    uint64 internal constant secondsPerSlot = 12;
    uint64 internal constant genesisTime = 12345;
    uint64 internal constant epochsToAssumedFinality = 4;
    uint256 internal constant annualAprUpperBound = 1000;
    uint256 internal constant relativeLowerBound = 250;

    event Internal_OnEarnings(uint256 amount);
    event Internal_PullELFees(uint256 _max, uint256 _returned);
    event Internal_PullCoverageFunds(uint256 _max, uint256 _returned);
    event Internal_ReportWithdrawToRedeemManager(uint256 currentAmountToRedeem);
    event Internal_PullCLFunds(uint256 skimmedEthAmount, uint256 exitedEthAmount);
    event Internal_PullRedeemManagerExceedingEth(uint256 max, uint256 result);
    event Internal_RequestExitsBasedOnRedeemDemandAfterRebalancings(
        uint256 exitingBalance, bool depositToRedeemRebalancingAllowed, uint256 exitCountRequest
    );
    event Internal_CommitBalanceToDeposit(uint256 period, uint256 depositBalance);
    event Internal_SkimExcessBalanceToRedeem(uint256 balanceToDeposit, uint256 balanceToRedeem);
    event Internal_SetReportedExitedETH(uint256[] exitedETHPerOperator);

    function setUp() public {
        admin = makeAddr("admin");
        oracle = makeAddr("oracle");
        oracleManager = new OracleManagerV1ExposeInitializer(
            oracle,
            admin,
            epochsPerFrame,
            slotsPerEpoch,
            secondsPerSlot,
            genesisTime,
            epochsToAssumedFinality,
            annualAprUpperBound,
            relativeLowerBound
        );
        LibImplementationUnbricker.unbrick(vm, address(oracleManager));
        vm.warp(genesisTime);
    }

    function testSetOracle(uint256 _oracleSalt) public {
        address _oracle = uf._new(_oracleSalt);
        assert(oracleManager.getOracle() == oracle);
        vm.prank(admin);
        vm.expectEmit(true, true, true, true);
        emit SetOracle(_oracle);
        oracleManager.setOracle(_oracle);
        assert(oracleManager.getOracle() == _oracle);
    }

    function testSetOracleUnauthorized(uint256 _oracleSalt) public {
        address _oracle = uf._new(_oracleSalt);
        assert(oracleManager.getOracle() == oracle);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", address(this)));
        oracleManager.setOracle(_oracle);
    }

    function _next(uint256 _salt) internal pure returns (uint256) {
        return uint256(keccak256(abi.encode(_salt)));
    }

    struct ReportingVars {
        IOracleManagerV1.ConsensusLayerReport clr;
        CLSpec.CLSpecStruct cls;
        ReportBounds.ReportBoundsStruct rb;
        uint256 depositedValidatorCount;
        uint256 reportedValidatorCount;
        uint256 currentTotalUnderlyingSupply;
        uint256 maxIncrease;
        uint256 elFeesAvailable;
        uint256 exceedingEth;
        uint256 coverageFundAvailable;
    }

    function testFuzzedReporting(uint256 _salt) external {
        ReportingVars memory v;
        OracleManagerV1ExposeInitializer om = OracleManagerV1ExposeInitializer(address(oracleManager));
        v.cls = om.getCLSpec();
        v.rb = om.getReportBounds();

        {
            // setup

            v.depositedValidatorCount = bound(_salt, 1, type(uint16).max);
            om.supersedeDepositedValidatorCount(v.depositedValidatorCount);

            _salt = _next(_salt);

            v.reportedValidatorCount = bound(_salt, 0, v.depositedValidatorCount);
            om.supersedeReportedValidatorCount(v.reportedValidatorCount);

            _salt = _next(_salt);

            uint256 reportedValidatorBalanceSum = v.reportedValidatorCount * 32 ether; // no rewards
            om.supersedeReportedBalanceSum(reportedValidatorBalanceSum);

            assertEq(om.debug_getTotalUnderlyingBalance(), v.depositedValidatorCount * 32 ether);
        }

        v.currentTotalUnderlyingSupply = om.debug_getTotalUnderlyingBalance();

        v.clr.epoch = bound(_salt, 1, 1_000_000) * epochsPerFrame;
        vm.warp(genesisTime + (v.clr.epoch + epochsToAssumedFinality) * v.cls.slotsPerEpoch * v.cls.secondsPerSlot);

        v.maxIncrease =
            debug_maxIncrease(v.rb, v.currentTotalUnderlyingSupply, debug_timeBetweenEpochs(v.cls, 0, v.clr.epoch));

        _salt = _next(_salt);

        uint256 stoppedValidatorCount = bound(_salt, 0, v.depositedValidatorCount);
        _salt = _next(_salt);
        uint256 exitedCount = bound(_salt, 0, stoppedValidatorCount);
        _salt = _next(_salt);

        v.clr.validatorsCount = uint32(v.depositedValidatorCount);
        v.clr.validatorsBalance = (v.depositedValidatorCount - exitedCount) * 32 ether;
        v.clr.validatorsSkimmedBalance = bound(_salt, 0, v.maxIncrease);
        v.maxIncrease -= v.clr.validatorsSkimmedBalance;
        _salt = _next(_salt);
        om.sudoSetElFeesAvailable(bound(_salt, 0, v.maxIncrease));
        _salt = _next(_salt);
        om.sudoSetExceedingEth(bound(_salt, 0, v.maxIncrease - om.elFeesAvailable()));
        _salt = _next(_salt);
        om.sudoSetCoverageFundAvailable(bound(_salt, 0, v.maxIncrease - om.elFeesAvailable() - om.exceedingEth()));

        v.clr.validatorsExitedBalance = exitedCount * 32 ether;
        v.clr.validatorsExitingBalance = (stoppedValidatorCount - exitedCount) * 32 ether;
        v.clr.exitedETHPerOperator = new uint256[](1);
        v.clr.rebalanceDepositToRedeemMode = false;
        v.clr.slashingContainmentMode = false;

        v.elFeesAvailable = om.elFeesAvailable();
        v.exceedingEth = om.exceedingEth();
        v.coverageFundAvailable = om.coverageFundAvailable();

        {
            (uint256 epochStart, uint256 timeStart, uint256 timeEnd) = om.getCurrentFrame();

            assertEq(epochStart, v.clr.epoch);
            assertEq(timeStart, v.clr.epoch * v.cls.slotsPerEpoch * v.cls.secondsPerSlot);
            assertEq(timeEnd, (v.clr.epoch + v.cls.epochsPerFrame) * v.cls.slotsPerEpoch * v.cls.secondsPerSlot - 1);
        }

        assertEq(om.getCurrentEpochId(), v.clr.epoch + epochsToAssumedFinality);
        assertEq(om.getFrameFirstEpochId(v.clr.epoch), v.clr.epoch);

        if (v.clr.validatorsSkimmedBalance + v.clr.validatorsExitedBalance > 0) {
            vm.expectEmit(true, true, true, true);
            emit Internal_PullCLFunds(v.clr.validatorsSkimmedBalance, v.clr.validatorsExitedBalance);
        }
        vm.expectEmit(true, true, true, true);
        emit Internal_PullELFees(v.maxIncrease, v.elFeesAvailable);
        vm.expectEmit(true, true, true, true);
        emit Internal_PullRedeemManagerExceedingEth(v.maxIncrease - v.elFeesAvailable, v.exceedingEth);
        vm.expectEmit(true, true, true, true);
        emit Internal_PullCoverageFunds(v.maxIncrease - v.elFeesAvailable - v.exceedingEth, v.coverageFundAvailable);
        vm.expectEmit(true, true, true, true);
        emit Internal_OnEarnings(v.elFeesAvailable + v.clr.validatorsSkimmedBalance);
        vm.expectEmit(true, true, true, true);
        emit Internal_SetReportedExitedETH(v.clr.exitedETHPerOperator);
        vm.expectEmit(true, true, true, true);
        emit Internal_RequestExitsBasedOnRedeemDemandAfterRebalancings(v.clr.validatorsExitingBalance, false, 0);
        vm.expectEmit(true, true, true, true);
        emit Internal_ReportWithdrawToRedeemManager(v.clr.validatorsExitedBalance);
        vm.expectEmit(true, true, true, true);
        emit Internal_SkimExcessBalanceToRedeem(
            v.clr.validatorsSkimmedBalance
                + LibUint256.min(v.maxIncrease, v.elFeesAvailable + v.exceedingEth + v.coverageFundAvailable),
            v.clr.validatorsExitedBalance
        );
        vm.expectEmit(true, true, true, true);
        emit Internal_CommitBalanceToDeposit(
            debug_timeBetweenEpochs(v.cls, 0, v.clr.epoch),
            v.clr.validatorsSkimmedBalance
                + LibUint256.min(v.maxIncrease, v.elFeesAvailable + v.exceedingEth + v.coverageFundAvailable)
                + v.clr.validatorsExitedBalance
        );
        vm.prank(oracle);
        om.setConsensusLayerData(v.clr);

        assertEq(om.getLastCompletedEpochId(), v.clr.epoch);
        assertEq(om.getExpectedEpochId(), v.clr.epoch + v.cls.epochsPerFrame);
    }

    function debug_maxIncrease(ReportBounds.ReportBoundsStruct memory rb, uint256 _prevTotalEth, uint256 _timeElapsed)
        internal
        pure
        returns (uint256)
    {
        return (_prevTotalEth * rb.annualAprUpperBound * _timeElapsed) / (LibBasisPoints.BASIS_POINTS_MAX * 365 days);
    }

    function debug_maxDecrease(ReportBounds.ReportBoundsStruct memory rb, uint256 _prevTotalEth)
        internal
        pure
        returns (uint256)
    {
        return (_prevTotalEth * rb.relativeLowerBound) / LibBasisPoints.BASIS_POINTS_MAX;
    }

    function debug_timeBetweenEpochs(CLSpec.CLSpecStruct memory cls, uint256 epochPast, uint256 epochNow)
        internal
        pure
        returns (uint256)
    {
        return (epochNow - epochPast) * (cls.secondsPerSlot * cls.slotsPerEpoch);
    }

    event SetSpec(
        uint64 epochsPerFrame,
        uint64 slotsPerEpoch,
        uint64 secondsPerSlot,
        uint64 genesisTime,
        uint64 epochsToAssumedFinality
    );
    event SetBounds(uint256 annualAprUpperBound, uint256 relativeLowerBound);

    function testSetCLSpec(
        uint64 _genesisTime,
        uint64 _epochsPerFrame,
        uint64 _slotsPerEpoch,
        uint64 _secondsPerSlot,
        uint64 _epochsToAssumedFinality
    ) external {
        CLSpec.CLSpecStruct memory newValue;
        newValue.genesisTime = _genesisTime;
        newValue.epochsPerFrame = _epochsPerFrame;
        newValue.slotsPerEpoch = _slotsPerEpoch;
        newValue.secondsPerSlot = _secondsPerSlot;
        newValue.epochsToAssumedFinality = _epochsToAssumedFinality;

        vm.prank(admin);
        vm.expectEmit(true, true, true, true);
        emit SetSpec(_epochsPerFrame, _slotsPerEpoch, _secondsPerSlot, _genesisTime, _epochsToAssumedFinality);
        oracleManager.setCLSpec(newValue);

        newValue = oracleManager.getCLSpec();

        assertEq(newValue.genesisTime, _genesisTime);
        assertEq(newValue.epochsPerFrame, _epochsPerFrame);
        assertEq(newValue.slotsPerEpoch, _slotsPerEpoch);
        assertEq(newValue.secondsPerSlot, _secondsPerSlot);
        assertEq(newValue.epochsToAssumedFinality, _epochsToAssumedFinality);
    }

    function testSetCLSpecUnauthorized(
        uint64 _genesisTime,
        uint64 _epochsPerFrame,
        uint64 _slotsPerEpoch,
        uint64 _secondsPerSlot,
        uint64 _epochsToAssumedFinality
    ) external {
        CLSpec.CLSpecStruct memory newValue;
        newValue.genesisTime = _genesisTime;
        newValue.epochsPerFrame = _epochsPerFrame;
        newValue.slotsPerEpoch = _slotsPerEpoch;
        newValue.secondsPerSlot = _secondsPerSlot;
        newValue.epochsToAssumedFinality = _epochsToAssumedFinality;

        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", address(this)));
        oracleManager.setCLSpec(newValue);
    }

    function testSetReportBounds(uint256 upper, uint256 lower) external {
        ReportBounds.ReportBoundsStruct memory newValue;
        newValue.annualAprUpperBound = upper;
        newValue.relativeLowerBound = lower;

        vm.prank(admin);
        vm.expectEmit(true, true, true, true);
        emit SetBounds(upper, lower);
        oracleManager.setReportBounds(newValue);

        newValue = oracleManager.getReportBounds();

        assertEq(newValue.annualAprUpperBound, upper);
        assertEq(newValue.relativeLowerBound, lower);
    }

    function testSetReportBoundsUnauthorized(uint256 upper, uint256 lower) external {
        ReportBounds.ReportBoundsStruct memory newValue;
        newValue.annualAprUpperBound = upper;
        newValue.relativeLowerBound = lower;

        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", address(this)));
        oracleManager.setReportBounds(newValue);
    }

    function testExternalViewFunctions() external {
        assertEq(false, oracleManager.isValidEpoch(1));
        assertEq(0, oracleManager.getCLValidatorCount());
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// OracleManager view and revert tests
// ─────────────────────────────────────────────────────────────────────────────

contract OracleManagerV1CoverageTests is OracleManagerV1Tests {
    bytes32 constant IN_FLIGHT_DEPOSIT_SLOT = bytes32(uint256(keccak256("river.state.inFlightDeposit")) - 1);
    bytes32 constant CONSOLIDATION_BUFFER_SLOT = bytes32(uint256(keccak256("river.state.consolidationBuffer")) - 1);
    bytes32 constant LAST_CLR_BASE_SLOT = bytes32(uint256(keccak256("river.state.lastConsensusLayerReport")) - 1);

    event Internal_PullConsolidationCoverageFunds(uint256 _max, uint256 _returned);
    event Internal_SetConsolidationBuffer(uint256 oldValue, uint256 newValue);

    /// Asserts that getCLValidatorTotalBalance returns the value stored in the last consensus layer report.
    function testGetCLValidatorTotalBalance() public {
        OracleManagerV1ExposeInitializer om = OracleManagerV1ExposeInitializer(address(oracleManager));
        om.supersedeReportedBalanceSum(99 ether);
        assertEq(oracleManager.getCLValidatorTotalBalance(), 99 ether);
    }

    /// Asserts that getLastConsensusLayerReport returns the stored report with the expected validatorsBalance.
    function testGetLastConsensusLayerReport() public {
        OracleManagerV1ExposeInitializer om = OracleManagerV1ExposeInitializer(address(oracleManager));
        om.supersedeReportedBalanceSum(64 ether);
        IOracleManagerV1.StoredConsensusLayerReport memory r = oracleManager.getLastConsensusLayerReport();
        assertEq(r.validatorsBalance, 64 ether);
    }

    /// Asserts that setConsensusLayerData reverts with InvalidTotalDepositedActivatedETHIncrease when
    /// the reported totalDepositedActivatedETH increase exceeds the current InFlightDeposit.
    function testSetConsensusLayerDataRevertsOnTotalDepositedActivatedETHExceedsInFlight() public {
        vm.store(address(oracleManager), IN_FLIGHT_DEPOSIT_SLOT, bytes32(uint256(10 ether)));
        uint256 epoch = epochsPerFrame;
        vm.warp(genesisTime + (epoch + epochsToAssumedFinality) * slotsPerEpoch * secondsPerSlot);
        IOracleManagerV1.ConsensusLayerReport memory clr;
        clr.epoch = epoch;
        clr.validatorsBalance = 0;
        clr.validatorsExitedBalance = 0;
        clr.validatorsSkimmedBalance = 0;
        clr.totalDepositedActivatedETH = 11 ether;
        clr.exitedETHPerOperator = new uint256[](1);
        vm.prank(oracle);
        vm.expectRevert(
            abi.encodeWithSignature("InvalidTotalDepositedActivatedETHIncrease(uint256,uint256)", 10 ether, 11 ether)
        );
        oracleManager.setConsensusLayerData(clr);
    }

    /// Asserts that setConsensusLayerData reverts with InvalidTotalDepositedActivatedETHDecrease when
    /// the reported totalDepositedActivatedETH is lower than the previously stored value.
    function testSetConsensusLayerDataRevertsOnTotalDepositedActivatedETHDecrease() public {
        // Slot 6 in StoredConsensusLayerReport is totalDepositedActivatedETH.
        vm.store(address(oracleManager), bytes32(uint256(LAST_CLR_BASE_SLOT) + 6), bytes32(uint256(10 ether)));

        uint256 epoch = epochsPerFrame;
        vm.warp(genesisTime + (epoch + epochsToAssumedFinality) * slotsPerEpoch * secondsPerSlot);
        IOracleManagerV1.ConsensusLayerReport memory clr;
        clr.epoch = epoch;
        clr.validatorsBalance = 0;
        clr.validatorsExitedBalance = 0;
        clr.validatorsSkimmedBalance = 0;
        clr.totalDepositedActivatedETH = 9 ether;
        clr.exitedETHPerOperator = new uint256[](1);
        vm.prank(oracle);
        vm.expectRevert(
            abi.encodeWithSignature("InvalidTotalDepositedActivatedETHDecrease(uint256,uint256)", 10 ether, 9 ether)
        );
        oracleManager.setConsensusLayerData(clr);
    }

    /// Asserts that setConsensusLayerData reverts when reported validator count decreases.
    function testSetConsensusLayerDataRevertsOnValidatorCountDecrease() public {
        // Slot 5 in StoredConsensusLayerReport is validatorsCount.
        vm.store(address(oracleManager), bytes32(uint256(LAST_CLR_BASE_SLOT) + 5), bytes32(uint256(10)));

        uint256 epoch = epochsPerFrame;
        vm.warp(genesisTime + (epoch + epochsToAssumedFinality) * slotsPerEpoch * secondsPerSlot);
        IOracleManagerV1.ConsensusLayerReport memory clr;
        clr.epoch = epoch;
        clr.validatorsBalance = 0;
        clr.validatorsExitedBalance = 0;
        clr.validatorsSkimmedBalance = 0;
        clr.validatorsCount = 9;
        clr.exitedETHPerOperator = new uint256[](1);
        vm.prank(oracle);
        vm.expectRevert(abi.encodeWithSignature("InvalidValidatorCountReport(uint256,uint256)", 9, 10));
        oracleManager.setConsensusLayerData(clr);
    }

    /// Asserts that with a non-zero ConsolidationBuffer, setConsensusLayerData calls _pullConsolidationCoverageFunds
    /// with the buffer amount and pulls the available amount.
    function testSetConsensusLayerDataConsolidationBufferNonZero() public {
        OracleManagerV1ExposeInitializer om = OracleManagerV1ExposeInitializer(address(oracleManager));

        uint256 buffer = 0.5 ether;
        uint256 fundAvailable = 0.5 ether;
        vm.store(address(oracleManager), CONSOLIDATION_BUFFER_SLOT, bytes32(buffer));
        om.sudoSetConsolidationCoverageFundAvailable(fundAvailable);

        uint256 epoch = epochsPerFrame;
        vm.warp(genesisTime + (epoch + epochsToAssumedFinality) * slotsPerEpoch * secondsPerSlot);
        IOracleManagerV1.ConsensusLayerReport memory clr;
        clr.epoch = epoch;
        clr.validatorsBalance = 0;
        clr.validatorsExitedBalance = 0;
        clr.validatorsSkimmedBalance = 0;
        clr.totalDepositedActivatedETH = 0;
        clr.exitedETHPerOperator = new uint256[](1);

        vm.expectEmit(true, true, true, true, address(om));
        emit Internal_PullConsolidationCoverageFunds(buffer, fundAvailable);

        vm.prank(oracle);
        oracleManager.setConsensusLayerData(clr);
    }

    /// Asserts that with a non-zero ConsolidationBuffer but zero pull, setConsensusLayerData skips _setConsolidationBuffer
    /// (covers the false branch of `pulledConsolidationCoverageFunds > 0`).
    function testSetConsensusLayerDataConsolidationBufferNoPull() public {
        OracleManagerV1ExposeInitializer om = OracleManagerV1ExposeInitializer(address(oracleManager));

        uint256 buffer = 0.5 ether;
        vm.store(address(oracleManager), CONSOLIDATION_BUFFER_SLOT, bytes32(buffer));
        // fundAvailable left at 0 - pull will return 0.

        uint256 epoch = epochsPerFrame;
        vm.warp(genesisTime + (epoch + epochsToAssumedFinality) * slotsPerEpoch * secondsPerSlot);
        IOracleManagerV1.ConsensusLayerReport memory clr;
        clr.epoch = epoch;
        clr.validatorsBalance = 0;
        clr.validatorsExitedBalance = 0;
        clr.validatorsSkimmedBalance = 0;
        clr.totalDepositedActivatedETH = 0;
        clr.exitedETHPerOperator = new uint256[](1);

        vm.expectEmit(true, true, true, true, address(om));
        emit Internal_PullConsolidationCoverageFunds(buffer, 0);

        vm.prank(oracle);
        oracleManager.setConsensusLayerData(clr);

        // Buffer slot must be untouched since the inner if (pulledConsolidationCoverageFunds > 0) was false,
        // so _setConsolidationBuffer was never invoked for this report.
        assertEq(uint256(vm.load(address(oracleManager), CONSOLIDATION_BUFFER_SLOT)), buffer);
    }

    /// Asserts that setConsensusLayerData reverts with InvalidTotalConsolidationsAmountReportedDecrease when the
    /// reported totalExternalConsolidationsAmountReported is lower than the previously stored value.
    function testSetConsensusLayerDataRevertsOnConsolidationsAmountDecrease() public {
        OracleManagerV1ExposeInitializer om = OracleManagerV1ExposeInitializer(address(oracleManager));
        om.supersedeTotalConsolidationsAmountReported(5 ether);

        uint256 epoch = epochsPerFrame;
        vm.warp(genesisTime + (epoch + epochsToAssumedFinality) * slotsPerEpoch * secondsPerSlot);
        IOracleManagerV1.ConsensusLayerReport memory clr;
        clr.epoch = epoch;
        clr.exitedETHPerOperator = new uint256[](1);
        clr.totalExternalConsolidationsAmountReported = 4 ether;

        vm.prank(oracle);
        vm.expectRevert(
            abi.encodeWithSignature(
                "InvalidTotalConsolidationsAmountReportedDecrease(uint256,uint256)", 5 ether, 4 ether
            )
        );
        oracleManager.setConsensusLayerData(clr);
    }

    /// Asserts that when totalExternalConsolidationsAmountReported increases within the available ConsolidationBuffer, the
    /// buffer is reduced by the delta and the new value is persisted.
    function testSetConsensusLayerDataConsolidationsIncreaseReducesBuffer() public {
        OracleManagerV1ExposeInitializer om = OracleManagerV1ExposeInitializer(address(oracleManager));

        uint256 buffer = 5 ether;
        vm.store(address(om), CONSOLIDATION_BUFFER_SLOT, bytes32(buffer));
        om.supersedeTotalConsolidationsAmountReported(1 ether);
        // Keep the later pull path from performing a second buffer update.
        om.sudoSetConsolidationCoverageFundAvailable(0);

        uint256 epoch = epochsPerFrame;
        vm.warp(genesisTime + (epoch + epochsToAssumedFinality) * slotsPerEpoch * secondsPerSlot);
        IOracleManagerV1.ConsensusLayerReport memory clr;
        clr.epoch = epoch;
        clr.exitedETHPerOperator = new uint256[](1);
        clr.totalExternalConsolidationsAmountReported = 3 ether; // delta = 2 ether
        // The consolidated principal (the 2 ether delta) lands in validatorsBalance in the same report, so the
        // buffer reduction offsets it rather than registering as a loss.
        clr.validatorsBalance = 2 ether;

        uint256 assetBalanceBefore = om.debug_getTotalUnderlyingBalance();

        vm.expectEmit(true, true, true, true, address(om));
        emit Internal_SetConsolidationBuffer(buffer, buffer - 2 ether); // 5 -> 3
        vm.prank(oracle);
        oracleManager.setConsensusLayerData(clr);

        assertEq(oracleManager.getLastConsensusLayerReport().totalExternalConsolidationsAmountReported, 3 ether);
        // The buffer delta (-2 ether) is exactly offset by the validatorsBalance increase (+2 ether): the total
        // underlying is unchanged and the consolidated principal is not counted as rewards.
        assertEq(om.debug_getTotalUnderlyingBalance(), assetBalanceBefore);
    }

    /// Asserts that an unchanged totalExternalConsolidationsAmountReported neither reverts nor reduces the buffer, and that
    /// the value is persisted (confirms the decrease guard is `<`, not `<=`).
    function testSetConsensusLayerDataConsolidationsUnchangedKeepsBuffer() public {
        OracleManagerV1ExposeInitializer om = OracleManagerV1ExposeInitializer(address(oracleManager));

        uint256 buffer = 5 ether;
        vm.store(address(om), CONSOLIDATION_BUFFER_SLOT, bytes32(buffer));
        om.supersedeTotalConsolidationsAmountReported(3 ether);
        om.sudoSetConsolidationCoverageFundAvailable(0);

        uint256 epoch = epochsPerFrame;
        vm.warp(genesisTime + (epoch + epochsToAssumedFinality) * slotsPerEpoch * secondsPerSlot);
        IOracleManagerV1.ConsensusLayerReport memory clr;
        clr.epoch = epoch;
        clr.exitedETHPerOperator = new uint256[](1);
        clr.totalExternalConsolidationsAmountReported = 3 ether; // equal -> buffer-reduction branch skipped

        uint256 assetBalanceBefore = om.debug_getTotalUnderlyingBalance();

        vm.prank(oracle);
        oracleManager.setConsensusLayerData(clr);

        assertEq(oracleManager.getLastConsensusLayerReport().totalExternalConsolidationsAmountReported, 3 ether);
        // Equal report skips the buffer-reduction branch, so the buffer and asset balance are unchanged.
        assertEq(uint256(vm.load(address(oracleManager), CONSOLIDATION_BUFFER_SLOT)), buffer);
        assertEq(om.debug_getTotalUnderlyingBalance(), assetBalanceBefore);
    }

    /// Fuzzes the full consolidation branch: decrease revert, capped buffer reduction on increase, APR-bound
    /// revert on unbuffered excess, and the unchanged case. Generalizes the targeted tests above.
    function testFuzzSetConsensusLayerDataConsolidations(
        uint256 lastConsolidation,
        uint256 newConsolidation,
        uint256 buffer
    ) public {
        OracleManagerV1ExposeInitializer om = OracleManagerV1ExposeInitializer(address(oracleManager));

        lastConsolidation = bound(lastConsolidation, 0, 1_000_000 ether);
        newConsolidation = bound(newConsolidation, 0, 1_000_000 ether);
        buffer = bound(buffer, 0, 1_000_000 ether);

        om.supersedeTotalConsolidationsAmountReported(lastConsolidation);
        vm.store(address(om), CONSOLIDATION_BUFFER_SLOT, bytes32(buffer));
        // Isolate the increase branch: the later pull path must not perform a second buffer update.
        om.sudoSetConsolidationCoverageFundAvailable(0);

        uint256 epoch = epochsPerFrame;
        vm.warp(genesisTime + (epoch + epochsToAssumedFinality) * slotsPerEpoch * secondsPerSlot);
        IOracleManagerV1.ConsensusLayerReport memory clr;
        clr.epoch = epoch;
        clr.exitedETHPerOperator = new uint256[](1);
        clr.totalExternalConsolidationsAmountReported = newConsolidation;

        if (newConsolidation < lastConsolidation) {
            vm.prank(oracle);
            vm.expectRevert(
                abi.encodeWithSignature(
                    "InvalidTotalConsolidationsAmountReportedDecrease(uint256,uint256)",
                    lastConsolidation,
                    newConsolidation
                )
            );
            oracleManager.setConsensusLayerData(clr);
        } else if (newConsolidation > lastConsolidation) {
            uint256 delta = newConsolidation - lastConsolidation;
            // The consolidated principal lands in validatorsBalance in the same report, so the buffer reduction
            // offsets as much of it as the current buffer can cover (mirrors the production flow).
            clr.validatorsBalance = delta;
            uint256 assetBalanceBefore = om.debug_getTotalUnderlyingBalance();
            uint256 bufferReduction = LibUint256.min(delta, buffer);
            uint256 expectedPostReportBalance = assetBalanceBefore + (delta - bufferReduction);
            uint256 timeElapsed = debug_timeBetweenEpochs(om.getCLSpec(), 0, epoch);
            ReportBounds.ReportBoundsStruct memory rb = om.getReportBounds();
            uint256 maxIncrease = debug_maxIncrease(rb, assetBalanceBefore, timeElapsed);

            if (expectedPostReportBalance > assetBalanceBefore + maxIncrease) {
                vm.prank(oracle);
                vm.expectRevert(
                    abi.encodeWithSignature(
                        "TotalValidatorBalanceIncreaseOutOfBound(uint256,uint256,uint256,uint256)",
                        assetBalanceBefore,
                        expectedPostReportBalance,
                        timeElapsed,
                        rb.annualAprUpperBound
                    )
                );
                oracleManager.setConsensusLayerData(clr);
            } else {
                if (bufferReduction > 0) {
                    vm.expectEmit(true, true, true, true, address(om));
                    emit Internal_SetConsolidationBuffer(buffer, buffer - bufferReduction);
                }
                vm.prank(oracle);
                oracleManager.setConsensusLayerData(clr);
                assertEq(
                    oracleManager.getLastConsensusLayerReport().totalExternalConsolidationsAmountReported,
                    newConsolidation
                );
                assertEq(uint256(vm.load(address(oracleManager), CONSOLIDATION_BUFFER_SLOT)), buffer - bufferReduction);
                assertEq(om.debug_getTotalUnderlyingBalance(), expectedPostReportBalance);
            }
        } else {
            vm.prank(oracle);
            oracleManager.setConsensusLayerData(clr);
            assertEq(
                oracleManager.getLastConsensusLayerReport().totalExternalConsolidationsAmountReported, newConsolidation
            );
        }
    }

    /// Asserts the consolidation-buffer ordering invariant: when consolidated principal lands in
    /// validatorsBalance in the SAME report that raises totalExternalConsolidationsAmountReported by the same
    /// delta, the buffer reduction offsets the validatorsBalance increase so the delta is NOT booked as rewards
    /// — even when the delta dwarfs the APR upper bound.
    ///
    /// This is the regression guard for the buffer-reduction ordering. The reduction must run between the pre-
    /// and post-report _assetBalance snapshots so the `-delta` cancels the `+delta` in validatorsBalance and
    /// rewards stay 0. If the reduction instead ran before the pre-report snapshot, the delta would be counted
    /// as rewards and this large consolidation would revert with TotalValidatorBalanceIncreaseOutOfBound.
    function testSetConsensusLayerDataConsolidationNetsOutAgainstValidatorBalanceIncrease() public {
        OracleManagerV1ExposeInitializer om = OracleManagerV1ExposeInitializer(address(oracleManager));

        uint256 validatorsBalanceBefore = 200 ether;
        uint256 buffer = 100 ether;
        om.supersedeReportedBalanceSum(validatorsBalanceBefore);
        om.supersedeTotalConsolidationsAmountReported(0);
        vm.store(address(om), CONSOLIDATION_BUFFER_SLOT, bytes32(buffer));
        // Isolate the report-time reduction from the later coverage-pull path (no second buffer update).
        om.sudoSetConsolidationCoverageFundAvailable(0);

        uint256 assetBalanceBefore = om.debug_getTotalUnderlyingBalance();

        // The consolidated principal (delta) appears in validatorsBalance AND is reported as external
        // consolidation in the same report. delta is intentionally far above the APR upper bound to prove it is
        // not treated as rewards (a pre-fix run would revert with TotalValidatorBalanceIncreaseOutOfBound).
        uint256 delta = 64 ether;

        uint256 epoch = epochsPerFrame;
        vm.warp(genesisTime + (epoch + epochsToAssumedFinality) * slotsPerEpoch * secondsPerSlot);
        IOracleManagerV1.ConsensusLayerReport memory clr;
        clr.epoch = epoch;
        clr.exitedETHPerOperator = new uint256[](1);
        clr.validatorsBalance = validatorsBalanceBefore + delta; // principal now visible on the consensus layer
        clr.totalExternalConsolidationsAmountReported = delta; // same delta reported as external consolidation

        // The buffer is reduced by exactly the delta, between the pre- and post-report snapshots.
        vm.expectEmit(true, true, true, true, address(om));
        emit Internal_SetConsolidationBuffer(buffer, buffer - delta); // 100 -> 36
        vm.prank(oracle);
        // Must NOT revert despite delta >> APR upper bound, since the delta is offset, not counted as rewards.
        oracleManager.setConsensusLayerData(clr);

        // Core invariant: the consolidated principal is fully offset. Total underlying is unchanged, which means
        // rewards == 0 (_onEarnings is only invoked when rewards > 0, so no fee is minted on the principal).
        assertEq(om.debug_getTotalUnderlyingBalance(), assetBalanceBefore);
        // The reported values are persisted: principal in validatorsBalance and the cumulative consolidation.
        assertEq(oracleManager.getLastConsensusLayerReport().validatorsBalance, validatorsBalanceBefore + delta);
        assertEq(oracleManager.getLastConsensusLayerReport().totalExternalConsolidationsAmountReported, delta);
        // Buffer reduced by exactly the delta.
        assertEq(uint256(vm.load(address(om), CONSOLIDATION_BUFFER_SLOT)), buffer - delta);
    }
}
