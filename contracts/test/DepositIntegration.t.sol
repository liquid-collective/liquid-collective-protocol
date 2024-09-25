// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
// fixtures
import "./fixtures/RiverUnitTestBase.sol";
import "./fixtures/DeploymentFixture.sol";
import "./fixtures/RiverV1ForceCommittable.sol";
// utils
import "./utils/RiverHelper.sol";
import "./utils/IntegrationTestHelpers.sol";
import "./utils/events/RiverEvents.sol";

contract DepositIntegrationTest is Test, DeploymentFixture, RiverHelper, IntegrationTestHelpers {
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
        // mock River address for pullCLfunds
        mockWithdrawalRiverAddress(address(withdraw), address(riverProxy));
    }

    /// @notice This test is to check the Oracle integration with the River contract
    function testUserDepositDoesNotAlterConversionRate(uint256 _salt, uint256 _frame) external {
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
        vm.assume(_frame <= 255);
        setUpOperators();
        uint256 previousSupply = RiverV1(payable(address(riverProxy))).totalUnderlyingSupply();

        // Bob deposits to LC
        _allow(IAllowlistV1(address(allowlistProxy)), allower, bob);
        vm.startPrank(bob);
        RiverV1(payable(address(riverProxy))).deposit{value: 32 ether}();
        vm.stopPrank();

        // Bob's funds are committed and deposited to the consensus layer
        RiverV1ForceCommittable(payable(address(riverProxy))).debug_moveDepositToCommitted();
        vm.prank(address(operatorsRegistryFirewall));
        RiverV1(payable(address(riverProxy))).depositToConsensusLayerWithDepositRoot(100, bytes32(0));

        assert(RiverV1(payable(address(riverProxy))).balanceOf(bob) == 32 ether);
        assert(RiverV1(payable(address(riverProxy))).balanceOfUnderlying(bob) == 32 ether);
        assert(RiverV1(payable(address(riverProxy))).totalUnderlyingSupply() == previousSupply + 32 ether);
    }

    /// @notice This test is to check the Oracle integration with the River contract
    function testOracleReportMovesDepositedToCommitted(uint256 _salt, uint256 _frame) external {
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
        vm.assume(_frame <= 255);

        // Bob deposits to LC
        _allow(IAllowlistV1(address(allowlistProxy)), allower, bob);
        vm.startPrank(bob);
        RiverV1(payable(address(riverProxy))).deposit{value: 32 ether}();
        vm.stopPrank();

        setUpOperators();

        address member = setUpOracleMember(_salt);
        // new oracle report
        clr.validatorsCount = depositCount;
        clr.validatorsSkimmedBalance = 0;
        clr.validatorsBalance = 32 ether * (depositCount);
        clr.validatorsExitedBalance = 0;
        mockValidEpoch(address(riverProxy), 1726660451, _frame, clr); // sets clr.epoch to valid epoch

        uint256 bobPreReportBalance = RiverV1(payable(address(riverProxy))).balanceOfUnderlying(bob);
        assert(RiverV1(payable(address(riverProxy))).getCommittedBalance() == 0);
        assert(RiverV1(payable(address(riverProxy))).getBalanceToDeposit() == 32 ether);

        mockDailyCommittableLimit(address(riverProxy), 2000, 32 ether);
        vm.prank(member);
        OracleV1(address(oracleProxy)).reportConsensusLayerData(clr);

        assert(RiverV1(payable(address(riverProxy))).getCommittedBalance() == 32 ether);
        assert(RiverV1(payable(address(riverProxy))).getBalanceToDeposit() == 0);
        assert(RiverV1(payable(address(riverProxy))).balanceOfUnderlying(bob) == bobPreReportBalance);
    }

    /// @notice This test checks if the Oracle report pulls CL funds and commits them for restaking, it does not alter the user conversion rate
    function testOraclePullsCLfundsDoesNotAlterUserConversionRate(uint256 _salt, uint256 _frame) external {
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
        _salt = uint256(keccak256(abi.encode(_salt)));
        uint256 framesBetween = bound(_salt, 1, 1_000_000);
        uint256 timeBetween = framesBetween * secondsPerSlot * slotsPerEpoch * epochsPerFrame;
        uint256 maxIncrease = debug_maxIncrease(
            RiverV1(payable(address(riverProxy))).getReportBounds(),
            RiverV1(payable(address(riverProxy))).totalUnderlyingSupply(),
            timeBetween
        );
        vm.assume(_frame <= 255);

        // Bob deposits to LC
        _allow(IAllowlistV1(address(allowlistProxy)), allower, bob);
        vm.startPrank(bob);
        RiverV1(payable(address(riverProxy))).deposit{value: 32 ether}();
        vm.stopPrank();

        setUpOperators();

        // Bob's funds are deposited to the consensus layer
        RiverV1ForceCommittable(payable(address(riverProxy))).debug_moveDepositToCommitted();
        vm.prank(address(operatorsRegistryFirewall));
        RiverV1(payable(address(riverProxy))).depositToConsensusLayerWithDepositRoot(100, bytes32(0));

        assert(RiverV1(payable(address(riverProxy))).balanceOf(bob) == 32 ether);
        assert(RiverV1(payable(address(riverProxy))).balanceOfUnderlying(bob) == 32 ether);

        address member = setUpOracleMember(_salt);
        // mock new oracle report
        uint256 committedBalance = RiverV1(payable(address(riverProxy))).getCommittedBalance();
        uint256 depositedBalance = RiverV1(payable(address(riverProxy))).getBalanceToDeposit();
        clr.validatorsCount = depositCount + 1;
        clr.validatorsSkimmedBalance = bound(_salt, 0, maxIncrease / 1000);
        clr.validatorsBalance =
            32 ether * (depositCount) + committedBalance + depositedBalance - clr.validatorsSkimmedBalance;
        clr.validatorsExitedBalance = 0;
        mockValidEpoch(address(riverProxy), 1726660451, _frame, clr);
        vm.deal(address(withdraw), clr.validatorsSkimmedBalance); // add CL rewards

        // mock previous oracle report balances
        mockPreviousValidatorReportBalances(address(riverProxy), depositCount * 32 ether, 0, clr.validatorsCount);

        uint256 preReportBalance = address(riverProxy).balance;
        uint256 preReportSupply = RiverV1(payable(address(riverProxy))).totalUnderlyingSupply();
        uint256 bobPreReportBalance = RiverV1(payable(address(riverProxy))).balanceOfUnderlying(bob);

        // oracle report will pull CL funds
        vm.prank(member);
        OracleV1(address(oracleProxy)).reportConsensusLayerData(clr);

        assert(address(riverProxy).balance == preReportBalance + clr.validatorsSkimmedBalance);
        assert(RiverV1(payable(address(riverProxy))).totalUnderlyingSupply() == preReportSupply);
        assert(RiverV1(payable(address(riverProxy))).balanceOfUnderlying(bob) == bobPreReportBalance);
    }

    function setUpOperators() internal {
        address operatorsRegistryAdmin = address(operatorsRegistryFirewall);

        // add operator
        vm.prank(operatorsRegistryAdmin);
        operatorOneIndex =
            OperatorsRegistryV1(address(operatorsRegistryProxy)).addOperator(operatorOneName, operatorOne);
        bytes memory hundredKeysOp1 = genBytes((48 + 96) * 100);

        // add validators
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
}
