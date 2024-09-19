import "Sanity.spec";
import "CVLMath.spec";

using AllowlistV1 as AL;
using CoverageFundV1 as CF;
// using DepositContractMock as DCM;
using ELFeeRecipientV1 as ELFR;
using OperatorsRegistryV1 as OR;
using RedeemManagerV1Harness as RM;
using WithdrawV1 as Wd;

use rule method_reachability;

// sanity passes here:
// https://prover.certora.com/output/40577/2031abdd92254bafb49b487cb7466b12?anonymousKey=cef84e43b9a622eb29ce44539dba2dd9a9721096
// sanity with less unresolved calls here:
// https://prover.certora.com/output/40577/49c466500a5248b8b95e9a3a6a2ea245?anonymousKey=e1f4c6e3f2bc651eccad0ed1463ece870525478b


methods {
    // AllowlistV1
    function AllowlistV1.onlyAllowed(address, uint256) external envfree;
    function _.onlyAllowed(address, uint256) external => DISPATCHER(true);
    function AllowlistV1.isDenied(address) external returns (bool) envfree;
    function _.isDenied(address) external => DISPATCHER(true);

    // RedeemManagerV1
    function RedeemManagerV1Harness.resolveRedeemRequests(uint32[]) external returns(int64[]) envfree;
    function _.resolveRedeemRequests(uint32[]) external => DISPATCHER(true);
     // requestRedeem function is also defined in River:
    // function _.requestRedeem(uint256) external => DISPATCHER(true); //not required, todo: remove
    function _.requestRedeem(uint256 _lsETHAmount, address _recipient) external => DISPATCHER(true);
    function _.claimRedeemRequests(uint32[], uint32[], bool, uint16) external => DISPATCHER(true);
    // function _.claimRedeemRequests(uint32[], uint32[]) external => DISPATCHER(true); //not required, todo: remove
    function _.pullExceedingEth(uint256) external => DISPATCHER(true);
    function _.reportWithdraw(uint256) external => DISPATCHER(true);
    function RedeemManagerV1Harness.getRedeemDemand() external returns (uint256) envfree;
    function _.getRedeemDemand() external => DISPATCHER(true);

    // RiverV1
    function getBalanceToDeposit() external returns(uint256) envfree;
    function getCommittedBalance() external returns(uint256) envfree;
    function getBalanceToRedeem() external returns(uint256) envfree;
    function consensusLayerDepositSize() external returns(uint256) envfree;
    function riverEthBalance() external returns(uint256) envfree;
    function _.sendRedeemManagerExceedingFunds() external => DISPATCHER(true);
    function _.getAllowlist() external => DISPATCHER(true);
    function RiverV1Harness.getAllowlist() external returns(address) envfree;
    function _.sendCLFunds() external => DISPATCHER(true);
    function _.sendCoverageFunds() external => DISPATCHER(true);
    function _.sendELFees() external => DISPATCHER(true);

    // RiverV1 : SharesManagerV1
    function _.transferFrom(address, address, uint256) external => DISPATCHER(true);
    function _.underlyingBalanceFromShares(uint256) external => DISPATCHER(true);
    function RiverV1Harness.underlyingBalanceFromShares(uint256) external returns(uint256) envfree;
    function RiverV1Harness.balanceOfUnderlying(address) external returns(uint256) envfree;
    function RiverV1Harness.totalSupply() external returns(uint256) envfree;
    function RiverV1Harness.totalUnderlyingSupply() external returns(uint256) envfree;
    function RiverV1Harness.sharesFromUnderlyingBalance(uint256) external returns(uint256) envfree;
    function RiverV1Harness.balanceOf(address) external returns(uint256) envfree;
    function RiverV1Harness.consensusLayerEthBalance() external returns(uint256) envfree;
    // RiverV1 : OracleManagerV1
    function _.setConsensusLayerData(IOracleManagerV1.ConsensusLayerReport) external => DISPATCHER(true);
    function RiverV1Harness.getCLValidatorCount() external returns(uint256) envfree;
    
    // RiverV1 : ConsensusLayerDepositManagerV1
    function _.depositToConsensusLayerWithDepositRoot(uint256, bytes32) external => DISPATCHER(true);
    function RiverV1Harness.getDepositedValidatorCount() external returns(uint256) envfree;

    // WithdrawV1
    function _.pullEth(uint256) external => DISPATCHER(true);

    // ELFeeRecipientV1
    function _.pullELFees(uint256) external => DISPATCHER(true);

    // CoverageFundV1
    function _.pullCoverageFunds(uint256) external => DISPATCHER(true);

    // OperatorsRegistryV1
    function _.reportStoppedValidatorCounts(uint32[], uint256) external => DISPATCHER(true);
    function OperatorsRegistryV1.getStoppedAndRequestedExitCounts() external returns (uint32, uint256) envfree;
    function _.getStoppedAndRequestedExitCounts() external => DISPATCHER(true);
    function _.demandValidatorExits(uint256, uint256) external => DISPATCHER(true);
    function _.pickNextValidatorsToDeposit(uint256) external => DISPATCHER(true); // has no effect - CERT-4615

    function _.deposit(bytes,bytes,bytes,bytes32) external => DISPATCHER(true); // has no effect - CERT-4615

    // function _.increment_onDepositCounter() external => ghostUpdate_onDepositCounter() expect bool ALL;

    // MathSummarizations
    // function _.mulDivDown(uint256 a, uint256 b, uint256 c) internal => mulDivDownAbstractPlus(a, b, c) expect uint256 ALL;

    //workaroun per CERT-4615
    function LibBytes.slice(bytes memory _bytes, uint256 _start, uint256 _length) internal returns (bytes memory) => bytesSliceSummary(_bytes, _start, _length);
}

ghost mapping(bytes32 => mapping(uint => bytes32)) sliceGhost;

function bytesSliceSummary(bytes buffer, uint256 start, uint256 len) returns bytes {
	bytes to_ret;
	require(to_ret.length == len);
	require(buffer.length >= require_uint256(start + len));
	bytes32 buffer_hash = keccak256(buffer);
	require keccak256(to_ret) == sliceGhost[buffer_hash][start];
	return to_ret;
}

function mulDivSummarization(uint256 x, uint256 y, uint256 z) returns uint256
{
	if (x == 0 || y == 0)
	{
		return 0;
	}
	if (x == z)
	{
		return y;
	}
	if (y == z)
	{
		return x;
	}
	
	if (y > x)
	{
		if (y > z)
		{
			require mulDivSummarizationValues[y][x] >= x;
		}
		if (x > z)
		{
			require mulDivSummarizationValues[y][x] >= y;
		}
		return mulDivSummarizationValues[y][x];
	}
	else{
		if (x > z)
		{
			require mulDivSummarizationValues[x][y] >= y;
		}
		if (y > z)
		{
			require mulDivSummarizationValues[x][y] >= x;
		}
		return mulDivSummarizationValues[x][y];
	}
}

ghost mapping(uint256 => mapping(uint256 => uint256)) mulDivSummarizationValues;
