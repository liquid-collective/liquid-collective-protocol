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
    function setUp() public override {
        super.setUp();

        // set up coverage fund
        vm.prank(address(riverProxyFirewall));
        RiverV1(payable(address(riverProxy))).setCoverageFund(address(coverageFundProxy));
        // set up keeper
        vm.prank(address(riverProxyFirewall));
        RiverV1(payable(address(riverProxy))).setKeeper(address(operatorsRegistryFirewall));
        // deal bob
        vm.deal(address(bob), 100 ether);

        // mock River Address Slot for pullCLfunds
        bytes32 second_storageSlot = RiverAddress.RIVER_ADDRESS_SLOT;
        vm.store(address(withdraw), second_storageSlot, bytes32(uint256(uint160(address(riverProxy)))));
    }

    /// @notice This test is to check the Oracle integration with the River contract
    function testUserDepositDoesNotAlterConversionRate(uint256 _salt, uint256 _frame) external {
        uint8 depositCount = uint8(bound(_salt, 4, 32));
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
            RiverV1(payable(address(riverProxy))).getReportBounds(),
            RiverV1(payable(address(riverProxy))).totalUnderlyingSupply(),
            timeBetween
        );
        vm.assume(_frame <= 255);

        // Bob deposits to LC
        _allow(IAllowlistV1(address(allowlistProxy)), allower, bob);
        vm.startPrank(bob);
        RiverV1(payable(address(riverProxy))).deposit{value: 32 ether}();
        vm.stopPrank();

        setUpOperators();

        // deposit Bob's funds to the consensus layer
        RiverV1ForceCommittable(payable(address(riverProxy))).debug_moveDepositToCommitted();
        vm.prank(address(operatorsRegistryFirewall));
        RiverV1(payable(address(riverProxy))).depositToConsensusLayerWithDepositRoot(100, bytes32(0)); // NoAvailableValidatorKeys()

        assert(RiverV1(payable(address(riverProxy))).balanceOf(bob) == 32 ether);
        assert(RiverV1(payable(address(riverProxy))).balanceOfUnderlying(bob) == 32 ether);
    }

    /// @notice This test is to check the Oracle integration with the River contract
    function testOracleReportMovesDepositedToCommitted(uint256 _salt, uint256 _frame) external {
        uint8 depositCount = uint8(bound(_salt, 4, 32));
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
            RiverV1(payable(address(riverProxy))).getReportBounds(),
            RiverV1(payable(address(riverProxy))).totalUnderlyingSupply(),
            timeBetween
        );
        vm.assume(_frame <= 255);

        // Bob deposits to LC
        _allow(IAllowlistV1(address(allowlistProxy)), allower, bob);
        vm.startPrank(bob);
        RiverV1(payable(address(riverProxy))).deposit{value: 32 ether}();
        vm.stopPrank();

        setUpOperators();

        address member = setUpOracleMember(_salt);
        // new oracle report
        clr.validatorsCount = depositCount;
        clr.validatorsSkimmedBalance = 0;
        clr.validatorsBalance = 32 ether * (depositCount);
        clr.validatorsExitedBalance = 0;
        setUpValidEpoch(1726660451, _frame, clr); // sets clr.epoch to valid epoch

        uint256 bobPreReportBalance = RiverV1(payable(address(riverProxy))).balanceOfUnderlying(bob);
        assert(RiverV1(payable(address(riverProxy))).getCommittedBalance() == 0);
        assert(RiverV1(payable(address(riverProxy))).getBalanceToDeposit() == 32 ether);

        mockDailyCommittableLimit(2000, 32 ether);
        vm.prank(member);
        OracleV1(address(oracleProxy)).reportConsensusLayerData(clr);

        assert(RiverV1(payable(address(riverProxy))).getCommittedBalance() == 32 ether);
        assert(RiverV1(payable(address(riverProxy))).getBalanceToDeposit() == 0);
        assert(RiverV1(payable(address(riverProxy))).balanceOfUnderlying(bob) == bobPreReportBalance);
    }

    /// @notice This test is to check the Oracle integration with the River contract
    function testDepositIntegration(uint256 _salt, uint256 _frame) external {
        uint8 depositCount = uint8(bound(_salt, 4, 32));
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
            RiverV1(payable(address(riverProxy))).getReportBounds(),
            RiverV1(payable(address(riverProxy))).totalUnderlyingSupply(),
            timeBetween
        );
        vm.assume(_frame <= 255);

        // Bob deposits to LC
        _allow(IAllowlistV1(address(allowlistProxy)), allower, bob);
        vm.startPrank(bob);
        RiverV1(payable(address(riverProxy))).deposit{value: 32 ether}();
        vm.stopPrank();

        setUpOperators();

        // deposit Bob's funds to the consensus layer
        RiverV1ForceCommittable(payable(address(riverProxy))).debug_moveDepositToCommitted();
        vm.prank(address(operatorsRegistryFirewall));
        RiverV1(payable(address(riverProxy))).depositToConsensusLayerWithDepositRoot(100, bytes32(0)); // NoAvailableValidatorKeys()

        assert(RiverV1(payable(address(riverProxy))).balanceOf(bob) == 32 ether);
        assert(RiverV1(payable(address(riverProxy))).balanceOfUnderlying(bob) == 32 ether);

        // accrue some rewards
        address member = setUpOracleMember(_salt);
        {
            // new oracle report
            uint256 committedBalance = RiverV1(payable(address(riverProxy))).getCommittedBalance();
            uint256 depositedBalance = RiverV1(payable(address(riverProxy))).getBalanceToDeposit();
            clr.validatorsCount = depositCount + 1;
            clr.validatorsSkimmedBalance = bound(_salt, 0, maxIncrease / 1000);
            clr.validatorsBalance =
                32 ether * (depositCount) + committedBalance + depositedBalance - clr.validatorsSkimmedBalance;
            clr.validatorsExitedBalance = 0;
            setUpValidEpoch(1726660451, _frame, clr); // sets clr.epoch to valid epoch
            vm.deal(address(withdraw), clr.validatorsSkimmedBalance); // add CL rewards
        }
        {
            // mock previous report balances
            bytes32 baseSlot = LastConsensusLayerReport.LAST_CONSENSUS_LAYER_REPORT_SLOT;
            bytes32 validatorsBalanceSlot = bytes32(uint256(baseSlot) + 1); // Assuming validatorsBalance is the second variable
            bytes32 validatorsSkimmedBalanceSlot = bytes32(uint256(baseSlot) + 2); // Assuming validatorsSkimmedBalance is the third variable
            bytes32 validatorsCountSlot = bytes32(uint256(baseSlot) + 5); //storedReport.validatorsCount = _report.validatorsCount;
            uint256 mockValidatorsBalance = 32 ether * (depositCount);
            uint256 mockValidatorsSkimmedBalance = 0;
            vm.store(address(riverProxy), validatorsBalanceSlot, bytes32(mockValidatorsBalance));
            vm.store(address(riverProxy), validatorsSkimmedBalanceSlot, bytes32(mockValidatorsSkimmedBalance));
            vm.store(address(riverProxy), validatorsCountSlot, bytes32(uint256(clr.validatorsCount)));
            // mock the River Address in the withdraw contract (so CL funds can be pulled)
            bytes32 second_storageSlot = RiverAddress.RIVER_ADDRESS_SLOT;
            vm.store(address(withdraw), second_storageSlot, bytes32(uint256(uint160(address(riverProxy)))));
        }
        uint256 preReportBalance = address(riverProxy).balance;
        uint256 preReportSupply = RiverV1(payable(address(riverProxy))).totalUnderlyingSupply();
        uint256 bobPreReportBalance = RiverV1(payable(address(riverProxy))).balanceOfUnderlying(bob);

        // oracle report will pull CL funds
        vm.prank(member);
        OracleV1(address(oracleProxy)).reportConsensusLayerData(clr);

        assert(address(riverProxy).balance == preReportBalance + clr.validatorsSkimmedBalance);
        assert(RiverV1(payable(address(riverProxy))).totalUnderlyingSupply() == preReportSupply);
        assert(RiverV1(payable(address(riverProxy))).balanceOfUnderlying(bob) == bobPreReportBalance);
    }

    function mockDailyCommittableLimit(uint128 maxDailyRelativeCommittable, uint128 minDailyNetCommittableAmount)
        internal
    {
        bytes32 baseSlot = DailyCommittableLimits.DAILY_COMMITTABLE_LIMITS_SLOT;
        bytes32 packedValues =
            bytes32((uint256(minDailyNetCommittableAmount) << 128) | uint256(maxDailyRelativeCommittable));
        vm.store(address(riverProxy), baseSlot, packedValues);
    }

    function setUpOperators() internal {
        address operatorsRegistryAdmin = address(operatorsRegistryFirewall);
        // add operator + validators
        vm.prank(operatorsRegistryAdmin);
        operatorOneIndex =
            OperatorsRegistryV1(address(operatorsRegistryProxy)).addOperator(operatorOneName, operatorOne);
        bytes memory hundredKeysOp1 = genBytes((48 + 96) * 100);
        vm.prank(operatorsRegistryAdmin);
        OperatorsRegistryV1(address(operatorsRegistryProxy)).addValidators(operatorOneIndex, 100, hundredKeysOp1);
        bytes memory hundredKeysOp2 = genBytes((48 + 96) * 100);
        vm.prank(operatorsRegistryAdmin);
        OperatorsRegistryV1(address(operatorsRegistryProxy)).addValidators(operatorTwoIndex, 100, hundredKeysOp2);

        uint256[] memory operatorIndexes = new uint256[](1);
        operatorIndexes[0] = operatorOneIndex;
        uint32[] memory operatorLimits = new uint32[](1);
        operatorLimits[0] = uint32(100);
        // set operator limits
        vm.prank(operatorsRegistryAdmin);
        OperatorsRegistryV1(address(operatorsRegistryProxy)).setOperatorLimits(
            operatorIndexes, operatorLimits, block.number
        );
    }

    function setUpOracleMember(uint256 _salt) internal returns (address) {
        address member = uf._new(_salt);
        vm.prank(admin);
        OracleV1(address(oracleProxy)).addMember(member, 1);

        return member;
    }

    function setUpValidEpoch(
        uint256 initBlockTimestamp,
        uint256 _frame,
        IOracleManagerV1.ConsensusLayerReport memory clr
    ) internal {
        // set the current epoch
        uint256 blockTimestamp = initBlockTimestamp + _frame;
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
