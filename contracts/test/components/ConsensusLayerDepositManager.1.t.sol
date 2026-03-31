//SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.34;

import "forge-std/Test.sol";

import "../../src/interfaces/IOperatorRegistry.1.sol";
import "../OperatorAllocationTestBase.sol";
import "../../src/components/ConsensusLayerDepositManager.1.sol";
import "../../src/libraries/LibBytes.sol";
import "../utils/LibImplementationUnbricker.sol";
import "../OperatorsRegistry.1.t.sol";

import "../mocks/DepositContractMock.sol";
import "../mocks/DepositContractEnhancedMock.sol";
import "../mocks/DepositContractInvalidMock.sol";

contract ConsensusLayerDepositManagerV1ExposeInitializer is ConsensusLayerDepositManagerV1 {
    function _getRiverAdmin() internal pure override returns (address) {
        return address(0);
    }

    function _incrementFundedETH(uint256[] memory) internal override {}

    function publicConsensusLayerDepositManagerInitializeV1(
        address _depositContractAddress,
        bytes32 _withdrawalCredentials
    ) external {
        ConsensusLayerDepositManagerV1.initConsensusLayerDepositManagerV1(
            _depositContractAddress, _withdrawalCredentials
        );
        _setKeeper(address(0x1));
    }

    function setKeeper(address _keeper) external {
        _setKeeper(_keeper);
    }

    function sudoSetWithdrawalCredentials(bytes32 _withdrawalCredentials) external {
        WithdrawalCredentials.set(_withdrawalCredentials);
    }

    function sudoSyncBalance() external {
        _setCommittedBalance(address(this).balance);
    }

    function _setCommittedBalance(uint256 newCommittedBalance) internal override {
        CommittedBalance.set(newCommittedBalance);
    }
}

/// @notice Deposit manager test double that delegates _getNextValidators to the real OperatorsRegistry (same as River in production)
contract ConsensusLayerDepositManagerV1UsesRegistry is ConsensusLayerDepositManagerV1 {
    IOperatorsRegistryV1 public registry;

    function _getRiverAdmin() internal pure override returns (address) {
        return address(0);
    }

    function _incrementFundedETH(uint256[] memory _fundedETH) internal override {
        registry.incrementFundedETH(_fundedETH);
    }

    function setRegistry(IOperatorsRegistryV1 _registry) external {
        registry = _registry;
    }

    function publicConsensusLayerDepositManagerInitializeV1(
        address _depositContractAddress,
        bytes32 _withdrawalCredentials
    ) external {
        ConsensusLayerDepositManagerV1.initConsensusLayerDepositManagerV1(
            _depositContractAddress, _withdrawalCredentials
        );
        _setKeeper(address(0x1));
    }

    function setKeeper(address _keeper) external {
        _setKeeper(_keeper);
    }

    function sudoSyncBalance() external {
        _setCommittedBalance(address(this).balance);
    }

    function _setCommittedBalance(uint256 newCommittedBalance) internal override {
        CommittedBalance.set(newCommittedBalance);
    }
}

contract ConsensusLayerDepositManagerV1InitTests is Test {
    bytes32 internal withdrawalCredentials = bytes32(uint256(1));

    ConsensusLayerDepositManagerV1 internal depositManager;
    IDepositContract internal depositContract;

    event SetDepositContractAddress(address indexed depositContract);
    event SetWithdrawalCredentials(bytes32 withdrawalCredentials);

    function testDepositContractEvent() public {
        depositContract = new DepositContractMock();

        depositManager = new ConsensusLayerDepositManagerV1ExposeInitializer();
        LibImplementationUnbricker.unbrick(vm, address(depositManager));

        vm.expectEmit(true, true, true, true);
        emit SetDepositContractAddress(address(depositContract));
        ConsensusLayerDepositManagerV1ExposeInitializer(address(depositManager))
            .publicConsensusLayerDepositManagerInitializeV1(address(depositContract), withdrawalCredentials);
    }

    function testWithdrawalCredentialsEvent() public {
        depositContract = new DepositContractMock();

        depositManager = new ConsensusLayerDepositManagerV1ExposeInitializer();
        LibImplementationUnbricker.unbrick(vm, address(depositManager));
        vm.expectEmit(true, true, true, true);
        emit SetWithdrawalCredentials(withdrawalCredentials);
        ConsensusLayerDepositManagerV1ExposeInitializer(address(depositManager))
            .publicConsensusLayerDepositManagerInitializeV1(address(depositContract), withdrawalCredentials);
    }
}

contract ConsensusLayerDepositManagerV1Tests is OperatorAllocationTestBase {
    bytes32 internal withdrawalCredentials = bytes32(uint256(1));

    ConsensusLayerDepositManagerV1 internal depositManager;
    IDepositContract internal depositContract;

    function setUp() public {
        depositContract = new DepositContractMock();

        depositManager = new ConsensusLayerDepositManagerV1ExposeInitializer();
        LibImplementationUnbricker.unbrick(vm, address(depositManager));
        ConsensusLayerDepositManagerV1ExposeInitializer(address(depositManager))
            .publicConsensusLayerDepositManagerInitializeV1(address(depositContract), withdrawalCredentials);
    }

    function testRetrieveWithdrawalCredentials() public view {
        assert(depositManager.getWithdrawalCredentials() == withdrawalCredentials);
    }

    function testDepositNotEnoughFunds() public {
        // committedBalance == 0 triggers NotEnoughFunds; balance exceeding deposits triggers ValidatorDepositsExceedCommittedBalance
        vm.deal(address(depositManager), 0);
        ConsensusLayerDepositManagerV1ExposeInitializer(address(depositManager)).sudoSyncBalance();
        vm.expectRevert(abi.encodeWithSignature("NotEnoughFunds()"));
        vm.prank(address(0x1));
        depositManager.depositToConsensusLayerWithDepositRoot(_createAllocation(1), bytes32(0));
    }

    function testDepositTenValidators() public {
        vm.deal(address(depositManager), 320 ether);
        ConsensusLayerDepositManagerV1ExposeInitializer(address(depositManager)).sudoSyncBalance();
        assert(address(depositManager).balance == 320 ether);
        vm.prank(address(0x1));
        depositManager.depositToConsensusLayerWithDepositRoot(_createAllocation(10), bytes32(0));
        assert(address(depositManager).balance == 0);
    }

    function testDepositLessThanMaxDepositableCount() public {
        vm.deal(address(depositManager), 640 ether);
        ConsensusLayerDepositManagerV1ExposeInitializer(address(depositManager)).sudoSyncBalance();
        assert(address(depositManager).balance == 640 ether);
        vm.prank(address(0x1));
        depositManager.depositToConsensusLayerWithDepositRoot(_createAllocation(10), bytes32(0));
        assert(address(depositManager).balance == 320 ether);
    }
}

contract ConsensusLayerDepositManagerV1ControllableValidatorKeyRequest is ConsensusLayerDepositManagerV1 {
    function _getRiverAdmin() internal pure override returns (address) {
        return address(0);
    }

    function _incrementFundedETH(uint256[] memory) internal override {}

    function publicConsensusLayerDepositManagerInitializeV1(
        address _depositContractAddress,
        bytes32 _withdrawalCredentials
    ) external {
        ConsensusLayerDepositManagerV1.initConsensusLayerDepositManagerV1(
            _depositContractAddress, _withdrawalCredentials
        );
        _setKeeper(address(0x1));
    }

    function setKeeper(address _keeper) external {
        _setKeeper(_keeper);
    }

    function sudoSetWithdrawalCredentials(bytes32 _withdrawalCredentials) external {
        WithdrawalCredentials.set(_withdrawalCredentials);
    }

    function sudoSyncBalance() external {
        _setCommittedBalance(address(this).balance);
    }

    function _setCommittedBalance(uint256 newCommittedBalance) internal override {
        CommittedBalance.set(newCommittedBalance);
    }
}

contract ConsensusLayerDepositManagerV1ErrorTests is OperatorAllocationTestBase {
    bytes32 internal withdrawalCredentials = bytes32(uint256(1));

    ConsensusLayerDepositManagerV1 internal depositManager;
    IDepositContract internal depositContract;

    function setUp() public {
        depositContract = new DepositContractMock();

        depositManager = new ConsensusLayerDepositManagerV1ControllableValidatorKeyRequest();
        LibImplementationUnbricker.unbrick(vm, address(depositManager));
        ConsensusLayerDepositManagerV1ControllableValidatorKeyRequest(address(depositManager))
            .publicConsensusLayerDepositManagerInitializeV1(address(depositContract), withdrawalCredentials);
    }

    // Pubkey/signature validation now happens inline via ValidatorDeposit
    function testInconsistentPublicKey() public {
        vm.deal(address(depositManager), 32 ether);
        ConsensusLayerDepositManagerV1ControllableValidatorKeyRequest(address(depositManager)).sudoSyncBalance();
        // Pass a 49-byte pubkey directly
        IOperatorsRegistryV1.ValidatorDeposit[] memory alloc = new IOperatorsRegistryV1.ValidatorDeposit[](1);
        alloc[0] = IOperatorsRegistryV1.ValidatorDeposit({
            operatorIndex: 0, pubkey: bytes(new bytes(49)), signature: bytes(new bytes(96)), depositAmount: 32 ether
        });
        vm.expectRevert(abi.encodeWithSignature("InconsistentPublicKey()"));
        vm.prank(address(0x1));
        depositManager.depositToConsensusLayerWithDepositRoot(alloc, bytes32(0));
    }

    function testInconsistentSignature() public {
        vm.deal(address(depositManager), 32 ether);
        ConsensusLayerDepositManagerV1ControllableValidatorKeyRequest(address(depositManager)).sudoSyncBalance();
        // Pass a 97-byte signature directly
        IOperatorsRegistryV1.ValidatorDeposit[] memory alloc = new IOperatorsRegistryV1.ValidatorDeposit[](1);
        alloc[0] = IOperatorsRegistryV1.ValidatorDeposit({
            operatorIndex: 0, pubkey: bytes(new bytes(48)), signature: bytes(new bytes(97)), depositAmount: 32 ether
        });
        vm.expectRevert(abi.encodeWithSignature("InconsistentSignature()"));
        vm.prank(address(0x1));
        depositManager.depositToConsensusLayerWithDepositRoot(alloc, bytes32(0));
    }

    function testEmptyAllocations() public {
        vm.deal(address(depositManager), 32 ether);
        ConsensusLayerDepositManagerV1ControllableValidatorKeyRequest(address(depositManager)).sudoSyncBalance();
        IOperatorsRegistryV1.ValidatorDeposit[] memory alloc = new IOperatorsRegistryV1.ValidatorDeposit[](0);
        vm.expectRevert(abi.encodeWithSignature("EmptyAllocations()"));
        vm.prank(address(0x1));
        depositManager.depositToConsensusLayerWithDepositRoot(alloc, bytes32(0));
    }

    function testAllocationExceedsCommittedBalance() public {
        vm.deal(address(depositManager), 2 * 32 ether);
        ConsensusLayerDepositManagerV1ControllableValidatorKeyRequest(address(depositManager)).sudoSyncBalance();
        vm.expectRevert(abi.encodeWithSignature("ValidatorDepositsExceedCommittedBalance()"));
        vm.prank(address(0x1));
        depositManager.depositToConsensusLayerWithDepositRoot(_createAllocation(5), bytes32(0));
    }

    function testAllocationExceedsCommittedBalanceByOne() public {
        vm.deal(address(depositManager), 2 * 32 ether);
        ConsensusLayerDepositManagerV1ControllableValidatorKeyRequest(address(depositManager)).sudoSyncBalance();
        vm.expectRevert(abi.encodeWithSignature("ValidatorDepositsExceedCommittedBalance()"));
        vm.prank(address(0x1));
        depositManager.depositToConsensusLayerWithDepositRoot(_createAllocation(3), bytes32(0));
    }

    function testAllocationExceedsCommittedBalanceMultiOperator() public {
        vm.deal(address(depositManager), 3 * 32 ether);
        ConsensusLayerDepositManagerV1ControllableValidatorKeyRequest(address(depositManager)).sudoSyncBalance();

        // 2 from op0 + 2 from op1 = 4 total = 128 ether > 96 ether committed
        IOperatorsRegistryV1.ValidatorDeposit[] memory allocations = new IOperatorsRegistryV1.ValidatorDeposit[](4);
        for (uint256 i = 0; i < 2; ++i) {
            allocations[i] = IOperatorsRegistryV1.ValidatorDeposit({
                operatorIndex: 0, pubkey: bytes(new bytes(48)), signature: bytes(new bytes(96)), depositAmount: 32 ether
            });
        }
        for (uint256 i = 2; i < 4; ++i) {
            allocations[i] = IOperatorsRegistryV1.ValidatorDeposit({
                operatorIndex: 1, pubkey: bytes(new bytes(48)), signature: bytes(new bytes(96)), depositAmount: 32 ether
            });
        }

        vm.expectRevert(abi.encodeWithSignature("ValidatorDepositsExceedCommittedBalance()"));
        vm.prank(address(0x1));
        depositManager.depositToConsensusLayerWithDepositRoot(allocations, bytes32(0));
    }

    function testAllocationExactlyMatchesCommittedBalance() public {
        vm.deal(address(depositManager), 3 * 32 ether);
        ConsensusLayerDepositManagerV1ControllableValidatorKeyRequest(address(depositManager)).sudoSyncBalance();
        vm.prank(address(0x1));
        depositManager.depositToConsensusLayerWithDepositRoot(_createAllocation(3), bytes32(0));
        assertEq(address(depositManager).balance, 0, "balance should be 0");
    }
}

/// @notice Integration tests for the full deposit flow: Keeper -> DepositManager -> Registry.pickNextValidatorsToDeposit -> DepositContract
contract ConsensusLayerDepositManagerV1FullDepositFlowTests is OperatorAllocationTestBase, BytesGenerator {
    bytes32 internal withdrawalCredentials = bytes32(uint256(1));
    address internal keeper = address(0x1);

    ConsensusLayerDepositManagerV1 internal depositManager;
    OperatorsRegistryV1 internal registry;
    IDepositContract internal depositContract;
    address internal admin;

    function setUp() public {
        admin = makeAddr("admin");
        depositContract = new DepositContractMock();

        depositManager = new ConsensusLayerDepositManagerV1UsesRegistry();
        registry = new OperatorsRegistryInitializableV1();

        LibImplementationUnbricker.unbrick(vm, address(depositManager));
        LibImplementationUnbricker.unbrick(vm, address(registry));

        registry.initOperatorsRegistryV1(admin, address(depositManager));
        ConsensusLayerDepositManagerV1UsesRegistry(address(depositManager))
            .publicConsensusLayerDepositManagerInitializeV1(address(depositContract), withdrawalCredentials);
        ConsensusLayerDepositManagerV1UsesRegistry(address(depositManager)).setRegistry(registry);
        // Keeper is set in init to 0x1; set again via contract to ensure storage is correct (e.g. after unbrick)
        ConsensusLayerDepositManagerV1UsesRegistry(address(depositManager)).setKeeper(keeper);
    }

    /// @dev Full flow: single operator, keeper deposits, registry funded and deposited count updated
    function testFullDepositFlowSingleOperator() public {
        vm.startPrank(admin);
        registry.addOperator("Op0", admin);
        vm.stopPrank();

        uint256 toDeposit = 2;
        vm.deal(address(depositManager), toDeposit * 32 ether);
        ConsensusLayerDepositManagerV1UsesRegistry(address(depositManager)).sudoSyncBalance();

        bytes32 depositRoot = depositContract.get_deposit_root();
        vm.prank(keeper);
        depositManager.depositToConsensusLayerWithDepositRoot(_createAllocation(0, toDeposit), depositRoot);

        assertEq(
            registry.getOperator(0).funded, toDeposit * 32 ether, "operator0 was not funded with the correct count"
        );
        assertEq(depositManager.getTotalDepositedETH(), toDeposit * 32 ether, "incorrect deposited validator count");
        assertEq(address(depositManager).balance, 0, "manager balance after deposit");
    }

    /// @dev Fuzz: full flow single operator with variable deposit count
    function testFullDepositFlowSingleOperatorFuzz(uint96 _keyCount, uint96 _toDeposit) public {
        uint256 keyCount = bound(_keyCount, 1, 12);
        uint256 toDeposit = bound(_toDeposit, 1, keyCount);

        vm.startPrank(admin);
        registry.addOperator("Op0", admin);
        vm.stopPrank();

        vm.deal(address(depositManager), toDeposit * 32 ether);
        ConsensusLayerDepositManagerV1UsesRegistry(address(depositManager)).sudoSyncBalance();

        bytes32 depositRoot = depositContract.get_deposit_root();
        vm.prank(keeper);
        depositManager.depositToConsensusLayerWithDepositRoot(_createAllocation(0, toDeposit), depositRoot);

        assertEq(registry.getOperator(0).funded, toDeposit * 32 ether, "operator0 funded");
        assertEq(depositManager.getTotalDepositedETH(), toDeposit * 32 ether, "deposited count");
        assertEq(address(depositManager).balance, 0, "manager balance");
    }

    /// @dev Fuzz: full flow two operators with variable allocation amounts
    function testFullDepositFlowMultiOperatorFuzz(uint96 _keyCount, uint96 _fromOp0, uint96 _fromOp1) public {
        uint256 keyCount = bound(_keyCount, 1, 12);
        uint256 fromOp0 = bound(_fromOp0, 1, keyCount);
        uint256 fromOp1 = bound(_fromOp1, 1, keyCount);
        uint256 total = fromOp0 + fromOp1;

        vm.startPrank(admin);
        registry.addOperator("Op0", admin);
        registry.addOperator("Op1", admin);
        vm.stopPrank();

        vm.deal(address(depositManager), total * 32 ether);
        ConsensusLayerDepositManagerV1UsesRegistry(address(depositManager)).sudoSyncBalance();

        uint256[] memory ops = new uint256[](2);
        ops[0] = 0;
        ops[1] = 1;
        uint32[] memory counts = new uint32[](2);
        counts[0] = uint32(fromOp0);
        counts[1] = uint32(fromOp1);

        bytes32 depositRoot = depositContract.get_deposit_root();
        vm.prank(keeper);
        depositManager.depositToConsensusLayerWithDepositRoot(_createAllocation(ops, counts), depositRoot);

        assertEq(registry.getOperator(0).funded, fromOp0 * 32 ether, "op0 funded");
        assertEq(registry.getOperator(1).funded, fromOp1 * 32 ether, "op1 funded");
        assertEq(depositManager.getTotalDepositedETH(), total * 32 ether, "deposited count");
        assertEq(address(depositManager).balance, 0, "manager balance");
    }

    /// @dev Full flow: three operators with middle one inactive; allocation only to op0 and op2
    function testFullDepositFlowWithInactiveOperatorInMiddle() public {
        vm.startPrank(admin);
        registry.addOperator("Op0", admin);
        registry.addOperator("Op1", admin);
        registry.addOperator("Op2", admin);
        registry.setOperatorStatus(1, false);
        vm.stopPrank();

        uint256 fromOp0 = 2;
        uint256 fromOp2 = 3;
        uint256 total = fromOp0 + fromOp2;
        vm.deal(address(depositManager), total * 32 ether);
        ConsensusLayerDepositManagerV1UsesRegistry(address(depositManager)).sudoSyncBalance();

        uint256[] memory ops = new uint256[](2);
        ops[0] = 0;
        ops[1] = 2;
        uint32[] memory counts = new uint32[](2);
        counts[0] = uint32(fromOp0);
        counts[1] = uint32(fromOp2);

        bytes32 depositRoot = depositContract.get_deposit_root();
        vm.prank(keeper);
        depositManager.depositToConsensusLayerWithDepositRoot(_createAllocation(ops, counts), depositRoot);

        assertEq(registry.getOperator(0).funded, fromOp0 * 32 ether, "op0 funded");
        assertEq(registry.getOperator(1).funded, 0, "op1 inactive, not funded");
        assertEq(registry.getOperator(2).funded, fromOp2 * 32 ether, "op2 funded");
        assertEq(depositManager.getTotalDepositedETH(), total * 32 ether, "deposited count");
    }

    /// @dev Full flow: inactive operators can still be funded (incrementFundedETH does not check active status)
    function testFullDepositFlowRevertsWhenRegistryRevertsInactiveOperator() public {
        vm.startPrank(admin);
        registry.addOperator("Op0", admin);
        registry.setOperatorStatus(0, false);
        vm.stopPrank();

        vm.deal(address(depositManager), 32 ether);
        ConsensusLayerDepositManagerV1UsesRegistry(address(depositManager)).sudoSyncBalance();

        bytes32 depositRoot = depositContract.get_deposit_root();
        vm.prank(keeper);
        vm.expectRevert(abi.encodeWithSignature("InactiveOperator(uint256)", 0));
        depositManager.depositToConsensusLayerWithDepositRoot(_createAllocation(0, 1), depositRoot);
    }

    /// @dev Only keeper can call depositToConsensusLayerWithDepositRoot
    function testFullDepositFlowOnlyKeeperCanDeposit() public {
        vm.startPrank(admin);
        registry.addOperator("Op0", admin);
        vm.stopPrank();

        vm.deal(address(depositManager), 2 * 32 ether);
        ConsensusLayerDepositManagerV1UsesRegistry(address(depositManager)).sudoSyncBalance();

        bytes32 depositRoot = depositContract.get_deposit_root();
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSignature("OnlyKeeper()"));
        depositManager.depositToConsensusLayerWithDepositRoot(_createAllocation(0, 1), depositRoot);
    }

    /// @dev Reverts before depositing when operator has ignored exit requests
    function testFullDepositFlowRevertsWhenOperatorIgnoredExitRequests() public {
        vm.startPrank(admin);
        registry.addOperator("Op0", admin);
        vm.stopPrank();

        // Give the operator some funded validators then request exits without stopping any
        OperatorsRegistryInitializableV1(address(registry)).sudoSetFunded(0, 5);
        OperatorsRegistryInitializableV1(address(registry)).sudoExitRequests(0, 5);

        vm.deal(address(depositManager), 32 ether);
        ConsensusLayerDepositManagerV1UsesRegistry(address(depositManager)).sudoSyncBalance();

        bytes32 depositRoot = depositContract.get_deposit_root();
        vm.prank(keeper);
        vm.expectRevert(abi.encodeWithSignature("OperatorIgnoredExitRequests(uint256)", 0));
        depositManager.depositToConsensusLayerWithDepositRoot(_createAllocation(0, 1), depositRoot);

        assertEq(registry.getOperator(0).funded, 5, "funded unchanged on revert");
        assertEq(depositManager.getTotalDepositedETH(), 0, "no deposited count");
        assertEq(address(depositManager).balance, 32 ether, "balance unchanged");
    }

    /// @dev Sequential deposits: first 2 validators, then 3 more from same operator
    function testFullDepositFlowSequentialDeposits() public {
        vm.startPrank(admin);
        registry.addOperator("Op0", admin);
        vm.stopPrank();

        vm.deal(address(depositManager), 5 * 32 ether);
        ConsensusLayerDepositManagerV1UsesRegistry(address(depositManager)).sudoSyncBalance();

        bytes32 depositRoot = depositContract.get_deposit_root();
        vm.prank(keeper);
        depositManager.depositToConsensusLayerWithDepositRoot(_createAllocation(0, 2), depositRoot);

        assertEq(registry.getOperator(0).funded, 2 * 32 ether, "after first batch");
        assertEq(depositManager.getTotalDepositedETH(), 2 * 32 ether, "deposited after first");
        assertEq(address(depositManager).balance, 3 * 32 ether, "remaining balance");

        vm.prank(keeper);
        depositManager.depositToConsensusLayerWithDepositRoot(_createAllocation(0, 3), depositRoot);

        assertEq(registry.getOperator(0).funded, 5 * 32 ether, "after second batch");
        assertEq(depositManager.getTotalDepositedETH(), 5 * 32 ether, "deposited after second");
        assertEq(address(depositManager).balance, 0, "balance drained");
    }
}

contract ConsensusLayerDepositManagerV1WithdrawalCredentialError is OperatorAllocationTestBase {
    bytes32 internal withdrawalCredentials = bytes32(uint256(1));

    ConsensusLayerDepositManagerV1 internal depositManager;
    IDepositContract internal depositContract;

    function setUp() public {
        depositContract = new DepositContractMock();

        depositManager = new ConsensusLayerDepositManagerV1ControllableValidatorKeyRequest();
        vm.store(
            address(depositManager),
            bytes32(uint256(keccak256("river.state.depositContractAddress")) - 1),
            bytes32(uint256(uint160(address(depositContract))))
        );
        LibImplementationUnbricker.unbrick(vm, address(depositManager));
    }

    function testInvalidWithdrawalCredential() public {
        vm.deal(address(depositManager), 32 ether);
        ConsensusLayerDepositManagerV1ControllableValidatorKeyRequest(address(depositManager)).sudoSyncBalance();
        ConsensusLayerDepositManagerV1ControllableValidatorKeyRequest(address(depositManager)).setKeeper(address(0x1));
        vm.expectRevert(abi.encodeWithSignature("InvalidWithdrawalCredentials()"));
        vm.prank(address(0x1));
        depositManager.depositToConsensusLayerWithDepositRoot(_createAllocation(1), bytes32(0));
        ConsensusLayerDepositManagerV1ExposeInitializer(address(depositManager))
            .sudoSetWithdrawalCredentials(withdrawalCredentials);
    }

    function testInvalidArgumentForWithdrawalCredential() public {
        vm.expectRevert(abi.encodeWithSignature("InvalidArgument()"));
        ConsensusLayerDepositManagerV1ExposeInitializer(address(depositManager)).sudoSetWithdrawalCredentials(0x00);
    }
}

// values are coming from this tx https://etherscan.io/tx/0x87eb1df9b26c7e655c9eb568e38009c7c2b0e10b397708ea63dffccd93c6626a that was picked randomly
contract ConsensusLayerDepositManagerV1ValidKeys is ConsensusLayerDepositManagerV1 {
    function _getRiverAdmin() internal pure override returns (address) {
        return address(0);
    }

    function _incrementFundedETH(uint256[] memory) internal override {}

    function publicConsensusLayerDepositManagerInitializeV1(
        address _depositContractAddress,
        bytes32 _withdrawalCredentials
    ) external {
        ConsensusLayerDepositManagerV1.initConsensusLayerDepositManagerV1(
            _depositContractAddress, _withdrawalCredentials
        );
        _setKeeper(address(0x1));
    }

    bytes public _publicKeys =
        hex"84B379476E22EE78F2767AECF6D4832E3C3B77BCF068E08A931FEA69C406753378FF1215F0D2077211126A7D7C54F83B";
    bytes public _signatures =
        hex"8A1979CC3E8D2897044AA18F99F78569AFC0EF9CF5CA5F9545070CF2D2A2CCD5C328B2B2280A8BA80CC810A46470BFC80D2EAAC53E533E43BA054A00587027BA0BCBA5FAD22355257CEB96B23E45D5746022312FBB7E7EFA8C3AE17C0713B426";

    function sudoSetWithdrawalCredentials(bytes32 _withdrawalCredentials) external {
        WithdrawalCredentials.set(_withdrawalCredentials);
    }

    function sudoSyncBalance() external {
        _setCommittedBalance(address(this).balance);
    }

    function _setCommittedBalance(uint256 newCommittedBalance) internal override {
        CommittedBalance.set(newCommittedBalance);
    }
}

contract ConsensusLayerDepositManagerV1ValidKeysTest is OperatorAllocationTestBase {
    ConsensusLayerDepositManagerV1 internal depositManager;
    IDepositContract internal depositContract;

    bytes32 internal withdrawalCredentials = bytes32(
        uint256(uint160(0xd74E967a7D771D7C6757eDb129229C3C8364A584))
            + 0x0100000000000000000000000000000000000000000000000000000000000000
    );

    // value is coming from this tx https://etherscan.io/tx/0x87eb1df9b26c7e655c9eb568e38009c7c2b0e10b397708ea63dffccd93c6626a that was picked randomly
    bytes32 internal depositDataRoot = 0x306fbdcbdbb43ac873b85aea54b2035b10b3b28d55d3869fb499f0b7f7811247;

    function setUp() public {
        depositContract = IDepositContract(address(new DepositContractEnhancedMock()));

        depositManager = new ConsensusLayerDepositManagerV1ValidKeys();
        LibImplementationUnbricker.unbrick(vm, address(depositManager));
        ConsensusLayerDepositManagerV1ValidKeys(address(depositManager))
            .publicConsensusLayerDepositManagerInitializeV1(address(depositContract), withdrawalCredentials);
    }

    function testDepositValidKey() external {
        vm.deal(address(depositManager), 32 ether);
        ConsensusLayerDepositManagerV1ValidKeys(address(depositManager)).sudoSyncBalance();
        vm.store(
            address(depositManager),
            bytes32(uint256(keccak256("river.state.KeeperAddress")) - 1),
            bytes32(uint256(uint160(address(0x1))))
        );
        // Use the actual pubkey and signature from the test contract
        IOperatorsRegistryV1.ValidatorDeposit[] memory alloc = new IOperatorsRegistryV1.ValidatorDeposit[](1);
        alloc[0] = IOperatorsRegistryV1.ValidatorDeposit({
            operatorIndex: 0,
            pubkey: ConsensusLayerDepositManagerV1ValidKeys(address(depositManager))._publicKeys(),
            signature: ConsensusLayerDepositManagerV1ValidKeys(address(depositManager))._signatures(),
            depositAmount: 32 ether
        });
        vm.startPrank(address(0x1));
        depositManager.depositToConsensusLayerWithDepositRoot(alloc, depositContract.get_deposit_root());
        assert(DepositContractEnhancedMock(address(depositContract)).debug_getLastDepositDataRoot() == depositDataRoot);
    }

    function testDepositFailsWithInvalidDepositRoot() public {
        vm.store(
            address(depositManager),
            bytes32(uint256(keccak256("river.state.KeeperAddress")) - 1),
            bytes32(uint256(uint160(address(0x1))))
        );
        vm.startPrank(address(0x1));
        vm.expectRevert(abi.encodeWithSignature("InvalidDepositRoot()"));
        depositManager.depositToConsensusLayerWithDepositRoot(_createAllocation(1), bytes32(0));
    }
}

contract ConsensusLayerDepositManagerV1InvalidDepositContract is OperatorAllocationTestBase {
    ConsensusLayerDepositManagerV1 internal depositManager;
    IDepositContract internal depositContract;

    bytes32 internal withdrawalCredentials = bytes32(uint256(1));

    function setUp() public {
        depositContract = IDepositContract(address(new DepositContractInvalidMock()));

        depositManager = new ConsensusLayerDepositManagerV1ValidKeys();
        LibImplementationUnbricker.unbrick(vm, address(depositManager));
        ConsensusLayerDepositManagerV1ValidKeys(address(depositManager))
            .publicConsensusLayerDepositManagerInitializeV1(address(depositContract), withdrawalCredentials);
    }

    function testDepositInvalidDepositContract() external {
        vm.deal(address(depositManager), 32 ether);
        ConsensusLayerDepositManagerV1ValidKeys(address(depositManager)).sudoSyncBalance();
        vm.expectRevert(abi.encodeWithSignature("ErrorOnDeposit()"));
        vm.prank(address(0x1));
        depositManager.depositToConsensusLayerWithDepositRoot(_createAllocation(1), bytes32(0));
    }
}

contract ConsensusLayerDepositManagerV1KeeperTest is OperatorAllocationTestBase {
    ConsensusLayerDepositManagerV1 internal depositManager;
    IDepositContract internal depositContract;

    bytes32 internal withdrawalCredentials = bytes32(
        uint256(uint160(0xd74E967a7D771D7C6757eDb129229C3C8364A584))
            + 0x0100000000000000000000000000000000000000000000000000000000000000
    );

    // value is coming from this tx https://etherscan.io/tx/0x87eb1df9b26c7e655c9eb568e38009c7c2b0e10b397708ea63dffccd93c6626a that was picked randomly
    bytes32 internal depositDataRoot = 0x306fbdcbdbb43ac873b85aea54b2035b10b3b28d55d3869fb499f0b7f7811247;

    function setUp() public {
        depositContract = IDepositContract(address(new DepositContractEnhancedMock()));

        depositManager = new ConsensusLayerDepositManagerV1ValidKeys();
        LibImplementationUnbricker.unbrick(vm, address(depositManager));
        ConsensusLayerDepositManagerV1ValidKeys(address(depositManager))
            .publicConsensusLayerDepositManagerInitializeV1(address(depositContract), withdrawalCredentials);
    }

    function testDepositValidKeeper() external {
        vm.deal(address(depositManager), 32 ether);
        ConsensusLayerDepositManagerV1ValidKeys(address(depositManager)).sudoSyncBalance();
        vm.store(
            address(depositManager),
            bytes32(uint256(keccak256("river.state.KeeperAddress")) - 1),
            bytes32(uint256(uint160(address(0x1))))
        );
        IOperatorsRegistryV1.ValidatorDeposit[] memory alloc = new IOperatorsRegistryV1.ValidatorDeposit[](1);
        alloc[0] = IOperatorsRegistryV1.ValidatorDeposit({
            operatorIndex: 0,
            pubkey: ConsensusLayerDepositManagerV1ValidKeys(address(depositManager))._publicKeys(),
            signature: ConsensusLayerDepositManagerV1ValidKeys(address(depositManager))._signatures(),
            depositAmount: 32 ether
        });
        vm.startPrank(address(0x1));
        depositManager.depositToConsensusLayerWithDepositRoot(alloc, depositContract.get_deposit_root());
        assert(DepositContractEnhancedMock(address(depositContract)).debug_getLastDepositDataRoot() == depositDataRoot);
    }

    function testDepositInvalidKeeper() external {
        vm.deal(address(depositManager), 32 ether);
        ConsensusLayerDepositManagerV1ValidKeys(address(depositManager)).sudoSyncBalance();
        vm.store(
            address(depositManager),
            bytes32(uint256(keccak256("river.state.KeeperAddress")) - 1),
            bytes32(uint256(uint160(address(0x2))))
        );
        bytes32 depositRoot = depositContract.get_deposit_root();
        vm.expectRevert(abi.encodeWithSignature("OnlyKeeper()"));
        vm.prank(address(0x1));
        depositManager.depositToConsensusLayerWithDepositRoot(_createAllocation(1), depositRoot);
    }
}

/// @dev Exposes _depositValidator to cover defensive length checks (lines 172, 176).
contract ConsensusLayerDepositManagerExposeDepositValidator is ConsensusLayerDepositManagerV1ExposeInitializer {
    function sudoDepositValidator(
        bytes memory pubkey,
        bytes memory signature,
        uint256 depositAmount,
        bytes32 withdrawalCredentials
    ) external {
        _depositValidator(pubkey, signature, depositAmount, withdrawalCredentials, DepositContractAddress.get());
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// ConsensusLayerDepositManager coverage tests (UnorderedOperatorList, InvalidDepositSize, _depositValidator length checks)
// ─────────────────────────────────────────────────────────────────────────────

contract ConsensusLayerDepositManagerV1CoverageTests is OperatorAllocationTestBase {
    bytes32 internal withdrawalCredentials = bytes32(uint256(1));
    ConsensusLayerDepositManagerV1ExposeInitializer internal dm;
    IDepositContract internal depositContract;

    function setUp() public {
        depositContract = new DepositContractMock();
        dm = new ConsensusLayerDepositManagerV1ExposeInitializer();
        LibImplementationUnbricker.unbrick(vm, address(dm));
        dm.publicConsensusLayerDepositManagerInitializeV1(address(depositContract), withdrawalCredentials);
        vm.deal(address(dm), 64 ether);
        dm.sudoSyncBalance();
        vm.store(
            address(dm),
            bytes32(uint256(keccak256("river.state.KeeperAddress")) - 1),
            bytes32(uint256(uint160(address(this))))
        );
    }

    /// Asserts that depositToConsensusLayerWithDepositRoot reverts with UnorderedOperatorList when operator indices are not non-decreasing.
    function testDepositRevertsOnUnorderedOperatorList() public {
        IOperatorsRegistryV1.ValidatorDeposit[] memory allocs = new IOperatorsRegistryV1.ValidatorDeposit[](2);
        allocs[0] = IOperatorsRegistryV1.ValidatorDeposit({
            operatorIndex: 1, pubkey: new bytes(48), signature: new bytes(96), depositAmount: 32 ether
        });
        allocs[1] = IOperatorsRegistryV1.ValidatorDeposit({
            operatorIndex: 0, pubkey: new bytes(48), signature: new bytes(96), depositAmount: 32 ether
        });
        vm.expectRevert(abi.encodeWithSignature("UnorderedOperatorList()"));
        dm.depositToConsensusLayerWithDepositRoot(allocs, bytes32(0));
    }

    /// Asserts that depositToConsensusLayerWithDepositRoot reverts with InvalidDepositSize when depositAmount is below 1 ether.
    function testDepositRevertsOnInvalidDepositSize() public {
        IOperatorsRegistryV1.ValidatorDeposit[] memory allocs = new IOperatorsRegistryV1.ValidatorDeposit[](1);
        allocs[0] = IOperatorsRegistryV1.ValidatorDeposit({
            operatorIndex: 0, pubkey: new bytes(48), signature: new bytes(96), depositAmount: 0.5 ether
        });
        vm.expectRevert(abi.encodeWithSignature("InvalidDepositSize(uint256)", 0.5 ether));
        dm.depositToConsensusLayerWithDepositRoot(allocs, bytes32(0));
    }
}

contract ConsensusLayerDepositManagerV1DepositValidatorCoverageTests is OperatorAllocationTestBase {
    ConsensusLayerDepositManagerExposeDepositValidator internal dm;

    function setUp() public {
        dm = new ConsensusLayerDepositManagerExposeDepositValidator();
        LibImplementationUnbricker.unbrick(vm, address(dm));
        dm.publicConsensusLayerDepositManagerInitializeV1(address(new DepositContractMock()), bytes32(uint256(1)));
    }

    /// Asserts that depositToConsensusLayerWithDepositRoot reverts with InconsistentPublicKey when pubkey length is not 48.
    function testDepositValidatorRevertsOnShortPublicKey() public {
        vm.deal(address(dm), 32 ether);
        dm.sudoSyncBalance();
        IOperatorsRegistryV1.ValidatorDeposit[] memory allocs = new IOperatorsRegistryV1.ValidatorDeposit[](1);
        allocs[0] = IOperatorsRegistryV1.ValidatorDeposit({
            operatorIndex: 0, pubkey: new bytes(47), signature: new bytes(96), depositAmount: 32 ether
        });
        vm.expectRevert(abi.encodeWithSignature("InconsistentPublicKey()"));
        vm.prank(address(0x1));
        dm.depositToConsensusLayerWithDepositRoot(allocs, bytes32(0));
    }

    /// Asserts that depositToConsensusLayerWithDepositRoot reverts with InconsistentSignature when signature length is not 96.
    function testDepositValidatorRevertsOnShortSignature() public {
        vm.deal(address(dm), 32 ether);
        dm.sudoSyncBalance();
        IOperatorsRegistryV1.ValidatorDeposit[] memory allocs = new IOperatorsRegistryV1.ValidatorDeposit[](1);
        allocs[0] = IOperatorsRegistryV1.ValidatorDeposit({
            operatorIndex: 0, pubkey: new bytes(48), signature: new bytes(95), depositAmount: 32 ether
        });
        vm.expectRevert(abi.encodeWithSignature("InconsistentSignature()"));
        vm.prank(address(0x1));
        dm.depositToConsensusLayerWithDepositRoot(allocs, bytes32(0));
    }
}
