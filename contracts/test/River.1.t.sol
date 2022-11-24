//SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "forge-std/Test.sol";

import "./utils/UserFactory.sol";
import "./utils/BytesGenerator.sol";
import "./mocks/DepositContractMock.sol";

import "../src/libraries/LibAllowlistMasks.sol";
import "../src/Allowlist.1.sol";
import "../src/River.1.sol";
import "../src/interfaces/IDepositContract.sol";
import "../src/Withdraw.1.sol";
import "../src/Oracle.1.sol";
import "../src/ELFeeRecipient.1.sol";
import "../src/OperatorsRegistry.1.sol";
import "../src/CoverageFund.1.sol";

contract RiverV1SetupOneTests is Test, BytesGenerator {
    UserFactory internal uf = new UserFactory();

    RiverV1 internal river;
    IDepositContract internal deposit;
    WithdrawV1 internal withdraw;
    OracleV1 internal oracle;
    ELFeeRecipientV1 internal elFeeRecipient;
    CoverageFundV1 internal coverageFund;
    AllowlistV1 internal allowlist;
    OperatorsRegistryV1 internal operatorsRegistry;

    address internal admin;
    address internal newAdmin;
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

    event PulledELFees(uint256 amount);
    event SetELFeeRecipient(address indexed elFeeRecipient);
    event SetCollector(address indexed collector);
    event SetAllowlist(address indexed allowlist);
    event SetGlobalFee(uint256 fee);
    event SetOperatorsRegistry(address indexed operatorsRegistry);

    function setUp() public {
        admin = makeAddr("admin");
        newAdmin = makeAddr("newAdmin");
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
        coverageFund = new CoverageFundV1();
        oracle = new OracleV1();
        allowlist = new AllowlistV1();
        deposit = new DepositContractMock();
        withdraw = new WithdrawV1();
        river = new RiverV1();
        operatorsRegistry = new OperatorsRegistryV1();

        bytes32 withdrawalCredentials = withdraw.getCredentials();
        allowlist.initAllowlistV1(admin, allower);
        operatorsRegistry.initOperatorsRegistryV1(admin, address(river));
        elFeeRecipient.initELFeeRecipientV1(address(river));
        coverageFund.initCoverageFundV1(address(river));
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
        oracle.initOracleV1(address(river), admin, 225, 32, 12, 0, 1000, 500);
        vm.startPrank(admin);

        river.setCoverageFund(address(coverageFund));

        // ===================

        oracle.addMember(oracleMember, 1);

        operatorOneIndex = operatorsRegistry.addOperator(operatorOneName, operatorOne);
        operatorTwoIndex = operatorsRegistry.addOperator(operatorTwoName, operatorTwo);

        bytes memory hundredKeysOp1 = genBytes((48 + 96) * 100);

        operatorsRegistry.addValidators(operatorOneIndex, 100, hundredKeysOp1);

        bytes memory hundredKeysOp2 = genBytes((48 + 96) * 100);

        operatorsRegistry.addValidators(operatorTwoIndex, 100, hundredKeysOp2);

        uint256[] memory operatorIndexes = new uint256[](2);
        operatorIndexes[0] = operatorOneIndex;
        operatorIndexes[1] = operatorTwoIndex;
        uint256[] memory operatorLimits = new uint256[](2);
        operatorLimits[0] = 100;
        operatorLimits[1] = 100;

        operatorsRegistry.setOperatorLimits(operatorIndexes, operatorLimits, block.number);
        vm.stopPrank();
    }

    function testInitWithZeroAddressValue() public {
        withdraw = new WithdrawV1();
        bytes32 withdrawalCredentials = withdraw.getCredentials();
        river = new RiverV1();
        vm.expectRevert(abi.encodeWithSignature("InvalidZeroAddress()"));
        river.initRiverV1(
            address(0),
            address(0),
            withdrawalCredentials,
            address(0),
            address(0),
            address(0),
            address(0),
            address(0),
            5000
        );
    }

    function testAdditionalInit() public {
        bytes32 withdrawalCredentials = withdraw.getCredentials();
        vm.startPrank(admin);
        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization(uint256,uint256)", 0, 1));
        river.initRiverV1(
            address(deposit),
            address(elFeeRecipient),
            withdrawalCredentials,
            address(oracle),
            admin,
            allower,
            address(operatorsRegistry),
            collector,
            5000
        );
        vm.stopPrank();
    }

    function testSetELFeeRecipient(uint256 _newELFeeRecipientSalt) public {
        address newELFeeRecipient = uf._new(_newELFeeRecipientSalt);
        vm.startPrank(admin);
        assert(river.getELFeeRecipient() == address(elFeeRecipient));
        vm.expectEmit(true, true, true, true);
        emit SetELFeeRecipient(newELFeeRecipient);
        river.setELFeeRecipient(newELFeeRecipient);
        assert(river.getELFeeRecipient() == newELFeeRecipient);
        vm.stopPrank();
    }

    function testSetELFeeRecipientUnauthorized(uint256 _newELFeeRecipientSalt) public {
        address newELFeeRecipient = uf._new(_newELFeeRecipientSalt);
        assert(river.getELFeeRecipient() == address(elFeeRecipient));
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", address(this)));
        river.setELFeeRecipient(newELFeeRecipient);
    }

    function testSendELFundsUnauthorized(uint256 _invalidAddressSalt) public {
        address invalidAddress = uf._new(_invalidAddressSalt);
        vm.startPrank(invalidAddress);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", invalidAddress));
        river.sendELFees();
        vm.stopPrank();
    }

    function testGetOperatorsRegistry() public view {
        assert(river.getOperatorsRegistry() == address(operatorsRegistry));
    }

    function testSetCollector() public {
        vm.startPrank(admin);
        assert(river.getCollector() == collector);
        vm.expectEmit(true, true, true, true);
        emit SetCollector(newCollector);
        river.setCollector(newCollector);
        assert(river.getCollector() == newCollector);
        vm.stopPrank();
    }

    function testSetCollectorUnauthorized() public {
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", address(this)));
        river.setCollector(newCollector);
    }

    function testSetAllowlist() public {
        vm.startPrank(admin);
        assert(river.getAllowlist() == address(allowlist));
        vm.expectEmit(true, true, true, true);
        emit SetAllowlist(newAllowlist);
        river.setAllowlist(newAllowlist);
        assert(river.getAllowlist() == newAllowlist);
        vm.stopPrank();
    }

    function testSetAllowlistUnauthorized() public {
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", address(this)));
        river.setAllowlist(newAllowlist);
    }

    function testSetGlobalFee() public {
        vm.startPrank(admin);
        vm.expectEmit(true, true, true, true);
        emit SetGlobalFee(5000);
        river.setGlobalFee(5000);
        vm.stopPrank();
        assert(river.getGlobalFee() == 5000);
    }

    function testSetGlobalFeeHigherThanBase() public {
        vm.startPrank(admin);
        vm.expectRevert(abi.encodeWithSignature("InvalidFee()"));
        river.setGlobalFee(100001);
        vm.stopPrank();
    }

    function testSetGlobalFeeUnauthorized() public {
        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", bob));
        river.setGlobalFee(5000);
        vm.stopPrank();
    }

    function testGetAdministrator() public {
        vm.startPrank(bob);
        assert(river.getAdmin() == admin);
        vm.stopPrank();
    }

    event SetMetadataURI(string metadataURI);

    function testSetMetadataURI(string memory _metadataURI) public {
        vm.assume(bytes(_metadataURI).length > 0);
        vm.startPrank(admin);
        assertEq(river.getMetadataURI(), "");
        vm.expectEmit(true, true, true, true);
        emit SetMetadataURI(_metadataURI);
        river.setMetadataURI(_metadataURI);
        assertEq(river.getMetadataURI(), _metadataURI);
        vm.stopPrank();
    }

    function testSetMetadataURIEmpty() public {
        vm.startPrank(admin);
        vm.expectRevert(abi.encodeWithSignature("InvalidEmptyString()"));
        river.setMetadataURI("");
        vm.stopPrank();
    }

    function testSetMetadataURIUnauthorized(string memory _metadataURI, uint256 _salt) public {
        address unauthorized = uf._new(_salt);
        vm.prank(unauthorized);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", unauthorized));
        river.setMetadataURI(_metadataURI);
    }

    function _allow(address _who, uint256 _mask) internal {
        address[] memory allowees = new address[](1);
        allowees[0] = _who;
        uint256[] memory statuses = new uint256[](1);
        statuses[0] = _mask;

        vm.startPrank(admin);
        allowlist.allow(allowees, statuses);
        vm.stopPrank();
    }

    function _deny(address _who) internal {
        address[] memory allowees = new address[](1);
        allowees[0] = _who;
        uint256[] memory statuses = new uint256[](1);
        statuses[0] = LibAllowlistMasks.DENY_MASK;

        vm.startPrank(admin);
        allowlist.allow(allowees, statuses);
        vm.stopPrank();
    }

    function testUnauthorizedDeposit() public {
        vm.deal(joe, 100 ether);

        vm.startPrank(joe);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", joe));
        river.deposit{value: 100 ether}();
        vm.stopPrank();
    }

    // Testing regular parameters
    function testUserDeposits() public {
        vm.deal(joe, 100 ether);
        vm.deal(bob, 1000 ether);

        _allow(joe, LibAllowlistMasks.DEPOSIT_MASK);
        _allow(bob, LibAllowlistMasks.DEPOSIT_MASK);

        vm.startPrank(joe);
        river.deposit{value: 100 ether}();
        vm.stopPrank();
        vm.startPrank(bob);
        river.deposit{value: 1000 ether}();
        vm.stopPrank();
        assert(river.balanceOfUnderlying(joe) == 100 ether);
        assert(river.balanceOfUnderlying(bob) == 1000 ether);
        assert(river.getDepositedValidatorCount() == 0);
        assert(river.totalUnderlyingSupply() == 1100 ether);

        vm.prank(admin);
        river.depositToConsensusLayer(17);
        vm.prank(admin);
        river.depositToConsensusLayer(17);

        Operators.Operator memory op1 = operatorsRegistry.getOperator(operatorOneIndex);
        Operators.Operator memory op2 = operatorsRegistry.getOperator(operatorTwoIndex);

        assert(op1.funded == 17);
        assert(op2.funded == 17);

        assert(river.getDepositedValidatorCount() == 34);
        assert(river.totalUnderlyingSupply() == 1100 ether);
        assert(address(river).balance == (1000 ether + 100 ether) - (32 ether * 34));
        assert(river.balanceOfUnderlying(joe) == 100 ether);
        assert(river.balanceOfUnderlying(bob) == 1000 ether);

        vm.startPrank(oracleMember);
        (uint256 epoch,,) = oracle.getCurrentFrame();
        oracle.reportConsensusLayerData(epoch, 33 * 1e9 * 34, 34);
        vm.stopPrank();

        assert(river.totalUnderlyingSupply() == 1100 ether - (34 * 32 ether) + (34 * 33 ether));
        assert(river.balanceOfUnderlying(joe) == 102936363636363636363);
        assert(river.balanceOfUnderlying(bob) == 1029363636363636363636);
        assert(river.balanceOfUnderlying(operatorOneFeeRecipient) == 0);
        assert(river.balanceOfUnderlying(operatorTwoFeeRecipient) == 0);
        assert(river.balanceOfUnderlying(collector) == 1699999999999999999);

        vm.startPrank(joe);
        river.transfer(bob, river.balanceOf(joe) - 1);
        vm.stopPrank();

        assert(river.balanceOfUnderlying(joe) == 1);
        assert(river.balanceOfUnderlying(bob) == 1132299999999999999999);
        assert(river.balanceOfUnderlying(operatorOneFeeRecipient) == 0);
        assert(river.balanceOfUnderlying(operatorTwoFeeRecipient) == 0);
        assert(river.balanceOfUnderlying(collector) == 1699999999999999999);

        assert(
            river.totalSupply()
                == river.balanceOf(joe) + river.balanceOf(bob) + river.balanceOf(operatorOneFeeRecipient)
                    + river.balanceOf(operatorTwoFeeRecipient) + river.balanceOf(collector)
        );
    }

    event RewardsEarned(
        address indexed _collector,
        uint256 _oldTotalUnderylyingBalance,
        uint256 _oldTotalSupply,
        uint256 _newTotalUnderlyingBalance,
        uint256 _newTotalSupply
    );

    function testRewardsEarnedEventBroadcasting() public {
        vm.deal(joe, 100 ether);
        vm.deal(bob, 1000 ether);

        _allow(joe, LibAllowlistMasks.DEPOSIT_MASK);
        _allow(bob, LibAllowlistMasks.DEPOSIT_MASK);

        vm.startPrank(joe);
        river.deposit{value: 100 ether}();
        vm.stopPrank();
        vm.startPrank(bob);
        river.deposit{value: 1000 ether}();
        vm.stopPrank();
        assert(river.balanceOfUnderlying(joe) == 100 ether);
        assert(river.balanceOfUnderlying(bob) == 1000 ether);
        assert(river.getDepositedValidatorCount() == 0);
        assert(river.totalUnderlyingSupply() == 1100 ether);

        vm.prank(admin);
        river.depositToConsensusLayer(17);
        vm.prank(admin);
        river.depositToConsensusLayer(17);

        Operators.Operator memory op1 = operatorsRegistry.getOperator(operatorOneIndex);
        Operators.Operator memory op2 = operatorsRegistry.getOperator(operatorTwoIndex);

        assert(op1.funded == 17);
        assert(op2.funded == 17);

        assert(river.getDepositedValidatorCount() == 34);
        assert(river.totalUnderlyingSupply() == 1100 ether);
        assert(address(river).balance == (1000 ether + 100 ether) - (32 ether * 34));
        assert(river.balanceOfUnderlying(joe) == 100 ether);
        assert(river.balanceOfUnderlying(bob) == 1000 ether);

        vm.startPrank(oracleMember);
        (uint256 epoch,,) = oracle.getCurrentFrame();
        vm.expectEmit(true, true, true, true);
        emit RewardsEarned(collector, 1100 ether, 1100 ether, 1134 ether, 1101651505784686037269);
        oracle.reportConsensusLayerData(epoch, 33 * 1e9 * 34, 34);
        vm.stopPrank();

        assert(river.totalUnderlyingSupply() == 1100 ether - (34 * 32 ether) + (34 * 33 ether));
        assert(river.balanceOfUnderlying(joe) == 102936363636363636363);
        assert(river.balanceOfUnderlying(bob) == 1029363636363636363636);
        assert(river.balanceOfUnderlying(operatorOneFeeRecipient) == 0);
        assert(river.balanceOfUnderlying(operatorTwoFeeRecipient) == 0);
        assert(river.balanceOfUnderlying(collector) == 1699999999999999999);

        vm.startPrank(joe);
        river.transfer(bob, river.balanceOf(joe) - 1);
        vm.stopPrank();

        assert(river.balanceOfUnderlying(joe) == 1);
        assert(river.balanceOfUnderlying(bob) == 1132299999999999999999);
        assert(river.balanceOfUnderlying(operatorOneFeeRecipient) == 0);
        assert(river.balanceOfUnderlying(operatorTwoFeeRecipient) == 0);
        assert(river.balanceOfUnderlying(collector) == 1699999999999999999);

        assert(
            river.totalSupply()
                == river.balanceOf(joe) + river.balanceOf(bob) + river.balanceOf(operatorOneFeeRecipient)
                    + river.balanceOf(operatorTwoFeeRecipient) + river.balanceOf(collector)
        );
    }

    function testValidatorsPenalties() public {
        vm.deal(joe, 100 ether);
        vm.deal(bob, 1000 ether);

        _allow(joe, LibAllowlistMasks.DEPOSIT_MASK);
        _allow(bob, LibAllowlistMasks.DEPOSIT_MASK);

        vm.startPrank(joe);
        river.deposit{value: 100 ether}();
        vm.stopPrank();
        vm.startPrank(bob);
        river.deposit{value: 1000 ether}();
        vm.stopPrank();
        assert(river.balanceOfUnderlying(joe) == 100 ether);
        assert(river.balanceOfUnderlying(bob) == 1000 ether);
        assert(river.getDepositedValidatorCount() == 0);
        assert(river.totalUnderlyingSupply() == 1100 ether);

        vm.prank(admin);
        river.depositToConsensusLayer(17);
        vm.prank(admin);
        river.depositToConsensusLayer(17);

        Operators.Operator memory op1 = operatorsRegistry.getOperator(operatorOneIndex);
        Operators.Operator memory op2 = operatorsRegistry.getOperator(operatorTwoIndex);

        assert(op1.funded == 17);
        assert(op2.funded == 17);

        assert(river.getDepositedValidatorCount() == 34);
        assert(river.totalUnderlyingSupply() == 1100 ether);
        assert(address(river).balance == (1000 ether + 100 ether) - (32 ether * 34));
        assert(river.balanceOfUnderlying(joe) == 100 ether);
        assert(river.balanceOfUnderlying(bob) == 1000 ether);

        vm.startPrank(oracleMember);
        (uint256 epoch,,) = oracle.getCurrentFrame();
        oracle.reportConsensusLayerData(epoch, 31 * 1e9 * 34, 34);
        vm.stopPrank();

        assert(river.totalUnderlyingSupply() == 1100 ether - (34 * 32 ether) + (34 * 31 ether));
        assert(river.balanceOfUnderlying(joe) == 96909090909090909090);
        assert(river.balanceOfUnderlying(bob) == 969090909090909090909);
        assert(river.balanceOfUnderlying(operatorOneFeeRecipient) == 0);
        assert(river.balanceOfUnderlying(operatorTwoFeeRecipient) == 0);
        assert(river.balanceOfUnderlying(collector) == 0);

        assert(
            river.totalSupply()
                == river.balanceOf(joe) + river.balanceOf(bob) + river.balanceOf(operatorOneFeeRecipient)
                    + river.balanceOf(operatorTwoFeeRecipient) + river.balanceOf(collector)
        );
    }

    function testValidatorsPenaltiesEqualToExecLayerFees() public {
        vm.deal(joe, 100 ether);
        vm.deal(bob, 1000 ether);

        _allow(joe, LibAllowlistMasks.DEPOSIT_MASK);
        _allow(bob, LibAllowlistMasks.DEPOSIT_MASK);

        vm.startPrank(joe);
        river.deposit{value: 100 ether}();
        vm.stopPrank();
        vm.startPrank(bob);
        river.deposit{value: 1000 ether}();
        vm.stopPrank();
        assert(river.balanceOfUnderlying(joe) == 100 ether);
        assert(river.balanceOfUnderlying(bob) == 1000 ether);
        assert(river.getDepositedValidatorCount() == 0);
        assert(river.totalUnderlyingSupply() == 1100 ether);

        vm.prank(admin);
        river.depositToConsensusLayer(17);
        vm.prank(admin);
        river.depositToConsensusLayer(17);

        Operators.Operator memory op1 = operatorsRegistry.getOperator(operatorOneIndex);
        Operators.Operator memory op2 = operatorsRegistry.getOperator(operatorTwoIndex);

        assert(op1.funded == 17);
        assert(op2.funded == 17);

        assert(river.getDepositedValidatorCount() == 34);
        assert(river.totalUnderlyingSupply() == 1100 ether);
        assert(address(river).balance == (1000 ether + 100 ether) - (32 ether * 34));
        assert(river.balanceOfUnderlying(joe) == 100 ether);
        assert(river.balanceOfUnderlying(bob) == 1000 ether);

        vm.deal(address(elFeeRecipient), 34 * 1 ether);

        vm.startPrank(oracleMember);
        (uint256 epoch,,) = oracle.getCurrentFrame();
        vm.expectEmit(true, true, true, true);
        emit PulledELFees(34 * 1 ether);
        oracle.reportConsensusLayerData(epoch, 31 * 1e9 * 34, 34);
        vm.stopPrank();

        assert(address(elFeeRecipient).balance == 0);

        assert(river.totalUnderlyingSupply() == 1100 ether);
        assert(river.balanceOfUnderlying(joe) == 100 ether);
        assert(river.balanceOfUnderlying(bob) == 1000 ether);
        assert(river.balanceOfUnderlying(operatorOneFeeRecipient) == 0);
        assert(river.balanceOfUnderlying(operatorTwoFeeRecipient) == 0);
        assert(river.balanceOfUnderlying(collector) == 0);

        assert(
            river.totalSupply()
                == river.balanceOf(joe) + river.balanceOf(bob) + river.balanceOf(operatorOneFeeRecipient)
                    + river.balanceOf(operatorTwoFeeRecipient) + river.balanceOf(collector)
        );
    }

    function testELFeeRecipientPullFunds() public {
        vm.deal(joe, 100 ether);
        vm.deal(bob, 1000 ether);

        _allow(joe, LibAllowlistMasks.DEPOSIT_MASK);
        _allow(bob, LibAllowlistMasks.DEPOSIT_MASK);

        vm.startPrank(joe);
        river.deposit{value: 100 ether}();
        vm.stopPrank();
        vm.startPrank(bob);
        river.deposit{value: 1000 ether}();
        vm.stopPrank();
        assert(river.balanceOfUnderlying(joe) == 100 ether);
        assert(river.balanceOfUnderlying(bob) == 1000 ether);
        assert(river.getDepositedValidatorCount() == 0);
        assert(river.totalUnderlyingSupply() == 1100 ether);

        vm.prank(admin);
        river.depositToConsensusLayer(17);
        vm.prank(admin);
        river.depositToConsensusLayer(17);

        Operators.Operator memory op1 = operatorsRegistry.getOperator(operatorOneIndex);
        Operators.Operator memory op2 = operatorsRegistry.getOperator(operatorTwoIndex);

        assert(op1.funded == 17);
        assert(op2.funded == 17);

        assert(river.getDepositedValidatorCount() == 34);
        assert(river.totalUnderlyingSupply() == 1100 ether);
        assert(address(river).balance == (1000 ether + 100 ether) - (32 ether * 34));
        assert(river.balanceOfUnderlying(joe) == 100 ether);
        assert(river.balanceOfUnderlying(bob) == 1000 ether);

        vm.deal(address(elFeeRecipient), 100 ether);

        vm.startPrank(oracleMember);
        (uint256 epoch,,) = oracle.getCurrentFrame();
        oracle.reportConsensusLayerData(epoch, 33 * 1e9 * 34, 34);
        vm.stopPrank();

        assert(address(elFeeRecipient).balance == 0); // first ever report allows big balance delta

        assert(river.totalUnderlyingSupply() == 1100 ether - (34 * 32 ether) + (34 * 33 ether) + 100 ether);
        assert(river.balanceOfUnderlying(joe) == 111572727272727272727);
        assert(river.balanceOfUnderlying(bob) == 1115727272727272727273);
        assert(river.balanceOfUnderlying(operatorOneFeeRecipient) == 0);
        assert(river.balanceOfUnderlying(operatorTwoFeeRecipient) == 0);
        assert(river.balanceOfUnderlying(collector) == 6699999999999999999);

        vm.startPrank(joe);
        river.transfer(bob, river.balanceOf(joe) - 1);
        vm.stopPrank();

        assert(river.balanceOfUnderlying(joe) == 1);
        assert(river.balanceOfUnderlying(bob) == 1227299999999999999999);
        assert(river.balanceOfUnderlying(operatorOneFeeRecipient) == 0);
        assert(river.balanceOfUnderlying(operatorTwoFeeRecipient) == 0);
        assert(river.balanceOfUnderlying(collector) == 6699999999999999999);

        assert(
            river.totalSupply()
                == river.balanceOf(joe) + river.balanceOf(bob) + river.balanceOf(operatorOneFeeRecipient)
                    + river.balanceOf(operatorTwoFeeRecipient) + river.balanceOf(collector)
        );
    }

    function testELFeeRecipientPullFundsAfterFirstReport() public {
        vm.deal(joe, 100 ether);
        vm.deal(bob, 1000 ether);

        _allow(joe, LibAllowlistMasks.DEPOSIT_MASK);
        _allow(bob, LibAllowlistMasks.DEPOSIT_MASK);

        vm.startPrank(joe);
        river.deposit{value: 100 ether}();
        vm.stopPrank();
        vm.startPrank(bob);
        river.deposit{value: 1000 ether}();
        vm.stopPrank();
        assert(river.balanceOfUnderlying(joe) == 100 ether);
        assert(river.balanceOfUnderlying(bob) == 1000 ether);
        assert(river.getDepositedValidatorCount() == 0);
        assert(river.totalUnderlyingSupply() == 1100 ether);

        vm.prank(admin);
        river.depositToConsensusLayer(17);
        vm.prank(admin);
        river.depositToConsensusLayer(17);

        Operators.Operator memory op1 = operatorsRegistry.getOperator(operatorOneIndex);
        Operators.Operator memory op2 = operatorsRegistry.getOperator(operatorTwoIndex);

        assert(op1.funded == 17);
        assert(op2.funded == 17);

        assert(river.getDepositedValidatorCount() == 34);
        assert(river.totalUnderlyingSupply() == 1100 ether);
        assert(address(river).balance == (1000 ether + 100 ether) - (32 ether * 34));
        assert(river.balanceOfUnderlying(joe) == 100 ether);
        assert(river.balanceOfUnderlying(bob) == 1000 ether);

        vm.startPrank(oracleMember);
        (uint256 epoch,,) = oracle.getCurrentFrame();
        oracle.reportConsensusLayerData(epoch, 32 * 1e9 * 34, 34);
        vm.stopPrank();

        assert(river.getDepositedValidatorCount() == 34);
        assert(river.totalUnderlyingSupply() == 1100 ether);
        assert(address(river).balance == (1000 ether + 100 ether) - (32 ether * 34));
        assert(river.balanceOfUnderlying(joe) == 100 ether);
        assert(river.balanceOfUnderlying(bob) == 1000 ether);

        vm.warp(block.timestamp + 1 days);

        uint256 maxPulledFees = (1100 ether * 10 * 1 days) / uint256(100 * 365 days);
        vm.deal(address(elFeeRecipient), maxPulledFees);

        vm.startPrank(oracleMember);
        (epoch,,) = oracle.getCurrentFrame();
        oracle.reportConsensusLayerData(epoch, 32 * 1e9 * 34, 34);
        vm.stopPrank();

        assert(address(elFeeRecipient).balance == 0); //not first report, so upperBound is sane

        assert(river.totalUnderlyingSupply() == 1100 ether + maxPulledFees);
        assert(river.balanceOfUnderlying(joe) == 100026027397260273972);
        assert(river.balanceOfUnderlying(bob) == 1000260273972602739725);
        assert(river.balanceOfUnderlying(operatorOneFeeRecipient) == 0);
        assert(river.balanceOfUnderlying(operatorTwoFeeRecipient) == 0);
        assert(river.balanceOfUnderlying(collector) == 15068493150684931);

        assert(
            river.totalSupply()
                == river.balanceOf(joe) + river.balanceOf(bob) + river.balanceOf(operatorOneFeeRecipient)
                    + river.balanceOf(operatorTwoFeeRecipient) + river.balanceOf(collector)
        );
    }

    function testCoverageFundPullFundsAfterFirstReport() public {
        vm.deal(joe, 100 ether);
        vm.deal(bob, 1000 ether);

        _allow(joe, LibAllowlistMasks.DEPOSIT_MASK + LibAllowlistMasks.DONATE_MASK);
        _allow(bob, LibAllowlistMasks.DEPOSIT_MASK);

        vm.startPrank(joe);
        river.deposit{value: 100 ether}();
        vm.stopPrank();
        vm.startPrank(bob);
        river.deposit{value: 1000 ether}();
        vm.stopPrank();
        assert(river.balanceOfUnderlying(joe) == 100 ether);
        assert(river.balanceOfUnderlying(bob) == 1000 ether);
        assert(river.getDepositedValidatorCount() == 0);
        assert(river.totalUnderlyingSupply() == 1100 ether);

        vm.prank(admin);
        river.depositToConsensusLayer(17);
        vm.prank(admin);
        river.depositToConsensusLayer(17);

        Operators.Operator memory op1 = operatorsRegistry.getOperator(operatorOneIndex);
        Operators.Operator memory op2 = operatorsRegistry.getOperator(operatorTwoIndex);

        assert(op1.funded == 17);
        assert(op2.funded == 17);

        assert(river.getDepositedValidatorCount() == 34);
        assert(river.totalUnderlyingSupply() == 1100 ether);
        assert(address(river).balance == (1000 ether + 100 ether) - (32 ether * 34));
        assert(river.balanceOfUnderlying(joe) == 100 ether);
        assert(river.balanceOfUnderlying(bob) == 1000 ether);

        vm.startPrank(oracleMember);
        (uint256 epoch,,) = oracle.getCurrentFrame();
        oracle.reportConsensusLayerData(epoch, 32 * 1e9 * 34, 34);
        vm.stopPrank();

        assert(river.getDepositedValidatorCount() == 34);
        assert(river.totalUnderlyingSupply() == 1100 ether);
        assert(address(river).balance == (1000 ether + 100 ether) - (32 ether * 34));
        assert(river.balanceOfUnderlying(joe) == 100 ether);
        assert(river.balanceOfUnderlying(bob) == 1000 ether);

        vm.warp(block.timestamp + 1 days);

        uint256 maxCoverageFunds = (1100 ether * 10 * 1 days) / uint256(100 * 365 days);
        vm.deal(joe, maxCoverageFunds);
        vm.prank(joe);
        coverageFund.donate{value: maxCoverageFunds}();

        assert(address(coverageFund).balance == maxCoverageFunds); //not first report, so upperBound is sane

        vm.startPrank(oracleMember);
        (epoch,,) = oracle.getCurrentFrame();
        oracle.reportConsensusLayerData(epoch, 32 * 1e9 * 34, 34);
        vm.stopPrank();

        assert(address(coverageFund).balance == 0); //not first report, so upperBound is sane

        assert(river.totalUnderlyingSupply() == 1100 ether + maxCoverageFunds);
        assert(river.balanceOfUnderlying(joe) == 100027397260273972602);
        assert(river.balanceOfUnderlying(bob) == 1000273972602739726027);
        assert(river.balanceOfUnderlying(operatorOneFeeRecipient) == 0);
        assert(river.balanceOfUnderlying(operatorTwoFeeRecipient) == 0);
        assert(river.balanceOfUnderlying(collector) == 0);

        assert(
            river.totalSupply()
                == river.balanceOf(joe) + river.balanceOf(bob) + river.balanceOf(operatorOneFeeRecipient)
                    + river.balanceOf(operatorTwoFeeRecipient) + river.balanceOf(collector)
        );
    }

    function testELFeeRecipientAndCoverageFundPullFundsAfterFirstReport() public {
        vm.deal(joe, 100 ether);
        vm.deal(bob, 1000 ether);

        _allow(joe, LibAllowlistMasks.DEPOSIT_MASK + LibAllowlistMasks.DONATE_MASK);
        _allow(bob, LibAllowlistMasks.DEPOSIT_MASK);

        vm.startPrank(joe);
        river.deposit{value: 100 ether}();
        vm.stopPrank();
        vm.startPrank(bob);
        river.deposit{value: 1000 ether}();
        vm.stopPrank();
        assert(river.balanceOfUnderlying(joe) == 100 ether);
        assert(river.balanceOfUnderlying(bob) == 1000 ether);
        assert(river.getDepositedValidatorCount() == 0);
        assert(river.totalUnderlyingSupply() == 1100 ether);

        vm.prank(admin);
        river.depositToConsensusLayer(17);
        vm.prank(admin);
        river.depositToConsensusLayer(17);

        Operators.Operator memory op1 = operatorsRegistry.getOperator(operatorOneIndex);
        Operators.Operator memory op2 = operatorsRegistry.getOperator(operatorTwoIndex);

        assert(op1.funded == 17);
        assert(op2.funded == 17);

        assert(river.getDepositedValidatorCount() == 34);
        assert(river.totalUnderlyingSupply() == 1100 ether);
        assert(address(river).balance == (1000 ether + 100 ether) - (32 ether * 34));
        assert(river.balanceOfUnderlying(joe) == 100 ether);
        assert(river.balanceOfUnderlying(bob) == 1000 ether);

        vm.startPrank(oracleMember);
        (uint256 epoch,,) = oracle.getCurrentFrame();
        oracle.reportConsensusLayerData(epoch, 32 * 1e9 * 34, 34);
        vm.stopPrank();

        assert(river.getDepositedValidatorCount() == 34);
        assert(river.totalUnderlyingSupply() == 1100 ether);
        assert(address(river).balance == (1000 ether + 100 ether) - (32 ether * 34));
        assert(river.balanceOfUnderlying(joe) == 100 ether);
        assert(river.balanceOfUnderlying(bob) == 1000 ether);

        vm.warp(block.timestamp + 1 days);

        uint256 maxPulledFees = (1100 ether * 10 * 1 days) / uint256(100 * 365 days);
        uint256 maxCoverageFunds = maxPulledFees / 2;
        maxPulledFees -= maxCoverageFunds;
        vm.deal(address(elFeeRecipient), maxPulledFees);
        vm.deal(joe, maxCoverageFunds);
        vm.prank(joe);
        coverageFund.donate{value: maxCoverageFunds}();

        assert(address(elFeeRecipient).balance == maxPulledFees); //not first report, so upperBound is sane
        assert(address(coverageFund).balance == maxCoverageFunds); //not first report, so upperBound is sane

        vm.startPrank(oracleMember);
        (epoch,,) = oracle.getCurrentFrame();
        oracle.reportConsensusLayerData(epoch, 32 * 1e9 * 34, 34);
        vm.stopPrank();

        assert(address(elFeeRecipient).balance == 0); //not first report, so upperBound is sane
        assert(address(coverageFund).balance == 0); //not first report, so upperBound is sane

        assert(river.totalUnderlyingSupply() == 1100 ether + maxPulledFees + maxCoverageFunds);
        assert(river.balanceOfUnderlying(joe) == 100026712328767123287);
        assert(river.balanceOfUnderlying(bob) == 1000267123287671232877);
        assert(river.balanceOfUnderlying(operatorOneFeeRecipient) == 0);
        assert(river.balanceOfUnderlying(operatorTwoFeeRecipient) == 0);
        assert(river.balanceOfUnderlying(collector) == 7534246575342465);

        assert(
            river.totalSupply()
                == river.balanceOf(joe) + river.balanceOf(bob) + river.balanceOf(operatorOneFeeRecipient)
                    + river.balanceOf(operatorTwoFeeRecipient) + river.balanceOf(collector)
        );
    }

    function testELFeeRecipientPullFundsAfterFirstReportNegativeDelta() public {
        vm.deal(joe, 100 ether);
        vm.deal(bob, 1000 ether);

        _allow(joe, LibAllowlistMasks.DEPOSIT_MASK);
        _allow(bob, LibAllowlistMasks.DEPOSIT_MASK);

        vm.startPrank(joe);
        river.deposit{value: 100 ether}();
        vm.stopPrank();
        vm.startPrank(bob);
        river.deposit{value: 1000 ether}();
        vm.stopPrank();
        assert(river.balanceOfUnderlying(joe) == 100 ether);
        assert(river.balanceOfUnderlying(bob) == 1000 ether);
        assert(river.getDepositedValidatorCount() == 0);
        assert(river.totalUnderlyingSupply() == 1100 ether);

        vm.prank(admin);
        river.depositToConsensusLayer(17);
        vm.prank(admin);
        river.depositToConsensusLayer(17);

        Operators.Operator memory op1 = operatorsRegistry.getOperator(operatorOneIndex);
        Operators.Operator memory op2 = operatorsRegistry.getOperator(operatorTwoIndex);

        assert(op1.funded == 17);
        assert(op2.funded == 17);

        assert(river.getDepositedValidatorCount() == 34);
        assert(river.totalUnderlyingSupply() == 1100 ether);
        assert(address(river).balance == (1000 ether + 100 ether) - (32 ether * 34));
        assert(river.balanceOfUnderlying(joe) == 100 ether);
        assert(river.balanceOfUnderlying(bob) == 1000 ether);

        vm.startPrank(oracleMember);
        (uint256 epoch,,) = oracle.getCurrentFrame();
        oracle.reportConsensusLayerData(epoch, 32 * 1e9 * 34, 34);
        vm.stopPrank();

        assert(river.getDepositedValidatorCount() == 34);
        assert(river.totalUnderlyingSupply() == 1100 ether);
        assert(address(river).balance == (1000 ether + 100 ether) - (32 ether * 34));
        assert(river.balanceOfUnderlying(joe) == 100 ether);
        assert(river.balanceOfUnderlying(bob) == 1000 ether);

        vm.warp(block.timestamp + 1 days);

        uint256 maxPulledFees = ((1100 ether * 10 * 1 days) / uint256(100 * 365 days));
        uint256 loss = 34 ether;
        vm.deal(address(elFeeRecipient), maxPulledFees + loss);

        vm.startPrank(oracleMember);
        (epoch,,) = oracle.getCurrentFrame();
        oracle.reportConsensusLayerData(epoch, 31 * 1e9 * 34, 34);
        vm.stopPrank();

        assert(address(elFeeRecipient).balance == 0); //not first report, so upperBound is sane

        assert(river.totalUnderlyingSupply() == 1100 ether + maxPulledFees);
        assert(river.balanceOfUnderlying(joe) == 100026027397260273972);
        assert(river.balanceOfUnderlying(bob) == 1000260273972602739725);
        assert(river.balanceOfUnderlying(operatorOneFeeRecipient) == 0);
        assert(river.balanceOfUnderlying(operatorTwoFeeRecipient) == 0);
        assert(river.balanceOfUnderlying(collector) == 15068493150684931);

        assert(
            river.totalSupply()
                == river.balanceOf(joe) + river.balanceOf(bob) + river.balanceOf(operatorOneFeeRecipient)
                    + river.balanceOf(operatorTwoFeeRecipient) + river.balanceOf(collector)
        );
    }

    function testELFeeRecipientPullSomeELFundsAfterFirstReport() public {
        vm.deal(joe, 100 ether);
        vm.deal(bob, 1000 ether);

        _allow(joe, LibAllowlistMasks.DEPOSIT_MASK);
        _allow(bob, LibAllowlistMasks.DEPOSIT_MASK);

        vm.startPrank(joe);
        river.deposit{value: 100 ether}();
        vm.stopPrank();
        vm.startPrank(bob);
        river.deposit{value: 1000 ether}();
        vm.stopPrank();
        assert(river.balanceOfUnderlying(joe) == 100 ether);
        assert(river.balanceOfUnderlying(bob) == 1000 ether);
        assert(river.getDepositedValidatorCount() == 0);
        assert(river.totalUnderlyingSupply() == 1100 ether);

        vm.prank(admin);
        river.depositToConsensusLayer(17);
        vm.prank(admin);
        river.depositToConsensusLayer(17);

        Operators.Operator memory op1 = operatorsRegistry.getOperator(operatorOneIndex);
        Operators.Operator memory op2 = operatorsRegistry.getOperator(operatorTwoIndex);

        assert(op1.funded == 17);
        assert(op2.funded == 17);

        assert(river.getDepositedValidatorCount() == 34);
        assert(river.totalUnderlyingSupply() == 1100 ether);
        assert(address(river).balance == (1000 ether + 100 ether) - (32 ether * 34));
        assert(river.balanceOfUnderlying(joe) == 100 ether);
        assert(river.balanceOfUnderlying(bob) == 1000 ether);

        vm.startPrank(oracleMember);
        (uint256 epoch,,) = oracle.getCurrentFrame();
        oracle.reportConsensusLayerData(epoch, 32 * 1e9 * 34, 34);
        vm.stopPrank();

        assert(river.getDepositedValidatorCount() == 34);
        assert(river.totalUnderlyingSupply() == 1100 ether);
        assert(address(river).balance == (1000 ether + 100 ether) - (32 ether * 34));
        assert(river.balanceOfUnderlying(joe) == 100 ether);
        assert(river.balanceOfUnderlying(bob) == 1000 ether);

        vm.warp(block.timestamp + 1 days);

        uint256 maxPulledFees = (1100 ether * 10 * 1 days) / uint256(100 * 365 days);
        uint256 netAmountPulled = maxPulledFees - (maxPulledFees / (2 * 1e9)) * 1e9;
        vm.deal(address(elFeeRecipient), netAmountPulled);

        vm.startPrank(oracleMember);
        (epoch,,) = oracle.getCurrentFrame();
        oracle.reportConsensusLayerData(epoch, 32 * 1e9 * 34 + uint64(maxPulledFees / (2 * 1e9)), 34);
        vm.stopPrank();

        assert(address(elFeeRecipient).balance == 0); //not first report, so upperBound is sane

        assert(river.totalUnderlyingSupply() == 1100 ether + maxPulledFees);
        assert(river.balanceOfUnderlying(joe) == 100026027397260273972);
        assert(river.balanceOfUnderlying(bob) == 1000260273972602739725);
        assert(river.balanceOfUnderlying(operatorOneFeeRecipient) == 0);
        assert(river.balanceOfUnderlying(operatorTwoFeeRecipient) == 0);
        assert(river.balanceOfUnderlying(collector) == 15068493150684931);

        assert(
            river.totalSupply()
                == river.balanceOf(joe) + river.balanceOf(bob) + river.balanceOf(operatorOneFeeRecipient)
                    + river.balanceOf(operatorTwoFeeRecipient) + river.balanceOf(collector)
        );
    }

    // Testing regular parameters
    function testNoELFeeRecipient() public {
        vm.deal(joe, 100 ether);
        vm.deal(bob, 1000 ether);

        _allow(joe, LibAllowlistMasks.DEPOSIT_MASK);
        _allow(bob, LibAllowlistMasks.DEPOSIT_MASK);

        vm.startPrank(joe);
        river.deposit{value: 100 ether}();
        vm.stopPrank();
        vm.startPrank(bob);
        river.deposit{value: 1000 ether}();
        vm.stopPrank();
        assert(river.balanceOfUnderlying(joe) == 100 ether);
        assert(river.balanceOfUnderlying(bob) == 1000 ether);
        assert(river.getDepositedValidatorCount() == 0);
        assert(river.totalUnderlyingSupply() == 1100 ether);

        vm.prank(admin);
        river.depositToConsensusLayer(17);
        vm.prank(admin);
        river.depositToConsensusLayer(17);

        Operators.Operator memory op1 = operatorsRegistry.getOperator(operatorOneIndex);
        Operators.Operator memory op2 = operatorsRegistry.getOperator(operatorTwoIndex);

        assert(op1.funded == 17);
        assert(op2.funded == 17);

        assert(river.getDepositedValidatorCount() == 34);
        assert(river.totalUnderlyingSupply() == 1100 ether);
        assert(address(river).balance == (1000 ether + 100 ether) - (32 ether * 34));
        assert(river.balanceOfUnderlying(joe) == 100 ether);
        assert(river.balanceOfUnderlying(bob) == 1000 ether);

        vm.deal(address(elFeeRecipient), 100 ether);

        vm.startPrank(admin);
        river.setELFeeRecipient(address(0));
        vm.stopPrank();

        vm.startPrank(oracleMember);
        (uint256 epoch,,) = oracle.getCurrentFrame();
        oracle.reportConsensusLayerData(epoch, 33 * 1e9 * 34, 34);
        vm.stopPrank();

        assert(address(elFeeRecipient).balance == 100 ether);

        assert(river.totalUnderlyingSupply() == 1100 ether - (34 * 32 ether) + (34 * 33 ether));
        assert(river.balanceOfUnderlying(joe) == 102936363636363636363);
        assert(river.balanceOfUnderlying(bob) == 1029363636363636363636);
        assert(river.balanceOfUnderlying(operatorOneFeeRecipient) == 0);
        assert(river.balanceOfUnderlying(operatorTwoFeeRecipient) == 0);
        assert(river.balanceOfUnderlying(collector) == 1699999999999999999);

        vm.startPrank(joe);
        river.transfer(bob, river.balanceOf(joe) - 1);
        vm.stopPrank();

        assert(river.balanceOfUnderlying(joe) == 1);
        assert(river.balanceOfUnderlying(bob) == 1132299999999999999999);
        assert(river.balanceOfUnderlying(operatorOneFeeRecipient) == 0);
        assert(river.balanceOfUnderlying(operatorTwoFeeRecipient) == 0);
        assert(river.balanceOfUnderlying(collector) == 1699999999999999999);

        assert(
            river.totalSupply()
                == river.balanceOf(joe) + river.balanceOf(bob) + river.balanceOf(operatorOneFeeRecipient)
                    + river.balanceOf(operatorTwoFeeRecipient) + river.balanceOf(collector)
        );
    }

    // Testing regular parameters
    function testUserDepositsForAnotherUser() public {
        vm.deal(bob, 1100 ether);
        vm.deal(joe, 100 ether);

        _allow(joe, LibAllowlistMasks.DEPOSIT_MASK);
        _allow(bob, LibAllowlistMasks.DEPOSIT_MASK);

        vm.startPrank(bob);
        river.depositAndTransfer{value: 100 ether}(joe);
        vm.stopPrank();
        vm.startPrank(bob);
        river.deposit{value: 1000 ether}();
        vm.stopPrank();
        assert(river.balanceOfUnderlying(joe) == 100 ether);
        assert(river.balanceOfUnderlying(bob) == 1000 ether);
        assert(river.getDepositedValidatorCount() == 0);
        assert(river.totalUnderlyingSupply() == 1100 ether);

        vm.prank(admin);
        river.depositToConsensusLayer(17);
        vm.prank(admin);
        river.depositToConsensusLayer(17);

        Operators.Operator memory op1 = operatorsRegistry.getOperator(operatorOneIndex);
        Operators.Operator memory op2 = operatorsRegistry.getOperator(operatorTwoIndex);

        assert(op1.funded == 17);
        assert(op2.funded == 17);

        assert(river.getDepositedValidatorCount() == 34);
        assert(river.totalUnderlyingSupply() == 1100 ether);
        assert(address(river).balance == (1000 ether + 100 ether) - (32 ether * 34));
        assert(river.balanceOfUnderlying(joe) == 100 ether);
        assert(river.balanceOfUnderlying(bob) == 1000 ether);

        vm.startPrank(oracleMember);
        (uint256 epoch,,) = oracle.getCurrentFrame();
        oracle.reportConsensusLayerData(epoch, 33 * 1e9 * 34, 34);
        vm.stopPrank();

        assert(river.totalUnderlyingSupply() == 1100 ether - (34 * 32 ether) + (34 * 33 ether));
        assert(river.balanceOfUnderlying(joe) == 102936363636363636363);
        assert(river.balanceOfUnderlying(bob) == 1029363636363636363636);
        assert(river.balanceOfUnderlying(collector) == 1699999999999999999);
        assert(river.balanceOfUnderlying(operatorOneFeeRecipient) == 0);
        assert(river.balanceOfUnderlying(operatorTwoFeeRecipient) == 0);

        vm.startPrank(joe);
        river.transfer(bob, river.balanceOf(joe) - 1);
        vm.stopPrank();

        assert(river.balanceOfUnderlying(joe) == 1);
        assert(river.balanceOfUnderlying(bob) == 1132299999999999999999);
        assert(river.balanceOfUnderlying(operatorOneFeeRecipient) == 0);
        assert(river.balanceOfUnderlying(operatorTwoFeeRecipient) == 0);
        assert(river.balanceOfUnderlying(collector) == 1699999999999999999);

        vm.startPrank(joe);
        river.transfer(bob, river.balanceOf(joe));
        river.depositAndTransfer{value: 100 ether}(bob);
        vm.stopPrank();

        assert(
            river.totalSupply()
                == river.balanceOf(joe) + river.balanceOf(bob) + river.balanceOf(operatorOneFeeRecipient)
                    + river.balanceOf(operatorTwoFeeRecipient) + river.balanceOf(collector)
        );
    }

    // Testing regular parameters
    function testDeniedUser() public {
        vm.deal(joe, 200 ether);
        vm.deal(bob, 1100 ether);

        _allow(joe, LibAllowlistMasks.DEPOSIT_MASK);
        _allow(bob, LibAllowlistMasks.DEPOSIT_MASK);

        vm.startPrank(joe);
        river.deposit{value: 100 ether}();
        vm.stopPrank();
        vm.startPrank(bob);
        river.deposit{value: 1000 ether}();
        vm.stopPrank();

        _deny(joe);
        vm.startPrank(joe);
        vm.expectRevert(abi.encodeWithSignature("Denied(address)", joe));
        river.deposit{value: 100 ether}();
        vm.stopPrank();

        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSignature("Denied(address)", joe));
        river.depositAndTransfer{value: 100 ether}(joe);
        vm.stopPrank();

        assert(river.balanceOfUnderlying(joe) == 100 ether);
        assert(river.balanceOfUnderlying(bob) == 1000 ether);
        assert(river.getDepositedValidatorCount() == 0);
        assert(river.totalUnderlyingSupply() == 1100 ether);

        vm.prank(admin);
        river.depositToConsensusLayer(17);
        vm.prank(admin);
        river.depositToConsensusLayer(17);

        Operators.Operator memory op1 = operatorsRegistry.getOperator(operatorOneIndex);
        Operators.Operator memory op2 = operatorsRegistry.getOperator(operatorTwoIndex);

        assert(op1.funded == 17);
        assert(op2.funded == 17);

        assert(river.getDepositedValidatorCount() == 34);
        assert(river.totalUnderlyingSupply() == 1100 ether);
        assert(address(river).balance == (1000 ether + 100 ether) - (32 ether * 34));
        assert(river.balanceOfUnderlying(joe) == 100 ether);
        assert(river.balanceOfUnderlying(bob) == 1000 ether);

        vm.startPrank(oracleMember);
        (uint256 epoch,,) = oracle.getCurrentFrame();
        oracle.reportConsensusLayerData(epoch, 33 * 1e9 * 34, 34);
        vm.stopPrank();

        assert(river.totalUnderlyingSupply() == 1100 ether - (34 * 32 ether) + (34 * 33 ether));
        assert(river.balanceOfUnderlying(joe) == 102936363636363636363);
        assert(river.balanceOfUnderlying(bob) == 1029363636363636363636);
        assert(river.balanceOfUnderlying(operatorOneFeeRecipient) == 0);
        assert(river.balanceOfUnderlying(operatorTwoFeeRecipient) == 0);
        assert(river.balanceOfUnderlying(collector) == 1699999999999999999);

        vm.startPrank(joe);
        uint256 joeBalance = river.balanceOf(joe);
        vm.expectRevert(abi.encodeWithSignature("Denied(address)", joe));
        river.transfer(bob, joeBalance - 1);
        vm.stopPrank();
    }

    // Testing regular parameters
    function testUserDepositsFullAllowance() public {
        vm.deal(joe, 100 ether);
        vm.deal(bob, 1000 ether);

        _allow(joe, LibAllowlistMasks.DEPOSIT_MASK);
        _allow(bob, LibAllowlistMasks.DEPOSIT_MASK);

        vm.startPrank(joe);
        river.deposit{value: 100 ether}();
        vm.stopPrank();
        vm.startPrank(bob);
        river.deposit{value: 1000 ether}();
        vm.stopPrank();
        assert(river.balanceOfUnderlying(joe) == 100 ether);
        assert(river.balanceOfUnderlying(bob) == 1000 ether);
        assert(river.getDepositedValidatorCount() == 0);
        assert(river.totalUnderlyingSupply() == 1100 ether);

        vm.prank(admin);
        river.depositToConsensusLayer(17);
        vm.prank(admin);
        river.depositToConsensusLayer(17);

        Operators.Operator memory op1 = operatorsRegistry.getOperator(operatorOneIndex);
        Operators.Operator memory op2 = operatorsRegistry.getOperator(operatorTwoIndex);

        assert(op1.funded == 17);
        assert(op2.funded == 17);

        assert(river.getDepositedValidatorCount() == 34);
        assert(river.totalUnderlyingSupply() == 1100 ether);
        assert(address(river).balance == (1000 ether + 100 ether) - (32 ether * 34));
        assert(river.balanceOfUnderlying(joe) == 100 ether);
        assert(river.balanceOfUnderlying(bob) == 1000 ether);

        vm.startPrank(oracleMember);
        (uint256 epoch,,) = oracle.getCurrentFrame();
        oracle.reportConsensusLayerData(epoch, 33 * 1e9 * 34, 34);
        vm.stopPrank();

        assert(river.totalUnderlyingSupply() == 1100 ether - (34 * 32 ether) + (34 * 33 ether));
        assert(river.balanceOfUnderlying(joe) == 102936363636363636363);
        assert(river.balanceOfUnderlying(bob) == 1029363636363636363636);
        assert(river.balanceOfUnderlying(operatorOneFeeRecipient) == 0);
        assert(river.balanceOfUnderlying(operatorTwoFeeRecipient) == 0);
        assert(river.balanceOfUnderlying(collector) == 1699999999999999999);

        vm.startPrank(joe);
        river.transfer(bob, 100 ether);
        vm.stopPrank();

        assert(river.balanceOfUnderlying(joe) == 0);
        assert(river.balanceOfUnderlying(bob) == 1132300000000000000000);
        assert(river.balanceOfUnderlying(operatorOneFeeRecipient) == 0);
        assert(river.balanceOfUnderlying(operatorTwoFeeRecipient) == 0);
        assert(river.balanceOfUnderlying(collector) == 1699999999999999999);

        assert(
            river.totalSupply()
                == river.balanceOf(joe) + river.balanceOf(bob) + river.balanceOf(operatorOneFeeRecipient)
                    + river.balanceOf(operatorTwoFeeRecipient) + river.balanceOf(collector)
        );
    }

    // Testing operator fee split with 10% fee on rewards
    function testUserDepositsTenPercentFee() public {
        vm.deal(joe, 100 ether);
        vm.deal(bob, 1000 ether);

        _allow(joe, LibAllowlistMasks.DEPOSIT_MASK);
        _allow(bob, LibAllowlistMasks.DEPOSIT_MASK);

        vm.startPrank(admin);
        river.setGlobalFee(1000);
        vm.stopPrank();

        vm.startPrank(joe);
        river.deposit{value: 100 ether}();
        vm.stopPrank();
        vm.startPrank(bob);
        river.deposit{value: 1000 ether}();
        vm.stopPrank();
        assert(river.balanceOfUnderlying(joe) == 100 ether);
        assert(river.balanceOfUnderlying(bob) == 1000 ether);
        assert(river.getDepositedValidatorCount() == 0);
        assert(river.totalUnderlyingSupply() == 1100 ether);

        vm.prank(admin);
        river.depositToConsensusLayer(17);
        vm.prank(admin);
        river.depositToConsensusLayer(17);

        Operators.Operator memory op1 = operatorsRegistry.getOperator(operatorOneIndex);
        Operators.Operator memory op2 = operatorsRegistry.getOperator(operatorTwoIndex);

        assert(op1.funded == 17);
        assert(op2.funded == 17);

        assert(river.getDepositedValidatorCount() == 34);
        assert(river.totalUnderlyingSupply() == 1100 ether);
        assert(address(river).balance == (1000 ether + 100 ether) - (32 ether * 34));
        assert(river.balanceOfUnderlying(joe) == 100 ether);
        assert(river.balanceOfUnderlying(bob) == 1000 ether);

        vm.startPrank(oracleMember);
        (uint256 epoch,,) = oracle.getCurrentFrame();
        oracle.reportConsensusLayerData(epoch, 33 * 1e9 * 34, 34);
        vm.stopPrank();

        assert(river.totalUnderlyingSupply() == 1100 ether - (34 * 32 ether) + (34 * 33 ether));
        assert(river.balanceOfUnderlying(joe) == 102781818181818181818);
        assert(river.balanceOfUnderlying(bob) == 1027818181818181818181);
        assert(river.balanceOfUnderlying(operatorOneFeeRecipient) == 0);
        assert(river.balanceOfUnderlying(operatorTwoFeeRecipient) == 0);
        assert(river.balanceOfUnderlying(collector) == 3399999999999999999);

        vm.startPrank(joe);
        river.transfer(bob, 100 ether);
        vm.stopPrank();

        assert(river.balanceOfUnderlying(joe) == 0);
        assert(river.balanceOfUnderlying(bob) == 1130600000000000000000);
        assert(river.balanceOfUnderlying(operatorOneFeeRecipient) == 0);
        assert(river.balanceOfUnderlying(operatorTwoFeeRecipient) == 0);
        assert(river.balanceOfUnderlying(collector) == 3399999999999999999);

        assert(
            river.totalSupply()
                == river.balanceOf(joe) + river.balanceOf(bob) + river.balanceOf(operatorOneFeeRecipient)
                    + river.balanceOf(operatorTwoFeeRecipient) + river.balanceOf(collector)
        );
    }

    // Testing operator fee split when operators have different validator counts, and how keys are selected
    // based on which operator has the lowest key count
    function testUserDepositsUnconventionalDeposits() public {
        vm.deal(joe, 100 ether);
        vm.deal(bob, 1000 ether);

        _allow(joe, LibAllowlistMasks.DEPOSIT_MASK);
        _allow(bob, LibAllowlistMasks.DEPOSIT_MASK);

        vm.startPrank(joe);
        river.deposit{value: 100 ether}();
        vm.stopPrank();
        vm.startPrank(bob);
        river.deposit{value: 1000 ether}();
        vm.stopPrank();
        assert(river.balanceOfUnderlying(joe) == 100 ether);
        assert(river.balanceOfUnderlying(bob) == 1000 ether);
        assert(river.getDepositedValidatorCount() == 0);
        assert(river.totalUnderlyingSupply() == 1100 ether);

        vm.prank(admin);
        river.depositToConsensusLayer(1);
        vm.prank(admin);
        river.depositToConsensusLayer(2);
        vm.prank(admin);
        river.depositToConsensusLayer(31);

        Operators.Operator memory op1 = operatorsRegistry.getOperator(operatorOneIndex);
        Operators.Operator memory op2 = operatorsRegistry.getOperator(operatorTwoIndex);

        assert(op1.funded == 17);
        assert(op2.funded == 17);

        assert(river.getDepositedValidatorCount() == 34);
        assert(river.totalUnderlyingSupply() == 1100 ether);
        assert(address(river).balance == (1000 ether + 100 ether) - (32 ether * 34));
        assert(river.balanceOfUnderlying(joe) == 100 ether);
        assert(river.balanceOfUnderlying(bob) == 1000 ether);

        vm.startPrank(oracleMember);
        (uint256 epoch,,) = oracle.getCurrentFrame();
        oracle.reportConsensusLayerData(epoch, 33 * 1e9 * 34, 34);
        vm.stopPrank();

        assert(river.totalUnderlyingSupply() == 1100 ether - (34 * 32 ether) + (34 * 33 ether));
        assert(river.balanceOfUnderlying(joe) == 102936363636363636363);
        assert(river.balanceOfUnderlying(bob) == 1029363636363636363636);
        assert(river.balanceOfUnderlying(operatorOneFeeRecipient) == 0);
        assert(river.balanceOfUnderlying(operatorTwoFeeRecipient) == 0);
        assert(river.balanceOfUnderlying(collector) == 1699999999999999999);

        vm.startPrank(joe);
        river.transfer(bob, 100 ether);
        vm.stopPrank();

        assert(river.balanceOfUnderlying(joe) == 0);
        assert(river.balanceOfUnderlying(bob) == 1132300000000000000000);
        assert(river.balanceOfUnderlying(operatorOneFeeRecipient) == 0);
        assert(river.balanceOfUnderlying(operatorTwoFeeRecipient) == 0);
        assert(river.balanceOfUnderlying(collector) == 1699999999999999999);

        assert(
            river.totalSupply()
                == river.balanceOf(joe) + river.balanceOf(bob) + river.balanceOf(operatorOneFeeRecipient)
                    + river.balanceOf(operatorTwoFeeRecipient) + river.balanceOf(collector)
        );
    }

    // Testing operator fee split when one operator has stopped validators
    function testUserDepositsOperatorWithStoppedValidators() public {
        vm.deal(joe, 100 ether);
        vm.deal(bob, 1000 ether);

        _allow(joe, LibAllowlistMasks.DEPOSIT_MASK);
        _allow(bob, LibAllowlistMasks.DEPOSIT_MASK);

        vm.startPrank(joe);
        river.deposit{value: 100 ether}();
        vm.stopPrank();
        vm.startPrank(bob);
        river.deposit{value: 1000 ether}();
        vm.stopPrank();
        assert(river.balanceOfUnderlying(joe) == 100 ether);
        assert(river.balanceOfUnderlying(bob) == 1000 ether);
        assert(river.getDepositedValidatorCount() == 0);
        assert(river.totalUnderlyingSupply() == 1100 ether);

        vm.prank(admin);
        river.depositToConsensusLayer(20);
        vm.startPrank(admin);
        operatorsRegistry.setOperatorStoppedValidatorCount(operatorOneIndex, 10);
        vm.stopPrank();
        vm.prank(admin);
        river.depositToConsensusLayer(10);

        Operators.Operator memory op1 = operatorsRegistry.getOperator(operatorOneIndex);
        Operators.Operator memory op2 = operatorsRegistry.getOperator(operatorTwoIndex);

        assert(op1.funded == 20);
        assert(op1.stopped == 10);
        assert(op2.funded == 10);

        assert(river.getDepositedValidatorCount() == 30);
        assert(river.totalUnderlyingSupply() == 1100 ether);
        assert(address(river).balance == (1000 ether + 100 ether) - (32 ether * 30));
        assert(river.balanceOfUnderlying(joe) == 100 ether);
        assert(river.balanceOfUnderlying(bob) == 1000 ether);

        vm.startPrank(oracleMember);
        (uint256 epoch,,) = oracle.getCurrentFrame();
        oracle.reportConsensusLayerData(epoch, 33 * 1e9 * 30, 30);
        vm.stopPrank();

        assert(river.totalUnderlyingSupply() == 1100 ether - (30 * 32 ether) + (30 * 33 ether));
        assert(river.balanceOfUnderlying(joe) == 102590909090909090909);
        assert(river.balanceOfUnderlying(bob) == 1025909090909090909091);
        assert(river.balanceOfUnderlying(operatorOneFeeRecipient) == 0);
        assert(river.balanceOfUnderlying(operatorTwoFeeRecipient) == 0);
        assert(river.balanceOfUnderlying(collector) == 1499999999999999999);

        vm.startPrank(joe);
        river.transfer(bob, 100 ether);
        vm.stopPrank();

        assert(river.balanceOfUnderlying(joe) == 0);
        assert(river.balanceOfUnderlying(bob) == 1128500000000000000000);
        assert(river.balanceOfUnderlying(operatorOneFeeRecipient) == 0);
        assert(river.balanceOfUnderlying(operatorTwoFeeRecipient) == 0);
        assert(river.balanceOfUnderlying(collector) == 1499999999999999999);

        assert(
            river.totalSupply()
                == river.balanceOf(joe) + river.balanceOf(bob) + river.balanceOf(operatorOneFeeRecipient)
                    + river.balanceOf(operatorTwoFeeRecipient) + river.balanceOf(collector)
        );
    }

    function testRiverFuzzing(uint96 joeBalance, uint96 bobBalance, uint32 increasePerValidator) public {
        vm.deal(joe, joeBalance);
        vm.deal(bob, bobBalance);

        _allow(joe, LibAllowlistMasks.DEPOSIT_MASK);
        _allow(bob, LibAllowlistMasks.DEPOSIT_MASK);

        vm.startPrank(joe);
        if (joeBalance == 0) {
            vm.expectRevert(abi.encodeWithSignature("EmptyDeposit()"));
        }
        river.deposit{value: joeBalance}();
        vm.stopPrank();
        vm.startPrank(bob);
        if (bobBalance == 0) {
            vm.expectRevert(abi.encodeWithSignature("EmptyDeposit()"));
        }
        river.deposit{value: bobBalance}();
        vm.stopPrank();
        assert(river.balanceOfUnderlying(joe) == joeBalance);
        assert(river.balanceOfUnderlying(bob) == bobBalance);
        assert(river.getDepositedValidatorCount() == 0);
        assert(river.totalUnderlyingSupply() == uint256(joeBalance) + uint256(bobBalance));

        uint256 validatorCount = river.totalUnderlyingSupply() / 32 ether;
        if (validatorCount > 0) {
            uint256 realValidatorCount = LibUint256.min(34, validatorCount);
            uint256 op2Validator;
            uint256 op1Validator;
            if (realValidatorCount > 5) {
                op2Validator =
                    ((realValidatorCount / 10) * 5) + ((realValidatorCount / 5) % 2 == 1 ? realValidatorCount % 5 : 0);
                op1Validator = realValidatorCount - op2Validator;
            } else {
                op1Validator = realValidatorCount;
            }

            vm.prank(admin);
            river.depositToConsensusLayer(realValidatorCount);

            Operators.Operator memory op1 = operatorsRegistry.getOperator(operatorOneIndex);
            Operators.Operator memory op2 = operatorsRegistry.getOperator(operatorTwoIndex);

            assert(op1.funded == op1Validator);
            assert(op2.funded == op2Validator);

            assert(river.getDepositedValidatorCount() == realValidatorCount);
            assert(river.totalUnderlyingSupply() == uint256(joeBalance) + uint256(bobBalance));
            assert(address(river).balance == river.totalUnderlyingSupply() - (32 ether * realValidatorCount));
            assert(river.balanceOfUnderlying(joe) == joeBalance);
            assert(river.balanceOfUnderlying(bob) == bobBalance);

            vm.startPrank(oracleMember);
            (uint256 epoch,,) = oracle.getCurrentFrame();
            oracle.reportConsensusLayerData(
                epoch,
                uint64(realValidatorCount) * (32 * 1e9 + uint64(increasePerValidator)),
                uint32(realValidatorCount)
            );
            vm.stopPrank();

            assert(
                river.totalUnderlyingSupply()
                    == uint256(joeBalance) + uint256(bobBalance) + (realValidatorCount * increasePerValidator * 1e9)
            );
        } else {
            vm.prank(admin);
            vm.expectRevert(abi.encodeWithSignature("NotEnoughFunds()"));
            river.depositToConsensusLayer(1);
        }
    }

    function _debugMaxIncrease(uint256 annualAprUpperBound, uint256 _prevTotalEth, uint256 _timeElapsed)
        internal
        pure
        returns (uint256)
    {
        return (_prevTotalEth * annualAprUpperBound * _timeElapsed) / uint256(10000 * 365 days);
    }

    function testRiverBoundsFuzzing(
        uint8 _initialValidatorCount,
        uint64 _delta,
        uint256 _upperBound,
        uint256 _lowerBound
    ) external {
        _initialValidatorCount = (_initialValidatorCount % 200) + 1;
        _upperBound = _upperBound % 10001;
        _lowerBound = _lowerBound % 5001;

        vm.prank(admin);
        oracle.setReportBounds(_upperBound, _lowerBound);

        vm.deal(joe, 32 ether * uint256(_initialValidatorCount));

        _allow(joe, LibAllowlistMasks.DEPOSIT_MASK);

        vm.prank(joe);
        river.deposit{value: 32 ether * uint256(_initialValidatorCount)}();

        vm.prank(admin);
        river.depositToConsensusLayer(_initialValidatorCount);

        uint64 totalBalanceReported = uint64((32 ether * uint256(_initialValidatorCount)) / 1 gwei);

        vm.startPrank(oracleMember);
        (uint256 epoch,,) = oracle.getCurrentFrame();
        oracle.reportConsensusLayerData(epoch, totalBalanceReported, _initialValidatorCount);
        vm.stopPrank();

        vm.warp(block.timestamp + 1 days);

        uint256 middle = type(uint64).max / 2;
        uint256 prevTotalEth = river.totalUnderlyingSupply();

        if (_delta > middle) {
            // balance increase
            uint256 innerDelta = _delta - middle;
            uint256 maxIncrease = _debugMaxIncrease(_upperBound, prevTotalEth, 1 days);
            uint256 increase = maxIncrease * innerDelta / (middle / 2);
            (epoch,,) = oracle.getCurrentFrame();

            if (innerDelta > middle / 2) {
                if (increase == 0) {
                    increase = 1 gwei;
                }
                vm.expectRevert(
                    abi.encodeWithSignature(
                        "TotalValidatorBalanceIncreaseOutOfBound(uint256,uint256,uint256,uint256)",
                        prevTotalEth,
                        prevTotalEth + (increase / 1 gwei) * 1 gwei,
                        1 days,
                        _upperBound
                    )
                );
                vm.prank(oracleMember);
                oracle.reportConsensusLayerData(
                    epoch, totalBalanceReported + uint64((increase / 1 gwei)), _initialValidatorCount
                );
            } else {
                uint256 elFeeRecipientBalance = maxIncrease - ((increase / 1 gwei) * 1 gwei);
                vm.deal(address(elFeeRecipient), elFeeRecipientBalance);
                vm.prank(oracleMember);
                oracle.reportConsensusLayerData(
                    epoch, totalBalanceReported + uint64((increase / 1 gwei)), _initialValidatorCount
                );
                assert(address(elFeeRecipient).balance == 0);
            }
        } else {
            // balance decrease
            uint256 decrease = (prevTotalEth * _lowerBound) / 10000;

            (epoch,,) = oracle.getCurrentFrame();

            if (_delta % 2 == 0) {
                decrease += 1 gwei; // we cross the max allowed decrease by the smallest possible amount
                vm.expectRevert(
                    abi.encodeWithSignature(
                        "TotalValidatorBalanceDecreaseOutOfBound(uint256,uint256,uint256,uint256)",
                        prevTotalEth,
                        prevTotalEth - (decrease / 1 gwei) * 1 gwei,
                        1 days,
                        _lowerBound
                    )
                );
                vm.prank(oracleMember);
                oracle.reportConsensusLayerData(
                    epoch, totalBalanceReported - uint64((decrease / 1 gwei)), _initialValidatorCount
                );
            } else {
                uint256 maxIncrease = _debugMaxIncrease(_upperBound, prevTotalEth, 1 days);
                uint256 elFeeRecipientBalance = maxIncrease + (decrease / 1 gwei) * 1 gwei;

                vm.deal(address(elFeeRecipient), elFeeRecipientBalance);
                vm.prank(oracleMember);
                oracle.reportConsensusLayerData(
                    epoch, totalBalanceReported - uint64((decrease / 1 gwei)), _initialValidatorCount
                );
                assert(address(elFeeRecipient).balance == 0);
            }
        }
    }

    function testRiverBoundsFuzzingWithCoverageFund(
        uint8 _initialValidatorCount,
        uint64 _delta,
        uint256 _upperBound,
        uint256 _lowerBound
    ) external {
        _initialValidatorCount = (_initialValidatorCount % 200) + 1;
        _upperBound = _upperBound % 10001;
        _lowerBound = _lowerBound % 5001;

        vm.prank(admin);
        oracle.setReportBounds(_upperBound, _lowerBound);

        vm.deal(joe, 32 ether * uint256(_initialValidatorCount));

        _allow(joe, LibAllowlistMasks.DEPOSIT_MASK + LibAllowlistMasks.DONATE_MASK);

        vm.prank(joe);
        river.deposit{value: 32 ether * uint256(_initialValidatorCount)}();

        vm.prank(admin);
        river.depositToConsensusLayer(_initialValidatorCount);

        uint64 totalBalanceReported = uint64((32 ether * uint256(_initialValidatorCount)) / 1 gwei);

        vm.startPrank(oracleMember);
        (uint256 epoch,,) = oracle.getCurrentFrame();
        oracle.reportConsensusLayerData(epoch, totalBalanceReported, _initialValidatorCount);
        vm.stopPrank();

        vm.warp(block.timestamp + 1 days);

        uint256 middle = type(uint64).max / 2;
        uint256 prevTotalEth = river.totalUnderlyingSupply();

        if (_delta > middle) {
            // balance increase
            uint256 innerDelta = _delta - middle;
            uint256 maxIncrease = _debugMaxIncrease(_upperBound, prevTotalEth, 1 days);
            uint256 increase = maxIncrease * innerDelta / (middle / 2);
            (epoch,,) = oracle.getCurrentFrame();

            if (innerDelta > middle / 2) {
                if (increase == 0) {
                    increase = 1 gwei;
                }
                vm.expectRevert(
                    abi.encodeWithSignature(
                        "TotalValidatorBalanceIncreaseOutOfBound(uint256,uint256,uint256,uint256)",
                        prevTotalEth,
                        prevTotalEth + (increase / 1 gwei) * 1 gwei,
                        1 days,
                        _upperBound
                    )
                );
                vm.prank(oracleMember);
                oracle.reportConsensusLayerData(
                    epoch, totalBalanceReported + uint64((increase / 1 gwei)), _initialValidatorCount
                );
            } else {
                {
                    uint256 elFeeRecipientBalance = (maxIncrease - ((increase / 1 gwei) * 1 gwei)) / 2;
                    vm.deal(address(elFeeRecipient), elFeeRecipientBalance);
                }
                {
                    uint256 coverageFundBalance = (maxIncrease - ((increase / 1 gwei) * 1 gwei))
                        - ((maxIncrease - ((increase / 1 gwei) * 1 gwei)) / 2);
                    vm.deal(joe, coverageFundBalance);
                    vm.prank(joe);
                    coverageFund.donate{value: coverageFundBalance}();
                }
                vm.prank(oracleMember);
                oracle.reportConsensusLayerData(
                    epoch, totalBalanceReported + uint64((increase / 1 gwei)), _initialValidatorCount
                );
                assert(address(elFeeRecipient).balance == 0);
                assert(address(coverageFund).balance == 0);
            }
        } else {
            // balance decrease
            uint256 decrease = (prevTotalEth * _lowerBound) / 10000;

            (epoch,,) = oracle.getCurrentFrame();

            if (_delta % 2 == 0) {
                decrease += 1 gwei; // we cross the max allowed decrease by the smallest possible amount
                vm.expectRevert(
                    abi.encodeWithSignature(
                        "TotalValidatorBalanceDecreaseOutOfBound(uint256,uint256,uint256,uint256)",
                        prevTotalEth,
                        prevTotalEth - (decrease / 1 gwei) * 1 gwei,
                        1 days,
                        _lowerBound
                    )
                );
                vm.prank(oracleMember);
                oracle.reportConsensusLayerData(
                    epoch, totalBalanceReported - uint64((decrease / 1 gwei)), _initialValidatorCount
                );
            } else {
                uint256 maxIncrease = _debugMaxIncrease(_upperBound, prevTotalEth, 1 days);
                {
                    uint256 elFeeRecipientBalance = maxIncrease + (decrease / 1 gwei) * 1 gwei / 2;
                    vm.deal(address(elFeeRecipient), elFeeRecipientBalance);
                }
                {
                    uint256 coverageFundBalance =
                        (maxIncrease + (decrease / 1 gwei) * 1 gwei) - (maxIncrease + (decrease / 1 gwei) * 1 gwei / 2);
                    vm.deal(joe, coverageFundBalance);
                    vm.prank(joe);
                    coverageFund.donate{value: coverageFundBalance}();
                }

                vm.prank(oracleMember);
                oracle.reportConsensusLayerData(
                    epoch, totalBalanceReported - uint64((decrease / 1 gwei)), _initialValidatorCount
                );
                assert(address(elFeeRecipient).balance == 0);
            }
        }
    }

    function testRiverUpperBoundsFuzzing(uint8 _initialValidatorCount, uint16 _upperBound) external {
        _initialValidatorCount = (_initialValidatorCount % 200) + 1;
        _upperBound = _upperBound % 10001;

        vm.prank(admin);
        oracle.setReportBounds(_upperBound, 500);

        vm.deal(joe, 32 ether * uint256(_initialValidatorCount));

        _allow(joe, LibAllowlistMasks.DEPOSIT_MASK);

        vm.prank(joe);
        river.deposit{value: 32 ether * uint256(_initialValidatorCount)}();

        vm.prank(admin);
        river.depositToConsensusLayer(_initialValidatorCount);

        uint64 totalBalanceReported = uint64((32 ether * uint256(_initialValidatorCount)) / 1 gwei);

        uint256 maxIncrease = _debugMaxIncrease(_upperBound, uint256(totalBalanceReported) * 1 gwei, 1 days);

        vm.deal(address(elFeeRecipient), maxIncrease);

        vm.startPrank(oracleMember);
        (uint256 epoch,,) = oracle.getCurrentFrame();
        oracle.reportConsensusLayerData(epoch, totalBalanceReported, _initialValidatorCount);
        vm.stopPrank();

        assert(address(elFeeRecipient).balance == 0);
    }
}
