//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
// fixtures
import "./fixtures/RiverV1TestBase.sol";
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
    IRiverV1 riverImpl;
    IOracleV1 oracleImpl;

    function setUp() public override {
        super.setUp();
        riverImpl = RiverV1ForceCommittable(payable(address(riverProxy)));
        oracleImpl = OracleV1(address(oracleProxy));

    }

    /// @notice This test is to check the Oracle integration with the River contract
    function testOracleIntegration(uint256 _salt) external {
        uint8 depositCount = uint8(bound(_salt, 2, 32));
        IOracleManagerV1.ConsensusLayerReport memory clr = _generateEmptyReport();

        vm.prank(address(riverProxyFirewall));
        riverImpl = RiverV1ForceCommittable(payable(address(riverProxy)));
        riverImpl.setCoverageFund(address(coverageFundProxy));

        // operators registry admin
        address operatorsRegistryAdmin = address(operatorsRegistryFirewall);
        vm.prank(address(riverProxyFirewall));
        RiverV1(payable(address(riverProxy))).setKeeper(operatorsRegistryAdmin);
        _salt = _depositValidators(AllowlistV1(address(allowlistProxy)), allower, OperatorsRegistryV1(address(operatorsRegistryProxy)), RiverV1ForceCommittable(payable(address(riverProxy))), operatorsRegistryAdmin, depositCount, _salt);
        _salt = uint256(keccak256(abi.encode(_salt)));
        uint256 framesBetween = bound(_salt, 1, 1_000_000);
        uint256 timeBetween = framesBetween * secondsPerSlot * slotsPerEpoch * epochsPerFrame;
        uint256 maxIncrease = debug_maxIncrease(IOracleManagerV1(river).getReportBounds(),  ISharesManagerV1(river).totalUnderlyingSupply(), timeBetween);
        vm.deal(address(elFeeRecipientProxy), maxIncrease);

        // Mock oracle report
        clr.validatorsCount = depositCount;
        clr.validatorsBalance = 32 ether * (depositCount);
        clr.validatorsExitingBalance = 0;
        clr.validatorsSkimmedBalance = 0;
        clr.validatorsExitedBalance = 0;
        // clr.epoch = // TBD; 

        // 3 conditions to check:
        // curEpoch >= e + cls.assumedFinality
        // e > cl(e)
        // e % cls.frames == 0

        // add oracle member
        address member = uf._new(_salt);
        vm.prank(admin);
        OracleV1(address(oracleProxy)).addMember(member, 1);

        // 1st condition: _currentEpoch(_cls) >= _epoch + _cls.epochsToAssumedFinality
        uint256 blockTimestamp = 1726660451;  // vm.assume()
        vm.warp(blockTimestamp);
        uint256 calcCurE =((blockTimestamp - genesisTime) / secondsPerSlot) / slotsPerEpoch;
        console.log("calcCurE: ", calcCurE);
        console.log("block time vs. oracleManagerTime", blockTimestamp, oracleManager.getTime());
        uint256 currentEpoch = oracleManager.getCurrentEpochId();
        uint256 expectedEpoch = oracleManager.getExpectedEpochId();
        console.log("current Epoch: ", currentEpoch);
        clr.epoch = expectedEpoch;
        console.log("expected Epoch: ", expectedEpoch);
        // assert
        assert(currentEpoch > clr.epoch+ epochsToAssumedFinality);
        console.log("first condition passed successfully");

        // 2nd condition
        // satisfy last cl epoch condition
        // Mock the storage for LastConsensusLayerReport.get().epoch
        bytes32 baseSlot = LastConsensusLayerReport.LAST_CONSENSUS_LAYER_REPORT_SLOT;
        uint256 mockEpochValue = clr.epoch-1; // Example value
        vm.store(address(riverProxy), baseSlot, bytes32(mockEpochValue));
        uint256 lastConsensusEpoch = IOracleManagerV1(address(riverProxy)).getLastCompletedEpochId();
        // e > cl(e)
        assert(clr.epoch > lastConsensusEpoch);
        console.log("second condition passed successfully");

        // 3rd condition
        // e % cls.frames == 0
        assert(clr.epoch % epochsPerFrame == 0);
        console.log("third condition passed successfully");

        console.log("[test] cl e < e < curE: ", lastConsensusEpoch, clr.epoch, currentEpoch);
        vm.prank(member);
        OracleV1(address(oracleProxy)).reportConsensusLayerData(clr);
    }

    function testEpoch() external {
        uint256 currentEpoch = oracleManager.getCurrentEpochId();
        console.log("currentEpoch", currentEpoch);
        uint256 blockTimestamp = 1726660451; 
        // set the current epoch:
        // vm.roll(blockNumber);
        vm.warp(blockTimestamp);
        // 1st condition _currentEpoch(_cls) >= _epoch + _cls.epochsToAssumedFinality
        currentEpoch = oracleManager.getCurrentEpochId();
        console.log("currentEpoch", currentEpoch);

        bytes32 baseSlot = LastConsensusLayerReport.LAST_CONSENSUS_LAYER_REPORT_SLOT;
        // bytes32 epochSlot = keccak256(abi.encodePacked(baseSlot));
        uint256 mockEpochValue = 123456; // Example value
        vm.store(address(oracleManager), baseSlot, bytes32(mockEpochValue));

        uint256 lastConsensusEpoch = oracleManager.getLastCompletedEpochId(); 
        console.log("consensus", lastConsensusEpoch);
    }
}