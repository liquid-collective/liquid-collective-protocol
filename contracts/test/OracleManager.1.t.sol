//SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "./Vm.sol";
import "../src/components/OracleManager.1.sol";
import "../src/libraries/Errors.sol";

contract OracleManagerV1ExposeInitializer is OracleManagerV1 {
    uint256 public lastReceived;

    function _onEarnings(uint256 amount) internal override {
        lastReceived = amount;
    }

    function supersedeBalanceSum(uint256 amount) external {
        BeaconValidatorBalanceSum.set(amount);
    }

    function supersedeAllValidatorCount(uint256 amount) external {
        DepositedValidatorCount.set(amount);
        BeaconValidatorCount.set(amount);
    }

    function supersedeDepositedValidatorCount(uint256 amount) external {
        DepositedValidatorCount.set(amount);
    }

    function publicOracleManagerInitializeV1(address _oracleAddress) external {
        OracleManagerV1.oracleManagerInitializeV1(_oracleAddress);
    }
}

contract OracleManagerV1Tests {
    Vm internal vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    address internal oracle =
        address(0xEA674fdDe714fd979de3EdF0F56AA9716B898ec8);

    OracleManagerV1 internal oracleManager;

    function setUp() public {
        oracleManager = new OracleManagerV1ExposeInitializer();
        OracleManagerV1ExposeInitializer(address(oracleManager))
            .publicOracleManagerInitializeV1(oracle);
    }

    function testSetBeaconData(uint256 val2, bytes32 roundId) public {
        vm.startPrank(oracle);
        OracleManagerV1ExposeInitializer(address(oracleManager))
            .supersedeBalanceSum(32 ether);
        OracleManagerV1ExposeInitializer(address(oracleManager))
            .supersedeAllValidatorCount(1);
        oracleManager.setBeaconData(1, val2 + 32 ether, roundId);
        assert(
            OracleManagerV1ExposeInitializer(address(oracleManager))
                .lastReceived() == val2
        );
    }

    function testSetBeaconDataWithValidatorCountDelta(
        uint256 val2,
        bytes32 roundId
    ) public {
        vm.startPrank(oracle);
        OracleManagerV1ExposeInitializer(address(oracleManager))
            .supersedeBalanceSum(32 ether);
        OracleManagerV1ExposeInitializer(address(oracleManager))
            .supersedeAllValidatorCount(1);
        OracleManagerV1ExposeInitializer(address(oracleManager))
            .supersedeDepositedValidatorCount(2);
        oracleManager.setBeaconData(2, val2 + 64 ether, roundId);
        assert(
            OracleManagerV1ExposeInitializer(address(oracleManager))
                .lastReceived() == val2
        );
    }

    function testSetBeaconDataUnauthorized(
        address user,
        uint256 val1,
        bytes32 roundId
    ) public {
        vm.startPrank(user);
        OracleManagerV1ExposeInitializer(address(oracleManager))
            .supersedeAllValidatorCount(1);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", user));
        oracleManager.setBeaconData(1, val1 + 32 ether, roundId);
    }
}
