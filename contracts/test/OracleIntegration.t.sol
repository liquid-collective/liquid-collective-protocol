//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
// fixtures
import "./fixtures/RiverUnitTestBase.sol";
import "./fixtures/DeploymentFixture.sol";
import "./fixtures/RiverV1ForceCommittable.sol";
// utils
import "./utils/BytesGenerator.sol";
import "./utils/LibImplementationUnbricker.sol";
import "./utils/UserFactory.sol";
import "./utils/RiverHelper.sol";
import "./utils/events/OracleEvents.sol";
import "../src/libraries/LibUnstructuredStorage.sol";
import "../src/state/river/OracleAddress.sol";
import "../src/state/river/LastConsensusLayerReport.sol";
// contracts
import "../src/Allowlist.1.sol";
import "../src/River.1.sol";
import "../src/Oracle.1.sol";
import "../src/Withdraw.1.sol";
import "../src/OperatorsRegistry.1.sol";
import "../src/ELFeeRecipient.1.sol";
import "../src/RedeemManager.1.sol";
import "../src/CoverageFund.1.sol";
import "../src/interfaces/IWLSETH.1.sol";
import "./components/OracleManager.1.t.sol";
import "../src/Firewall.sol";
import "../src/TUPProxy.sol";
// mocks
import "./mocks/DepositContractMock.sol";
import "./mocks/RiverMock.sol";

contract OracleIntegrationTest is Test, DeploymentFixture, RiverHelper, OracleEvents {
    /// @notice This test is to check the Oracle integration with the River contract
    function testOracleReportsUpdateOnQuorum(uint256 _salt, uint256 _frame) external {
        vm.assume(_frame <= 255);
        uint8 depositCount = uint8(bound(_salt, 2, 32));
        IOracleManagerV1.ConsensusLayerReport memory clr = _generateEmptyReport();

        vm.prank(address(riverProxyFirewall));
        RiverV1(payable(address(riverProxy))).setCoverageFund(address(coverageFundProxy));

        address operatorsRegistryAdmin = address(operatorsRegistryFirewall);
        vm.prank(address(riverProxyFirewall));
        RiverV1(payable(address(riverProxy))).setKeeper(address(operatorsRegistryFirewall));
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

        setUpValidEpoch(_frame, clr);
        uint256 initialBalance = address(riverProxy).balance;

        // oracle report
        vm.prank(member);
        OracleV1(address(oracleProxy)).reportConsensusLayerData(clr);

        // no balance change (quorum not met)
        assertEq(address(riverProxy).balance, initialBalance);
        assertEq(OracleV1(address(oracleProxy)).getLastReportedEpochId(), clr.epoch);

        // oracle report
        vm.prank(member2);
        OracleV1(address(oracleProxy)).reportConsensusLayerData(clr);

        // balance changed (quorum reached)
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

    function setUpValidEpoch(uint256 _frame, IOracleManagerV1.ConsensusLayerReport memory clr) internal {
        // set the current epoch
        uint256 blockTimestamp = 1726660451 + _frame;
        vm.warp(blockTimestamp);
        uint256 expectedEpoch = RiverV1(payable(address(riverProxy))).getExpectedEpochId();
        // set valid epoch
        clr.epoch = expectedEpoch;
        // set the storage for the LastConsensusLayerReport.get().epoch
        bytes32 storageSlot = LastConsensusLayerReport.LAST_CONSENSUS_LAYER_REPORT_SLOT;
        uint256 mockLastCLEpoch = clr.epoch - 1;
        vm.store(address(riverProxy), storageSlot, bytes32(mockLastCLEpoch));
    }
}
