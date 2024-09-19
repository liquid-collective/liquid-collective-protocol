//SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.20;

import "../../../src/interfaces/components/IOracleManager.1.sol";
import "../../../src/interfaces/IRiver.1.sol";

/// @title RiverEvents
/// @author Alluvial Finance Inc.
/// @notice Event definitions as emitted by the River contract for testing purposes
contract RiverEvents {
    event PulledELFees(uint256 amount);
    event PulledCLFunds(uint256 pulledSkimmedEthAmount, uint256 pullExitedEthAmount);
    event SetELFeeRecipient(address indexed elFeeRecipient);
    event SetCollector(address indexed collector);
    event SetCoverageFund(address indexed coverageFund);
    event SetAllowlist(address indexed allowlist);
    event SetGlobalFee(uint256 fee);
    event SetOperatorsRegistry(address indexed operatorsRegistry);
    event SetBalanceToDeposit(uint256 oldAmount, uint256 newAmount);
    event ProcessedConsensusLayerReport(
        IOracleManagerV1.ConsensusLayerReport report,
        IOracleManagerV1.ConsensusLayerDataReportingTrace trace
    );
    event ReportedConsensusLayerData(
        address indexed member,
        bytes32 indexed variant,
        IRiverV1.ConsensusLayerReport report,
        uint256 voteCount,
        uint256 quorum
    );
}
