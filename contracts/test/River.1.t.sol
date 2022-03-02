//SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "./Vm.sol";
import "../src/River.1.sol";
import "../src/libraries/Errors.sol";
import "../src/interfaces/IDepositContract.sol";
import "../src/Withdraw.1.sol";
import "./utils/River.setup1.sol";

contract DepositContractMock is IDepositContract {
    event DepositEvent(bytes pubkey, bytes withdrawal_credentials, bytes amount, bytes signature, bytes index);

    uint256 internal counter;

    function to_little_endian_64(uint64 value) internal pure returns (bytes memory ret) {
        ret = new bytes(8);
        bytes8 bytesValue = bytes8(value);
        // Byteswapping during copying to bytes.
        ret[0] = bytesValue[7];
        ret[1] = bytesValue[6];
        ret[2] = bytesValue[5];
        ret[3] = bytesValue[4];
        ret[4] = bytesValue[3];
        ret[5] = bytesValue[2];
        ret[6] = bytesValue[1];
        ret[7] = bytesValue[0];
    }

    function deposit(
        bytes calldata pubkey,
        bytes calldata withdrawalCredentials,
        bytes calldata signature,
        bytes32
    ) external payable {
        emit DepositEvent(
            pubkey,
            withdrawalCredentials,
            to_little_endian_64(uint64(msg.value / 1 gwei)),
            signature,
            to_little_endian_64(uint64(counter))
        );
        counter += 1;
    }
}

contract RiverV1SetupOneTests {
    RiverV1 internal river;

    IDepositContract internal deposit;
    WithdrawV1 internal withdraw;
    Vm internal vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    address internal admin = address(0xEA674fdDe714fd979de3EdF0F56AA9716B898ec8);
    address internal treasury = address(0xC88F7666330b4b511358b7742dC2a3234710e7B1);
    address internal oracle = address(0xD97bF0222C8F4b21A4cedd9d6aC8e3269b099Eba);
    address internal allower = address(0x363ED97eebe06690625bf7b4e21c5B6540016366);

    address internal operatorOne = address(0x7fe52bbF4D779cA115231b604637d5f80bab2C40);
    string internal operatorOneName = "NodeMasters";
    address internal operatorTwo = address(0xb479DE67E0827Cc72bf5c1727e3bf6fe15007554);
    string internal operatorTwoName = "StakePros";

    address internal bob = address(0x34b4424f81AF11f8B8c261b339dd27e1Da796f11);
    address internal joe = address(0xA7206d878c5c3871826DfdB42191c49B1D11F466);

    function setUp() public {
        deposit = new DepositContractMock();
        withdraw = new WithdrawV1();
        bytes32 withdrawalCredentials = withdraw.getCredentials();
        river = new RiverV1();
        river.initRiverV1(address(deposit), withdrawalCredentials, admin, allower, treasury, 5000, 50000);
        vm.startPrank(admin);
        river.setOracle(oracle);

        // ===================

        river.addOperator(operatorOneName, operatorOne);
        river.addOperator(operatorTwoName, operatorTwo);

        (int256 _operatorOneIndex, ) = river.getOperatorDetails(operatorOneName);
        assert(_operatorOneIndex >= 0);
        uint256 operatorOneIndex = uint256(_operatorOneIndex);

        (int256 _operatorTwoIndex, ) = river.getOperatorDetails(operatorTwoName);
        assert(_operatorTwoIndex >= 0);
        uint256 operatorTwoIndex = uint256(_operatorTwoIndex);

        bytes memory op1PublicKeys = RiverSetupOne.getOperatorOnePublicKeys();
        bytes memory op1Signatures = RiverSetupOne.getOperatorOneSignatures();

        river.addValidators(operatorOneIndex, 100, op1PublicKeys, op1Signatures);
        river.setOperatorLimit(operatorOneIndex, 100);

        bytes memory op2PublicKeys = RiverSetupOne.getOperatorTwoPublicKeys();
        bytes memory op2Signatures = RiverSetupOne.getOperatorTwoSignatures();

        river.addValidators(operatorTwoIndex, 100, op2PublicKeys, op2Signatures);
        river.setOperatorLimit(operatorTwoIndex, 100);
    }

    function testAdditionalInit() public {
        bytes32 withdrawalCredentials = withdraw.getCredentials();
        vm.startPrank(admin);
        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization(uint256,uint256)", 0, 1));
        river.initRiverV1(address(deposit), withdrawalCredentials, admin, allower, treasury, 5000, 50000);
        vm.stopPrank();
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

    function testUnauthorizedDeposit() public {
        vm.deal(joe, 100 ether);

        vm.startPrank(joe);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", joe));
        river.deposit{value: 100 ether}(address(0));
    }

    // Testing regular parameters
    function testUserDeposits() public {
        vm.deal(joe, 100 ether);
        vm.deal(bob, 1000 ether);

        vm.startPrank(admin);
        river.allow(joe, true);
        river.allow(bob, true);
        vm.stopPrank();

        vm.startPrank(joe);
        river.deposit{value: 100 ether}(address(0));
        vm.stopPrank();
        vm.startPrank(bob);
        river.deposit{value: 1000 ether}(address(0));
        vm.stopPrank();
        assert(river.balanceOf(joe) == 100 ether);
        assert(river.balanceOf(bob) == 1000 ether);
        assert(river.getDepositedValidatorCount() == 0);
        assert(river.totalSupply() == 1100 ether);

        river.depositToConsensusLayer(17);
        river.depositToConsensusLayer(17);

        Operators.Operator memory op1 = river.getOperatorByName(operatorOneName);
        Operators.Operator memory op2 = river.getOperatorByName(operatorTwoName);

        assert(op1.funded == 17);
        assert(op2.funded == 17);

        assert(river.getDepositedValidatorCount() == 34);
        assert(river.totalSupply() == 1100 ether);
        assert(address(river).balance == (1000 ether + 100 ether) - (32 ether * 34));
        assert(river.balanceOf(joe) == 100 ether);
        assert(river.balanceOf(bob) == 1000 ether);

        vm.startPrank(oracle);
        river.setBeaconData(34, 33 ether * 34, bytes32(0));
        vm.stopPrank();

        assert(river.totalSupply() == 1100 ether - (34 * 32 ether) + (34 * 33 ether));
        assert(river.balanceOf(joe) == 102936363636363636365);
        assert(river.balanceOf(bob) == 1029363636363636363659);
        assert(river.balanceOf(operatorOne) == 424999999999999987);
        assert(river.balanceOf(operatorTwo) == 424999999999999987);
        assert(river.balanceOf(treasury) == 850000000000000000);

        vm.startPrank(joe);
        river.transfer(bob, 102936363636363636365);
        vm.stopPrank();

        assert(river.balanceOf(joe) == 1);
        assert(river.balanceOf(bob) == 1132300000000000000023);
        assert(river.balanceOf(operatorOne) == 424999999999999987);
        assert(river.balanceOf(operatorTwo) == 424999999999999987);
        assert(river.balanceOf(treasury) == 850000000000000000);

        assert(
            river.totalShares() ==
                river.sharesOf(joe) +
                    river.sharesOf(bob) +
                    river.sharesOf(operatorOne) +
                    river.sharesOf(operatorTwo) +
                    river.sharesOf(treasury)
        );
    }

    // Testing operator fee split with 10% fee on rewards
    function testUserDepositsTenPercentFee() public {
        vm.deal(joe, 100 ether);
        vm.deal(bob, 1000 ether);

        vm.startPrank(admin);
        river.allow(joe, true);
        river.allow(bob, true);
        river.setGlobalFee(10000);
        vm.stopPrank();

        vm.startPrank(joe);
        river.deposit{value: 100 ether}(address(0));
        vm.stopPrank();
        vm.startPrank(bob);
        river.deposit{value: 1000 ether}(address(0));
        vm.stopPrank();
        assert(river.balanceOf(joe) == 100 ether);
        assert(river.balanceOf(bob) == 1000 ether);
        assert(river.getDepositedValidatorCount() == 0);
        assert(river.totalSupply() == 1100 ether);

        river.depositToConsensusLayer(17);
        river.depositToConsensusLayer(17);

        Operators.Operator memory op1 = river.getOperatorByName(operatorOneName);
        Operators.Operator memory op2 = river.getOperatorByName(operatorTwoName);

        assert(op1.funded == 17);
        assert(op2.funded == 17);

        assert(river.getDepositedValidatorCount() == 34);
        assert(river.totalSupply() == 1100 ether);
        assert(address(river).balance == (1000 ether + 100 ether) - (32 ether * 34));
        assert(river.balanceOf(joe) == 100 ether);
        assert(river.balanceOf(bob) == 1000 ether);

        vm.startPrank(oracle);
        river.setBeaconData(34, 33 ether * 34, bytes32(0));
        vm.stopPrank();

        assert(river.totalSupply() == 1100 ether - (34 * 32 ether) + (34 * 33 ether));
        assert(river.balanceOf(joe) == 102781818181818181818);
        assert(river.balanceOf(bob) == 1027818181818181818181);
        assert(river.balanceOf(operatorOne) == 849999999999999999);
        assert(river.balanceOf(operatorTwo) == 849999999999999999);
        assert(river.balanceOf(treasury) == 1700000000000000000);

        vm.startPrank(joe);
        river.transfer(bob, 102781818181818181818);
        vm.stopPrank();

        assert(river.balanceOf(joe) == 1);
        assert(river.balanceOf(bob) == 1130599999999999999999);
        assert(river.balanceOf(operatorOne) == 849999999999999999);
        assert(river.balanceOf(operatorTwo) == 849999999999999999);
        assert(river.balanceOf(treasury) == 1700000000000000000);

        assert(
            river.totalShares() ==
                river.sharesOf(joe) +
                    river.sharesOf(bob) +
                    river.sharesOf(operatorOne) +
                    river.sharesOf(operatorTwo) +
                    river.sharesOf(treasury)
        );
    }

    // Testing operator fee split when operators have different validator counts, and how keys are selected
    // based on which operator has the lowest key count
    function testUserDepositsUnconventionalDeposits() public {
        vm.deal(joe, 100 ether);
        vm.deal(bob, 1000 ether);

        vm.startPrank(admin);
        river.allow(joe, true);
        river.allow(bob, true);
        vm.stopPrank();

        vm.startPrank(joe);
        river.deposit{value: 100 ether}(address(0));
        vm.stopPrank();
        vm.startPrank(bob);
        river.deposit{value: 1000 ether}(address(0));
        vm.stopPrank();
        assert(river.balanceOf(joe) == 100 ether);
        assert(river.balanceOf(bob) == 1000 ether);
        assert(river.getDepositedValidatorCount() == 0);
        assert(river.totalSupply() == 1100 ether);

        river.depositToConsensusLayer(1);
        river.depositToConsensusLayer(2);
        river.depositToConsensusLayer(31);

        Operators.Operator memory op1 = river.getOperatorByName(operatorOneName);
        Operators.Operator memory op2 = river.getOperatorByName(operatorTwoName);

        assert(op1.funded == 32);
        assert(op2.funded == 2);

        assert(river.getDepositedValidatorCount() == 34);
        assert(river.totalSupply() == 1100 ether);
        assert(address(river).balance == (1000 ether + 100 ether) - (32 ether * 34));
        assert(river.balanceOf(joe) == 100 ether);
        assert(river.balanceOf(bob) == 1000 ether);

        vm.startPrank(oracle);
        river.setBeaconData(34, 33 ether * 34, bytes32(0));
        vm.stopPrank();

        assert(river.totalSupply() == 1100 ether - (34 * 32 ether) + (34 * 33 ether));
        assert(river.balanceOf(joe) == 102936363636363636365);
        assert(river.balanceOf(bob) == 1029363636363636363659);
        assert(river.balanceOf(operatorOne) == 799999999999999976);
        assert(river.balanceOf(operatorTwo) == 49999999999999998);
        assert(river.balanceOf(treasury) == 850000000000000000);

        vm.startPrank(joe);
        river.transfer(bob, 102936363636363636365);
        vm.stopPrank();

        assert(river.balanceOf(joe) == 1);
        assert(river.balanceOf(bob) == 1132300000000000000023);
        assert(river.balanceOf(operatorOne) == 799999999999999976);
        assert(river.balanceOf(operatorTwo) == 49999999999999998);
        assert(river.balanceOf(treasury) == 850000000000000000);

        assert(
            river.totalShares() ==
                river.sharesOf(joe) +
                    river.sharesOf(bob) +
                    river.sharesOf(operatorOne) +
                    river.sharesOf(operatorTwo) +
                    river.sharesOf(treasury)
        );
    }

    // Testing operator fee split when one operator has stopped validators
    function testUserDepositsOperatorWithStoppedValiadtors() public {
        vm.deal(joe, 100 ether);
        vm.deal(bob, 1000 ether);

        vm.startPrank(admin);
        river.allow(joe, true);
        river.allow(bob, true);
        (int256 _operatorOneIndex, ) = river.getOperatorDetails(operatorOneName);
        assert(_operatorOneIndex >= 0);
        uint256 operatorOneIndex = uint256(_operatorOneIndex);
        vm.stopPrank();

        vm.startPrank(joe);
        river.deposit{value: 100 ether}(address(0));
        vm.stopPrank();
        vm.startPrank(bob);
        river.deposit{value: 1000 ether}(address(0));
        vm.stopPrank();
        assert(river.balanceOf(joe) == 100 ether);
        assert(river.balanceOf(bob) == 1000 ether);
        assert(river.getDepositedValidatorCount() == 0);
        assert(river.totalSupply() == 1100 ether);

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
        assert(river.totalSupply() == 1100 ether);
        assert(address(river).balance == (1000 ether + 100 ether) - (32 ether * 30));
        assert(river.balanceOf(joe) == 100 ether);
        assert(river.balanceOf(bob) == 1000 ether);

        vm.startPrank(oracle);
        river.setBeaconData(30, 33 ether * 30, bytes32(0));
        vm.stopPrank();

        assert(river.totalSupply() == 1100 ether - (30 * 32 ether) + (30 * 33 ether));
        assert(river.balanceOf(joe) == 102590909090909090910);
        assert(river.balanceOf(bob) == 1025909090909090909105);
        assert(river.balanceOf(operatorOne) == 374999999999999991);
        assert(river.balanceOf(operatorTwo) == river.balanceOf(operatorOne));
        assert(river.balanceOf(treasury) == 750000000000000000);

        vm.startPrank(joe);
        river.transfer(bob, 102590909090909090910);
        vm.stopPrank();

        assert(river.balanceOf(joe) == 1);
        assert(river.balanceOf(bob) == 1128500000000000000014);
        assert(river.balanceOf(operatorOne) == 374999999999999991);
        assert(river.balanceOf(operatorTwo) == river.balanceOf(operatorOne));
        assert(river.balanceOf(treasury) == 750000000000000000);

        assert(
            river.totalShares() ==
                river.sharesOf(joe) +
                    river.sharesOf(bob) +
                    river.sharesOf(operatorOne) +
                    river.sharesOf(operatorTwo) +
                    river.sharesOf(treasury)
        );
    }

    function testRiverFuzzing(
        uint96 joeBalance,
        uint96 bobBalance,
        uint96 increasePerValidator
    ) public {
        vm.deal(joe, joeBalance);
        vm.deal(bob, bobBalance);

        vm.startPrank(admin);
        river.allow(joe, true);
        river.allow(bob, true);
        vm.stopPrank();

        vm.startPrank(joe);
        if (joeBalance == 0) {
            vm.expectRevert(abi.encodeWithSignature("EmptyDeposit()"));
        }
        river.deposit{value: joeBalance}(address(0));
        vm.stopPrank();
        vm.startPrank(bob);
        if (bobBalance == 0) {
            vm.expectRevert(abi.encodeWithSignature("EmptyDeposit()"));
        }
        river.deposit{value: bobBalance}(address(0));
        vm.stopPrank();
        assert(river.balanceOf(joe) == joeBalance);
        assert(river.balanceOf(bob) == bobBalance);
        assert(river.getDepositedValidatorCount() == 0);
        assert(river.totalSupply() == uint256(joeBalance) + uint256(bobBalance));

        uint256 validatorCount = river.totalSupply() / 32 ether;
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
            assert(river.totalSupply() == uint256(joeBalance) + uint256(bobBalance));
            assert(address(river).balance == river.totalSupply() - (32 ether * realValidatorCount));
            assert(river.balanceOf(joe) == joeBalance);
            assert(river.balanceOf(bob) == bobBalance);

            vm.startPrank(oracle);
            river.setBeaconData(
                realValidatorCount,
                realValidatorCount * (32 ether + uint256(increasePerValidator)),
                bytes32(0)
            );
            vm.stopPrank();

            assert(
                river.totalSupply() ==
                    uint256(joeBalance) + uint256(bobBalance) + (realValidatorCount * increasePerValidator)
            );
        } else {
            vm.expectRevert(abi.encodeWithSignature("NotEnoughFunds()"));
            river.depositToConsensusLayer(1);
        }
    }
}
