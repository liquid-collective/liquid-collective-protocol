//SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.20;

import "forge-std/Test.sol";

// fixtures
import "../fixtures/OracleManagerWithOverridesV1.sol";

// contracts
import "../../src/components/OracleManager.1.sol";
import "../../src/libraries/LibUint256.sol";

// utils
import "../utils/UserFactory.sol";
import "../utils/LibImplementationUnbricker.sol";

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
    event Internal_SetReportedStoppedValidatorCounts(uint32[] stoppedValidatorCounts);

    function setUp() public {
        admin = makeAddr("admin");
        oracle = makeAddr("oracle");
        oracleManager = new OracleManagerWithOverridesV1(
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
        OracleManagerWithOverridesV1 om = OracleManagerWithOverridesV1(address(oracleManager));
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
        v.clr.stoppedValidatorCountPerOperator = new uint32[](1);
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
        emit Internal_SetReportedStoppedValidatorCounts(v.clr.stoppedValidatorCountPerOperator);
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
