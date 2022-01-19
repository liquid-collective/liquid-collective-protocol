//SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "./Vm.sol";
import "../src/components/deposit/DepositManager.1.sol";

contract DepositManagerV1Tests is DepositManagerV1 {
    Vm internal vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    address internal depositContractAddress =
        0x00000000219ab540356cBB839Cbe05303d7705Fa;

    function setUp() public {
        DepositManagerV1.depositManagerInitializeV1(depositContractAddress);
    }

    function testDeposit() public view {
        DepositManagerV1.depositToETH2();
    }
}
