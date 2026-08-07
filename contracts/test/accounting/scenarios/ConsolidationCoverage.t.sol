// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../AccountingInvariants.sol";
import "../../utils/LibImplementationUnbricker.sol";
import "../../../src/ConsolidationCoverageFund.1.sol";
import "../../../src/interfaces/components/IOracleManager.1.sol";
import "../../../src/interfaces/IAttestationVerifier.1.sol";
import "../../../src/state/river/ReportBounds.sol";

/// @title ConsolidationCoverageScenarioTest
/// @notice Scenario tests for the consolidation-reporting accounting path, exercised against the real
///         River contract and a real ConsolidationCoverageFund. They cover the IMPLEMENTED behaviour:
///         (1) reporting a consolidation increase reduces the consolidation buffer by the delta,
///         (2) the remaining buffer is then drained by pulling matching ETH from the coverage fund,
///         (3) the total underlying supply never increases as the buffer decreases,
///
///         The consolidation buffer has no on-chain increase path on this branch — its value is
///         "computed off-chain and provided manually" (see ConsolidationCoverageFundV1) — so the
///         buffer is seeded directly via `vm.store` to stand in for that pending initiation path.
contract ConsolidationCoverageScenarioTest is AccountingInvariants {
    /// @dev Storage slot of River's consolidation buffer (mirrors ConsolidationBuffer.sol).
    bytes32 internal constant CONSOLIDATION_BUFFER_SLOT =
        bytes32(uint256(keccak256("river.state.consolidationBuffer")) - 1);

    ConsolidationCoverageFundV1 internal consolidationCoverageFund;

    /// @notice Extends the base setup by replacing the consolidation-coverage-fund stub with a real,
    ///         river-wired ConsolidationCoverageFundV1 so the report-time pull path actually moves ETH.
    function setUp() public override {
        super.setUp();
        consolidationCoverageFund = new ConsolidationCoverageFundV1();
        LibImplementationUnbricker.unbrick(vm, address(consolidationCoverageFund));
        consolidationCoverageFund.initConsolidationCoverageFundV1(address(river));
        vm.prank(admin);
        river.setConsolidationCoverageFund(address(consolidationCoverageFund));
    }

    /// @dev Allowlists a donor for consolidation donations and donates `amount` into the coverage fund.
    function _donateConsolidationCoverage(uint256 amount) internal {
        address donor = makeAddr("consolidationDonor");
        address[] memory addrs = new address[](1);
        addrs[0] = donor;
        uint256[] memory masks = new uint256[](1);
        masks[0] = LibAllowlistMasks.DONATE_CONSOLIDATION_MASK;
        vm.prank(allower);
        allowlist.setAllowPermissions(addrs, masks);

        vm.deal(donor, amount);
        vm.prank(donor);
        consolidationCoverageFund.donate{value: amount}();
    }

    /// @dev Brings the protocol to a steady state: fund, deposit and activate 3 validators, then report.
    function _baseline() internal {
        _fundRiver(3 * DEPOSIT_SIZE);
        sim_deposit(operatorOneIndex, _amounts(3, DEPOSIT_SIZE));
        sim_activateValidators(3);
        sim_oracleReport();
    }

    /// @notice Reporting a consolidation increase within the buffer reduces the buffer by the delta,
    ///         drains the remainder from the coverage fund, persists the reported value, and never
    ///         increases the total underlying supply (it drops by exactly the reported delta, since the
    ///         coverage pull is underlying-neutral: buffer -> BalanceToDeposit).
    function testConsolidationReportReducesBufferAndDoesNotIncreaseAssets() public {
        _baseline();

        uint256 coverage = 5 ether;
        _donateConsolidationCoverage(coverage);

        // Seed the consolidation buffer (stands in for the pending on-chain initiation path).
        uint256 buffer = 4 ether;
        vm.store(address(river), CONSOLIDATION_BUFFER_SLOT, bytes32(buffer));

        uint256 underlyingBefore = river.totalUnderlyingSupply();
        uint256 fundBalanceBefore = address(consolidationCoverageFund).balance;

        // Report a consolidation increase within the available buffer.
        uint256 delta = 1 ether;
        IOracleManagerV1.ConsensusLayerReport memory report = _buildBadReport(false, false);
        report.totalExternalConsolidationETH = delta;
        vm.prank(oracleMember);
        oracle.reportConsensusLayerData(report);

        // The reported value is persisted into the stored report.
        assertEq(
            river.getLastConsensusLayerReport().totalExternalConsolidationETH,
            delta,
            "totalExternalConsolidationETH persisted"
        );
        // Buffer: reduced by `delta` on the consolidation increase, then the remaining `buffer - delta`
        // is pulled from the coverage fund (coverage >= remaining), draining it to zero.
        assertEq(uint256(vm.load(address(river), CONSOLIDATION_BUFFER_SLOT)), 0, "buffer fully drained");
        // The coverage fund paid out exactly the post-consolidation remaining buffer.
        assertEq(
            address(consolidationCoverageFund).balance,
            fundBalanceBefore - (buffer - delta),
            "coverage funds pulled == remaining buffer"
        );
        // Core invariant: the asset balance must NOT increase as the buffer decreases. Here it drops by
        // exactly the reported delta (the coverage pull moves buffer into BalanceToDeposit, net-neutral).
        assertLe(river.totalUnderlyingSupply(), underlyingBefore, "total underlying must not increase");
        assertEq(river.totalUnderlyingSupply(), underlyingBefore - delta, "total underlying drops by the delta");
    }

    /// @notice Netting flow (the realistic case): the consolidated principal lands in validatorsBalance in
    ///         the same report that raises the reported consolidation by the same delta. The buffer reduction
    ///         then offsets the validatorsBalance increase, so the total underlying supply is UNCHANGED — the
    ///         consolidated principal is not booked as rewards and no fee shares are minted. This complements
    ///         testConsolidationReportReducesBufferAndDoesNotIncreaseAssets, which covers the buffer-only
    ///         (coverage-backfill) case where the principal does not land in validatorsBalance.
    function testConsolidationReportWithValidatorBalanceIncreaseNetsOut() public {
        _baseline();

        // Seed the buffer with exactly the delta we are about to report (stands in for the off-chain mint),
        // so the consolidation reduction draws it to zero and leaves no residual for the coverage pull.
        uint256 delta = 1 ether;
        vm.store(address(river), CONSOLIDATION_BUFFER_SLOT, bytes32(delta));

        uint256 underlyingBefore = river.totalUnderlyingSupply();
        uint256 sharesBefore = river.totalSupply();

        // The consolidated principal appears in validatorsBalance AND is reported as consolidation in the same
        // report; the buffer is drawn down by the same delta (no coverage residual, so no fund pull).
        IOracleManagerV1.ConsensusLayerReport memory report = _buildBadReport(false, false);
        report.validatorsBalance += delta;
        report.totalExternalConsolidationETH = delta;
        vm.prank(oracleMember);
        oracle.reportConsensusLayerData(report);

        // The reported value is persisted and the buffer is fully drawn down by the consolidation reduction.
        assertEq(river.getLastConsensusLayerReport().totalExternalConsolidationETH, delta);
        assertEq(uint256(vm.load(address(river), CONSOLIDATION_BUFFER_SLOT)), 0, "buffer drawn down by delta");
        // Core invariant: the consolidated principal is exactly offset, so the total underlying is UNCHANGED
        // (neither a drop nor an increase) and no fee shares are minted on the principal.
        assertEq(river.totalUnderlyingSupply(), underlyingBefore, "total underlying unchanged (netted out)");
        assertEq(river.totalSupply(), sharesBefore, "no fee shares minted on consolidated principal");
    }

    function testMintReportDrawdownAndCoveragePullConservesUnderlyingAndShares() public {
        _baseline();

        uint256 coverage = 5 ether;
        _donateConsolidationCoverage(coverage);

        address consolidated = makeAddr("consolidatedUser");
        address[] memory addrs = new address[](1);
        addrs[0] = consolidated;
        uint256[] memory masks = new uint256[](1);
        masks[0] = LibAllowlistMasks.CONSOLIDATE_MASK;
        vm.prank(allower);
        allowlist.setAllowPermissions(addrs, masks);

        uint256 amount = 4 ether;
        IAttestationVerifierV1.ConsolidationObject memory consolidation = IAttestationVerifierV1.ConsolidationObject({
            withdrawalAddress: consolidated,
            sourcePubkeys: new bytes[](1),
            targetPubkeys: new bytes[](1),
            totalAmount: amount,
            signatures: new bytes[](1)
        });
        vm.mockCall(
            address(attestationVerifier),
            abi.encodeWithSelector(IAttestationVerifierV1.validateConsolidation.selector),
            abi.encode(true)
        );

        uint256 underlyingBeforeMint = river.totalUnderlyingSupply();
        uint256 supplyBeforeMint = river.totalSupply();
        uint256 expectedShares = (amount * supplyBeforeMint) / underlyingBeforeMint;

        vm.prank(consolidator);
        river.mintLsETHForConsolidation(consolidation);

        assertEq(river.getBalanceToConsolidate(), amount, "mint increases buffer by totalAmount");
        assertEq(
            river.totalUnderlyingSupply(), underlyingBeforeMint + amount, "mint increases underlying by totalAmount"
        );
        assertEq(river.balanceOf(consolidated), expectedShares, "mint converts totalAmount at share price");

        uint256 delta = 1 ether;
        IOracleManagerV1.ConsensusLayerReport memory report = _buildBadReport(false, false);
        report.validatorsBalance += delta;
        report.totalExternalConsolidationETH += delta;
        vm.prank(oracleMember);
        oracle.reportConsensusLayerData(report);

        assertEq(river.getBalanceToConsolidate(), 0, "report drawdown plus fund pull drains buffer");
        assertEq(
            address(consolidationCoverageFund).balance,
            coverage - (amount - delta),
            "fund covers exactly the residual buffer"
        );
        assertEq(
            river.totalUnderlyingSupply(),
            underlyingBeforeMint + amount,
            "underlying conserved across drawdown and pull"
        );
        assertEq(river.totalSupply(), supplyBeforeMint + expectedShares, "no shares minted by drawdown or pull");
    }

    /// @notice End-to-end regression for source-validator rewards earned after the external-consolidation
    ///         request was buffered. The simulator report exceeds the buffer, the buffer is drawn to zero,
    ///         the surplus is booked as APR-bounded rewards, and the Oracle -> River flow does not revert.
    function testConsolidationReportAboveBufferedPrincipalBooksRewards() public {
        _baseline();

        uint256 bufferedPrincipal = DEPOSIT_SIZE;
        vm.store(address(river), CONSOLIDATION_BUFFER_SLOT, bytes32(bufferedPrincipal));

        uint256 underlyingBefore = river.totalUnderlyingSupply();
        uint256 sharesBefore = river.totalSupply();

        uint256 rewardSurplus = _maxIncreaseForNextReport(underlyingBefore);
        assertGt(rewardSurplus, 0, "test setup: reward surplus must be non-zero");

        sim_reportExternalConsolidation(bufferedPrincipal, bufferedPrincipal + rewardSurplus);
        sim_oracleReport();

        IOracleManagerV1.StoredConsensusLayerReport memory stored = river.getLastConsensusLayerReport();
        assertEq(
            stored.totalExternalConsolidationETH, bufferedPrincipal + rewardSurplus, "reported principal plus surplus"
        );
        assertEq(stored.validatorsBalance, 4 * DEPOSIT_SIZE + rewardSurplus, "surplus landed in validatorsBalance");
        assertEq(uint256(vm.load(address(river), CONSOLIDATION_BUFFER_SLOT)), 0, "buffer drawn to zero");
        assertEq(river.totalUnderlyingSupply(), underlyingBefore + rewardSurplus, "surplus booked as rewards");
        assertGt(river.totalSupply(), sharesBefore, "fee shares minted only on rewards");
    }

    /// @notice Pins the other side of the same boundary: if the reported consolidation surplus exceeds
    ///         the APR ceiling, the report reverts through the Oracle -> River flow with
    ///         `TotalValidatorBalanceIncreaseOutOfBound`.
    function testConsolidationReportAboveBufferedPrincipalAndAprCeilingReverts() public {
        _baseline();

        uint256 bufferedPrincipal = DEPOSIT_SIZE;
        vm.store(address(river), CONSOLIDATION_BUFFER_SLOT, bytes32(bufferedPrincipal));

        uint256 preReportUnderlying = river.totalUnderlyingSupply();
        uint256 excessiveRewardSurplus = _maxIncreaseForNextReport(preReportUnderlying) + 1;
        sim_reportExternalConsolidation(bufferedPrincipal, bufferedPrincipal + excessiveRewardSurplus);

        ReportBounds.ReportBoundsStruct memory rb = river.getReportBounds();
        IOracleManagerV1.ConsensusLayerReport memory report = _buildBadReport(false, false);
        vm.prank(oracleMember);
        vm.expectRevert(
            abi.encodeWithSelector(
                IOracleManagerV1.TotalValidatorBalanceIncreaseOutOfBound.selector,
                preReportUnderlying,
                preReportUnderlying + excessiveRewardSurplus,
                _frameDuration(),
                rb.annualAprUpperBound
            )
        );
        oracle.reportConsensusLayerData(report);
    }

    function _maxIncreaseForNextReport(uint256 preReportUnderlying) internal view returns (uint256) {
        ReportBounds.ReportBoundsStruct memory rb = river.getReportBounds();
        return (preReportUnderlying * rb.annualAprUpperBound * _frameDuration()) / (10_000 * 365 days);
    }
}
