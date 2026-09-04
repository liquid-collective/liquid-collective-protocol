//SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.34;

// ─────────────────────────────────────────────────────────────────────────────
// COVERAGE NOTE (post LibOracleReporting extraction)
//
// `OracleManagerV1.setConsensusLayerData` is now a thin stub that DELEGATECALLs `LibOracleReporting`, whose
// report orchestration self-calls River's `ISharesManagerV1(address(this)).totalUnderlyingSupply()/totalSupply()/
// underlyingBalanceFromShares()/sharesFromUnderlyingBalance()` and real collaborators (Withdraw, ELFeeRecipient,
// RedeemManager, CoverageFund, OperatorsRegistry). The lightweight mock below cannot satisfy those, so the FULL
// report-orchestration path is no longer testable here. This file now keeps only what does NOT touch that seam:
//   - access control + setters (setOracle / setCLSpec / setReportBounds, authorized + unauthorized)
//   - getters + epoch/frame math (getOracle, getCLSpec, getReportBounds, getCurrentFrame, getCurrentEpochId,
//     getFrameFirstEpochId, getExpectedEpochId, isValidEpoch, getLastCompletedEpochId, getCLValidator*,
//     getLastConsensusLayerReport)
//   - the EARLY bound-check reverts inside setConsensusLayerData that fire in LibOracleReporting BEFORE the first
//     self-call (validator-count decrease, totalDepositedActivatedETH increase-over-in-flight / decrease,
//     totalExternalConsolidationETH decrease).
// ─────────────────────────────────────────────────────────────────────────────

import "forge-std/Test.sol";

import "../utils/UserFactory.sol";
import "../utils/LibImplementationUnbricker.sol";

import "../../src/components/OracleManager.1.sol";
import "../../src/libraries/LibUint256.sol";
import "../../src/state/shared/AdministratorAddress.sol";
import "../../src/state/river/DepositedValidatorCount.sol";

/// @dev Lightweight harness over `OracleManagerV1` used to exercise the parts of the base contract that do NOT
///      depend on the full report orchestration: access control, setters, getters and epoch/bounds math, plus
///      the early bound-check reverts inside `setConsensusLayerData` (validator-count / exited / skimmed /
///      totalDepositedActivatedETH / consolidations-amount) that fire in `LibOracleReporting` BEFORE any
///      `ISharesManagerV1(address(this))` self-call.
///
///      NOTE: `setConsensusLayerData` now DELEGATECALLs `LibOracleReporting`, which self-calls River's
///      `totalUnderlyingSupply()/totalSupply()/...` and real collaborators. Those cannot be satisfied by this
///      bare mock, so the full report-orchestration path (fund pulls, rewards, exit requests, redeem-manager
///      reporting, commit-to-deposit, consolidation-buffer reduction) is NOT tested here. Those behaviors are
///      covered by the real-River integration tests in contracts/test/River.1.t.sol (see the file header note
///      below for the exact mapping).
contract OracleManagerV1ExposeInitializer is OracleManagerV1 {
    function supersedeReportedBalanceSum(uint256 amount) external {
        LastConsensusLayerReport.get().validatorsBalance = amount;
    }

    function supersedeReportedValidatorCount(uint256 amount) external {
        LastConsensusLayerReport.get().validatorsCount = uint32(amount);
    }

    function supersedeTotalExternalConsolidationETH(uint256 amount) external {
        LastConsensusLayerReport.get().totalExternalConsolidationETH = amount;
    }

    function supersedeValidatorsStoppedEarningBalance(uint256 amount) external {
        LastConsensusLayerReport.get().validatorsStoppedEarningBalance = amount;
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

        // Restore coverage for the epoch/frame getters lost with the old OracleManager unit suite.
        // setUp warps to genesisTime, so the current epoch is 0.
        assertEq(0, oracleManager.getCurrentEpochId());

        (uint256 startEpochId, uint256 startTime, uint256 endTime) = oracleManager.getCurrentFrame();
        assertEq(0, startEpochId);
        assertEq(0, startTime);
        assertEq(uint256(epochsPerFrame) * slotsPerEpoch * secondsPerSlot - 1, endTime);

        // Exact multiple of epochsPerFrame maps back to itself.
        assertEq(uint256(epochsPerFrame), oracleManager.getFrameFirstEpochId(epochsPerFrame));
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// OracleManager view and revert tests
// ─────────────────────────────────────────────────────────────────────────────

contract OracleManagerV1CoverageTests is OracleManagerV1Tests {
    bytes32 constant IN_FLIGHT_DEPOSIT_SLOT = bytes32(uint256(keccak256("river.state.inFlightDeposit")) - 1);
    bytes32 constant LAST_CLR_BASE_SLOT = bytes32(uint256(keccak256("river.state.lastConsensusLayerReport")) - 1);

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
        OracleManagerV1ExposeInitializer(address(oracleManager)).supersedeReportedValidatorCount(10);

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

    /// Asserts that setConsensusLayerData reverts with InvalidTotalConsolidationsAmountReportedDecrease when the
    /// reported totalExternalConsolidationETH is lower than the previously stored value.
    function testSetConsensusLayerDataRevertsOnConsolidationsAmountDecrease() public {
        OracleManagerV1ExposeInitializer om = OracleManagerV1ExposeInitializer(address(oracleManager));
        om.supersedeTotalExternalConsolidationETH(5 ether);

        uint256 epoch = epochsPerFrame;
        vm.warp(genesisTime + (epoch + epochsToAssumedFinality) * slotsPerEpoch * secondsPerSlot);
        IOracleManagerV1.ConsensusLayerReport memory clr;
        clr.epoch = epoch;
        clr.exitedETHPerOperator = new uint256[](1);
        clr.totalExternalConsolidationETH = 4 ether;

        vm.prank(oracle);
        vm.expectRevert(
            abi.encodeWithSignature(
                "InvalidTotalConsolidationsAmountReportedDecrease(uint256,uint256)", 5 ether, 4 ether
            )
        );
        oracleManager.setConsensusLayerData(clr);
    }

    /// Asserts that setConsensusLayerData reverts with InvalidDecreasingValidatorsStoppedEarningBalance
    /// when the reported cumulative stopped-earning balance is lower than the stored value. The field
    /// counts principal that has crossed exit_epoch, which nothing can un-cross, so a decrease is an
    /// oracle bug rather than a reportable state.
    function testSetConsensusLayerDataRevertsOnStoppedEarningBalanceDecrease() public {
        OracleManagerV1ExposeInitializer om = OracleManagerV1ExposeInitializer(address(oracleManager));
        om.supersedeValidatorsStoppedEarningBalance(64 ether);

        uint256 epoch = epochsPerFrame;
        vm.warp(genesisTime + (epoch + epochsToAssumedFinality) * slotsPerEpoch * secondsPerSlot);
        IOracleManagerV1.ConsensusLayerReport memory clr;
        clr.epoch = epoch;
        clr.exitedETHPerOperator = new uint256[](1);
        clr.validatorsStoppedEarningBalance = 32 ether;

        vm.prank(oracle);
        vm.expectRevert(
            abi.encodeWithSignature(
                "InvalidDecreasingValidatorsStoppedEarningBalance(uint256,uint256)", 64 ether, 32 ether
            )
        );
        oracleManager.setConsensusLayerData(clr);
    }

    /// Asserts that reporting an unchanged stopped-earning balance is accepted (a reporting interval in
    /// which no validator crossed exit_epoch is the common case, and must not revert).
    function testSetConsensusLayerDataAcceptsUnchangedStoppedEarningBalance() public {
        OracleManagerV1ExposeInitializer om = OracleManagerV1ExposeInitializer(address(oracleManager));
        om.supersedeValidatorsStoppedEarningBalance(64 ether);

        uint256 epoch = epochsPerFrame;
        vm.warp(genesisTime + (epoch + epochsToAssumedFinality) * slotsPerEpoch * secondsPerSlot);
        IOracleManagerV1.ConsensusLayerReport memory clr;
        clr.epoch = epoch;
        clr.exitedETHPerOperator = new uint256[](1);
        clr.validatorsStoppedEarningBalance = 64 ether;

        // reverts later in the orchestration (this bare mock cannot satisfy the self-calls), but NOT
        // with the monotonicity error — that is what this asserts
        vm.prank(oracle);
        try oracleManager.setConsensusLayerData(clr) {}
        catch (bytes memory reason) {
            assertTrue(
                bytes4(reason) != IOracleManagerV1.InvalidDecreasingValidatorsStoppedEarningBalance.selector,
                "equal stopped-earning balance must not trip the monotonicity guard"
            );
        }
    }
}
