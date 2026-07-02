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
//     totalExternalConsolidationsAmountReported decrease).
//
// DROPPED report-orchestration tests and their integration coverage in contracts/test/River.1.t.sol:
//   - testFuzzedReporting                                    -> RiverV1TestsReport_HEAVY_FUZZING.testReportingFuzzing
//       (7 scenarios: nothing pulled / EL fees / coverage / exceeding buffer / half EL+coverage / rebalancing /
//        slashing containment) + testReportingSuccess_AssertCommittedAmountAfter{Skimming,ELFees,Coverage,MultiPulling}
//   - consolidation-buffer effect tests                      -> RiverV1CoverageTests.testPullConsolidationCoverageFunds*
//       (HappyPath / Partial / ZeroBalance / ZeroAddress). See the per-test mapping and remaining COVERAGE GAPs
//       in the note at the end of contract OracleManagerV1CoverageTests.
// ─────────────────────────────────────────────────────────────────────────────

import "forge-std/Test.sol";

import "../utils/UserFactory.sol";
import "../utils/LibImplementationUnbricker.sol";

import "../../src/components/OracleManager.1.sol";
import "../../src/libraries/LibUint256.sol";
import "../../src/state/shared/AdministratorAddress.sol";
import "../../src/state/river/DepositedValidatorCount.sol";
import "../../src/state/river/ConsolidationBuffer.sol";

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

    function _assetBalance() internal view override returns (uint256 result) {
        // Mirror RiverV1._assetBalance by including the consolidation buffer in the total underlying.
        result = (DepositedValidatorCount.get() - LastConsensusLayerReport.get().validatorsCount) * 32 ether
            + LastConsensusLayerReport.get().validatorsBalance + ConsolidationBuffer.get();
    }

    function debug_getTotalUnderlyingBalance() external view returns (uint256) {
        return _assetBalance();
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

    // NOTE: the former `testFuzzedReporting` fuzz test that drove the full report orchestration through the
    // (now removed) fake handler seam has been deleted — the report path now runs in LibOracleReporting via
    // DELEGATECALL and self-calls River's share math / collaborators, which this isolated mock cannot satisfy.
    // Its coverage is provided by the real-River fuzz test `RiverV1TestsReport_HEAVY_FUZZING.testReportingFuzzing`
    // (contracts/test/River.1.t.sol), which drives setConsensusLayerData across 7 pull/rebalance/slashing
    // scenarios and asserts real balances, committed amounts, shares/fees and redeem-manager reporting.

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

    // ─────────────────────────────────────────────────────────────────────────────
    // DROPPED consolidation-buffer report-effect tests (moved to real-River integration).
    //
    // The following tests previously drove setConsensusLayerData past the early bound checks and asserted
    // on consolidation-buffer reduction / consolidation-coverage pulls. Those effects now execute inside
    // LibOracleReporting via DELEGATECALL, which self-calls River's totalUnderlyingSupply()/totalSupply()
    // and real collaborators — none of which this isolated OracleManager mock can satisfy. They are covered
    // by real-River integration tests in contracts/test/River.1.t.sol:
    //   - testSetConsensusLayerDataConsolidationBufferNonZero          -> RiverV1CoverageTests.testPullConsolidationCoverageFundsHappyPath
    //   - testSetConsensusLayerDataConsolidationBufferNoPull           -> RiverV1CoverageTests.testPullConsolidationCoverageFundsZeroBalance / testPullConsolidationCoverageFundsZeroAddress
    //   - testSetConsensusLayerDataConsolidationsIncreaseReducesBuffer -> RiverV1CoverageTests.testPullConsolidationCoverageFundsPartial (buffer-reduction + persistence)
    //   - testSetConsensusLayerDataConsolidationsUnchangedKeepsBuffer  -> COVERAGE GAP: no integration test asserts the equal-report (`<` not `<=`) branch skips buffer reduction.
    //   - testFuzzSetConsensusLayerDataConsolidations                  -> partially by the above; the fuzzed decrease-revert / capped-reduction / APR-bound matrix is a COVERAGE GAP at integration level.
    //   - testSetConsensusLayerDataConsolidationNetsOutAgainstValidatorBalanceIncrease -> COVERAGE GAP: the buffer-reduction ordering regression guard (delta offsets validatorsBalance, not booked as rewards) has no equivalent River integration test.
    // ─────────────────────────────────────────────────────────────────────────────
}
