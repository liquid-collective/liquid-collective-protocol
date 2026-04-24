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

    function _incrementFundedETH(uint256[] memory, bytes[][] memory) internal override {}
    function _updateFundedETHFromBuffer(IDepositDataBuffer.DepositObject[] memory) internal override {}

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

    function _getSlashingContainmentMode() internal view override returns (bool) {
        return false;
    }
}

/// @notice Deposit manager test double that delegates _getNextValidators to the real OperatorsRegistry (same as River in production)
contract ConsensusLayerDepositManagerV1UsesRegistry is ConsensusLayerDepositManagerV1 {
    IOperatorsRegistryV1 public registry;

    function _getRiverAdmin() internal pure override returns (address) {
        return address(0);
    }

    function _incrementFundedETH(uint256[] memory _fundedETH, bytes[][] memory _publicKeys) internal override {
        registry.incrementFundedETH(_fundedETH, _publicKeys);
    }

    function _updateFundedETHFromBuffer(IDepositDataBuffer.DepositObject[] memory) internal override {}

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

    function _getSlashingContainmentMode() internal view override returns (bool) {
        return false;
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

    function _incrementFundedETH(uint256[] memory, bytes[][] memory) internal override {}
    function _updateFundedETHFromBuffer(IDepositDataBuffer.DepositObject[] memory) internal override {}

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

    function _getSlashingContainmentMode() internal view override returns (bool) {
        return false;
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

    function testUnorderedOperatorListReverts() public {
        vm.deal(address(depositManager), 3 * 32 ether);
        ConsensusLayerDepositManagerV1ControllableValidatorKeyRequest(address(depositManager)).sudoSyncBalance();

        // Build allocations with decreasing operator indices: [1, 0]
        IOperatorsRegistryV1.ValidatorDeposit[] memory allocations = new IOperatorsRegistryV1.ValidatorDeposit[](2);
        allocations[0] = IOperatorsRegistryV1.ValidatorDeposit({
            operatorIndex: 1, pubkey: bytes(new bytes(48)), signature: bytes(new bytes(96)), depositAmount: 32 ether
        });
        allocations[1] = IOperatorsRegistryV1.ValidatorDeposit({
            operatorIndex: 0, pubkey: bytes(new bytes(48)), signature: bytes(new bytes(96)), depositAmount: 32 ether
        });

        vm.expectRevert(abi.encodeWithSignature("UnorderedOperatorList()"));
        vm.prank(address(0x1));
        depositManager.depositToConsensusLayerWithDepositRoot(allocations, bytes32(0));
    }

    function testEqualConsecutiveOperatorIndicesAllowed() public {
        vm.deal(address(depositManager), 2 * 32 ether);
        ConsensusLayerDepositManagerV1ControllableValidatorKeyRequest(address(depositManager)).sudoSyncBalance();

        // Build allocations with equal consecutive operator indices: [0, 0]
        IOperatorsRegistryV1.ValidatorDeposit[] memory allocations = new IOperatorsRegistryV1.ValidatorDeposit[](2);
        allocations[0] = IOperatorsRegistryV1.ValidatorDeposit({
            operatorIndex: 0, pubkey: bytes(new bytes(48)), signature: bytes(new bytes(96)), depositAmount: 32 ether
        });
        allocations[1] = IOperatorsRegistryV1.ValidatorDeposit({
            operatorIndex: 0, pubkey: bytes(new bytes(48)), signature: bytes(new bytes(96)), depositAmount: 32 ether
        });

        // Should NOT revert with UnorderedOperatorList -- equal consecutive indices are valid
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

    function testInvalidDepositSizeReverts() public {
        vm.deal(address(depositManager), 64 ether);
        ConsensusLayerDepositManagerV1ControllableValidatorKeyRequest(address(depositManager)).sudoSyncBalance();

        IOperatorsRegistryV1.ValidatorDeposit[] memory alloc = new IOperatorsRegistryV1.ValidatorDeposit[](1);
        alloc[0] = IOperatorsRegistryV1.ValidatorDeposit({
            operatorIndex: 0, pubkey: bytes(new bytes(48)), signature: bytes(new bytes(96)), depositAmount: 0.5 ether
        });

        vm.expectRevert(abi.encodeWithSelector(IConsensusLayerDepositManagerV1.InvalidDepositSize.selector, 0.5 ether));
        vm.prank(address(0x1));
        depositManager.depositToConsensusLayerWithDepositRoot(alloc, bytes32(0));
    }

    function testInvalidDepositSizeZeroReverts() public {
        vm.deal(address(depositManager), 32 ether);
        ConsensusLayerDepositManagerV1ControllableValidatorKeyRequest(address(depositManager)).sudoSyncBalance();

        IOperatorsRegistryV1.ValidatorDeposit[] memory alloc = new IOperatorsRegistryV1.ValidatorDeposit[](1);
        alloc[0] = IOperatorsRegistryV1.ValidatorDeposit({
            operatorIndex: 0, pubkey: bytes(new bytes(48)), signature: bytes(new bytes(96)), depositAmount: 0
        });

        vm.expectRevert(abi.encodeWithSelector(IConsensusLayerDepositManagerV1.InvalidDepositSize.selector, 0));
        vm.prank(address(0x1));
        depositManager.depositToConsensusLayerWithDepositRoot(alloc, bytes32(0));
    }

    function testNonDecreasingMultiOperatorSequence() public {
        // Valid sequence: [0, 0, 1, 2, 2] across 3 distinct operators
        vm.deal(address(depositManager), 5 * 32 ether);
        ConsensusLayerDepositManagerV1ControllableValidatorKeyRequest(address(depositManager)).sudoSyncBalance();

        IOperatorsRegistryV1.ValidatorDeposit[] memory alloc = new IOperatorsRegistryV1.ValidatorDeposit[](5);
        uint256[5] memory ops = [uint256(0), 0, 1, 2, 2];
        for (uint256 i = 0; i < 5; ++i) {
            alloc[i] = IOperatorsRegistryV1.ValidatorDeposit({
                operatorIndex: ops[i],
                pubkey: bytes(new bytes(48)),
                signature: bytes(new bytes(96)),
                depositAmount: 32 ether
            });
        }

        vm.prank(address(0x1));
        depositManager.depositToConsensusLayerWithDepositRoot(alloc, bytes32(0));
        assertEq(address(depositManager).balance, 0, "all 5 deposits should succeed");
    }
}

/// @notice Tests deposit root staleness: the root changes between observation and execution
contract ConsensusLayerDepositManagerV1DepositRootStalenessTests is OperatorAllocationTestBase {
    ConsensusLayerDepositManagerV1 internal depositManager;
    DepositContractEnhancedMock internal depositContract;

    bytes32 internal withdrawalCredentials = bytes32(
        uint256(uint160(0xd74E967a7D771D7C6757eDb129229C3C8364A584))
            + 0x0100000000000000000000000000000000000000000000000000000000000000
    );

    function setUp() public {
        depositContract = new DepositContractEnhancedMock();

        depositManager = new ConsensusLayerDepositManagerV1ValidKeys();
        LibImplementationUnbricker.unbrick(vm, address(depositManager));
        ConsensusLayerDepositManagerV1ValidKeys(address(depositManager))
            .publicConsensusLayerDepositManagerInitializeV1(address(depositContract), withdrawalCredentials);
    }

    /// @notice Simulates deposit root staleness: keeper snapshots the root, then the deposit
    ///         contract's tree changes before the keeper's tx lands.
    function testDepositRootStaleAfterIntervening() public {
        vm.deal(address(depositManager), 32 ether);
        ConsensusLayerDepositManagerV1ValidKeys(address(depositManager)).sudoSyncBalance();
        vm.store(
            address(depositManager),
            bytes32(uint256(keccak256("river.state.KeeperAddress")) - 1),
            bytes32(uint256(uint160(address(0x1))))
        );

        // Keeper snapshots the deposit root
        bytes32 staleRoot = depositContract.get_deposit_root();

        // Simulate an intervening deposit by incrementing the deposit_count directly,
        // which changes the merkle tree root
        uint256 countSlot = 32; // deposit_count storage slot in DepositContractEnhancedMock
        vm.store(address(depositContract), bytes32(countSlot), bytes32(uint256(1)));

        // Root has changed
        bytes32 newRoot = depositContract.get_deposit_root();
        assertTrue(newRoot != staleRoot, "root should have changed after intervening deposit");

        // Keeper's tx uses the stale root -- should revert
        IOperatorsRegistryV1.ValidatorDeposit[] memory alloc = new IOperatorsRegistryV1.ValidatorDeposit[](1);
        alloc[0] = IOperatorsRegistryV1.ValidatorDeposit({
            operatorIndex: 0,
            pubkey: ConsensusLayerDepositManagerV1ValidKeys(address(depositManager))._publicKeys(),
            signature: ConsensusLayerDepositManagerV1ValidKeys(address(depositManager))._signatures(),
            depositAmount: 32 ether
        });

        vm.expectRevert(abi.encodeWithSignature("InvalidDepositRoot()"));
        vm.prank(address(0x1));
        depositManager.depositToConsensusLayerWithDepositRoot(alloc, staleRoot);
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

    event FundedValidatorKeys(uint256 indexed index, bytes[] publicKeys, bool deferred);

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

        // Give the operator some funded ETH then request exits without stopping any.
        // Both fields are wei-denominated under the Pectra accounting model.
        OperatorsRegistryInitializableV1(address(registry)).sudoSetFunded(0, 5 * 32 ether);
        OperatorsRegistryInitializableV1(address(registry)).sudoExitRequests(0, 5 * 32 ether);

        vm.deal(address(depositManager), 32 ether);
        ConsensusLayerDepositManagerV1UsesRegistry(address(depositManager)).sudoSyncBalance();

        bytes32 depositRoot = depositContract.get_deposit_root();
        vm.prank(keeper);
        vm.expectRevert(abi.encodeWithSignature("OperatorIgnoredExitRequests(uint256)", 0));
        depositManager.depositToConsensusLayerWithDepositRoot(_createAllocation(0, 1), depositRoot);

        assertEq(registry.getOperator(0).funded, 5 * 32 ether, "funded unchanged on revert");
        assertEq(depositManager.getTotalDepositedETH(), 0, "no deposited ETH");
        assertEq(address(depositManager).balance, 32 ether, "balance unchanged");
    }

    /// @dev Full flow with distinct pubkeys and signatures per validator across multiple operators.
    ///      Verifies that:
    ///      1. Each FundedValidatorKeys event contains the exact pubkeys for that operator (not just the count)
    ///      2. Keys are correctly split by operator when multiple operators are in the allocation
    function testFullDepositFlowDistinctKeysPerValidator() public {
        vm.startPrank(admin);
        registry.addOperator("Op0", admin);
        registry.addOperator("Op1", admin);
        vm.stopPrank();

        // Generate 2 distinct keys for op0, 3 for op1 = 5 total
        uint256 fromOp0 = 2;
        uint256 fromOp1 = 3;
        uint256 total = fromOp0 + fromOp1;

        IOperatorsRegistryV1.ValidatorDeposit[] memory alloc = new IOperatorsRegistryV1.ValidatorDeposit[](total);
        bytes[] memory op0ExpectedKeys = new bytes[](fromOp0);
        bytes[] memory op1ExpectedKeys = new bytes[](fromOp1);

        // Op0 keys: deterministic but distinct
        for (uint256 i = 0; i < fromOp0; ++i) {
            bytes memory pubkey = abi.encodePacked(keccak256(abi.encode("op0-pubkey", i)), bytes16(0));
            bytes memory sig = abi.encodePacked(
                keccak256(abi.encode("op0-sig-a", i)),
                keccak256(abi.encode("op0-sig-b", i)),
                keccak256(abi.encode("op0-sig-c", i))
            );
            alloc[i] = IOperatorsRegistryV1.ValidatorDeposit({
                operatorIndex: 0, pubkey: pubkey, signature: sig, depositAmount: 32 ether
            });
            op0ExpectedKeys[i] = pubkey;
        }

        // Op1 keys: distinct from op0 and from each other
        for (uint256 i = 0; i < fromOp1; ++i) {
            bytes memory pubkey = abi.encodePacked(keccak256(abi.encode("op1-pubkey", i)), bytes16(0));
            bytes memory sig = abi.encodePacked(
                keccak256(abi.encode("op1-sig-a", i)),
                keccak256(abi.encode("op1-sig-b", i)),
                keccak256(abi.encode("op1-sig-c", i))
            );
            alloc[fromOp0 + i] = IOperatorsRegistryV1.ValidatorDeposit({
                operatorIndex: 1, pubkey: pubkey, signature: sig, depositAmount: 32 ether
            });
            op1ExpectedKeys[i] = pubkey;
        }

        // Sanity: all pubkeys are distinct
        for (uint256 i = 0; i < total; ++i) {
            for (uint256 j = i + 1; j < total; ++j) {
                assertTrue(keccak256(alloc[i].pubkey) != keccak256(alloc[j].pubkey), "pubkeys must be distinct");
            }
        }

        vm.deal(address(depositManager), total * 32 ether);
        ConsensusLayerDepositManagerV1UsesRegistry(address(depositManager)).sudoSyncBalance();

        // Expect FundedValidatorKeys for op0 with op0's exact keys
        vm.expectEmit(true, false, false, true, address(registry));
        emit FundedValidatorKeys(0, op0ExpectedKeys, false);
        // Expect FundedValidatorKeys for op1 with op1's exact keys
        vm.expectEmit(true, false, false, true, address(registry));
        emit FundedValidatorKeys(1, op1ExpectedKeys, false);

        bytes32 depositRoot = depositContract.get_deposit_root();
        vm.prank(keeper);
        depositManager.depositToConsensusLayerWithDepositRoot(alloc, depositRoot);

        assertEq(registry.getOperator(0).funded, fromOp0 * 32 ether, "op0 funded");
        assertEq(registry.getOperator(1).funded, fromOp1 * 32 ether, "op1 funded");
        assertEq(depositManager.getTotalDepositedETH(), total * 32 ether, "total deposited");
        assertEq(address(depositManager).balance, 0, "all ETH deposited");
    }

    /// @dev Single operator with distinct keys: verify the emitted event matches key-by-key
    function testFullDepositFlowDistinctKeysSingleOperator() public {
        vm.startPrank(admin);
        registry.addOperator("Op0", admin);
        vm.stopPrank();

        uint256 count = 4;
        IOperatorsRegistryV1.ValidatorDeposit[] memory alloc = new IOperatorsRegistryV1.ValidatorDeposit[](count);
        bytes[] memory expectedKeys = new bytes[](count);

        for (uint256 i = 0; i < count; ++i) {
            bytes memory pubkey = abi.encodePacked(keccak256(abi.encode("single-op-key", i)), bytes16(0));
            bytes memory sig = abi.encodePacked(
                keccak256(abi.encode("single-op-sig-a", i)),
                keccak256(abi.encode("single-op-sig-b", i)),
                keccak256(abi.encode("single-op-sig-c", i))
            );
            alloc[i] = IOperatorsRegistryV1.ValidatorDeposit({
                operatorIndex: 0, pubkey: pubkey, signature: sig, depositAmount: 32 ether
            });
            expectedKeys[i] = pubkey;
        }

        vm.deal(address(depositManager), count * 32 ether);
        ConsensusLayerDepositManagerV1UsesRegistry(address(depositManager)).sudoSyncBalance();

        vm.expectEmit(true, false, false, true, address(registry));
        emit FundedValidatorKeys(0, expectedKeys, false);

        bytes32 depositRoot = depositContract.get_deposit_root();
        vm.prank(keeper);
        depositManager.depositToConsensusLayerWithDepositRoot(alloc, depositRoot);

        assertEq(registry.getOperator(0).funded, count * 32 ether, "funded ETH");
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
    IOperatorsRegistryV1 public registry;

    function _getRiverAdmin() internal pure override returns (address) {
        return address(0);
    }

    function _incrementFundedETH(uint256[] memory, bytes[][] memory) internal override {}
    function _updateFundedETHFromBuffer(IDepositDataBuffer.DepositObject[] memory) internal override {}

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

    function _getSlashingContainmentMode() internal view override returns (bool) {
        return false;
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

contract ConsensusLayerDepositManagerV1ToggleableSlashingMode is ConsensusLayerDepositManagerV1 {
    IOperatorsRegistryV1 public registry;
    bool public slashingMode;

    function _getRiverAdmin() internal pure override returns (address) {
        return address(0);
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

    function setRegistry(IOperatorsRegistryV1 _registry) external {
        registry = _registry;
    }

    function sudoSetSlashingContainmentMode(bool _slashingContainmentMode) external {
        slashingMode = _slashingContainmentMode;
    }

    bytes public _publicKeys =
        hex"746ce769697901e86d4fb795527393e974d182e8ac03e6ea6c8bb3e0f4458e9196a87915affcc77c543e302e743fa15f65ecc7e935467d39f1296d8a5bd693ce87248f969b36d3f226f573d28a42bbcd4d27fe4399e60e9a55565391df1210c5d472643c683a63ae1e8d2796e52cb209dcf58188bb4d26fb9ede7a49d2737af9d32081497a0edd12aaf815157736c50814fdffbfb1fb51d4c5a4db9a2ff8222f036347e6046eb85c9e04bbcea922261694118aa4714685ffff83cbf3f74cabe2a01f8b1924045e9aceeba071cb46efc0ee3ff3ecd2eac6ecdd8d0bdbb660eabe30a695d887b6b5a138012ca0fcc40f652a6401c91102088769ef0df4f17874a8d2c832dc5371c6350b94fd637f6b7eba1f3aefea815460dd1bb56d41339a39bb977ca9018a56ee20ad09defcd184c3a9988bdbe0ca19da2d39e8ecd5aa4e7f1a81b3d9145ecd7a19317379c10edc875f345f4ccd905440a57986ea3e981804a3bfcd72c64faa543e3b7d1bc1eddb03df6576afec37e4cd04fb928d4039e8e7495e92efaa2cb7dcbb3e817f771b6fc0d6ce8db7cbed38bf6fabd198cd2b7184d7b737c1c05f1d1a10d8e8141b875f1d2c4681ddeb7bad423182704048f3fb9fe82bded37429b0643af12c730b0f0851815a6ef1a563fdcef7c05512b33278218c";
    bytes public _signatures =
        hex"6e93b287f9972d6e4bb7b9b7bdf75e2f3190b61dff0699d9708ee2a6e08f0ce1436b3f0213c1d7e0168cd1b221326b917e0dba509208bf586923ccc53e30b9bc697834508a4c54cd4f097f2c8c5d1b7b3c829fdc326f8df92aae75f008099e1e0324e6ea8734ab375bc33000ab02c63423c3dec20823ac27cadc1e393fa1f15774e52c6a5194dd9136f253b1dc8e0cf9f1a9eec02517d923af4f242e2215d4f82d2bfb657e666f24e5c5f8e6c9636250c0e8f2c20ddd91eda71d1ef5896dbc0fd84508f71958ab19b047030cee1911d55194e38051111021e0710e0be25c3f878ba11c7db118b06a6fc04570cba519c1aa4184693f024bc0e02019dfb62dacab8a2b1127d1b03645ed6377717cbd099aab8d6a5bef2be1aa8e0bb7e2565c8eddfa91b72ae014adb0a47a272d1aedd5920a2ec2f788fe76852b45961d959fdb627329326352f8f3e73bb758022265174af7bc6e3b8ef19f173244735f68789d0f6a34de6da1e22142478205388e8b9db291e01227aa5e4e7173aa11624341b31a202ffade6b5418099dd583708c1fb95525bbfa87b1d08455b640ce25cf322b00471f8dc813dbcd8b82c20e9d07c6215e86237d94ed6f81c7a7ffce0180c128be4f036203e9acfa713d41609a654de0a56a1689da6dcd3950dfd1e3f36987cca569ba947c97b205e34f8ed2dd87b4e29a822676457121ff48ee8bb4dd0b7200093883f6cde4edf1026abc5bc5692dbbfb2197fb4cfbac4eecc99b7956a4dab19cc74db50cf83ff35e880ef58457d3a5b444a17c072ea617ff28cf7bba2657f8ef118a8e6f65453548aafea8c8b88a0df7dbeeaecff69d05ff0dfc55fb97eb94b05b7d7aa748f5aaf6fe38aa6183f400d65e0152004780a089449a5bd77e04b7bd0682c67f5c4fd12bf56b6b31ec3eccfe104f8f64c8b9d23375e0078ba8fe6253037a8a2171682301d5463ce24b4e920af83fd009b6214450382309a143332e8dfa05a95dfa686a630b95b80cfd9b42d33cc3de7f5708dd67714192a14ca814a1f3cc4b4932c36831674ee8ba3a58f12643c1b4bf1e00370290ac4d5e994410d69bad8c691efaf5b6e8fe8331882f7dc304d8ccb6bd9d6079c1698dbdef47996c937046157498db082443ddd33f61e1abb204f12d553b25ea1d773812f701a3c9b36c5909c3b9ebd18d2ba1b8a2daeae36a2811a59bbae1d334fde54e07eac5770172c36d50d821fb181c97bb00a9684a904a2fc8c9c520e730fca4751b4f0d266dc33ddbb7e8ea065ccc47a7dbea61a185ab2413917a039e505e85e2f781eeef96658b94a07f9662ff3e6c8728de755c7a305f975ae8772c8b75468ad30a5467";

    function sudoSyncBalance() external {
        _setCommittedBalance(address(this).balance);
    }

    function _setCommittedBalance(uint256 newCommittedBalance) internal override {
        CommittedBalance.set(newCommittedBalance);
    }

    function _getSlashingContainmentMode() internal view override returns (bool) {
        return slashingMode;
    }

    function _incrementFundedETH(uint256[] memory _fundedETH, bytes[][] memory _publicKeys) internal override {
        registry.incrementFundedETH(_fundedETH, _publicKeys);
    }

    function _updateFundedETHFromBuffer(IDepositDataBuffer.DepositObject[] memory) internal override {}
}

contract ConsensusLayerDepositManagerV1SlashingModeTests is OperatorAllocationTestBase {
    bytes32 internal withdrawalCredentials = bytes32(uint256(1));
    address internal keeper = address(0x1);
    address internal admin;

    ConsensusLayerDepositManagerV1ToggleableSlashingMode internal depositManager;
    OperatorsRegistryV1 internal registry;
    IDepositContract internal depositContract;

    function setUp() public {
        admin = makeAddr("admin");
        depositContract = new DepositContractMock();

        depositManager = new ConsensusLayerDepositManagerV1ToggleableSlashingMode();
        registry = new OperatorsRegistryInitializableV1();

        LibImplementationUnbricker.unbrick(vm, address(depositManager));
        LibImplementationUnbricker.unbrick(vm, address(registry));

        registry.initOperatorsRegistryV1(admin, address(depositManager));
        depositManager.publicConsensusLayerDepositManagerInitializeV1(address(depositContract), withdrawalCredentials);
        depositManager.setRegistry(registry);
        depositManager.setKeeper(keeper);

        vm.prank(admin);
        registry.addOperator("Op0", admin);
    }

    /// @notice Slashing containment mode blocks deposit even with sufficient funds
    function testSlashingContainmentModeBlocksDeposit() public {
        vm.deal(address(depositManager), 32 ether);
        depositManager.sudoSyncBalance();
        depositManager.sudoSetSlashingContainmentMode(true);

        vm.expectRevert(abi.encodeWithSignature("SlashingContainmentModeEnabled()"));
        vm.prank(keeper);
        depositManager.depositToConsensusLayerWithDepositRoot(_createAllocation(1), bytes32(0));
    }

    /// @notice Slashing containment mode disabled allows deposit to proceed normally
    function testSlashingContainmentModeAllowsDepositWhenDisabled() public {
        vm.deal(address(depositManager), 32 ether);
        depositManager.sudoSyncBalance();
        depositManager.sudoSetSlashingContainmentMode(false);

        vm.prank(keeper);
        depositManager.depositToConsensusLayerWithDepositRoot(_createAllocation(1), bytes32(0));
        assertEq(address(depositManager).balance, 0);
    }

    /// @notice Keeper check comes before slashing containment mode check
    function testKeeperCheckPrecedesSlashingModeCheck() public {
        vm.deal(address(depositManager), 32 ether);
        depositManager.sudoSyncBalance();
        depositManager.sudoSetSlashingContainmentMode(true);

        vm.expectRevert(abi.encodeWithSignature("OnlyKeeper()"));
        vm.prank(address(0xdead));
        depositManager.depositToConsensusLayerWithDepositRoot(_createAllocation(1), bytes32(0));
    }

    /// @notice Slashing containment mode check comes before deposit root check
    function testSlashingModeCheckPrecedesDepositRootCheck() public {
        vm.deal(address(depositManager), 32 ether);
        depositManager.sudoSyncBalance();
        depositManager.sudoSetSlashingContainmentMode(true);

        // Pass a non-zero deposit root that won't match; slashing mode should revert first
        vm.expectRevert(abi.encodeWithSignature("SlashingContainmentModeEnabled()"));
        vm.prank(keeper);
        depositManager.depositToConsensusLayerWithDepositRoot(_createAllocation(1), bytes32(uint256(1)));
    }

    /// @notice Slashing containment mode check comes before balance check
    function testSlashingModeCheckPrecedesBalanceCheck() public {
        // No funds — would normally revert with NotEnoughFunds
        depositManager.sudoSetSlashingContainmentMode(true);

        vm.expectRevert(abi.encodeWithSignature("SlashingContainmentModeEnabled()"));
        vm.prank(keeper);
        depositManager.depositToConsensusLayerWithDepositRoot(_createAllocation(1), bytes32(0));
    }

    /// @notice Toggling slashing mode off after it was on allows deposits again
    function testSlashingModeToggleOffAllowsDeposit() public {
        vm.deal(address(depositManager), 32 ether);
        depositManager.sudoSyncBalance();
        depositManager.sudoSetSlashingContainmentMode(true);

        vm.expectRevert(abi.encodeWithSignature("SlashingContainmentModeEnabled()"));
        vm.prank(keeper);
        depositManager.depositToConsensusLayerWithDepositRoot(_createAllocation(1), bytes32(0));

        depositManager.sudoSetSlashingContainmentMode(false);
        vm.prank(keeper);
        depositManager.depositToConsensusLayerWithDepositRoot(_createAllocation(1), bytes32(0));
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
        // Use 3 allocations so the last element has the highest operatorIndex (sizing the internal
        // publicKeyCountPerOperator array correctly), while an out-of-order pair earlier triggers the revert.
        IOperatorsRegistryV1.ValidatorDeposit[] memory allocs = new IOperatorsRegistryV1.ValidatorDeposit[](3);
        allocs[0] = IOperatorsRegistryV1.ValidatorDeposit({
            operatorIndex: 1, pubkey: new bytes(48), signature: new bytes(96), depositAmount: 32 ether
        });
        allocs[1] = IOperatorsRegistryV1.ValidatorDeposit({
            operatorIndex: 0, pubkey: new bytes(48), signature: new bytes(96), depositAmount: 32 ether
        });
        allocs[2] = IOperatorsRegistryV1.ValidatorDeposit({
            operatorIndex: 2, pubkey: new bytes(48), signature: new bytes(96), depositAmount: 32 ether
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
