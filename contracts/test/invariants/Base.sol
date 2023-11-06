//SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import {Test} from "forge-std/Test.sol";

import "../utils/BytesGenerator.sol";
import "../utils/LibImplementationUnbricker.sol";
import "../mocks/DepositContractMock.sol";

import "../../src/libraries/LibAllowlistMasks.sol";
import "../../src/Allowlist.1.sol";
import "../../src/River.1.sol";
import "../../src/interfaces/IDepositContract.sol";
import "../../src/Withdraw.1.sol";
import "../../src/Oracle.1.sol";
import "../../src/ELFeeRecipient.1.sol";
import "../../src/OperatorsRegistry.1.sol";
import "../../src/CoverageFund.1.sol";
import "../../src/RedeemManager.1.sol";

import {StakerService} from "./handlers/StakerService.sol";

// 1. add getTimestamp, getBlockNumber, setTimestamp, setBlockNumber to Base
// 2. create BaseService that is constructed with a Base instance
// 3. BaseService has a modifier that loads timestamp and block number into the context using vm
// 4. The modifier should save everything back to base using the setters and reading the values from block.timestamp and block.number
// 5. BaseService should return the target selectors that the invariant tests should call (an array of inputs sent to Test.targetSelector). It should be selectors of methods
//    on the BaseService. We can prefix all of them with "action_" so we can quickly identify them. They should all use the modifier.
//    ex: StakerService, has one address that represents a staker, exposes `action_stakeAll`, `action_stakePercent(uint256)`, `action_unstakeAll` etc ...
// 6. Base setup should deploy all stack, then deploy all Services and for each one retrieve the list of target selectors and call Test.targetSelector for each one
// 7. Write invariant_test test that does a dummy action just to see that the services are called
// 8. run "env FOUNDRY_INVARIANT_FAIL_ON_REVERT=true FOUNDRY_INVARIANT_RUNS=128 FOUNDRY_INVARIANT_DEPTH=128 forge test -vvv --match-contract INVARIANT"
// 9. It would be good to move Base and the logic around block.timestamp and block.number into another contract and inherit from that on the test contract. This way we can call
//    the contract "INVARIANT_River" or something like that in order for the --match-contract argument to work

contract Base is Test, BytesGenerator {
    // Protocol contracts
    RiverV1 public river;
    IDepositContract public deposit;
    WithdrawV1 public withdraw;
    OracleV1 public oracle;
    ELFeeRecipientV1 public elFeeRecipient;
    CoverageFundV1 public coverageFund;
    AllowlistV1 public allowlist;
    OperatorsRegistryV1 public operatorsRegistry;

    address internal admin;
    address internal newAdmin;
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

    uint64 constant epochsPerFrame = 225;
    uint64 constant slotsPerEpoch = 32;
    uint64 constant secondsPerSlot = 12;
    uint64 constant epochsUntilFinal = 4;

    uint128 constant maxDailyNetCommittableAmount = 3200 ether;
    uint128 constant maxDailyRelativeCommittableAmount = 2000;

    // Tracking data
    uint256 timeStamp;
    uint256 blockNumber;

    // Services
    StakerService public stakerService;

    function setUp() public virtual {
        deployProtocol();
        deployServices();
        addTargetSelectors();
    }

    function loadBlockState() public {
        vm.warp(getTimeStamp());
        vm.roll(getBlockNumber());
    }

    function writeBlockState() public {
        setBlockNumber(block.number + 1);
        setTimeStamp(block.timestamp + 1);
    }

    function getTimeStamp() public view returns (uint256) {
        return timeStamp;
    }

    function getBlockNumber() public view returns (uint256) {
        return blockNumber;
    }

    function setTimeStamp(uint256 _timeStamp) internal {
        timeStamp = _timeStamp;
    }

    function setBlockNumber(uint256 _blockNumber) internal {
        blockNumber = _blockNumber;
    }

    // @dev: This function will deploy the protocol with the correct config
    function deployProtocol() internal {
        admin = makeAddr("admin");
        newAdmin = makeAddr("newAdmin");
        collector = makeAddr("collector");
        newCollector = makeAddr("newCollector");
        allower = makeAddr("allower");
        oracleMember = makeAddr("oracleMember");
        newAllowlist = makeAddr("newAllowlist");
        operatorOne = makeAddr("operatorOne");
        operatorTwo = makeAddr("operatorTwo");
        bob = makeAddr("bob");
        joe = makeAddr("joe");

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
        river = new RiverV1();
        LibImplementationUnbricker.unbrick(vm, address(river));
        operatorsRegistry = new OperatorsRegistryV1();
        LibImplementationUnbricker.unbrick(vm, address(operatorsRegistry));

        bytes32 withdrawalCredentials = withdraw.getCredentials();
        allowlist.initAllowlistV1(admin, allower);
        operatorsRegistry.initOperatorsRegistryV1(admin, address(river));
        elFeeRecipient.initELFeeRecipientV1(address(river));
        coverageFund.initCoverageFundV1(address(river));

        river.initRiverV1(
            address(deposit),
            address(elFeeRecipient),
            withdrawalCredentials,
            address(oracle),
            admin,
            address(allowlist),
            address(operatorsRegistry),
            collector,
            500
        );
        oracle.initOracleV1(address(river), admin, 225, 32, 12, 0, 1000, 500);
        vm.startPrank(admin);

        river.setCoverageFund(address(coverageFund));

        // ===================

        oracle.addMember(oracleMember, 1);

        operatorOneIndex = operatorsRegistry.addOperator(operatorOneName, operatorOne);
        operatorTwoIndex = operatorsRegistry.addOperator(operatorTwoName, operatorTwo);

        bytes memory hundredKeysOp1 = genBytes((48 + 96) * 100);

        operatorsRegistry.addValidators(operatorOneIndex, 100, hundredKeysOp1);

        bytes memory hundredKeysOp2 = genBytes((48 + 96) * 100);

        operatorsRegistry.addValidators(operatorTwoIndex, 100, hundredKeysOp2);

        uint256[] memory operatorIndexes = new uint256[](2);
        operatorIndexes[0] = operatorOneIndex;
        operatorIndexes[1] = operatorTwoIndex;
        uint32[] memory operatorLimits = new uint32[](2);
        operatorLimits[0] = 100;
        operatorLimits[1] = 100;

        operatorsRegistry.setOperatorLimits(operatorIndexes, operatorLimits, block.number);
        vm.stopPrank();
    }

    function deployServices() internal {
        stakerService = new StakerService(this);
    }

    function dealETH(address _to, uint256 _amount) external {
        vm.deal(_to, _amount);
    }

    function addTargetSelectors() internal virtual {
        StdInvariant.FuzzSelector memory selectors = stakerService.getTargetSelectors();
        targetSelector(selectors);
    }
}
