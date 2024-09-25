// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.20;

import "forge-std/Test.sol";
// fixtures
import "./RiverV1ForceCommittable.sol";
import "./OperatorsRegistryWithOverridesV1.sol";
import "./OracleManagerWithOverridesV1.sol";
// mocks
import "../mocks/DepositContractMock.sol";
// contracts
import "../../src/Withdraw.1.sol";
import "../../src/Oracle.1.sol";
import "../../src/ELFeeRecipient.1.sol";
import "../../src/CoverageFund.1.sol";
import "../../src/Allowlist.1.sol";
import "../../src/components/OracleManager.1.sol";
import "../../src/RedeemManager.1.sol";
// utils
import "../utils/BytesGenerator.sol";
import "../utils/events/RiverEvents.sol";
import "../utils/LibImplementationUnbricker.sol";
import "../utils/UserFactory.sol";

/// @title RiverUnitTestBase
/// @author Alluvial Finance Inc.
/// @notice Basic deployment of LC contracts for unit testing
abstract contract RiverUnitTestBase is Test, BytesGenerator, RiverEvents {
    RiverV1ForceCommittable internal river;
    IDepositContract internal deposit;
    WithdrawV1 internal withdraw;
    OracleV1 internal oracle;
    ELFeeRecipientV1 internal elFeeRecipient;
    CoverageFundV1 internal coverageFund;
    AllowlistV1 internal allowlist;
    OperatorsRegistryWithOverridesV1 internal operatorsRegistry;
    OracleManagerWithOverridesV1 internal oracleManager;
    RedeemManagerV1 internal redeemManager;

    address internal admin;
    address internal newAdmin;
    address internal denier;
    address internal collector;
    address internal newCollector;
    address internal allower;
    address internal oracleMember;
    address internal newAllowlist;
    address internal operatorOne;
    address internal operatorOneFeeRecipient;
    address internal operatorTwo;
    address internal operatorTwoFeeRecipient;
    address internal bob;
    address internal joe;

    string internal operatorOneName = "NodeMasters";
    string internal operatorTwoName = "StakePros";

    uint256 internal operatorOneIndex;
    uint256 internal operatorTwoIndex;

    uint64 internal constant epochsPerFrame = 225;
    uint64 internal constant slotsPerEpoch = 32;
    uint64 internal constant secondsPerSlot = 12;
    uint64 internal constant genesisTime = 1695902400;
    uint64 internal constant epochsToAssumedFinality = 4;
    uint256 internal constant annualAprUpperBound = 1000;
    uint256 internal constant relativeLowerBound = 250;
    uint64 internal constant epochsUntilFinal = 4;
    uint128 internal constant minDailyNetCommittableAmount = 3200 ether;
    uint128 internal constant maxDailyRelativeCommittable = 2000;

    function setUp() public virtual {
        setupAddresses();

        vm.warp(857034746);

        elFeeRecipient = new ELFeeRecipientV1();
        LibImplementationUnbricker.unbrick(vm, address(elFeeRecipient));
        coverageFund = new CoverageFundV1();
        LibImplementationUnbricker.unbrick(vm, address(coverageFund));
        oracle = new OracleV1();
        LibImplementationUnbricker.unbrick(vm, address(oracle));
        allowlist = new AllowlistV1();
        LibImplementationUnbricker.unbrick(vm, address(allowlist));
        deposit = new DepositContractMock();
        LibImplementationUnbricker.unbrick(vm, address(deposit));
        withdraw = new WithdrawV1();
        LibImplementationUnbricker.unbrick(vm, address(withdraw));
        river = new RiverV1ForceCommittable();
        LibImplementationUnbricker.unbrick(vm, address(river));
        operatorsRegistry = new OperatorsRegistryWithOverridesV1();
        LibImplementationUnbricker.unbrick(vm, address(operatorsRegistry));
        oracleManager = new OracleManagerWithOverridesV1(
            address(oracle),
            admin,
            epochsPerFrame,
            slotsPerEpoch,
            secondsPerSlot,
            genesisTime,
            epochsToAssumedFinality,
            annualAprUpperBound,
            relativeLowerBound
        );
        LibImplementationUnbricker.unbrick(vm, address(oracleManager));
        allowlist.initAllowlistV1(admin, allower);
        allowlist.initAllowlistV1_1(denier);
        operatorsRegistry.initOperatorsRegistryV1(admin, address(river));
        elFeeRecipient.initELFeeRecipientV1(address(river));
        coverageFund.initCoverageFundV1(address(river));
    }

    /// @notice Setup the addresses for testing
    function setupAddresses() internal {
        admin = makeAddr("admin");
        newAdmin = makeAddr("newAdmin");
        denier = makeAddr("denier");
        collector = makeAddr("collector");
        newCollector = makeAddr("newCollector");
        allower = makeAddr("allower");
        oracleMember = makeAddr("oracleMember");
        newAllowlist = makeAddr("newAllowlist");
        operatorOne = makeAddr("operatorOne");
        operatorTwo = makeAddr("operatorTwo");
        bob = makeAddr("bob");
        joe = makeAddr("joe");
    }
}
