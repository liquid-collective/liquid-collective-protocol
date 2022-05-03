//SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "./Vm.sol";
import "../src/Firewall.1.sol";
import "../src/River.1.sol";
import "../src/interfaces/IDepositContract.sol";
import "../src/Withdraw.1.sol";
import "../src/Oracle.1.sol";
import "./mocks/DepositContractMock.sol";
import "./mocks/RiverMock.sol";

contract FirewallV1Tests {
    RiverV1 internal river;
    FirewallV1 internal riverFirewall;
    RiverV1 internal firewalledRiver;
    IDepositContract internal deposit;
    WithdrawV1 internal withdraw;
    address internal proxyUpgraderDAO = address(0x484bCd65393c9E835a245Bfa3a299FA02fD1cb18);
    address internal riverGovernorDAO = address(0xEA674fdDe714fd979de3EdF0F56AA9716B898ec8);
    address internal executor = address(0xa22c003A45554Ce90E7F97a3f613F16905440468);
    address internal bob = address(0x34b4424f81AF11f8B8c261b339dd27e1Da796f11);
    address internal joe = address(0xA7206d878c5c3871826DfdB42191c49B1D11F466);
    address internal don = address(0xc99b2dBB74607A04B458Ea740F3906C4851C6531);
    address internal treasury = address(0xC88F7666330b4b511358b7742dC2a3234710e7B1);

    OracleV1 internal oracle;
    FirewallV1 internal oracleFirewall;
    OracleV1 internal firewalledOracle;
    IRiverOracleInput internal oracleInput;
    uint64 internal constant EPOCHS_PER_FRAME = 225;
    uint64 internal constant SLOTS_PER_EPOCH = 32;
    uint64 internal constant SECONDS_PER_SLOT = 12;
    uint64 internal constant GENESIS_TIME = 1606824023;
    uint256 internal constant UPPER_BOUND = 1000;
    uint256 internal constant LOWER_BOUND = 500;

    Vm internal vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    bytes internal unauthJoe = abi.encodeWithSignature("Unauthorized(address)", joe);
    bytes internal unauthExecutor = abi.encodeWithSignature("Unauthorized(address)", executor);

    function setUp() public {
        deposit = new DepositContractMock();
        withdraw = new WithdrawV1();
        bytes32 withdrawalCredentials = withdraw.getCredentials();
        river = new RiverV1();
        riverFirewall = new FirewallV1(riverGovernorDAO, executor, address(river));
        firewalledRiver = RiverV1(payable(address(riverFirewall)));
        river.initRiverV1(
            address(deposit),
            withdrawalCredentials,
            payable(address(riverFirewall)),
            payable(address(riverFirewall)),
            treasury,
            5000,
            50000
        );

        oracle = new OracleV1();
        oracleFirewall = new FirewallV1(riverGovernorDAO, executor, address(oracle));
        firewalledOracle = OracleV1(address(oracleFirewall));
        oracleInput = new RiverMock();
        oracle.initOracleV1(
            address(oracleInput),
            address(oracleFirewall),
            EPOCHS_PER_FRAME,
            SLOTS_PER_EPOCH,
            SECONDS_PER_SLOT,
            GENESIS_TIME,
            UPPER_BOUND,
            LOWER_BOUND
        );
    }

    function testGovernorCanAddOperator() public {
        vm.startPrank(riverGovernorDAO);
        firewalledRiver.addOperator("bob", bob);
        (int256 _operatorBobIndex, ) = river.getOperatorDetails("bob");
        assert(_operatorBobIndex >= 0);
        vm.stopPrank();
    }

    function testExecutorCannotAddOperator() public {
        vm.startPrank(executor);
        vm.expectRevert(unauthExecutor);
        firewalledRiver.addOperator("joe", joe);
        vm.stopPrank();
    }

    function testRandomCallerCannotAddOperator() public {
        vm.startPrank(joe);
        vm.expectRevert(unauthJoe);
        firewalledRiver.addOperator("joe", joe);
        vm.stopPrank();
    }

    function testGovernorCanSetGlobalFee() public {
        vm.startPrank(riverGovernorDAO);
        firewalledRiver.setGlobalFee(5);
        // no assert, just expect no revert - no easy way to check the actual fee value
        vm.stopPrank();
    }

    function testExecutorCannotSetGlobalFee() public {
        vm.startPrank(executor);
        vm.expectRevert(unauthExecutor);
        firewalledRiver.setGlobalFee(4);
        vm.stopPrank();
    }

    function testRandomCallerCannotSetGlobalFee() public {
        vm.startPrank(joe);
        vm.expectRevert(unauthJoe);
        firewalledRiver.setGlobalFee(3);
        vm.stopPrank();
    }

    function testGovernorCanSetOperatorsRewardShare() public {
        vm.startPrank(riverGovernorDAO);
        firewalledRiver.setOperatorRewardsShare(5);
        // no assert, just expect no revert - no easy way to check the actual rewards share value
        vm.stopPrank();
    }

    function testExecutorCannotSetOperatorsRewardShare() public {
        vm.startPrank(executor);
        vm.expectRevert(unauthExecutor);
        firewalledRiver.setOperatorRewardsShare(4);
        vm.stopPrank();
    }

    function testRandomCallerCannotSetOperatorsRewardShare() public {
        vm.startPrank(joe);
        vm.expectRevert(unauthJoe);
        firewalledRiver.setOperatorRewardsShare(3);
        vm.stopPrank();
    }

    function testGovernorCanSetAllower() public {
        vm.startPrank(riverGovernorDAO);
        firewalledRiver.setAllower(don);
        assert(river.getAllower() == don);
        vm.stopPrank();
    }

    function testExecutorCannotSetAllower() public {
        vm.startPrank(executor);
        vm.expectRevert(unauthExecutor);
        firewalledRiver.setAllower(joe);
        vm.stopPrank();
    }

    function testRandomCallerCannotSetAllower() public {
        vm.startPrank(joe);
        vm.expectRevert(unauthJoe);
        firewalledRiver.setAllower(joe);
        vm.stopPrank();
    }

    function haveGovernorAddOperatorBob() public returns (uint256 operatorBobIndex) {
        vm.startPrank(riverGovernorDAO);
        firewalledRiver.addOperator("bob", bob);
        (int256 _operatorBobIndex, ) = river.getOperatorDetails("bob");
        assert(_operatorBobIndex >= 0);
        vm.stopPrank();
        return (uint256(_operatorBobIndex));
    }

    function testGovernorCanSetOperatorStatus() public {
        uint256 operatorBobIndex = haveGovernorAddOperatorBob();
        vm.startPrank(riverGovernorDAO);
        firewalledRiver.setOperatorStatus(operatorBobIndex, true);
        assert(river.getOperator(operatorBobIndex).active == true);
        vm.stopPrank();
    }

    function testExecutorCanSetOperatorStatus() public {
        uint256 operatorBobIndex = haveGovernorAddOperatorBob();
        vm.startPrank(executor);
        firewalledRiver.setOperatorStatus(operatorBobIndex, false);
        assert(river.getOperator(operatorBobIndex).active == false);
        vm.stopPrank();
    }

    function testRandomCallerCannotSetOperatorStatus() public {
        uint256 operatorBobIndex = haveGovernorAddOperatorBob();
        vm.startPrank(joe);
        vm.expectRevert(unauthJoe);
        firewalledRiver.setOperatorStatus(operatorBobIndex, true);
        vm.stopPrank();
    }

    function testGovernorCanSetOperatorStoppedValidatorCount() public {
        uint256 operatorBobIndex = haveGovernorAddOperatorBob();
        // Assert this by expecting InvalidArgument, NOT Unauthorized
        vm.startPrank(riverGovernorDAO);
        vm.expectRevert(abi.encodeWithSignature("InvalidArgument()"));
        firewalledRiver.setOperatorStoppedValidatorCount(operatorBobIndex, 3);
        vm.stopPrank();
    }

    function testExecutorCanSetOperatorStoppedValidatorCount() public {
        uint256 operatorBobIndex = haveGovernorAddOperatorBob();
        // Assert this by expecting InvalidArgument, NOT Unauthorized
        vm.startPrank(executor);
        vm.expectRevert(abi.encodeWithSignature("InvalidArgument()"));
        firewalledRiver.setOperatorStoppedValidatorCount(operatorBobIndex, 3);
        vm.stopPrank();
    }

    function testRandomCallerCannotSetOperatorStoppedValidatorCount() public {
        uint256 operatorBobIndex = haveGovernorAddOperatorBob();
        vm.startPrank(joe);
        vm.expectRevert(unauthJoe);
        firewalledRiver.setOperatorStoppedValidatorCount(operatorBobIndex, 3);
        vm.stopPrank();
    }

    function testGovernorCanSetOperatorLimit() public {
        uint256 operatorBobIndex = haveGovernorAddOperatorBob();
        vm.startPrank(riverGovernorDAO);
        firewalledRiver.setOperatorLimit(operatorBobIndex, 13);
        assert(river.getOperator(operatorBobIndex).limit == 13);
        vm.stopPrank();
    }

    function testExecutorCanSetOperatorLimit() public {
        uint256 operatorBobIndex = haveGovernorAddOperatorBob();
        vm.startPrank(executor);
        firewalledRiver.setOperatorLimit(operatorBobIndex, 13);
        assert(river.getOperator(operatorBobIndex).limit == 13);
        vm.stopPrank();
    }

    function testRandomCallerCannotSetOperatorLimit() public {
        uint256 operatorBobIndex = haveGovernorAddOperatorBob();
        vm.startPrank(joe);
        vm.expectRevert(unauthJoe);
        firewalledRiver.setOperatorLimit(operatorBobIndex, 13);
        vm.stopPrank();
    }

    function testGovernorCanDepositToConsensusLayer() public {
        // Assert this by expecting NotEnoughFunds, NOT Unauthorized
        vm.startPrank(riverGovernorDAO);
        vm.expectRevert(abi.encodeWithSignature("NotEnoughFunds()"));
        firewalledRiver.depositToConsensusLayer(10);
        vm.stopPrank();
    }

    function testExecutorCanDepositToConsensusLayer() public {
        // Assert this by expecting NotEnoughFunds, NOT Unauthorized
        vm.startPrank(executor);
        vm.expectRevert(abi.encodeWithSignature("NotEnoughFunds()"));
        firewalledRiver.depositToConsensusLayer(10);
        vm.stopPrank();
    }

    function testRandomCallerCannotDepositToConsensusLayer() public {
        vm.startPrank(joe);
        vm.expectRevert(unauthJoe);
        firewalledRiver.depositToConsensusLayer(10);
        vm.stopPrank();
    }

    function testGovernorCanSetOracle() public {
        vm.startPrank(riverGovernorDAO);
        firewalledRiver.setOracle(don);
        assert(river.getOracle() == don);
        vm.stopPrank();
    }

    function testExecutorCanSetOracle() public {
        vm.startPrank(executor);
        firewalledRiver.setOracle(don);
        assert(river.getOracle() == don);
        vm.stopPrank();
    }

    function testRandomCallerCannotSetOracle() public {
        vm.startPrank(joe);
        vm.expectRevert(unauthJoe);
        firewalledRiver.setOracle(don);
        vm.stopPrank();
    }

    function testGovernorCanAddMember() public {
        vm.startPrank(riverGovernorDAO);
        firewalledOracle.addMember(bob);
        assert(oracle.isMember(bob));
        vm.stopPrank();
    }

    function testGovernorCanRemoveMember() public {
        vm.startPrank(riverGovernorDAO);
        firewalledOracle.addMember(bob);
        assert(oracle.isMember(bob));
        firewalledOracle.removeMember(bob);
        assert(!oracle.isMember(bob));
        vm.stopPrank();
    }

    function testExecutorCanAddMember() public {
        vm.startPrank(executor);
        firewalledOracle.addMember(bob);
        assert(oracle.isMember(bob));
        vm.stopPrank();
    }

    function testExecutorCanRemoveMember() public {
        vm.startPrank(executor);
        firewalledOracle.addMember(bob);
        assert(oracle.isMember(bob));
        firewalledOracle.removeMember(bob);
        assert(!oracle.isMember(bob));
        vm.stopPrank();
    }

    function testRandomCallerCannotAddMember() public {
        vm.startPrank(joe);
        vm.expectRevert(unauthJoe);
        firewalledOracle.addMember(bob);
        vm.stopPrank();
    }

    function testRandomCallerCannotRemoveMember() public {
        vm.startPrank(riverGovernorDAO);
        firewalledOracle.addMember(bob);
        assert(oracle.isMember(bob));
        vm.stopPrank();
        vm.startPrank(joe);
        vm.expectRevert(unauthJoe);
        firewalledOracle.removeMember(bob);
        vm.stopPrank();
    }

    function testGovernorCanSetQuorum() public {
        vm.startPrank(riverGovernorDAO);
        firewalledOracle.setQuorum(2);
        assert(oracle.getQuorum() == 2);
        vm.stopPrank();
    }

    function testExecutorCanSetQuorum() public {
        vm.startPrank(executor);
        firewalledOracle.setQuorum(2);
        assert(oracle.getQuorum() == 2);
        vm.stopPrank();
    }

    function testRandomCallerCannotSetQuorum() public {
        vm.startPrank(joe);
        vm.expectRevert(unauthJoe);
        firewalledOracle.setQuorum(2);
        vm.stopPrank();
    }

    function testGovernorCanSetBeaconSpec() public {
        vm.startPrank(riverGovernorDAO);
        firewalledOracle.setBeaconSpec(2, 3, 4, 5);
        assert(oracle.getBeaconSpec().epochsPerFrame == 2);
        vm.stopPrank();
    }

    function testExecutorCanSetBeaconSpec() public {
        vm.startPrank(executor);
        firewalledOracle.setBeaconSpec(2, 3, 4, 5);
        assert(oracle.getBeaconSpec().epochsPerFrame == 2);
        vm.stopPrank();
    }

    function testRandomCallerCannotSetBeaconSpec() public {
        vm.startPrank(joe);
        vm.expectRevert(unauthJoe);
        firewalledOracle.setBeaconSpec(2, 3, 4, 5);
        vm.stopPrank();
    }

    function testGovernorCanSetBeaconBounds() public {
        vm.startPrank(riverGovernorDAO);
        firewalledOracle.setBeaconBounds(2, 3);
        assert(oracle.getBeaconBounds().annualAprUpperBound == 2);
        vm.stopPrank();
    }

    function testExecutorCanSetBeaconBounds() public {
        vm.startPrank(executor);
        firewalledOracle.setBeaconBounds(2, 3);
        assert(oracle.getBeaconBounds().annualAprUpperBound == 2);
        vm.stopPrank();
    }

    function testRandomCallerCannotSetBeaconBounds() public {
        vm.startPrank(joe);
        vm.expectRevert(unauthJoe);
        firewalledOracle.setBeaconBounds(2, 3);
        vm.stopPrank();
    }

    /// @dev convert function sig, of form "functionName(arg1Type,arg2Type)", to the 4 bytes used in
    ///      a contract call, accessible at msg.sig
    function getSelector(string memory functionSig) internal pure returns (bytes4) {
        return bytes4(keccak256(bytes(functionSig)));
    }

    function testMakingFunctionGovernorOnly() public {
        // At first, both governor and executor can setOperatorStatus
        vm.startPrank(riverGovernorDAO);
        firewalledRiver.addOperator("bob", bob);
        (int256 _operatorBobIndex, ) = firewalledRiver.getOperatorDetails("bob");
        assert(_operatorBobIndex >= 0);
        uint256 operatorBobIndex = uint256(_operatorBobIndex);
        firewalledRiver.setOperatorStatus(operatorBobIndex, true);
        assert(river.getOperator(operatorBobIndex).active == true);
        vm.stopPrank();

        vm.startPrank(executor);
        firewalledRiver.setOperatorStatus(operatorBobIndex, false);
        assert(river.getOperator(operatorBobIndex).active == false);
        vm.stopPrank();

        // Then we make it governorOnly.
        // Assert governor can still call it, and executor now cannot.
        vm.startPrank(riverGovernorDAO);
        riverFirewall.permissionFunction(getSelector("setOperatorStatus(uint256,bool)"), false);
        firewalledRiver.setOperatorStatus(operatorBobIndex, true);
        assert(river.getOperator(operatorBobIndex).active == true);
        vm.stopPrank();
        vm.expectRevert(unauthExecutor);
        vm.startPrank(executor);
        firewalledRiver.setOperatorStatus(operatorBobIndex, false);
        vm.stopPrank();
    }

    function testMakingFunctionGovernorOrExecutor() public {
        vm.startPrank(riverGovernorDAO);
        riverFirewall.permissionFunction(getSelector("setAllower(address)"), true);
        vm.stopPrank();
        vm.startPrank(executor);
        firewalledRiver.setAllower(joe);
        assert(river.getAllower() == joe);
        vm.stopPrank();
    }

    function testExecutorCannotChangePermissions() public {
        vm.startPrank(executor);
        vm.expectRevert(unauthExecutor);
        riverFirewall.permissionFunction(getSelector("setGlobalFee(uint256)"), true);
        vm.stopPrank();
    }

    function testRandomCallerCannotChangePermissions() public {
        vm.startPrank(joe);
        vm.expectRevert(unauthJoe);
        riverFirewall.permissionFunction(getSelector("setOperatorStatus(uint256,bool)"), true);
        vm.stopPrank();
    }

    function testGovernorCanChangeGovernor() public {
        // Assert that governor can changeGovernor, and the new governor can
        // setAllower, a governorOnly action
        address newGovernorDAO = address(0xdF2a01F10f86A7cdd2EE10cf35B8ab62723096a6);
        vm.startPrank(riverGovernorDAO);
        riverFirewall.changeGovernor(newGovernorDAO);
        vm.stopPrank();
        vm.startPrank(newGovernorDAO);
        firewalledRiver.setAllower(joe);
        assert(river.getAllower() == joe);
        vm.stopPrank();
    }

    function testGovernorCanChangeExecutor() public {
        // Assert that governor can changeExecutor and the new executor can
        // setOracle, a governorOrExecutor action
        vm.startPrank(riverGovernorDAO);
        riverFirewall.changeExecutor(bob);
        vm.stopPrank();
        vm.startPrank(bob);
        firewalledRiver.setOracle(don);
        assert(river.getOracle() == don);
        vm.stopPrank();
    }

    function testExecutorCanChangeExecutor() public {
        // Assert that executor can changeExecutor and the new executor can
        // setOracle, a governorOrExecutor action
        vm.startPrank(executor);
        riverFirewall.changeExecutor(joe);
        vm.stopPrank();
        vm.startPrank(joe);
        firewalledRiver.setOracle(don);
        assert(river.getOracle() == don);
        vm.stopPrank();
    }

    function testExecutorCannotChangeGovernor() public {
        vm.startPrank(executor);
        vm.expectRevert(unauthExecutor);
        riverFirewall.changeGovernor(don);
        vm.stopPrank();
    }

    function testRandomCallerCannotChangeGovernor() public {
        vm.startPrank(joe);
        vm.expectRevert(unauthJoe);
        riverFirewall.changeGovernor(don);
        vm.stopPrank();
    }

    function testRandomCallerCannotChangeExecutor() public {
        vm.startPrank(joe);
        vm.expectRevert(unauthJoe);
        riverFirewall.changeExecutor(don);
        vm.stopPrank();
    }
}
