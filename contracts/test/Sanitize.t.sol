//SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "../src/Sanitize.sol";

import "forge-std/Test.sol";

contract SanitizedInputs is Sanitize {
    function setAddress(address _address) external notZeroAddress(_address) {}
    function setString(string calldata _string) external notEmptyString(_string) {}
    function setFee(uint256 _fee) external validFee(_fee) {}
}

contract SanitizeTest is Test {
    SanitizedInputs internal si;

    function setUp() external {
        si = new SanitizedInputs();
    }

    function testSetZeroAddress() external {
        vm.expectRevert(abi.encodeWithSignature("InvalidZeroAddress()"));
        si.setAddress(address(0));
    }

    function testSetNonZeroAddress() external {
        address validAddress = makeAddr("validAddress");
        si.setAddress(validAddress);
    }

    function testSetEmptyString() external {
        vm.expectRevert(abi.encodeWithSignature("InvalidEmptyString()"));
        si.setString("");
    }

    function testSetNonEmptyString() external {
        string memory _string = "valid string";
        si.setString(_string);
    }

    function testSetFeeTooHigh() external {
        vm.expectRevert(abi.encodeWithSignature("InvalidFee()"));
        si.setFee(100001);
    }

    function testSetValidFee() external {
        uint256 validFee = 100000;
        si.setFee(validFee);
    }
}
