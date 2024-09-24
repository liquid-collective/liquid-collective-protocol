//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/libraries/LibAdministrable.sol";
// fixtures
import "./fixtures/RiverUnitTestBase.sol";
import "./fixtures/DeploymentFixture.sol";
import "./fixtures/RiverV1ForceCommittable.sol";
// utils
import "./utils/BytesGenerator.sol";
import "./utils/LibImplementationUnbricker.sol";
import "./utils/UserFactory.sol";
import "./utils/RiverHelper.sol";
import "./utils/events/RiverEvents.sol";
import "../src/libraries/LibUnstructuredStorage.sol";
import "../src/state/river/OracleAddress.sol";
import "../src/state/river/LastConsensusLayerReport.sol";
import "../src/state/shared/RiverAddress.sol";
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

contract DepositIntegrationTest is Test, DeploymentFixture, RiverHelper {

    /// @notice This test is to check the Oracle integration with the River contract
    function testDepositIntegration(uint256 _salt, uint256 _frame) external {
        uint8 depositCount = uint8(bound(_salt, 2, 32));
        IOracleManagerV1.ConsensusLayerReport memory clr = _generateEmptyReport();
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

        vm.assume(_frame <= 255);

        vm.prank(address(riverProxyFirewall));
        RiverV1(payable(address(riverProxy))).setCoverageFund(address(coverageFundProxy));

        // bytes32 storageSlot = AdministratorAddress.ADMINISTRATOR_ADDRESS_SLOT;
        address operatorsRegistryAdmin = address(operatorsRegistryFirewall);

        {
        vm.prank(operatorsRegistryAdmin);
        operatorOneIndex = OperatorsRegistryV1(address(operatorsRegistryProxy)).addOperator(operatorOneName, operatorOne);
        bytes memory hundredKeysOp1 = genBytes((48 + 96) * 100);
        vm.prank(operatorsRegistryAdmin);
        OperatorsRegistryV1(address(operatorsRegistryProxy)).addValidators(operatorOneIndex, 100, hundredKeysOp1);
        bytes memory hundredKeysOp2 = genBytes((48 + 96) * 100);
        vm.prank(operatorsRegistryAdmin);
        OperatorsRegistryV1(address(operatorsRegistryProxy)).addValidators(operatorTwoIndex, 100, hundredKeysOp2);
        }
        _salt = uint256(keccak256(abi.encode(_salt)));
        uint256 framesBetween = bound(_salt, 1, 1_000_000);
        uint256 timeBetween = framesBetween * secondsPerSlot * slotsPerEpoch * epochsPerFrame;
        uint256 maxIncrease = debug_maxIncrease(
            IOracleManagerV1(river).getReportBounds(),
            ISharesManagerV1(river).totalUnderlyingSupply(),
            timeBetween
        );
        vm.deal(address(bob), 100 ether);

        // user deposits
        _allow(IAllowlistV1(address(allowlistProxy)), allower, bob);
        vm.startPrank(bob);
        RiverV1(payable(address(riverProxy))).deposit{value: 32 ether}();
        vm.stopPrank();
    
        {
        uint256[] memory operatorIndexes = new uint256[](1);
        operatorIndexes[0] = operatorOneIndex;
        uint32[] memory operatorLimits = new uint32[](1);
        operatorLimits[0] = uint32(100);

        vm.prank(operatorsRegistryAdmin);
        OperatorsRegistryV1(address(operatorsRegistryProxy)).setOperatorLimits(operatorIndexes, operatorLimits, block.number);

        river.debug_moveDepositToCommitted();
        }

        RiverV1ForceCommittable(payable(address(riverProxy))).debug_moveDepositToCommitted();
        vm.prank(address(operatorsRegistryFirewall));
        RiverV1(payable(address(riverProxy))).depositToConsensusLayerWithDepositRoot(100, bytes32(0)); // NoAvailableValidatorKeys()

        // river LsETH : ETH rate is 1:1
        assert(RiverV1(payable(address(riverProxy))).balanceOf(bob) == 32 ether);
        assert(RiverV1(payable(address(riverProxy))).balanceOfUnderlying(bob) == 32 ether);

        // accrue some rewards

        //TODO extract into helper
        // add oracle members
        address member = uf._new(_salt);
        vm.prank(admin);
        OracleV1(address(oracleProxy)).addMember(member, 1);

        // set the current epoch
        uint256 blockTimestamp = 1726660451 + _frame;
        vm.warp(blockTimestamp);
        uint256 expectedEpoch = RiverV1(payable(address(riverProxy))).getExpectedEpochId();

        // mock oracle report
        clr.validatorsCount = depositCount;
        clr.validatorsBalance = 32 ether * (depositCount);
        clr.validatorsExitingBalance = 0;
        clr.validatorsSkimmedBalance = 100 ether;
        clr.validatorsExitedBalance = 0;
        clr.epoch = expectedEpoch; // set the oracle report epoch
        vm.deal(address(withdrawProxy), 100 ether);

        // set the storage for the LastConsensusLayerReport.get().epoch
        bytes32 storageSlot = LastConsensusLayerReport.LAST_CONSENSUS_LAYER_REPORT_SLOT;
        uint256 mockLastCLEpoch = clr.epoch - 1;
        vm.store(address(riverProxy), storageSlot, bytes32(mockLastCLEpoch));

        //!TODO failing mock river address in shared/RiverAddress.sol
        bytes32 second_storageSlot = RiverAddress.RIVER_ADDRESS_SLOT;
        vm.store(address(riverProxy), second_storageSlot, bytes32(uint256(uint160(address(riverProxy)))));

        uint256 initialBalance = address(riverProxy).balance;

        // oracle report will pull CL funds
        vm.prank(member);
        OracleV1(address(oracleProxy)).reportConsensusLayerData(clr);

        // check ETH balance increase
        assert(address(riverProxy).balance > initialBalance);
        assert(RiverV1(payable(address(riverProxy))).balanceOf(bob) == 32 ether);
        assert(RiverV1(payable(address(riverProxy))).balanceOfUnderlying(bob) > 32 ether);
    }
}
