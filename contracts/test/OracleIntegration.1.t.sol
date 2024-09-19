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
        address expectedOracleAddress = address(oracleProxy);
        vm.mockCall(
            address(river),
            abi.encodeWithSelector(bytes4(keccak256("get()"))),
            abi.encode(expectedOracleAddress)
        );
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

        // oracle report
        clr.validatorsCount = depositCount;
        clr.validatorsBalance = 32 ether * (depositCount);
        clr.validatorsExitingBalance = 0;
        clr.validatorsSkimmedBalance = 0;
        clr.validatorsExitedBalance = 0;
        
        {
        
        uint256 blockTimestamp = 1726660451; 
        // set the current epoch:
        // vm.roll(blockNumber);
        vm.warp(blockTimestamp);
        // 1st condition _currentEpoch(_cls) >= _epoch + _cls.epochsToAssumedFinality
        uint256 currentEpoch = oracleManager.getCurrentEpochId();
        // uint256 currentEpoch = oracleManager.getCurrentEpochId();
        uint256 tentativeEpoch = currentEpoch + epochsPerFrame -54 -225;
        clr.epoch = 312075; 

        // uint256 expectedEpoch = oracleManager.getExpectedEpochId();
        // uint256 currentEpoch = oracleManager.getCurrentEpochId();
        // // currentEpoch >= inputEpoch + epochsToAssumedFinalty 
        // // AND inputEpoch > LastConsensusLayerEpoch 
        // // AND inputEpoch % epochsPerFrame == 0 (divisible by 225)
        // uint256 tentativeEpoch = currentEpoch + epochsPerFrame -54 -225;
        // clr.epoch = tentativeEpoch; 
        uint256 lastConsensusEpoch = oracleManager.getLastCompletedEpochId(); 
        // assert(currentEpoch >= tentativeEpoch+epochsToAssumedFinality);
        assert(tentativeEpoch > lastConsensusEpoch);
        assert(tentativeEpoch % epochsPerFrame == 0);
        assert(oracleManager.isValidEpoch(tentativeEpoch));
            // uint256 expectedEpoch = oracleManager.getExpectedEpochId();
            // uint256 currentEpoch = oracleManager.getCurrentEpochId();
            // // currentEpoch >= inputEpoch + epochsToAssumedFinalty 
            // // AND inputEpoch > LastConsensusLayerEpoch 
            // // AND inputEpoch % epochsPerFrame == 0 (divisible by 225)
            // uint256 lastConsensusEpoch = oracleManager.getLastCompletedEpochId(); 
            // uint256 tentativeEpoch = lastConsensusEpoch + epochsPerFrame -54 -225;
            // clr.epoch = tentativeEpoch; 
            // // uint256 lastConsensusEpoch = oracleManager.getLastCompletedEpochId(); 
        }
        // clr.epoch = 312075;
        // // framesBetween * epochsPerFrame;
        // vm.warp(20777406);
        // vm.warp(1641070800);
        // vm.warp((clr.epoch + epochsUntilFinal) * (secondsPerSlot * slotsPerEpoch));
        // internal epoch: 312075

        // vm.warp((clr.epoch + epochsUntilFinal) * (secondsPerSlot * slotsPerEpoch));
        vm.deal(address(elFeeRecipientProxy), maxIncrease);
        uint256 committedAmount = riverImpl.getCommittedBalance();
        uint256 depositAmount = riverImpl.getBalanceToDeposit();

        // add oracle member
        address member = uf._new(_salt);
        assertEq(oracleImpl.getQuorum(), 0);
        assertEq(oracleImpl.isMember(member), false);

        vm.prank(admin);
        OracleV1(address(oracleProxy)).addMember(member, 1);

        assertEq(oracleImpl.getQuorum(), 1);
        assertEq(oracleImpl.isMember(member), true);


        uint256 elBalanceBefore = address(elFeeRecipient).balance;
        uint256 riverBalanceBefore = address(riverImpl).balance;

        // Oracle level
        // vm.expectEmit(true, true, true, true);
        // emit ReportedConsensusLayerData(address(member), keccak256(abi.encode(clr)), clr, 1, 1);
        
        // // Oracle manager level
        // vm.expectEmit(true, false, false, false);
        // IOracleManagerV1.ConsensusLayerDataReportingTrace memory newStruct;
        // emit ProcessedConsensusLayerReport(clr, newStruct);
        
        uint256 supplyBeforeReport = riverImpl.totalSupply();

        // call as oracle member
        vm.prank(member);
        // IOracleManagerV1.StoredConsensusLayerReport memory mockReport;
        // mockReport.epoch = 123456; // Example value
        // vm.mockCall(
        //     address(river),
        //     abi.encodeWithSelector(bytes4(keccak256("get()"))),
        //     abi.encode(mockReport)
        // );
        bytes32 baseSlot = LastConsensusLayerReport.LAST_CONSENSUS_LAYER_REPORT_SLOT;

        // Mock the storage for LastConsensusLayerReport.get().epoch
        uint256 mockEpochValue = clr.epoch; // Example value
        vm.store(address(oracleManager), baseSlot, bytes32(mockEpochValue));

        uint256 lastConsensusEpoch = oracleManager.getLastCompletedEpochId(); 
        OracleV1(address(oracleProxy)).reportConsensusLayerData(clr);
        
        // // check river balance increased upon reporting
        // uint256 elBalanceAfter = address(elFeeRecipient).balance;
        // uint256 riverBalanceAfter = address(river).balance;

        // // pulls committed amounts from ELFeeRecipient into River
        // uint256 elBalanceDecrease = elBalanceBefore - elBalanceAfter;
        // uint256 riverBalanceIncrease = riverBalanceAfter - riverBalanceBefore;
        // assert(riverBalanceIncrease == elBalanceDecrease);

        // // assert rewards shares were minted token supply increased
        // uint256 supplyAfterReport = riverImpl.totalSupply();
        // assert(supplyAfterReport == supplyBeforeReport);
 
        // assertEq(riverImpl.getCommittedBalance() % 32 ether, 0);
    }


    // function getEpochsReady(OracleManagerV1 oracleManager) public view returns {
    //     // 1st condition _currentEpoch(_cls) >= _epoch + _cls.epochsToAssumedFinality
    //     uint256 currentEpoch = oracleManager.getCurrentEpochId();
    //     // 2nd condition _epoch > LastConsensusLayerReport.get().epoch
        
    //     // 3rd condition _epoch % _cls.epochsPerFrame == 0
    // }

    function testEpoch() external {
        uint256 currentEpoch = oracleManager.getCurrentEpochId();
        console.log("currentEpoch", currentEpoch);
        // uint256 blockNumber = 20777406;
        uint256 blockTimestamp = 1726660451; 
        // set the current epoch:
        // vm.roll(blockNumber);
        vm.warp(blockTimestamp);
        // 1st condition _currentEpoch(_cls) >= _epoch + _cls.epochsToAssumedFinality
        currentEpoch = oracleManager.getCurrentEpochId();
        console.log("currentEpoch", currentEpoch);
        // 2nd condition _epoch > LastConsensusLayerReport.get().epoch
        
        // IOracleManagerV1.StoredConsensusLayerReport memory mockReport;
        // mockReport.epoch = 123456; // Example value
        // vm.mockCall(
        //     address(river),
        //     abi.encodeWithSelector(bytes4(keccak256("get()"))),
        //     abi.encode(mockReport)
        // );

        // bytes32 baseSlot = LastConsensusLayerReport.LAST_CONSENSUS_LAYER_REPORT_SLOT;
        // bytes32 epochSlot = keccak256(abi.encodePacked(baseSlot));

        // // Mock the storage for LastConsensusLayerReport.get().epoch
        // uint256 mockEpochValue = 123456; // Example value
        // vm.store(address(oracleManager), epochSlot, bytes32(mockEpochValue));

        bytes32 baseSlot = LastConsensusLayerReport.LAST_CONSENSUS_LAYER_REPORT_SLOT;

        // Mock the storage for LastConsensusLayerReport.get().epoch
        uint256 mockEpochValue = 123456; // Example value
        vm.store(address(oracleManager), baseSlot, bytes32(mockEpochValue));

        uint256 lastConsensusEpoch = oracleManager.getLastCompletedEpochId(); 
        console.log("consensus", lastConsensusEpoch);
        // bytes32(uint256(0))
        // 3rd condition _epoch % _cls.epochsPerFrame == 0
    }
}
