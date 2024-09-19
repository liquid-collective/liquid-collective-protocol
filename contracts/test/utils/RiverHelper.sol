//SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.20;

import "forge-std/Test.sol";

// fixtures
import "../fixtures/RiverV1ForceCommittable.sol";
// utils
import "./BytesGenerator.sol";
import "./UserFactory.sol";

import "../../src/libraries/LibAllowlistMasks.sol";
import "../../src/interfaces/IOperatorRegistry.1.sol";
import "../../src/interfaces/IRiver.1.sol";
import "../../src/interfaces/IAllowlist.1.sol";
import "../../src/River.1.sol";

abstract contract RiverHelperTestBase is Test, BytesGenerator {
    UserFactory internal uf = new UserFactory();
}

/// @title RiverHelper
/// @notice Helper functions for testing River contract functionality
contract RiverHelper is RiverHelperTestBase {
    function _next(uint256 _salt) internal pure returns (uint256 _newSalt) {
        return uint256(keccak256(abi.encode(_salt)));
    }

    function _allow(IAllowlistV1 allowlist, address allower, address _who) internal {
        address[] memory allowees = new address[](1);
        allowees[0] = _who;
        uint256[] memory permissions = new uint256[](1);
        permissions[0] = LibAllowlistMasks.REDEEM_MASK | LibAllowlistMasks.DEPOSIT_MASK;

        vm.startPrank(allower);
        allowlist.setAllowPermissions(allowees, permissions);
        vm.stopPrank();
    }

    function _depositValidators(
        IAllowlistV1 allowlist,
        address allower,
        IOperatorsRegistryV1 operatorsRegistry,
        RiverV1ForceCommittable river,
        address admin,
        uint256 count,
        uint256 _salt
    ) internal returns (uint256) {
        address depositor = uf._new(_salt);
        _salt = _next(_salt);
        _allow(allowlist, allower, depositor);
        vm.deal(depositor, count * 32 ether);
        vm.prank(depositor);
        river.deposit{value: count * 32 ether}();

        address operator = uf._new(_salt);
        _salt = _next(_salt);
        string memory operatorName = string(abi.encode(_salt));
        _salt = _next(_salt);

        vm.prank(admin);
        uint256 operatorIndex = operatorsRegistry.addOperator(operatorName, operator);
        vm.prank(operator);
        operatorsRegistry.addValidators(operatorIndex, uint32(count), BytesGenerator.genBytes((48 + 96) * count));

        uint256[] memory operatorIndexes = new uint256[](1);
        operatorIndexes[0] = operatorIndex;
        uint32[] memory operatorLimits = new uint32[](1);
        operatorLimits[0] = uint32(count);

        vm.prank(admin);
        operatorsRegistry.setOperatorLimits(operatorIndexes, operatorLimits, block.number);

        river.debug_moveDepositToCommitted();

        vm.prank(admin);
        river.depositToConsensusLayerWithDepositRoot(count, bytes32(0));

        return _salt;
    }

    function _generateEmptyReport() internal pure returns (IOracleManagerV1.ConsensusLayerReport memory clr) {
        clr.stoppedValidatorCountPerOperator = new uint32[](1);
        clr.stoppedValidatorCountPerOperator[0] = 0;
    }

    function _generateEmptyReport(
        uint256 stoppedValidatorsCountElements
    ) internal pure returns (IOracleManagerV1.ConsensusLayerReport memory clr) {
        clr.stoppedValidatorCountPerOperator = new uint32[](stoppedValidatorsCountElements);
    }

    function debug_maxIncrease(
        ReportBounds.ReportBoundsStruct memory rb,
        uint256 _prevTotalEth,
        uint256 _timeElapsed
    ) internal pure returns (uint256) {
        return (_prevTotalEth * rb.annualAprUpperBound * _timeElapsed) / (LibBasisPoints.BASIS_POINTS_MAX * 365 days);
    }
}
