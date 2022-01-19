//SPDX-License-Identifier: Unlicense

pragma solidity 0.8.10;

import "./Vm.sol";
import "../src/Greeter.sol";

contract GreeterTests {
    Greeter internal greeter;

    Vm internal vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    string internal constant GREETING_MESSAGE = "Hello, World !";

    function setUp() public {
        greeter = new Greeter(GREETING_MESSAGE);
    }

    function testGreet() public {
        string memory receivedGreeting = greeter.greet();
        assert(
            keccak256(bytes(receivedGreeting)) ==
                keccak256(bytes(GREETING_MESSAGE))
        );
    }
}
