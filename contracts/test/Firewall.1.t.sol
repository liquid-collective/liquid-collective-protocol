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
        riverFirewall = new FirewallV1(
            riverGovernorDAO,
            executor,
            address(river)
        );
        firewalledRiver = RiverV1(payable(address(riverFirewall)));
        firewalledRiver.initRiverV1(
            address(deposit),
            withdrawalCredentials,
            payable(address(riverFirewall)),
            payable(address(riverFirewall)),
            treasury,
            5000,
            50000
        );

        oracle = new OracleV1();
        oracleFirewall = new FirewallV1(
            riverGovernorDAO,
            executor,
            address(oracle)
        );
        firewalledOracle = OracleV1(address(oracleFirewall));
        oracleInput = new RiverMock();
        firewalledOracle.initOracleV1(
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

    function testGovernorOnlyRiverFunctions() public {
        // Assert that the governor can call at least one governor-only function
        vm.startPrank(riverGovernorDAO);
        firewalledRiver.addOperator("bob", bob);
        (int256 _operatorBobIndex, ) = firewalledRiver.getOperatorDetails("bob");
        assert(_operatorBobIndex >= 0);
        vm.stopPrank();

        // Assert that the executor cannot call any of the admin-only functions
        vm.startPrank(executor);
        vm.expectRevert(unauthExecutor);
        firewalledRiver.addOperator("joe", joe);

        vm.expectRevert(unauthExecutor);
        firewalledRiver.setGlobalFee(4);

        vm.expectRevert(unauthExecutor);
        firewalledRiver.setOperatorRewardsShare(4);

        vm.expectRevert(unauthExecutor);
        firewalledRiver.setAllower(joe);

        vm.stopPrank();

        // Assert that a random caller cannot call at least one of the admin-only functions
        vm.startPrank(joe);
        vm.expectRevert(unauthJoe);
        firewalledRiver.setGlobalFee(4);
    }

    function testGovernorOrExecutorRiverFunctions() public {
        // Assert that both admin and executor can setOperatorStatus, and a random caller cannot
        vm.startPrank(riverGovernorDAO);
        firewalledRiver.addOperator("bob", bob);
        (int256 _operatorBobIndex, ) = firewalledRiver.getOperatorDetails("bob");
        assert(_operatorBobIndex >= 0);
        uint256 operatorBobIndex = uint256(_operatorBobIndex);
        firewalledRiver.setOperatorStatus(operatorBobIndex, true);
        assert(firewalledRiver.getOperator(operatorBobIndex).active == true);
        vm.stopPrank();

        vm.startPrank(executor);
        firewalledRiver.setOperatorStatus(operatorBobIndex, false);
        assert(firewalledRiver.getOperator(operatorBobIndex).active == false);
        vm.stopPrank();

        vm.startPrank(joe);
        vm.expectRevert(unauthJoe);
        firewalledRiver.setOperatorStatus(operatorBobIndex, true);
        vm.stopPrank();

        // Assert that both admin and executor can setOperatorStoppedValidatorCount, and a random caller cannot
        // Assert this by expecting InvalidArgument, NOT Unauthorized
        vm.startPrank(riverGovernorDAO);
        vm.expectRevert(abi.encodeWithSignature("InvalidArgument()"));
        firewalledRiver.setOperatorStoppedValidatorCount(operatorBobIndex, 3);
        vm.stopPrank();
        vm.startPrank(executor);
        vm.expectRevert(abi.encodeWithSignature("InvalidArgument()"));
        firewalledRiver.setOperatorStoppedValidatorCount(operatorBobIndex, 7);
        vm.stopPrank();
        vm.startPrank(joe);
        vm.expectRevert(unauthJoe);
        firewalledRiver.setOperatorStoppedValidatorCount(operatorBobIndex, 11);
        vm.stopPrank();

        // Assert that both admin and executor can setOperatorLimit, and a random caller cannot
        vm.startPrank(riverGovernorDAO);
        firewalledRiver.setOperatorLimit(operatorBobIndex, 13);
        assert(firewalledRiver.getOperator(operatorBobIndex).limit == 13);
        vm.stopPrank();
        vm.startPrank(executor);
        firewalledRiver.setOperatorLimit(operatorBobIndex, 17);
        assert(firewalledRiver.getOperator(operatorBobIndex).limit == 17);
        vm.stopPrank();
        vm.startPrank(joe);
        vm.expectRevert(unauthJoe);
        firewalledRiver.setOperatorLimit(operatorBobIndex, 19);
        vm.stopPrank();

        // Assert that both admin and executor can depositToConsensusLayer, and a random caller cannot
        // Assert this by expecting NotEnoughFunds, NOT Unauthorized
        vm.startPrank(riverGovernorDAO);
        vm.expectRevert(abi.encodeWithSignature("NotEnoughFunds()"));
        firewalledRiver.depositToConsensusLayer(10);
        vm.stopPrank();
        vm.startPrank(executor);
        vm.expectRevert(abi.encodeWithSignature("NotEnoughFunds()"));
        firewalledRiver.depositToConsensusLayer(10);
        vm.stopPrank();
        vm.startPrank(joe);
        vm.expectRevert(unauthJoe);
        firewalledRiver.depositToConsensusLayer(10);
        vm.stopPrank();

        // Assert that both admin and executor can setOracle, and a random caller cannot
        vm.startPrank(riverGovernorDAO);
        firewalledRiver.setOracle(joe);
        assert(firewalledRiver.getOracle() == joe);
        vm.stopPrank();
        vm.startPrank(executor);
        firewalledRiver.setOracle(bob);
        assert(firewalledRiver.getOracle() == bob);
        vm.stopPrank();
        vm.startPrank(joe);
        vm.expectRevert(unauthJoe);
        firewalledRiver.setOracle(riverGovernorDAO);
        vm.stopPrank();
    }

    function testGovernorOrExecutorOracleFunctions() public {
        // Assert that both admin and executor can addMember and removeMember
        vm.startPrank(riverGovernorDAO);
        firewalledOracle.addMember(bob);
        assert(firewalledOracle.isMember(bob));
        firewalledOracle.removeMember(bob);
        assert(!firewalledOracle.isMember(bob));
        vm.stopPrank();

        vm.startPrank(executor);
        firewalledOracle.addMember(bob);
        assert(firewalledOracle.isMember(bob));
        firewalledOracle.removeMember(bob);
        assert(!firewalledOracle.isMember(bob));
        vm.stopPrank();

        // Assert that a random caller cannot addMember or removeMember
        vm.startPrank(joe);
        vm.expectRevert(unauthJoe);
        firewalledOracle.addMember(bob);
        vm.stopPrank();
        vm.startPrank(riverGovernorDAO);
        firewalledOracle.addMember(bob);
        vm.stopPrank();
        vm.startPrank(joe);
        vm.expectRevert(unauthJoe);
        firewalledOracle.removeMember(bob);
        vm.stopPrank();

        // Assert that both admin and executor can setQuorum, and a random caller cannot
        vm.startPrank(riverGovernorDAO);
        firewalledOracle.setQuorum(2);
        assert(firewalledOracle.getQuorum() == 2);
        vm.stopPrank();
        vm.startPrank(executor);
        firewalledOracle.setQuorum(3);
        assert(firewalledOracle.getQuorum() == 3);
        vm.stopPrank();
        vm.startPrank(joe);
        vm.expectRevert(unauthJoe);
        firewalledOracle.setQuorum(4);
        vm.stopPrank();

        // Assert that both admin and executor can setBeaconSpec, and a random caller cannot
        vm.startPrank(riverGovernorDAO);
        firewalledOracle.setBeaconSpec(2, 3, 4, 5);
        assert(firewalledOracle.getBeaconSpec().epochsPerFrame == 2);
        vm.stopPrank();
        vm.startPrank(executor);
        firewalledOracle.setBeaconSpec(6, 7, 8, 9);
        assert(firewalledOracle.getBeaconSpec().epochsPerFrame == 6);
        vm.stopPrank();
        vm.startPrank(joe);
        vm.expectRevert(unauthJoe);
        firewalledOracle.setBeaconSpec(10, 11, 12, 13);
        vm.stopPrank();

        // Assert that both admin and executor can setBeaconSpec, and a random caller cannot
        vm.startPrank(riverGovernorDAO);
        firewalledOracle.setBeaconBounds(2, 3);
        assert(firewalledOracle.getBeaconBounds().annualAprUpperBound == 2);
        vm.stopPrank();
        vm.startPrank(executor);
        firewalledOracle.setBeaconBounds(4, 5);
        assert(firewalledOracle.getBeaconBounds().annualAprUpperBound == 4);
        vm.stopPrank();
        vm.startPrank(joe);
        vm.expectRevert(unauthJoe);
        firewalledOracle.setBeaconBounds(6, 7);
        vm.stopPrank();
    }

    /// @dev convert function sig, of form "functionName(arg1Type,arg2Type)", to the 4 bytes used in
    ///      a contract call, accessible at msg.sig
    function getSelector(string memory functionSig) internal pure returns (bytes4) {
        return bytes4(keccak256(bytes(functionSig)));
    }

    function testPermissionChanges() public {
        // 1. Assert executor and random caller cannot change permissions
        vm.startPrank(executor);
        vm.expectRevert(unauthExecutor);
        riverFirewall.makeGovernorOrExecutor(getSelector("setGlobalFee(uint256)"));
        vm.stopPrank();
        vm.startPrank(joe);
        vm.expectRevert(unauthJoe);
        riverFirewall.makeFreelyCallable(getSelector("setOperatorStatus(uint256,bool)"));
        vm.stopPrank();

        // 2. Assert that passing a governorOrExecutor function to makeGovernorOnly disables the
        //    executor from calling the function
        // At first, both governor and executor can setOperatorStatus
        vm.startPrank(riverGovernorDAO);
        firewalledRiver.addOperator("bob", bob);
        (int256 _operatorBobIndex, ) = firewalledRiver.getOperatorDetails("bob");
        assert(_operatorBobIndex >= 0);
        uint256 operatorBobIndex = uint256(_operatorBobIndex);
        firewalledRiver.setOperatorStatus(operatorBobIndex, true);
        assert(firewalledRiver.getOperator(operatorBobIndex).active == true);
        vm.stopPrank();

        vm.startPrank(executor);
        firewalledRiver.setOperatorStatus(operatorBobIndex, false);
        assert(firewalledRiver.getOperator(operatorBobIndex).active == false);
        vm.stopPrank();

        // Then we make it governorOnly.
        // Assert governor can still call it, and executor now cannot.
        vm.startPrank(riverGovernorDAO);
        riverFirewall.makeGovernorOnly(getSelector("setOperatorStatus(uint256,bool)"));
        firewalledRiver.setOperatorStatus(operatorBobIndex, true);
        assert(firewalledRiver.getOperator(operatorBobIndex).active == true);
        vm.stopPrank();
        vm.expectRevert(unauthExecutor);
        vm.startPrank(executor);
        firewalledRiver.setOperatorStatus(operatorBobIndex, false);
        vm.stopPrank();

        // 3. Assert that passing a freely callable function to makeGovernorOrExecutor disables a
        // someone who is not the governor or executor from calling it
        // Example: addValidators is normally callable if the operator we add to is the msg.sender
        // First, add the operator
        vm.startPrank(riverGovernorDAO);
        firewalledRiver.addOperator("joe", joe);
        (int256 _operatorJoeIndex, ) = firewalledRiver.getOperatorDetails("joe");
        assert(_operatorJoeIndex >= 0);
        uint256 operatorJoeIndex = uint256(_operatorJoeIndex);
        firewalledRiver.setOperatorStatus(operatorJoeIndex, true);
        vm.stopPrank();
        // Assert that bob can currently call the function -
        // expect a revert for too few keys, NOT Unauthorized()
        vm.startPrank(joe);
        vm.expectRevert(abi.encodeWithSignature("InvalidKeyCount()"));
        bytes memory noData = "";
        firewalledRiver.addValidators(operatorJoeIndex, 0, noData, noData);
        vm.stopPrank();
        // Then, make the function governorOrExecutor only, and now expect Unauthorized()
        vm.startPrank(riverGovernorDAO);
        riverFirewall.makeGovernorOrExecutor(getSelector("addValidators(uint256,uint256,bytes,bytes)"));
        vm.stopPrank();
        vm.startPrank(joe);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", joe));
        firewalledRiver.addValidators(operatorJoeIndex, 0, noData, noData);
        vm.stopPrank();

        // 4. Assert that passing a governorOnly function to makeGovernorOrExecutor enables the
        //    executor to call it
        vm.startPrank(riverGovernorDAO);
        riverFirewall.makeGovernorOrExecutor(getSelector("setAllower(address)"));
        vm.stopPrank();
        vm.startPrank(executor);
        firewalledRiver.setAllower(joe);
        assert(firewalledRiver.getAllower() == joe);
        vm.stopPrank();

        // 5. Assert that passing a governorOnly function to makeFreelyCallable enables anyone to
        //    call it
        vm.startPrank(riverGovernorDAO);
        riverFirewall.makeFreelyCallable(getSelector("addOperator(string,address)"));
        vm.stopPrank();
        vm.startPrank(joe);
        firewalledRiver.addOperator("don", don);
        (int256 _operatorDonIndex, ) = firewalledRiver.getOperatorDetails("don");
        assert(_operatorDonIndex >= 0);
    }

    function testFirewallRoleChanging() public {
        // 1. Assert that governor can changeGovernor, and the new governor can
        //    setAllower, a governorOnly action
        address newGovernorDAO = address(0xdF2a01F10f86A7cdd2EE10cf35B8ab62723096a6);
        vm.startPrank(riverGovernorDAO);
        riverFirewall.changeGovernor(newGovernorDAO);
        vm.stopPrank();
        vm.startPrank(newGovernorDAO);
        firewalledRiver.setAllower(joe);
        assert(firewalledRiver.getAllower() == joe);

        // 2. Assert that governor can changeExecutor and the new executor can
        //    setOracle, a governorOrExecutor action
        riverFirewall.changeExecutor(bob);
        vm.stopPrank();
        vm.startPrank(bob);
        firewalledRiver.setOracle(don);
        assert(firewalledRiver.getOracle() == don);

        // 3. Assert that executor can changeExecutor and the new executor can
        //    setOracle, a governorOrExecutor action
        riverFirewall.changeExecutor(joe);
        vm.stopPrank();
        vm.startPrank(joe);
        firewalledRiver.setOracle(joe);
        assert(firewalledRiver.getOracle() == joe);
        vm.stopPrank();
    }
}
