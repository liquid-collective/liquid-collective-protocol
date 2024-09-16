// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/Vm.sol"; 

import "./utils/BytesGenerator.sol";
import "./utils/LibImplementationUnbricker.sol";
import "./utils/UserFactory.sol";
import "./utils/RiverHelper.sol";

import "../src/Allowlist.1.sol";
import "../src/River.1.sol";
import "../src/Oracle.1.sol";
import "../src/Withdraw.1.sol";
import "../src/OperatorsRegistry.1.sol";
import "../src/ELFeeRecipient.1.sol";
import "../src/RedeemManager.1.sol";
import "../src/CoverageFund.1.sol";
import "../src/interfaces/IWLSETH.1.sol";
import "../src/components/OracleManager.1.sol";
import "./components/OracleManager.1.t.sol";

import "./mocks/DepositContractMock.sol";
import "../src/Firewall.sol";
import "../src/TUPProxy.sol";
import "./mocks/RiverMock.sol";

contract OperatorsRegistryWithOverridesV1 is OperatorsRegistryV1 {
    function sudoStoppedValidatorCounts(uint32[] calldata stoppedValidatorCounts, uint256 depositedValidatorCount)
        external
    {
        _setStoppedValidatorCounts(stoppedValidatorCounts, depositedValidatorCount);
    }
}

abstract contract RiverV1TestBase is Test, BytesGenerator {

    RiverV1ForceCommittable internal river;
    IDepositContract internal deposit;
    WithdrawV1 internal withdraw;
    OracleV1 internal oracle;
    ELFeeRecipientV1 internal elFeeRecipient;
    CoverageFundV1 internal coverageFund;
    AllowlistV1 internal allowlist;
    OperatorsRegistryWithOverridesV1 internal operatorsRegistry;
    OracleManagerV1 internal oracleManager;
    RedeemManagerV1 internal redeemManager;

    address internal admin;
    address internal newAdmin;
    address internal denier;
    address internal collector;
    address internal newCollector;
    address internal allower;
    address internal oracleMember;
    address internal newAllowlist;
    address internal operatorOne;
    address internal operatorOneFeeRecipient;
    address internal operatorTwo;
    address internal operatorTwoFeeRecipient;
    address internal bob;
    address internal joe;

    string internal operatorOneName = "NodeMasters";
    string internal operatorTwoName = "StakePros";

    uint256 internal operatorOneIndex;
    uint256 internal operatorTwoIndex;

    uint64 internal constant epochsPerFrame = 225;
    uint64 internal constant slotsPerEpoch = 32;
    uint64 internal constant secondsPerSlot = 12;
    uint64 internal constant genesisTime = 12345;
    uint64 internal constant epochsToAssumedFinality = 4;
    uint256 internal constant annualAprUpperBound = 1000;
    uint256 internal constant relativeLowerBound = 250;

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
        IOracleManagerV1.ConsensusLayerReport report, IOracleManagerV1.ConsensusLayerDataReportingTrace trace
    );
    event ReportedConsensusLayerData(
        address indexed member,
        bytes32 indexed variant,
        IRiverV1.ConsensusLayerReport report,
        uint256 voteCount,
        uint256 quorum
    );
    uint64 constant epochsUntilFinal = 4;
    uint128 constant maxDailyNetCommittableAmount = 3200 ether;
    uint128 constant maxDailyRelativeCommittableAmount = 2000;

    function setUp() public virtual {
        admin = makeAddr("admin");
        newAdmin = makeAddr("newAdmin");
        denier = makeAddr("denier");
        collector = makeAddr("collector");
        newCollector = makeAddr("newCollector");
        allower = makeAddr("allower");
        oracleMember = makeAddr("oracleMember");
        newAllowlist = makeAddr("newAllowlist");
        operatorOne = makeAddr("operatorOne");
        operatorTwo = makeAddr("operatorTwo");
        bob = makeAddr("bob");
        joe = makeAddr("joe");

        vm.warp(857034746);

        elFeeRecipient = new ELFeeRecipientV1();
        LibImplementationUnbricker.unbrick(vm, address(elFeeRecipient));
        coverageFund = new CoverageFundV1();
        LibImplementationUnbricker.unbrick(vm, address(coverageFund));
        oracle = new OracleV1();
        LibImplementationUnbricker.unbrick(vm, address(oracle));
        allowlist = new AllowlistV1();
        LibImplementationUnbricker.unbrick(vm, address(allowlist));
        deposit = new DepositContractMock();
        LibImplementationUnbricker.unbrick(vm, address(deposit));
        withdraw = new WithdrawV1();
        LibImplementationUnbricker.unbrick(vm, address(withdraw));
        river = new RiverV1ForceCommittable();
        LibImplementationUnbricker.unbrick(vm, address(river));
        operatorsRegistry = new OperatorsRegistryWithOverridesV1();
        LibImplementationUnbricker.unbrick(vm, address(operatorsRegistry));
        oracleManager = new OracleManagerV1ExposeInitializer(
            address(oracle),
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

        allowlist.initAllowlistV1(admin, allower);
        allowlist.initAllowlistV1_1(denier);
        operatorsRegistry.initOperatorsRegistryV1(admin, address(river));
        elFeeRecipient.initELFeeRecipientV1(address(river));
        coverageFund.initCoverageFundV1(address(river));  
    }
}

contract OracleIntegrationTest is Test, RiverV1TestBase, RiverHelper {
    // Constants
    address constant DEPOSIT_CONTRACT = address(0x00000000219ab540356cBB839Cbe05303d7705Fa);
    uint64 constant genesisTimestamp = 1695902400;
    uint256 constant grossFee = 1250;

    // Addresses
    address deployer = address(0x123); // Example address for the deployer
    address governor = address(0x456); // Example address for the governor
    address executor = address(0x789); // Example address for the executor
    address proxyAdministrator = address(0xabc); // Example address for the proxy admin
    address futureOracleAddress;
    address futureOperatorsRegistryAddress;
    address futureELFeeRecipientAddress;
    address futureRiverAddress;
    address futureRedeemManagerAddress;

    event SetQuorum(uint256 _newQuorum);
    event AddMember(address indexed member);
    event RemoveMember(address indexed member);
    event SetMember(address indexed oldAddress, address indexed newAddress);
    event SetSpec(uint64 _epochsPerFrame, uint64 _slotsPerEpoch, uint64 _secondsPerSlot, uint64 _genesisTime);
    event SetBounds(uint256 _annualAprUpperBound, uint256 _relativeLowerBound);
    event SetRiver(address _river);
    event RewardsEarned(
        address indexed _collector,
        uint256 _oldTotalUnderlyingBalance,
        uint256 _oldTotalSupply,
        uint256 _newTotalUnderlyingBalance,
        uint256 _newTotalSupply
    );

    function setUp() public override {
        super.setUp();
        bytes32 withdrawalCredentials = withdraw.getCredentials();
        vm.expectEmit(true, true, true, true);
        emit SetOperatorsRegistry(address(operatorsRegistry));
        river.initRiverV1(
            address(deposit),
            address(elFeeRecipient),
            withdrawalCredentials,
            address(oracle),
            admin,
            address(allowlist),
            address(operatorsRegistry),
            collector,
            500
        );
        
        WithdrawV1 proxyAsWithdrawV1 = WithdrawV1(address(withdraw));
        proxyAsWithdrawV1.initializeWithdrawV1(address(river));
        uint64 epochsPerFrame = 225;
        uint64 slotsPerEpoch = 32;
        uint64 secondsPerSlot = 12;
        uint64 epochsToAssumedFinality = 4;
        uint256 upperBound = 1000;
        uint256 lowerBound = 500;
        uint128 minDailyNetCommittable =3200 * 1e18;
        uint128 maxDailyRelativeCommittable = 1000;

        redeemManager = new RedeemManagerV1();
        RiverV1 proxyAsRiverV1 = RiverV1(payable(address(river)));
        proxyAsRiverV1.initRiverV1_1(
            address(redeemManager),
            epochsPerFrame,
            slotsPerEpoch,
            secondsPerSlot,
            genesisTime,
            epochsToAssumedFinality,
            upperBound,
            lowerBound,
            minDailyNetCommittable,
            maxDailyRelativeCommittable
        );
        OperatorsRegistryV1 proxyAsOperatorsRegistryV1 = OperatorsRegistryV1(address(operatorsRegistry));
        proxyAsOperatorsRegistryV1.forceFundedValidatorKeysEventEmission(1);

        vm.expectEmit(true, true, true, true);
        emit SetRiver(address(river));
        vm.expectEmit(true, true, true, true);
        emit SetSpec(epochsPerFrame, slotsPerEpoch, secondsPerSlot, genesisTime);
        vm.expectEmit(true, true, true, true);
        emit SetBounds(annualAprUpperBound, relativeLowerBound);
        vm.expectEmit(true, true, true, true);
        emit SetQuorum(0);

        oracle.initOracleV1(
            address(river),
            admin,
            epochsPerFrame,
            slotsPerEpoch,
            secondsPerSlot,
            genesisTime,
            annualAprUpperBound,
            relativeLowerBound
        );
        oracle.initOracleV1_1();

        vm.startPrank(admin);
        river.setCoverageFund(address(coverageFund));
        river.setKeeper(admin);
        oracle.addMember(oracleMember, 1);
        // ===================

        operatorOneIndex = operatorsRegistry.addOperator(operatorOneName, operatorOne);
        operatorTwoIndex = operatorsRegistry.addOperator(operatorTwoName, operatorTwo);

        bytes memory hundredKeysOp1 = genBytes((48 + 96) * 100);

        operatorsRegistry.addValidators(operatorOneIndex, 100, hundredKeysOp1);

        bytes memory hundredKeysOp2 = genBytes((48 + 96) * 100);

        operatorsRegistry.addValidators(operatorTwoIndex, 100, hundredKeysOp2);

        uint256[] memory operatorIndexes = new uint256[](2);
        operatorIndexes[0] = operatorOneIndex;
        operatorIndexes[1] = operatorTwoIndex;
        uint32[] memory operatorLimits = new uint32[](2);
        operatorLimits[0] = 100;
        operatorLimits[1] = 100;

        operatorsRegistry.setOperatorLimits(operatorIndexes, operatorLimits, block.number);
        vm.stopPrank();
    }

    function _generateEmptyReport() internal pure returns (IOracleManagerV1.ConsensusLayerReport memory clr) {
        clr.stoppedValidatorCountPerOperator = new uint32[](1);
        clr.stoppedValidatorCountPerOperator[0] = 0;
    }

    function _generateEmptyReport(uint256 stoppedValidatorsCountElements)
        internal
        pure
        returns (IOracleManagerV1.ConsensusLayerReport memory clr)
    {
        clr.stoppedValidatorCountPerOperator = new uint32[](stoppedValidatorsCountElements);
    }

    function debug_maxIncrease(ReportBounds.ReportBoundsStruct memory rb, uint256 _prevTotalEth, uint256 _timeElapsed)
        internal
        pure
        returns (uint256)
    {
        return (_prevTotalEth * rb.annualAprUpperBound * _timeElapsed) / (LibBasisPoints.BASIS_POINTS_MAX * 365 days);
    }

    ///// Test

    function testReportingSuccess_AssertELfeesPulledInclRewards(uint256 _salt) external {
        uint8 depositCount = uint8(bound(_salt, 2, 32));
        IOracleManagerV1.ConsensusLayerReport memory clr = _generateEmptyReport();

        _salt = _depositValidators(allowlist, allower, operatorsRegistry, river, admin, depositCount, _salt);

        _salt = uint256(keccak256(abi.encode(_salt)));
        uint256 framesBetween = bound(_salt, 1, 1_000_000);
        uint256 timeBetween = framesBetween * secondsPerSlot * slotsPerEpoch * epochsPerFrame;
        uint256 maxIncrease = debug_maxIncrease(river.getReportBounds(), river.totalUnderlyingSupply(), timeBetween);

        clr.validatorsCount = depositCount;
        clr.validatorsBalance = 32 ether * (depositCount);
        clr.validatorsExitingBalance = 0;
        clr.validatorsSkimmedBalance = 0;
        clr.validatorsExitedBalance = 0;

        uint256 currentEpoch = oracleManager.getCurrentEpochId();
        uint256 tentativeEpoch = currentEpoch + epochsPerFrame -54 -225;
        clr.epoch = tentativeEpoch; 

        vm.deal(address(elFeeRecipient), maxIncrease);

        // uint256 committedAmount = river.getCommittedBalance();
        // uint256 depositAmount = river.getBalanceToDeposit();

        // check balance before
        // river balance
        // EL fee recipient balance
        uint256 elBalanceBefore = address(elFeeRecipient).balance;
        uint256 riverBalanceBefore = address(river).balance;


        address member = uf._new(_salt);

        assertEq(oracle.getQuorum(), 1); // was 0
        assertEq(oracle.isMember(member), false);

        vm.prank(admin);
        oracle.addMember(member, 1);

        assertEq(oracle.getQuorum(), 1);
        assertEq(oracle.isMember(member), true);


        // Oracle level
        vm.expectEmit(true, true, true, true);
        emit ReportedConsensusLayerData(address(member), keccak256(abi.encode(clr)), clr, 1, 1);

        // River level
        vm.expectEmit(false, false, true, false);
        emit SetBalanceToDeposit(0, 0);

        vm.expectEmit(false, true, true, false);
        emit PulledELFees(0);

        address collector = river.getCollector();
        vm.expectEmit(true, false, false, false);
        emit RewardsEarned(collector, 0, 0, 0, 0);
        // compare new vs old token supply
        uint256 supplyBeforeReport = river.totalSupply();
        
        // Oracle manager level
        vm.expectEmit(true, false, false, false);
        IOracleManagerV1.ConsensusLayerDataReportingTrace memory newStruct;
        emit ProcessedConsensusLayerReport(clr, newStruct);

        vm.prank(member);
        vm.mockCall(
            address(redeemManager),
            abi.encodeWithSelector(RedeemManagerV1.pullExceedingEth.selector),
            abi.encode()
        );
        oracle.reportConsensusLayerData(clr);

        // check river balance increased upon reporting
        uint256 elBalanceAfter = address(elFeeRecipient).balance;
        uint256 riverBalanceAfter = address(river).balance;

        // pulls committed amounts from ELFeeRecipient into River
        uint256 elBalanceDecrease = elBalanceBefore - elBalanceAfter;
        uint256 riverBalanceIncrease = riverBalanceAfter - riverBalanceBefore;
        assert(riverBalanceIncrease == elBalanceDecrease);

        // assert rewards shares were mintedm token supply increased
        uint256 supplyAfterReport = river.totalSupply();
        assert(supplyAfterReport > supplyBeforeReport);
 
        assertEq(river.getCommittedBalance() % 32 ether, 0);
    }

}
