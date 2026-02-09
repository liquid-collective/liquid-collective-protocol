
definition ignoredMethod(method f) returns bool =
    f.selector == sig:initRiverV1_1(address, uint64, uint64, uint64, uint64, uint64, uint256, uint256, uint128, uint128).selector ||
    f.selector == sig:helper1_fillUpVarsAndPullCL(IOracleManagerV1.ConsensusLayerReport).selector ||
    f.selector == sig:helper2_updateLastReport(IOracleManagerV1.ConsensusLayerReport).selector ||
    f.selector == sig:helper3_checkBounds(OracleManagerV1.ConsensusLayerDataReportingVariables, ReportBounds.ReportBoundsStruct, uint256).selector ||
    f.selector == sig:helper4_pullELFees(OracleManagerV1.ConsensusLayerDataReportingVariables).selector ||
    f.selector == sig:helper5_pullRedeemManagerExceedingEth(OracleManagerV1.ConsensusLayerDataReportingVariables).selector ||
    f.selector == sig:helper6_pullCoverageFunds(OracleManagerV1.ConsensusLayerDataReportingVariables).selector ||
    f.selector == sig:helper7_onEarnings(OracleManagerV1.ConsensusLayerDataReportingVariables).selector ||
    f.selector == sig:helper8_requestExitsBasedOnRedeemDemandAfterRebalancings(OracleManagerV1.ConsensusLayerDataReportingVariables, IOracleManagerV1.ConsensusLayerReport).selector || 
    f.selector == sig:helper9_reportWithdrawToRedeemManager(OracleManagerV1.ConsensusLayerDataReportingVariables).selector ||
    f.selector == sig:helper10_skimExcessBalanceToRedeem(OracleManagerV1.ConsensusLayerDataReportingVariables).selector ||
    f.selector == sig:helper11_commitBalanceToDeposit(OracleManagerV1.ConsensusLayerDataReportingVariables).selector;

definition excludedInCI(method f) returns bool =
    f.selector == sig:depositToConsensusLayerWithDepositRoot(IOperatorsRegistryV1.OperatorAllocation[], bytes32).selector;