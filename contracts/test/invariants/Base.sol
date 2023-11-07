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
import "../../src/TUPProxy.sol";

import {StakerService} from "./handlers/StakerService.sol";
import {OperatorService} from "./handlers/OperatorService.sol";
import {OracleDaemonService} from "./handlers/OracleDaemonService.sol";

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
    IDepositContract internal deposit;
    RiverV1 internal riverImplementation;
    WithdrawV1 internal withdrawImplementation;
    OracleV1 internal oracleImplementation;
    ELFeeRecipientV1 internal elFeeRecipientImplementation;
    CoverageFundV1 internal coverageFundImplementation;
    AllowlistV1 internal allowlistImplementation;
    OperatorsRegistryV1 internal operatorsRegistryImplementation;
    RedeemManagerV1 internal redeemManagerImplementation;

    TUPProxy internal riverProxy;
    TUPProxy internal withdrawProxy;
    TUPProxy internal oracleProxy;
    TUPProxy internal elFeeRecipientProxy;
    TUPProxy internal coverageFundProxy;
    TUPProxy internal allowListProxy;
    TUPProxy internal operatorsRegistryProxy;
    TUPProxy internal redeemManagerProxy;

    RiverV1 public river;
    WithdrawV1 public withdraw;
    OracleV1 public oracle;
    ELFeeRecipientV1 public elFeeRecipient;
    CoverageFundV1 public coverageFund;
    AllowlistV1 public allowlist;
    OperatorsRegistryV1 public operatorsRegistry;
    RedeemManagerV1 public redeemManager;

    address public admin;
    address internal proxyAdmin;
    address internal newAdmin;
    address internal collector;
    address internal newCollector;
    address internal allower;
    address internal newAllowlist;
    address public oracleMember;
    address internal bob;
    address internal joe;

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
    OperatorService public operatorService;
    OracleDaemonService public oracleDaemonService;

    function setUp() public virtual {
        deployProtocol();
        deployServices();
        addTargetSelectors();
        excludeDeployedContracts();
    }

    function loadBlockState() public {
        vm.warp(getTimeStamp());
        vm.roll(getBlockNumber());
    }

    function writeBlockState() public {
        setBlockNumber(block.number + 1);
        setTimeStamp(block.timestamp + 12);
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
        proxyAdmin = makeAddr("proxyAdmin");
        newAdmin = makeAddr("newAdmin");
        collector = makeAddr("collector");
        newCollector = makeAddr("newCollector");
        allower = makeAddr("allower");
        oracleMember = makeAddr("oracleMember");

        newAllowlist = makeAddr("newAllowlist");
        bob = makeAddr("bob");
        joe = makeAddr("joe");

        vm.warp(857034746);

        deposit = new DepositContractMock();

        // Implementation deployment
        withdrawImplementation = new WithdrawV1();
        allowlistImplementation = new AllowlistV1();
        elFeeRecipientImplementation = new ELFeeRecipientV1();
        coverageFundImplementation = new CoverageFundV1();
        oracleImplementation = new OracleV1();
        operatorsRegistryImplementation = new OperatorsRegistryV1();
        redeemManagerImplementation = new RedeemManagerV1();
        riverImplementation = new RiverV1();

        // Proxy deployment
        withdrawProxy = new TUPProxy(address(withdrawImplementation), proxyAdmin, "");
        allowListProxy = new TUPProxy(
            address(allowlistImplementation),
            proxyAdmin,
            abi.encodeWithSelector(AllowlistV1.initAllowlistV1.selector, admin, allower)
        );
        elFeeRecipientProxy = new TUPProxy(address(elFeeRecipientImplementation), proxyAdmin, "");
        coverageFundProxy = new TUPProxy(address(coverageFundImplementation), proxyAdmin, "");
        operatorsRegistryProxy = new TUPProxy(address(operatorsRegistryImplementation), proxyAdmin, "");
        redeemManagerProxy = new TUPProxy(address(redeemManagerImplementation), proxyAdmin, "");
        riverProxy = new TUPProxy(address(riverImplementation), proxyAdmin, "");
        oracleProxy = new TUPProxy(address(oracleImplementation), proxyAdmin, "");

        bytes32 withdrawalCredentials = WithdrawV1(address(withdrawProxy)).getCredentials();
        // Proxy initialization
        OperatorsRegistryV1(address(operatorsRegistryProxy)).initOperatorsRegistryV1(admin, address(riverProxy));
        ELFeeRecipientV1(payable(address(elFeeRecipientProxy))).initELFeeRecipientV1(address(riverProxy));
        CoverageFundV1(payable(address(coverageFundProxy))).initCoverageFundV1(address(riverProxy));
        RedeemManagerV1(payable(address(redeemManagerProxy))).initializeRedeemManagerV1(address(riverProxy));
        RiverV1(payable(address(riverProxy))).initRiverV1(
            address(deposit),
            address(elFeeRecipientProxy),
            withdrawalCredentials,
            address(oracleProxy),
            admin,
            address(allowListProxy),
            address(operatorsRegistryProxy),
            collector,
            500
        );
        OracleV1(address(oracleProxy)).initOracleV1(address(riverProxy), admin, 225, 32, 12, 0, 1000, 500);

        // Assigning proxy contracts to variables for readability
        river = RiverV1(payable(address(riverProxy)));
        withdraw = WithdrawV1(address(withdrawProxy));
        oracle = OracleV1(address(oracleProxy));
        elFeeRecipient = ELFeeRecipientV1(payable(address(elFeeRecipientProxy)));
        coverageFund = CoverageFundV1(payable(address(coverageFundProxy)));
        allowlist = AllowlistV1(address(allowListProxy));
        operatorsRegistry = OperatorsRegistryV1(address(operatorsRegistryProxy));
        redeemManager = RedeemManagerV1(address(redeemManagerProxy));

        vm.prank(admin);
        river.setCoverageFund(address(coverageFund));
    }

    function deployServices() internal {
        stakerService = new StakerService(this);
        address[] memory stakerServiceArray = new address[](1);
        stakerServiceArray[0] = address(stakerService);
        uint256[] memory stakerServiceMask = new uint256[](1);
        stakerServiceMask[0] = 5;
        vm.prank(allower);
        allowlist.allow(stakerServiceArray, stakerServiceMask);

        operatorService = new OperatorService(this);
        oracleDaemonService = new OracleDaemonService(this);
    }

    function dealETH(address _to, uint256 _amount) public {
        console.log("dealing");
        vm.deal(_to, _amount);
    }

    function addTargetSelectors() internal virtual {
        targetSelector(stakerService.getTargetSelectors());
        // targetSelector(operatorService.getTargetSelectors());
        targetSelector(oracleDaemonService.getTargetSelectors());
    }

    function excludeDeployedContracts() internal virtual {
        excludeContract(address(river));
        excludeContract(address(deposit));
        excludeContract(address(withdraw));
        excludeContract(address(oracle));
        excludeContract(address(elFeeRecipient));
        excludeContract(address(coverageFund));
        excludeContract(address(allowlist));
        excludeContract(address(operatorsRegistry));
        excludeContract(address(redeemManager));
    }
}
