// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
// fixtures
import "./fixtures/DeploymentFixture.sol";
import "./fixtures/RiverV1ForceCommittable.sol";
// utils
import "./utils/RiverHelper.sol";
import "./utils/IntegrationTestHelpers.sol";
import "./utils/events/OperatorRegistryEvents.sol";
import "./utils/events/RedeemManagerEvents.sol";

contract WithdrawIntegration is
    Test,
    DeploymentFixture,
    RiverHelper,
    IntegrationTestHelpers,
    OperatorRegistryEvents,
    RedeemManagerEvents
{
    function setUp() public override {
        super.setUp();
        // set up coverage fund
        vm.prank(address(riverProxyFirewall));
        RiverV1(payable(address(riverProxy))).setCoverageFund(address(coverageFundProxy));
        // set up keeper
        vm.prank(address(riverProxyFirewall));
        RiverV1(payable(address(riverProxy))).setKeeper(address(operatorsRegistryFirewall));
        // deal bob
        vm.deal(address(bob), 100 ether);
        mockWithdrawalRiverAddress(address(withdraw), address(riverProxy));
    }

    function testRequestRedeemMultiple(uint256 _salt) external {
        uint8 depositCount = uint8(bound(_salt, 4, 32));
        _salt = _depositValidators(
            AllowlistV1(address(allowlistProxy)),
            allower,
            OperatorsRegistryV1(address(operatorsRegistryProxy)),
            RiverV1ForceCommittable(payable(address(riverProxy))),
            address(operatorsRegistryFirewall),
            depositCount,
            _salt
        );

        // Bob deposits to LC
        uint256 depositAmount = bound(_salt, 2 ether, 100 ether);
        allowlistedUserDeposits(bob, depositAmount);
        userApprovesRedeemMananger(bob, depositAmount);

        // Bob requests redeem number 1
        uint128 amount_1 = uint128(bound(_salt, 1, depositAmount / 2));
        uint256 maxRedeemableEth_1 = RiverV1(payable(address(riverProxy))).underlyingBalanceFromShares(amount_1);
        vm.prank(bob);
        RiverV1(payable(address(riverProxy))).requestRedeem(amount_1, address(bob));

        assert(IRedeemManagerV1(payable(address(redeemManagerProxy))).getRedeemRequestCount() == 1);
        assert(IRedeemManagerV1(payable(address(redeemManagerProxy))).getRedeemRequestDetails(0).amount == amount_1);
        assert(
            IRedeemManagerV1(payable(address(redeemManagerProxy))).getRedeemRequestDetails(0).maxRedeemableEth
                == maxRedeemableEth_1
        );
        assert(
            IRedeemManagerV1(payable(address(redeemManagerProxy))).getRedeemRequestDetails(0).recipient == address(bob)
        );
        assert(IRedeemManagerV1(payable(address(redeemManagerProxy))).getRedeemRequestDetails(0).height == 0);

        // Bob requests redeem number 2
        uint256 amount_2 = uint128(bound(_salt, 1, depositAmount / 2));
        uint256 height_2 = amount_2;
        uint256 maxRedeemableEth_2 = RiverV1(payable(address(riverProxy))).underlyingBalanceFromShares(amount_2);
        vm.prank(bob);
        RiverV1(payable(address(riverProxy))).requestRedeem(amount_2, address(bob));

        assert(IRedeemManagerV1(payable(address(redeemManagerProxy))).getRedeemRequestCount() == 2);
        assert(IRedeemManagerV1(payable(address(redeemManagerProxy))).getRedeemRequestDetails(1).amount == amount_2);
        assert(
            IRedeemManagerV1(payable(address(redeemManagerProxy))).getRedeemRequestDetails(1).maxRedeemableEth
                == maxRedeemableEth_2
        );
        assert(
            IRedeemManagerV1(payable(address(redeemManagerProxy))).getRedeemRequestDetails(1).recipient == address(bob)
        );
        assert(IRedeemManagerV1(payable(address(redeemManagerProxy))).getRedeemRequestDetails(1).height == height_2);
    }

    function testOracleTriggersValidatorExitUponRedeemRequests(uint256 _salt) external {
        uint8 depositCount = uint8(bound(_salt, 4, 32));
        IOracleManagerV1.ConsensusLayerReport memory clr = _generateEmptyReport();
        _salt = _depositValidators(
            AllowlistV1(address(allowlistProxy)),
            allower,
            OperatorsRegistryV1(address(operatorsRegistryProxy)),
            RiverV1ForceCommittable(payable(address(riverProxy))),
            address(operatorsRegistryFirewall),
            depositCount,
            _salt
        );
        setUpOperators();
        address member = setUpOracleMember(_salt);

        // mock oracle report
        clr.validatorsCount = depositCount;
        clr.validatorsSkimmedBalance = 0;
        clr.validatorsBalance = 32 ether * (depositCount);
        clr.validatorsExitedBalance = 0;
        clr.rebalanceDepositToRedeemMode = false;
        mockValidEpoch(address(riverProxy), 1726660451, 0, clr);

        // Bob deposits to LC
        uint256 depositAmount = bound(_salt, 2 ether, 32 ether);
        allowlistedUserDeposits(bob, depositAmount);
        userApprovesRedeemMananger(bob, depositAmount);

        // Bob requests redeem
        uint128 amount_1 = uint128(bound(_salt, 1, depositAmount / 2));
        uint256 maxRedeemableEth_1 = RiverV1(payable(address(riverProxy))).underlyingBalanceFromShares(amount_1);
        assert(maxRedeemableEth_1 < 32 ether);

        vm.prank(bob);
        RiverV1(payable(address(riverProxy))).requestRedeem(amount_1, address(bob));

        mockDailyCommittableLimit(address(riverProxy), 2000, 32 ether);

        // Oracle report triggers 1 validator to exit (total redeem deamnd = 32 ETH, maxR)
        vm.expectEmit(true, true, true, true);
        emit SetCurrentValidatorExitsDemand(0, 1);

        vm.prank(member);
        OracleV1(address(oracleProxy)).reportConsensusLayerData(clr);
    }

    function testOracleRebalancesDepositToRedeemAndUserWithdrdawsFunds(uint256 _salt) external {
        uint8 depositCount = uint8(bound(_salt, 4, 32));
        IOracleManagerV1.ConsensusLayerReport memory clr = _generateEmptyReport();
        _salt = _depositValidators(
            AllowlistV1(address(allowlistProxy)),
            allower,
            OperatorsRegistryV1(address(operatorsRegistryProxy)),
            RiverV1ForceCommittable(payable(address(riverProxy))),
            address(operatorsRegistryFirewall),
            depositCount,
            _salt
        );
        setUpOperators();
        address member = setUpOracleMember(_salt);

        // set up new oracle report
        clr.validatorsCount = depositCount;
        clr.validatorsSkimmedBalance = 0;
        clr.validatorsBalance = 32 ether * (depositCount);
        clr.validatorsExitedBalance = 0;
        clr.rebalanceDepositToRedeemMode = true;
        mockValidEpoch(address(riverProxy), 1726660451, 0, clr); // sets clr.epoch to valid epoch

        // Bob deposits to LC
        uint256 depositAmount = bound(_salt, 2 ether, 32 ether);
        allowlistedUserDeposits(bob, depositAmount);
        userApprovesRedeemMananger(bob, depositAmount);

        // Bob requests redeem
        uint128 amount_1 = uint128(bound(_salt, 1, depositAmount / 2));
        uint256 redeemDemand = RiverV1(payable(address(riverProxy))).underlyingBalanceFromShares(amount_1);
        vm.prank(bob);
        RiverV1(payable(address(riverProxy))).requestRedeem(amount_1, address(bob));

        // Oracle update directly withdraws from deposit amount (rebalanceDepositToRedeemMode = true)
        mockDailyCommittableLimit(address(riverProxy), 2000, 32 ether);
        vm.expectEmit(true, true, true, true);
        emit ReportedWithdrawal(0, redeemDemand, redeemDemand, 0);
        vm.prank(member);
        OracleV1(address(oracleProxy)).reportConsensusLayerData(clr);

        assert(IRedeemManagerV1(payable(address(redeemManagerProxy))).getWithdrawalEventCount() == 1);
        assert(
            IRedeemManagerV1(payable(address(redeemManagerProxy))).getWithdrawalEventDetails(0).amount == redeemDemand
        );

        // Bob withdraws the requested ETH
        uint32[] memory redeemRequestIds = new uint32[](1);
        uint32[] memory withdrawEventIds = new uint32[](1);
        redeemRequestIds[0] = 0;
        withdrawEventIds[0] = 0;

        uint256 bobBalance = address(bob).balance;
        IRedeemManagerV1(payable(address(redeemManagerProxy))).claimRedeemRequests(
            redeemRequestIds, withdrawEventIds, true, type(uint16).max
        );
        // assert Bob received the requested ETH
        assert(address(bob).balance == bobBalance + redeemDemand);
    }

    function setUpOperators() internal {
        address operatorsRegistryAdmin = address(operatorsRegistryFirewall);
        // add operator + validators
        vm.prank(operatorsRegistryAdmin);
        operatorOneIndex =
            OperatorsRegistryV1(address(operatorsRegistryProxy)).addOperator(operatorOneName, operatorOne);
        bytes memory hundredKeysOp1 = genBytes((48 + 96) * 100);
        vm.prank(operatorsRegistryAdmin);
        OperatorsRegistryV1(address(operatorsRegistryProxy)).addValidators(operatorOneIndex, 100, hundredKeysOp1);
        bytes memory hundredKeysOp2 = genBytes((48 + 96) * 100);
        vm.prank(operatorsRegistryAdmin);
        OperatorsRegistryV1(address(operatorsRegistryProxy)).addValidators(operatorTwoIndex, 100, hundredKeysOp2);

        uint256[] memory operatorIndexes = new uint256[](1);
        operatorIndexes[0] = operatorOneIndex;
        uint32[] memory operatorLimits = new uint32[](1);
        operatorLimits[0] = uint32(100);
        // set operator limits
        vm.prank(operatorsRegistryAdmin);
        OperatorsRegistryV1(address(operatorsRegistryProxy)).setOperatorLimits(
            operatorIndexes, operatorLimits, block.number
        );
    }

    function setUpOracleMember(uint256 _salt) internal returns (address) {
        address member = uf._new(_salt);
        vm.prank(admin);
        OracleV1(address(oracleProxy)).addMember(member, 1);

        return member;
    }

    function allowlistedUserDeposits(address user, uint256 amount) internal {
        _allow(IAllowlistV1(address(allowlistProxy)), allower, user);
        vm.startPrank(user);
        RiverV1(payable(address(riverProxy))).deposit{value: amount}();
        vm.stopPrank();
    }

    function userApprovesRedeemMananger(address user, uint256 amount) internal {
        vm.prank(user);
        RiverV1(payable(address(riverProxy))).approve(address(redeemManagerProxy), amount);
    }
}
