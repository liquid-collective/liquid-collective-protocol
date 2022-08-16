//SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "./Vm.sol";
import "../src/Allowlist.1.sol";
import "../src/River.1.sol";
import "../src/libraries/Errors.sol";
import "../src/interfaces/IDepositContract.sol";
import "../src/Withdraw.1.sol";
import "../src/Oracle.1.sol";
import "../src/ELFeeRecipient.1.sol";
import "./utils/AllowlistHelper.sol";
import "./utils/River.setup1.sol";
import "./utils/UserFactory.sol";
import "./mocks/DepositContractMock.sol";

contract RiverV1SetupOneTests {
    RiverV1 internal river;

    IDepositContract internal deposit;
    WithdrawV1 internal withdraw;
    Vm internal vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    address internal admin = address(0xEA674fdDe714fd979de3EdF0F56AA9716B898ec8);
    address internal newAdmin = address(0x52bc44d5378309EE2abF1539BF71dE1b7d7bE3b5);
    address internal treasury = address(0xC88F7666330b4b511358b7742dC2a3234710e7B1);
    address internal newTreasury = address(0x856D51b27701DB7d863264c9f2262327Ee3eD2d9);
    address internal allower = address(0x363ED97eebe06690625bf7b4e21c5B6540016366);
    address internal oracleMember = address(0xa3eCC095B592e88ebF1A9EC90817D3E2F362D7E3);
    OracleV1 internal oracle;
    ELFeeRecipientV1 internal elFeeRecipient;

    AllowlistV1 internal allowlist;
    address internal newAllowlist = address(0x00192Fb10dF37c9FB26829eb2CC623cd1BF599E8);

    address internal operatorOne = address(0x7fe52bbF4D779cA115231b604637d5f80bab2C40);
    address internal operatorOneFeeRecipient = address(0x4960b82Ab2fCD4Fa0ab0E52F72C06e95EDCd7360);
    string internal operatorOneName = "NodeMasters";
    address internal operatorTwo = address(0xb479DE67E0827Cc72bf5c1727e3bf6fe15007554);
    address internal operatorTwoFeeRecipient = address(0x892A5d1166C33a3571f01d7F407D678eb4E45805);
    string internal operatorTwoName = "StakePros";

    address internal bob = address(0x34b4424f81AF11f8B8c261b339dd27e1Da796f11);
    address internal joe = address(0xA7206d878c5c3871826DfdB42191c49B1D11F466);

    UserFactory internal uf = new UserFactory();

    uint256 internal constant DEPOSIT_MASK = 0x1;

    event PulledELFees(uint256 amount);

    function setUp() public {
        vm.warp(857034746);
        elFeeRecipient = new ELFeeRecipientV1();
        oracle = new OracleV1();
        allowlist = new AllowlistV1();
        allowlist.initAllowlistV1(admin, allower);
        deposit = new DepositContractMock();
        withdraw = new WithdrawV1();
        bytes32 withdrawalCredentials = withdraw.getCredentials();
        river = new RiverV1();
        elFeeRecipient.initELFeeRecipientV1(address(river));
        river.initRiverV1(
            address(deposit),
            address(elFeeRecipient),
            withdrawalCredentials,
            address(oracle),
            admin,
            address(allowlist),
            treasury,
            5000,
            50000
        );
        oracle.initOracleV1(address(river), admin, 225, 32, 12, 0, 1000, 500);
        vm.startPrank(admin);

        // ===================

        oracle.addMember(oracleMember);

        river.addOperator(operatorOneName, operatorOne, operatorOneFeeRecipient);
        river.addOperator(operatorTwoName, operatorTwo, operatorTwoFeeRecipient);

        (int256 _operatorOneIndex, ) = river.getOperatorDetails(operatorOneName);
        assert(_operatorOneIndex >= 0);
        uint256 operatorOneIndex = uint256(_operatorOneIndex);

        (int256 _operatorTwoIndex, ) = river.getOperatorDetails(operatorTwoName);
        assert(_operatorTwoIndex >= 0);
        uint256 operatorTwoIndex = uint256(_operatorTwoIndex);

        bytes memory op1PublicKeys = RiverSetupOne.getOperatorOnePublicKeys();
        bytes memory op1Signatures = RiverSetupOne.getOperatorOneSignatures();

        river.addValidators(operatorOneIndex, 100, op1PublicKeys, op1Signatures);

        bytes memory op2PublicKeys = RiverSetupOne.getOperatorTwoPublicKeys();
        bytes memory op2Signatures = RiverSetupOne.getOperatorTwoSignatures();

        river.addValidators(operatorTwoIndex, 100, op2PublicKeys, op2Signatures);

        uint256[] memory operatorIndexes = new uint256[](2);
        operatorIndexes[0] = operatorOneIndex;
        operatorIndexes[1] = operatorTwoIndex;
        uint256[] memory operatorLimits = new uint256[](2);
        operatorLimits[0] = 100;
        operatorLimits[1] = 100;

        river.setOperatorLimits(operatorIndexes, operatorLimits);
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
            5000,
            50000
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
            treasury,
            5000,
            50000
        );
        vm.stopPrank();
    }

    function testAcceptOwnerhshipUnauthorized() public {
        assert(river.getAdministrator() == admin);
        assert(river.getPendingAdministrator() == address(0));
        vm.startPrank(newAdmin);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", newAdmin));
        river.acceptOwnership();
        vm.stopPrank();
    }

    function testTransferAndAcceptOwnerhship() public {
        assert(river.getAdministrator() == admin);
        assert(river.getPendingAdministrator() == address(0));
        vm.startPrank(admin);
        river.transferOwnership(newAdmin);
        vm.stopPrank();
        assert(river.getAdministrator() == admin);
        assert(river.getPendingAdministrator() == newAdmin);
        vm.startPrank(newAdmin);
        river.acceptOwnership();
        vm.stopPrank();
        assert(river.getAdministrator() == newAdmin);
        assert(river.getPendingAdministrator() == address(0));
    }

    function testTransferOwnershipUnauthorized() public {
        vm.startPrank(newAdmin);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", newAdmin));
        river.transferOwnership(newAdmin);
        vm.stopPrank();
    }

    function testSetELFeeRecipient(uint256 _newELFeeRecipientSalt) public {
        address newELFeeRecipient = uf._new(_newELFeeRecipientSalt);
        vm.startPrank(admin);
        assert(river.getELFeeRecipient() == address(elFeeRecipient));
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

    function testSetTreasury() public {
        vm.startPrank(admin);
        assert(river.getTreasury() == treasury);
        river.setTreasury(newTreasury);
        assert(river.getTreasury() == newTreasury);
        vm.stopPrank();
    }

    function testSetTreasuryUnauthorized() public {
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", address(this)));
        river.setTreasury(newTreasury);
    }

    function testSetAllowlist() public {
        vm.startPrank(admin);
        assert(river.getAllowlist() == address(allowlist));
        river.setAllowlist(newAllowlist);
        assert(river.getAllowlist() == newAllowlist);
        vm.stopPrank();
    }

    function testSetAllowlistUnauthorized() public {
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", address(this)));
        river.setAllowlist(newAllowlist);
    }

    function testSetGlobalFeeHigherThanBase() public {
        vm.startPrank(admin);
        vm.expectRevert(abi.encodeWithSignature("InvalidArgument()"));
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
        assert(river.getAdministrator() == admin);
        vm.stopPrank();
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
        statuses[0] = 0x1 << 255; // DENY_MASK

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

        _allow(joe, DEPOSIT_MASK);
        _allow(bob, DEPOSIT_MASK);

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

        river.depositToConsensusLayer(17);
        river.depositToConsensusLayer(17);

        Operators.Operator memory op1 = river.getOperatorByName(operatorOneName);
        Operators.Operator memory op2 = river.getOperatorByName(operatorTwoName);

        assert(op1.funded == 17);
        assert(op2.funded == 17);

        assert(river.getDepositedValidatorCount() == 34);
        assert(river.totalUnderlyingSupply() == 1100 ether);
        assert(address(river).balance == (1000 ether + 100 ether) - (32 ether * 34));
        assert(river.balanceOfUnderlying(joe) == 100 ether);
        assert(river.balanceOfUnderlying(bob) == 1000 ether);

        vm.startPrank(oracleMember);
        (uint256 epoch, , ) = oracle.getCurrentFrame();
        oracle.reportBeacon(epoch, 33 * 1e9 * 34, 34);
        vm.stopPrank();

        assert(river.totalUnderlyingSupply() == 1100 ether - (34 * 32 ether) + (34 * 33 ether));
        assert(river.balanceOfUnderlying(joe) == 102936363636363636365);
        assert(river.balanceOfUnderlying(bob) == 1029363636363636363659);
        assert(river.balanceOfUnderlying(operatorOneFeeRecipient) == 424999999999999987);
        assert(river.balanceOfUnderlying(operatorTwoFeeRecipient) == 424999999999999987);
        assert(river.balanceOfUnderlying(treasury) == 850000000000000000);

        vm.startPrank(joe);
        river.transfer(bob, river.balanceOf(joe) - 1);
        vm.stopPrank();

        assert(river.balanceOfUnderlying(joe) == 1);
        assert(river.balanceOfUnderlying(bob) == 1132300000000000000023);
        assert(river.balanceOfUnderlying(operatorOneFeeRecipient) == 424999999999999987);
        assert(river.balanceOfUnderlying(operatorTwoFeeRecipient) == 424999999999999987);
        assert(river.balanceOfUnderlying(treasury) == 850000000000000000);

        assert(
            river.totalSupply() ==
                river.balanceOf(joe) +
                    river.balanceOf(bob) +
                    river.balanceOf(operatorOneFeeRecipient) +
                    river.balanceOf(operatorTwoFeeRecipient) +
                    river.balanceOf(treasury)
        );
    }

    function testValidatorsPenalties() public {
        vm.deal(joe, 100 ether);
        vm.deal(bob, 1000 ether);

        _allow(joe, DEPOSIT_MASK);
        _allow(bob, DEPOSIT_MASK);

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

        river.depositToConsensusLayer(17);
        river.depositToConsensusLayer(17);

        Operators.Operator memory op1 = river.getOperatorByName(operatorOneName);
        Operators.Operator memory op2 = river.getOperatorByName(operatorTwoName);

        assert(op1.funded == 17);
        assert(op2.funded == 17);

        assert(river.getDepositedValidatorCount() == 34);
        assert(river.totalUnderlyingSupply() == 1100 ether);
        assert(address(river).balance == (1000 ether + 100 ether) - (32 ether * 34));
        assert(river.balanceOfUnderlying(joe) == 100 ether);
        assert(river.balanceOfUnderlying(bob) == 1000 ether);

        vm.startPrank(oracleMember);
        (uint256 epoch, , ) = oracle.getCurrentFrame();
        oracle.reportBeacon(epoch, 31 * 1e9 * 34, 34);
        vm.stopPrank();

        assert(river.totalUnderlyingSupply() == 1100 ether - (34 * 32 ether) + (34 * 31 ether));
        assert(river.balanceOfUnderlying(joe) == 96909090909090909090);
        assert(river.balanceOfUnderlying(bob) == 969090909090909090909);
        assert(river.balanceOfUnderlying(operatorOneFeeRecipient) == 0);
        assert(river.balanceOfUnderlying(operatorTwoFeeRecipient) == 0);
        assert(river.balanceOfUnderlying(treasury) == 0);

        assert(
            river.totalSupply() ==
                river.balanceOf(joe) +
                    river.balanceOf(bob) +
                    river.balanceOf(operatorOneFeeRecipient) +
                    river.balanceOf(operatorTwoFeeRecipient) +
                    river.balanceOf(treasury)
        );
    }

    function testValidatorsPenaltiesEqualToExecLayerFees() public {
        vm.deal(joe, 100 ether);
        vm.deal(bob, 1000 ether);

        _allow(joe, DEPOSIT_MASK);
        _allow(bob, DEPOSIT_MASK);

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

        river.depositToConsensusLayer(17);
        river.depositToConsensusLayer(17);

        Operators.Operator memory op1 = river.getOperatorByName(operatorOneName);
        Operators.Operator memory op2 = river.getOperatorByName(operatorTwoName);

        assert(op1.funded == 17);
        assert(op2.funded == 17);

        assert(river.getDepositedValidatorCount() == 34);
        assert(river.totalUnderlyingSupply() == 1100 ether);
        assert(address(river).balance == (1000 ether + 100 ether) - (32 ether * 34));
        assert(river.balanceOfUnderlying(joe) == 100 ether);
        assert(river.balanceOfUnderlying(bob) == 1000 ether);

        vm.deal(address(elFeeRecipient), 34 * 1 ether);

        vm.startPrank(oracleMember);
        (uint256 epoch, , ) = oracle.getCurrentFrame();
        vm.expectEmit(true, true, true, true);
        emit PulledELFees(34 * 1 ether);
        oracle.reportBeacon(epoch, 31 * 1e9 * 34, 34);
        vm.stopPrank();

        assert(address(elFeeRecipient).balance == 0);

        assert(river.totalUnderlyingSupply() == 1100 ether);
        assert(river.balanceOfUnderlying(joe) == 100 ether);
        assert(river.balanceOfUnderlying(bob) == 1000 ether);
        assert(river.balanceOfUnderlying(operatorOneFeeRecipient) == 0);
        assert(river.balanceOfUnderlying(operatorTwoFeeRecipient) == 0);
        assert(river.balanceOfUnderlying(treasury) == 0);

        assert(
            river.totalSupply() ==
                river.balanceOf(joe) +
                    river.balanceOf(bob) +
                    river.balanceOf(operatorOneFeeRecipient) +
                    river.balanceOf(operatorTwoFeeRecipient) +
                    river.balanceOf(treasury)
        );
    }

    function testELFeeRecipientPullFunds() public {
        vm.deal(joe, 100 ether);
        vm.deal(bob, 1000 ether);

        _allow(joe, DEPOSIT_MASK);
        _allow(bob, DEPOSIT_MASK);

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

        river.depositToConsensusLayer(17);
        river.depositToConsensusLayer(17);

        Operators.Operator memory op1 = river.getOperatorByName(operatorOneName);
        Operators.Operator memory op2 = river.getOperatorByName(operatorTwoName);

        assert(op1.funded == 17);
        assert(op2.funded == 17);

        assert(river.getDepositedValidatorCount() == 34);
        assert(river.totalUnderlyingSupply() == 1100 ether);
        assert(address(river).balance == (1000 ether + 100 ether) - (32 ether * 34));
        assert(river.balanceOfUnderlying(joe) == 100 ether);
        assert(river.balanceOfUnderlying(bob) == 1000 ether);

        vm.deal(address(elFeeRecipient), 100 ether);

        vm.startPrank(oracleMember);
        (uint256 epoch, , ) = oracle.getCurrentFrame();
        oracle.reportBeacon(epoch, 33 * 1e9 * 34, 34);
        vm.stopPrank();

        assert(address(elFeeRecipient).balance == 0);

        assert(river.totalUnderlyingSupply() == 1100 ether - (34 * 32 ether) + (34 * 33 ether) + 100 ether);
        assert(river.balanceOfUnderlying(joe) == 111572727272727272727);
        assert(river.balanceOfUnderlying(bob) == 1115727272727272727273);
        assert(river.balanceOfUnderlying(operatorOneFeeRecipient) == 1674999999999999999);
        assert(river.balanceOfUnderlying(operatorTwoFeeRecipient) == 1674999999999999999);
        assert(river.balanceOfUnderlying(treasury) == 3349999999999999999);

        vm.startPrank(joe);
        river.transfer(bob, river.balanceOf(joe) - 1);
        vm.stopPrank();

        assert(river.balanceOfUnderlying(joe) == 1);
        assert(river.balanceOfUnderlying(bob) == 1227299999999999999999);
        assert(river.balanceOfUnderlying(operatorOneFeeRecipient) == 1674999999999999999);
        assert(river.balanceOfUnderlying(operatorTwoFeeRecipient) == 1674999999999999999);
        assert(river.balanceOfUnderlying(treasury) == 3349999999999999999);

        assert(
            river.totalSupply() ==
                river.balanceOf(joe) +
                    river.balanceOf(bob) +
                    river.balanceOf(operatorOneFeeRecipient) +
                    river.balanceOf(operatorTwoFeeRecipient) +
                    river.balanceOf(treasury)
        );
    }

    // Testing regular parameters
    function testNoELFeeRecipient() public {
        vm.deal(joe, 100 ether);
        vm.deal(bob, 1000 ether);

        _allow(joe, DEPOSIT_MASK);
        _allow(bob, DEPOSIT_MASK);

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

        river.depositToConsensusLayer(17);
        river.depositToConsensusLayer(17);

        Operators.Operator memory op1 = river.getOperatorByName(operatorOneName);
        Operators.Operator memory op2 = river.getOperatorByName(operatorTwoName);

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
        (uint256 epoch, , ) = oracle.getCurrentFrame();
        oracle.reportBeacon(epoch, 33 * 1e9 * 34, 34);
        vm.stopPrank();

        assert(address(elFeeRecipient).balance == 100 ether);

        assert(river.totalUnderlyingSupply() == 1100 ether - (34 * 32 ether) + (34 * 33 ether));
        assert(river.balanceOfUnderlying(joe) == 102936363636363636365);
        assert(river.balanceOfUnderlying(bob) == 1029363636363636363659);
        assert(river.balanceOfUnderlying(operatorOneFeeRecipient) == 424999999999999987);
        assert(river.balanceOfUnderlying(operatorTwoFeeRecipient) == 424999999999999987);
        assert(river.balanceOfUnderlying(treasury) == 850000000000000000);

        vm.startPrank(joe);
        river.transfer(bob, river.balanceOf(joe) - 1);
        vm.stopPrank();

        assert(river.balanceOfUnderlying(joe) == 1);
        assert(river.balanceOfUnderlying(bob) == 1132300000000000000023);
        assert(river.balanceOfUnderlying(operatorOneFeeRecipient) == 424999999999999987);
        assert(river.balanceOfUnderlying(operatorTwoFeeRecipient) == 424999999999999987);
        assert(river.balanceOfUnderlying(treasury) == 850000000000000000);

        assert(
            river.totalSupply() ==
                river.balanceOf(joe) +
                    river.balanceOf(bob) +
                    river.balanceOf(operatorOneFeeRecipient) +
                    river.balanceOf(operatorTwoFeeRecipient) +
                    river.balanceOf(treasury)
        );
    }

    // Testing regular parameters
    function testUserDepositsForAnotherUser() public {
        vm.deal(bob, 1100 ether);

        _allow(joe, DEPOSIT_MASK);
        _allow(bob, DEPOSIT_MASK);

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

        river.depositToConsensusLayer(17);
        river.depositToConsensusLayer(17);

        Operators.Operator memory op1 = river.getOperatorByName(operatorOneName);
        Operators.Operator memory op2 = river.getOperatorByName(operatorTwoName);

        assert(op1.funded == 17);
        assert(op2.funded == 17);

        assert(river.getDepositedValidatorCount() == 34);
        assert(river.totalUnderlyingSupply() == 1100 ether);
        assert(address(river).balance == (1000 ether + 100 ether) - (32 ether * 34));
        assert(river.balanceOfUnderlying(joe) == 100 ether);
        assert(river.balanceOfUnderlying(bob) == 1000 ether);

        vm.startPrank(oracleMember);
        (uint256 epoch, , ) = oracle.getCurrentFrame();
        oracle.reportBeacon(epoch, 33 * 1e9 * 34, 34);
        vm.stopPrank();

        assert(river.totalUnderlyingSupply() == 1100 ether - (34 * 32 ether) + (34 * 33 ether));
        assert(river.balanceOfUnderlying(joe) == 102936363636363636365);
        assert(river.balanceOfUnderlying(bob) == 1029363636363636363659);
        assert(river.balanceOfUnderlying(treasury) == 850000000000000000);
        assert(river.balanceOfUnderlying(operatorOneFeeRecipient) == 424999999999999987);
        assert(river.balanceOfUnderlying(operatorTwoFeeRecipient) == 424999999999999987);

        vm.startPrank(joe);
        river.transfer(bob, river.balanceOf(joe) - 1);
        vm.stopPrank();

        assert(river.balanceOfUnderlying(joe) == 1);
        assert(river.balanceOfUnderlying(bob) == 1132300000000000000023);
        assert(river.balanceOfUnderlying(operatorOneFeeRecipient) == 424999999999999987);
        assert(river.balanceOfUnderlying(operatorTwoFeeRecipient) == 424999999999999987);
        assert(river.balanceOfUnderlying(treasury) == 850000000000000000);

        assert(
            river.totalSupply() ==
                river.balanceOf(joe) +
                    river.balanceOf(bob) +
                    river.balanceOf(operatorOneFeeRecipient) +
                    river.balanceOf(operatorTwoFeeRecipient) +
                    river.balanceOf(treasury)
        );
    }

    // Testing regular parameters
    function testDeniedUser() public {
        vm.deal(joe, 200 ether);
        vm.deal(bob, 1100 ether);

        _allow(joe, DEPOSIT_MASK);
        _allow(bob, DEPOSIT_MASK);

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

        river.depositToConsensusLayer(17);
        river.depositToConsensusLayer(17);

        Operators.Operator memory op1 = river.getOperatorByName(operatorOneName);
        Operators.Operator memory op2 = river.getOperatorByName(operatorTwoName);

        assert(op1.funded == 17);
        assert(op2.funded == 17);

        assert(river.getDepositedValidatorCount() == 34);
        assert(river.totalUnderlyingSupply() == 1100 ether);
        assert(address(river).balance == (1000 ether + 100 ether) - (32 ether * 34));
        assert(river.balanceOfUnderlying(joe) == 100 ether);
        assert(river.balanceOfUnderlying(bob) == 1000 ether);

        vm.startPrank(oracleMember);
        (uint256 epoch, , ) = oracle.getCurrentFrame();
        oracle.reportBeacon(epoch, 33 * 1e9 * 34, 34);
        vm.stopPrank();

        assert(river.totalUnderlyingSupply() == 1100 ether - (34 * 32 ether) + (34 * 33 ether));
        assert(river.balanceOfUnderlying(joe) == 102936363636363636365);
        assert(river.balanceOfUnderlying(bob) == 1029363636363636363659);
        assert(river.balanceOfUnderlying(operatorOneFeeRecipient) == 424999999999999987);
        assert(river.balanceOfUnderlying(operatorTwoFeeRecipient) == 424999999999999987);
        assert(river.balanceOfUnderlying(treasury) == 850000000000000000);

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

        _allow(joe, DEPOSIT_MASK);
        _allow(bob, DEPOSIT_MASK);

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

        river.depositToConsensusLayer(17);
        river.depositToConsensusLayer(17);

        Operators.Operator memory op1 = river.getOperatorByName(operatorOneName);
        Operators.Operator memory op2 = river.getOperatorByName(operatorTwoName);

        assert(op1.funded == 17);
        assert(op2.funded == 17);

        assert(river.getDepositedValidatorCount() == 34);
        assert(river.totalUnderlyingSupply() == 1100 ether);
        assert(address(river).balance == (1000 ether + 100 ether) - (32 ether * 34));
        assert(river.balanceOfUnderlying(joe) == 100 ether);
        assert(river.balanceOfUnderlying(bob) == 1000 ether);

        vm.startPrank(oracleMember);
        (uint256 epoch, , ) = oracle.getCurrentFrame();
        oracle.reportBeacon(epoch, 33 * 1e9 * 34, 34);
        vm.stopPrank();

        assert(river.totalUnderlyingSupply() == 1100 ether - (34 * 32 ether) + (34 * 33 ether));
        assert(river.balanceOfUnderlying(joe) == 102936363636363636365);
        assert(river.balanceOfUnderlying(bob) == 1029363636363636363659);
        assert(river.balanceOfUnderlying(operatorOneFeeRecipient) == 424999999999999987);
        assert(river.balanceOfUnderlying(operatorTwoFeeRecipient) == 424999999999999987);
        assert(river.balanceOfUnderlying(treasury) == 850000000000000000);

        vm.startPrank(joe);
        river.transfer(bob, 100 ether);
        vm.stopPrank();

        assert(river.balanceOfUnderlying(joe) == 0);
        assert(river.balanceOfUnderlying(bob) == 1132300000000000000024);
        assert(river.balanceOfUnderlying(operatorOneFeeRecipient) == 424999999999999987);
        assert(river.balanceOfUnderlying(operatorTwoFeeRecipient) == 424999999999999987);
        assert(river.balanceOfUnderlying(treasury) == 850000000000000000);

        assert(
            river.totalSupply() ==
                river.balanceOf(joe) +
                    river.balanceOf(bob) +
                    river.balanceOf(operatorOneFeeRecipient) +
                    river.balanceOf(operatorTwoFeeRecipient) +
                    river.balanceOf(treasury)
        );
    }

    // Testing operator fee split with 10% fee on rewards
    function testUserDepositsTenPercentFee() public {
        vm.deal(joe, 100 ether);
        vm.deal(bob, 1000 ether);

        _allow(joe, DEPOSIT_MASK);
        _allow(bob, DEPOSIT_MASK);

        vm.startPrank(admin);
        river.setGlobalFee(10000);
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

        river.depositToConsensusLayer(17);
        river.depositToConsensusLayer(17);

        Operators.Operator memory op1 = river.getOperatorByName(operatorOneName);
        Operators.Operator memory op2 = river.getOperatorByName(operatorTwoName);

        assert(op1.funded == 17);
        assert(op2.funded == 17);

        assert(river.getDepositedValidatorCount() == 34);
        assert(river.totalUnderlyingSupply() == 1100 ether);
        assert(address(river).balance == (1000 ether + 100 ether) - (32 ether * 34));
        assert(river.balanceOfUnderlying(joe) == 100 ether);
        assert(river.balanceOfUnderlying(bob) == 1000 ether);

        vm.startPrank(oracleMember);
        (uint256 epoch, , ) = oracle.getCurrentFrame();
        oracle.reportBeacon(epoch, 33 * 1e9 * 34, 34);
        vm.stopPrank();

        assert(river.totalUnderlyingSupply() == 1100 ether - (34 * 32 ether) + (34 * 33 ether));
        assert(river.balanceOfUnderlying(joe) == 102781818181818181818);
        assert(river.balanceOfUnderlying(bob) == 1027818181818181818181);
        assert(river.balanceOfUnderlying(operatorOneFeeRecipient) == 849999999999999999);
        assert(river.balanceOfUnderlying(operatorTwoFeeRecipient) == 849999999999999999);
        assert(river.balanceOfUnderlying(treasury) == 1700000000000000000);

        vm.startPrank(joe);
        river.transfer(bob, 100 ether);
        vm.stopPrank();

        assert(river.balanceOfUnderlying(joe) == 0);
        assert(river.balanceOfUnderlying(bob) == 1130600000000000000000);
        assert(river.balanceOfUnderlying(operatorOneFeeRecipient) == 849999999999999999);
        assert(river.balanceOfUnderlying(operatorTwoFeeRecipient) == 849999999999999999);
        assert(river.balanceOfUnderlying(treasury) == 1700000000000000000);

        assert(
            river.totalSupply() ==
                river.balanceOf(joe) +
                    river.balanceOf(bob) +
                    river.balanceOf(operatorOneFeeRecipient) +
                    river.balanceOf(operatorTwoFeeRecipient) +
                    river.balanceOf(treasury)
        );
    }

    // Testing operator fee split when operators have different validator counts, and how keys are selected
    // based on which operator has the lowest key count
    function testUserDepositsUnconventionalDeposits() public {
        vm.deal(joe, 100 ether);
        vm.deal(bob, 1000 ether);

        _allow(joe, DEPOSIT_MASK);
        _allow(bob, DEPOSIT_MASK);

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

        river.depositToConsensusLayer(1);
        river.depositToConsensusLayer(2);
        river.depositToConsensusLayer(31);

        Operators.Operator memory op1 = river.getOperatorByName(operatorOneName);
        Operators.Operator memory op2 = river.getOperatorByName(operatorTwoName);

        assert(op1.funded == 32);
        assert(op2.funded == 2);

        assert(river.getDepositedValidatorCount() == 34);
        assert(river.totalUnderlyingSupply() == 1100 ether);
        assert(address(river).balance == (1000 ether + 100 ether) - (32 ether * 34));
        assert(river.balanceOfUnderlying(joe) == 100 ether);
        assert(river.balanceOfUnderlying(bob) == 1000 ether);

        vm.startPrank(oracleMember);
        (uint256 epoch, , ) = oracle.getCurrentFrame();
        oracle.reportBeacon(epoch, 33 * 1e9 * 34, 34);
        vm.stopPrank();

        assert(river.totalUnderlyingSupply() == 1100 ether - (34 * 32 ether) + (34 * 33 ether));
        assert(river.balanceOfUnderlying(joe) == 102936363636363636365);
        assert(river.balanceOfUnderlying(bob) == 1029363636363636363659);
        assert(river.balanceOfUnderlying(operatorOneFeeRecipient) == 799999999999999976);
        assert(river.balanceOfUnderlying(operatorTwoFeeRecipient) == 49999999999999998);
        assert(river.balanceOfUnderlying(treasury) == 850000000000000000);

        vm.startPrank(joe);
        river.transfer(bob, 100 ether);
        vm.stopPrank();

        assert(river.balanceOfUnderlying(joe) == 0);
        assert(river.balanceOfUnderlying(bob) == 1132300000000000000024);
        assert(river.balanceOfUnderlying(operatorOneFeeRecipient) == 799999999999999976);
        assert(river.balanceOfUnderlying(operatorTwoFeeRecipient) == 49999999999999998);
        assert(river.balanceOfUnderlying(treasury) == 850000000000000000);

        assert(
            river.totalSupply() ==
                river.balanceOf(joe) +
                    river.balanceOf(bob) +
                    river.balanceOf(operatorOneFeeRecipient) +
                    river.balanceOf(operatorTwoFeeRecipient) +
                    river.balanceOf(treasury)
        );
    }

    // Testing operator fee split when one operator has stopped validators
    function testUserDepositsOperatorWithStoppedValiadtors() public {
        vm.deal(joe, 100 ether);
        vm.deal(bob, 1000 ether);

        _allow(joe, DEPOSIT_MASK);
        _allow(bob, DEPOSIT_MASK);

        vm.startPrank(admin);
        (int256 _operatorOneIndex, ) = river.getOperatorDetails(operatorOneName);
        assert(_operatorOneIndex >= 0);
        uint256 operatorOneIndex = uint256(_operatorOneIndex);
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

        river.depositToConsensusLayer(20);
        vm.startPrank(admin);
        river.setOperatorStoppedValidatorCount(operatorOneIndex, 10);
        vm.stopPrank();
        river.depositToConsensusLayer(10);

        Operators.Operator memory op1 = river.getOperatorByName(operatorOneName);
        Operators.Operator memory op2 = river.getOperatorByName(operatorTwoName);

        assert(op1.funded == 20);
        assert(op1.stopped == 10);
        assert(op2.funded == 10);

        assert(river.getDepositedValidatorCount() == 30);
        assert(river.totalUnderlyingSupply() == 1100 ether);
        assert(address(river).balance == (1000 ether + 100 ether) - (32 ether * 30));
        assert(river.balanceOfUnderlying(joe) == 100 ether);
        assert(river.balanceOfUnderlying(bob) == 1000 ether);

        vm.startPrank(oracleMember);
        (uint256 epoch, , ) = oracle.getCurrentFrame();
        oracle.reportBeacon(epoch, 33 * 1e9 * 30, 30);
        vm.stopPrank();

        assert(river.totalUnderlyingSupply() == 1100 ether - (30 * 32 ether) + (30 * 33 ether));
        assert(river.balanceOfUnderlying(joe) == 102590909090909090910);
        assert(river.balanceOfUnderlying(bob) == 1025909090909090909105);
        assert(river.balanceOfUnderlying(operatorOneFeeRecipient) == 374999999999999991);
        assert(
            river.balanceOfUnderlying(operatorTwoFeeRecipient) == river.balanceOfUnderlying(operatorOneFeeRecipient)
        );
        assert(river.balanceOfUnderlying(treasury) == 750000000000000000);

        vm.startPrank(joe);
        river.transfer(bob, 100 ether);
        vm.stopPrank();

        assert(river.balanceOfUnderlying(joe) == 0);
        assert(river.balanceOfUnderlying(bob) == 1128500000000000000015);
        assert(river.balanceOfUnderlying(operatorOneFeeRecipient) == 374999999999999991);
        assert(
            river.balanceOfUnderlying(operatorTwoFeeRecipient) == river.balanceOfUnderlying(operatorOneFeeRecipient)
        );
        assert(river.balanceOfUnderlying(treasury) == 750000000000000000);

        assert(
            river.totalSupply() ==
                river.balanceOf(joe) +
                    river.balanceOf(bob) +
                    river.balanceOf(operatorOneFeeRecipient) +
                    river.balanceOf(operatorTwoFeeRecipient) +
                    river.balanceOf(treasury)
        );
    }

    function testRiverFuzzing(
        uint96 joeBalance,
        uint96 bobBalance,
        uint32 increasePerValidator
    ) public {
        vm.deal(joe, joeBalance);
        vm.deal(bob, bobBalance);

        _allow(joe, DEPOSIT_MASK);
        _allow(bob, DEPOSIT_MASK);

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
            uint256 realValidatorCount = Uint256Lib.min(34, validatorCount);
            uint256 op1Validator = realValidatorCount / 2;
            uint256 op2Validator = op1Validator;
            if (op1Validator + op2Validator != realValidatorCount) {
                op1Validator += 1;
            }

            river.depositToConsensusLayer(op1Validator);
            if (op2Validator > 0) {
                river.depositToConsensusLayer(op2Validator);
            }

            Operators.Operator memory op1 = river.getOperatorByName(operatorOneName);
            Operators.Operator memory op2 = river.getOperatorByName(operatorTwoName);

            assert(op1.funded == op1Validator);
            assert(op2.funded == op2Validator);

            assert(river.getDepositedValidatorCount() == realValidatorCount);
            assert(river.totalUnderlyingSupply() == uint256(joeBalance) + uint256(bobBalance));
            assert(address(river).balance == river.totalUnderlyingSupply() - (32 ether * realValidatorCount));
            assert(river.balanceOfUnderlying(joe) == joeBalance);
            assert(river.balanceOfUnderlying(bob) == bobBalance);

            vm.startPrank(oracleMember);
            (uint256 epoch, , ) = oracle.getCurrentFrame();
            oracle.reportBeacon(
                epoch,
                uint64(realValidatorCount) * (32 * 1e9 + uint64(increasePerValidator)),
                uint32(realValidatorCount)
            );
            vm.stopPrank();

            assert(
                river.totalUnderlyingSupply() ==
                    uint256(joeBalance) + uint256(bobBalance) + (realValidatorCount * increasePerValidator * 1e9)
            );
        } else {
            vm.expectRevert(abi.encodeWithSignature("NotEnoughFunds()"));
            river.depositToConsensusLayer(1);
        }
    }
}
