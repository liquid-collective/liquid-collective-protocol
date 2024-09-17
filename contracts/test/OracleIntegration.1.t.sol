//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
// fixtures
import "./fixtures/RiverV1TestBase.sol";
// utils
import "./utils/BytesGenerator.sol";
import "./utils/LibImplementationUnbricker.sol";
import "./utils/UserFactory.sol";
import "./utils/RiverHelper.sol";
import "./utils/events/OracleEvents.sol";
// contracts
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
import "../src/Firewall.sol";
import "../src/TUPProxy.sol";
// mocks
import "./mocks/DepositContractMock.sol";
import "./mocks/RiverMock.sol";

contract OracleIntegrationTest is Test, RiverV1TestBase, RiverHelper, OracleEvents {
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

        redeemManager = new RedeemManagerV1();
        RiverV1 proxyAsRiverV1 = RiverV1(payable(address(river)));
        proxyAsRiverV1.initRiverV1_1(
            address(redeemManager),
            epochsPerFrame,
            slotsPerEpoch,
            secondsPerSlot,
            genesisTime,
            epochsToAssumedFinality,
            annualAprUpperBound,
            relativeLowerBound,
            minDailyNetCommittableAmount,
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

    /// @notice This test is to check the Oracle integration with the River contract
    function testOracleIntegration(uint256 _salt) external {
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
