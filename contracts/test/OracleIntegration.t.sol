//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
// fixtures
import "./fixtures/RiverUnitTestBase.sol";
import "./fixtures/DeploymentFixture.sol";
import "./fixtures/RiverV1ForceCommittable.sol";
// utils
import "./utils/RiverHelper.sol";
import "./utils/IntegrationTestHelpers.sol";
import "./utils/events/OracleEvents.sol";

contract OracleIntegrationTest is Test, DeploymentFixture, RiverHelper, IntegrationTestHelpers, OracleEvents {
    function setUp() public override {
        super.setUp();
        // set up coverage fund
        vm.prank(address(riverProxyFirewall));
        RiverV1(payable(address(riverProxy))).setCoverageFund(address(coverageFundProxy));
        // set up keeper
        vm.prank(address(riverProxyFirewall));
        RiverV1(payable(address(riverProxy))).setKeeper(address(operatorsRegistryFirewall));
    }

    /// @notice Test oracle-triggered actions are only taken once quorum is reached
    function testOracleOnlyPullsFundsWhenQuorumIsReached(uint256 _salt, uint256 _frame) external {
        vm.assume(_frame <= 255);
        uint8 depositCount = uint8(bound(_salt, 2, 32));
        IOracleManagerV1.ConsensusLayerReport memory clr = _generateEmptyReport();
        _salt = _depositValidators(
            AllowlistV1(address(allowlistProxy)),
            allower,
            OperatorsRegistryV1(address(operatorsRegistryProxy)),
            RiverV1ForceCommittable(payable(address(riverProxy))),
            address(operatorsRegistryFirewall),
            depositCount,
            _salt
        );
        _salt = uint256(keccak256(abi.encode(_salt)));
        uint256 framesBetween = bound(_salt, 1, 1_000_000);
        uint256 timeBetween = framesBetween * secondsPerSlot * slotsPerEpoch * epochsPerFrame;
        uint256 maxIncrease = debug_maxIncrease(
            IOracleManagerV1(river).getReportBounds(), ISharesManagerV1(river).totalUnderlyingSupply(), timeBetween
        );
        vm.deal(address(elFeeRecipientProxy), maxIncrease);

        // add oracle members
        address member;
        address member2;
        (member, member2) = setUpTwoOracleMembers(_salt);

        // mock oracle report
        clr.validatorsCount = depositCount;
        clr.validatorsBalance = 32 ether * (depositCount);
        clr.validatorsExitingBalance = 0;
        clr.validatorsSkimmedBalance = 0;
        clr.validatorsExitedBalance = 0;
        mockValidEpoch(address(riverProxy), 1726660451, _frame, clr);
        uint256 initialBalance = address(riverProxy).balance;

        // 1st oracle report
        vm.prank(member);
        OracleV1(address(oracleProxy)).reportConsensusLayerData(clr);

        // no funds were pulled (quorum not met)
        assertEq(address(riverProxy).balance, initialBalance);
        assertEq(OracleV1(address(oracleProxy)).getLastReportedEpochId(), clr.epoch);

        // 2nd oracle report
        vm.prank(member2);
        OracleV1(address(oracleProxy)).reportConsensusLayerData(clr);

        // funds were pulled (quorum reached)
        assertEq(address(riverProxy).balance - maxIncrease, initialBalance);
    }

    function setUpTwoOracleMembers(uint256 _salt) internal returns (address, address) {
        address member = uf._new(_salt);
        vm.prank(admin);
        OracleV1(address(oracleProxy)).addMember(member, 1);

        address member2 = uf._new(_salt);
        vm.prank(admin);
        OracleV1(address(oracleProxy)).addMember(member2, 2);
        assertEq(OracleV1(address(oracleProxy)).getQuorum(), 2);

        return (member, member2);
    }
}
