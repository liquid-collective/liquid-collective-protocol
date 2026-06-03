//SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.34;

import "forge-std/Test.sol";
import "./utils/LibImplementationUnbricker.sol";
import "./utils/BytesGenerator.sol";
import "../src/OperatorsRegistry.1.sol";
import "../src/state/operatorsRegistry/Operators.2.sol";

event SetOperatorLimit(uint256 indexed index, uint256 newLimit);

/// @notice Minimal concrete registry (no overrides) so coverage for removeValidators is attributed to OperatorsRegistry.1.sol
contract OperatorsRegistryV1Minimal is OperatorsRegistryV1 {}

contract RiverMockForLimitTest {
    function setKeeper(address) external {}

    function getKeeper() external view returns (address) {
        return address(0);
    }
}
