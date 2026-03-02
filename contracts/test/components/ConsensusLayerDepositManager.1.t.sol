//SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.34;

import "forge-std/Test.sol";

import "../../src/interfaces/IOperatorRegistry.1.sol";
import "../../src/interfaces/components/IConsensusLayerDepositManager.1.sol";
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

    bytes public _publicKeys =
        hex"746ce769697901e86d4fb795527393e974d182e8ac03e6ea6c8bb3e0f4458e9196a87915affcc77c543e302e743fa15f65ecc7e935467d39f1296d8a5bd693ce87248f969b36d3f226f573d28a42bbcd4d27fe4399e60e9a55565391df1210c5d472643c683a63ae1e8d2796e52cb209dcf58188bb4d26fb9ede7a49d2737af9d32081497a0edd12aaf815157736c50814fdffbfb1fb51d4c5a4db9a2ff8222f036347e6046eb85c9e04bbcea922261694118aa4714685ffff83cbf3f74cabe2a01f8b1924045e9aceeba071cb46efc0ee3ff3ecd2eac6ecdd8d0bdbb660eabe30a695d887b6b5a138012ca0fcc40f652a6401c91102088769ef0df4f17874a8d2c832dc5371c6350b94fd637f6b7eba1f3aefea815460dd1bb56d41339a39bb977ca9018a56ee20ad09defcd184c3a9988bdbe0ca19da2d39e8ecd5aa4e7f1a81b3d9145ecd7a19317379c10edc875f345f4ccd905440a57986ea3e981804a3bfcd72c64faa543e3b7d1bc1eddb03df6576afec37e4cd04fb928d4039e8e7495e92efaa2cb7dcbb3e817f771b6fc0d6ce8db7cbed38bf6fabd198cd2b7184d7b737c1c05f1d1a10d8e8141b875f1d2c4681ddeb7bad423182704048f3fb9fe82bded37429b0643af12c730b0f0851815a6ef1a563fdcef7c05512b33278218c";
    bytes public _signatures =
        hex"6e93b287f9972d6e4bb7b9b7bdf75e2f3190b61dff0699d9708ee2a6e08f0ce1436b3f0213c1d7e0168cd1b221326b917e0dba509208bf586923ccc53e30b9bc697834508a4c54cd4f097f2c8c5d1b7b3c829fdc326f8df92aae75f008099e1e0324e6ea8734ab375bc33000ab02c63423c3dec20823ac27cadc1e393fa1f15774e52c6a5194dd9136f253b1dc8e0cf9f1a9eec02517d923af4f242e2215d4f82d2bfb657e666f24e5c5f8e6c9636250c0e8f2c20ddd91eda71d1ef5896dbc0fd84508f71958ab19b047030cee1911d55194e38051111021e0710e0be25c3f878ba11c7db118b06a6fc04570cba519c1aa4184693f024bc0e02019dfb62dacab8a2b1127d1b03645ed6377717cbd099aab8d6a5bef2be1aa8e0bb7e2565c8eddfa91b72ae014adb0a47a272d1aedd5920a2ec2f788fe76852b45961d959fdb627329326352f8f3e73bb758022265174af7bc6e3b8ef19f173244735f68789d0f6a34de6da1e22142478205388e8b9db291e01227aa5e4e7173aa11624341b31a202ffade6b5418099dd583708c1fb95525bbfa87b1d08455b640ce25cf322b00471f8dc813dbcd8b82c20e9d07c6215e86237d94ed6f81c7a7ffce0180c128be4f036203e9acfa713d41609a654de0a56a1689da6dcd3950dfd1e3f36987cca569ba947c97b205e34f8ed2dd87b4e29a822676457121ff48ee8bb4dd0b7200093883f6cde4edf1026abc5bc5692dbbfb2197fb4cfbac4eecc99b7956a4dab19cc74db50cf83ff35e880ef58457d3a5b444a17c072ea617ff28cf7bba2657f8ef118a8e6f65453548aafea8c8b88a0df7dbeeaecff69d05ff0dfc55fb97eb94b05b7d7aa748f5aaf6fe38aa6183f400d65e0152004780a089449a5bd77e04b7bd0682c67f5c4fd12bf56b6b31ec3eccfe104f8f64c8b9d23375e0078ba8fe6253037a8a2171682301d5463ce24b4e920af83fd009b6214450382309a143332e8dfa05a95dfa686a630b95b80cfd9b42d33cc3de7f5708dd67714192a14ca814a1f3cc4b4932c36831674ee8ba3a58f12643c1b4bf1e00370290ac4d5e994410d69bad8c691efaf5b6e8fe8331882f7dc304d8ccb6bd9d6079c1698dbdef47996c937046157498db082443ddd33f61e1abb204f12d553b25ea1d773812f701a3c9b36c5909c3b9ebd18d2ba1b8a2daeae36a2811a59bbae1d334fde54e07eac5770172c36d50d821fb181c97bb00a9684a904a2fc8c9c520e730fca4751b4f0d266dc33ddbb7e8ea065ccc47a7dbea61a185ab2413917a039e505e85e2f781eeef96658b94a07f9662ff3e6c8728de755c7a305f975ae8772c8b75468ad30a5467";

    function _onDepositsComplete(IConsensusLayerDepositManagerV1.ValidatorDeposit[] calldata) internal override {}

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

/// @notice Deposit manager test double that delegates _onDepositsComplete to the real OperatorsRegistry
contract ConsensusLayerDepositManagerV1UsesRegistry is ConsensusLayerDepositManagerV1 {
    IOperatorsRegistryV1 public registry;

    function _getRiverAdmin() internal pure override returns (address) {
        return address(0);
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

    function _onDepositsComplete(IConsensusLayerDepositManagerV1.ValidatorDeposit[] calldata _deposits)
        internal
        override
    {
        for (uint256 i = 0; i < _deposits.length; ++i) {
            registry.reportFundedBalance(_deposits[i].operatorIndex, _deposits[i].depositAmount);
        }
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

/// @notice Helper base for creating ValidatorDeposit arrays from inline hex key data
abstract contract ValidatorDepositHelper is Test {
    bytes internal constant TEST_PUBLIC_KEYS =
        hex"746ce769697901e86d4fb795527393e974d182e8ac03e6ea6c8bb3e0f4458e9196a87915affcc77c543e302e743fa15f65ecc7e935467d39f1296d8a5bd693ce87248f969b36d3f226f573d28a42bbcd4d27fe4399e60e9a55565391df1210c5d472643c683a63ae1e8d2796e52cb209dcf58188bb4d26fb9ede7a49d2737af9d32081497a0edd12aaf815157736c50814fdffbfb1fb51d4c5a4db9a2ff8222f036347e6046eb85c9e04bbcea922261694118aa4714685ffff83cbf3f74cabe2a01f8b1924045e9aceeba071cb46efc0ee3ff3ecd2eac6ecdd8d0bdbb660eabe30a695d887b6b5a138012ca0fcc40f652a6401c91102088769ef0df4f17874a8d2c832dc5371c6350b94fd637f6b7eba1f3aefea815460dd1bb56d41339a39bb977ca9018a56ee20ad09defcd184c3a9988bdbe0ca19da2d39e8ecd5aa4e7f1a81b3d9145ecd7a19317379c10edc875f345f4ccd905440a57986ea3e981804a3bfcd72c64faa543e3b7d1bc1eddb03df6576afec37e4cd04fb928d4039e8e7495e92efaa2cb7dcbb3e817f771b6fc0d6ce8db7cbed38bf6fabd198cd2b7184d7b737c1c05f1d1a10d8e8141b875f1d2c4681ddeb7bad423182704048f3fb9fe82bded37429b0643af12c730b0f0851815a6ef1a563fdcef7c05512b33278218c";
    bytes internal constant TEST_SIGNATURES =
        hex"6e93b287f9972d6e4bb7b9b7bdf75e2f3190b61dff0699d9708ee2a6e08f0ce1436b3f0213c1d7e0168cd1b221326b917e0dba509208bf586923ccc53e30b9bc697834508a4c54cd4f097f2c8c5d1b7b3c829fdc326f8df92aae75f008099e1e0324e6ea8734ab375bc33000ab02c63423c3dec20823ac27cadc1e393fa1f15774e52c6a5194dd9136f253b1dc8e0cf9f1a9eec02517d923af4f242e2215d4f82d2bfb657e666f24e5c5f8e6c9636250c0e8f2c20ddd91eda71d1ef5896dbc0fd84508f71958ab19b047030cee1911d55194e38051111021e0710e0be25c3f878ba11c7db118b06a6fc04570cba519c1aa4184693f024bc0e02019dfb62dacab8a2b1127d1b03645ed6377717cbd099aab8d6a5bef2be1aa8e0bb7e2565c8eddfa91b72ae014adb0a47a272d1aedd5920a2ec2f788fe76852b45961d959fdb627329326352f8f3e73bb758022265174af7bc6e3b8ef19f173244735f68789d0f6a34de6da1e22142478205388e8b9db291e01227aa5e4e7173aa11624341b31a202ffade6b5418099dd583708c1fb95525bbfa87b1d08455b640ce25cf322b00471f8dc813dbcd8b82c20e9d07c6215e86237d94ed6f81c7a7ffce0180c128be4f036203e9acfa713d41609a654de0a56a1689da6dcd3950dfd1e3f36987cca569ba947c97b205e34f8ed2dd87b4e29a822676457121ff48ee8bb4dd0b7200093883f6cde4edf1026abc5bc5692dbbfb2197fb4cfbac4eecc99b7956a4dab19cc74db50cf83ff35e880ef58457d3a5b444a17c072ea617ff28cf7bba2657f8ef118a8e6f65453548aafea8c8b88a0df7dbeeaecff69d05ff0dfc55fb97eb94b05b7d7aa748f5aaf6fe38aa6183f400d65e0152004780a089449a5bd77e04b7bd0682c67f5c4fd12bf56b6b31ec3eccfe104f8f64c8b9d23375e0078ba8fe6253037a8a2171682301d5463ce24b4e920af83fd009b6214450382309a143332e8dfa05a95dfa686a630b95b80cfd9b42d33cc3de7f5708dd67714192a14ca814a1f3cc4b4932c36831674ee8ba3a58f12643c1b4bf1e00370290ac4d5e994410d69bad8c691efaf5b6e8fe8331882f7dc304d8ccb6bd9d6079c1698dbdef47996c937046157498db082443ddd33f61e1abb204f12d553b25ea1d773812f701a3c9b36c5909c3b9ebd18d2ba1b8a2daeae36a2811a59bbae1d334fde54e07eac5770172c36d50d821fb181c97bb00a9684a904a2fc8c9c520e730fca4751b4f0d266dc33ddbb7e8ea065ccc47a7dbea61a185ab2413917a039e505e85e2f781eeef96658b94a07f9662ff3e6c8728de755c7a305f975ae8772c8b75468ad30a5467";

    /// @dev Create N ValidatorDeposit structs each with 32 ether, using inline hex test keys
    function _createDeposits(uint256 count)
        internal
        pure
        returns (IConsensusLayerDepositManagerV1.ValidatorDeposit[] memory)
    {
        return _createDeposits(count, 32 ether, 0);
    }

    /// @dev Create N ValidatorDeposit structs with specified amount and operatorIndex
    function _createDeposits(uint256 count, uint256 amount, uint256 operatorIndex)
        internal
        pure
        returns (IConsensusLayerDepositManagerV1.ValidatorDeposit[] memory)
    {
        uint256 effective = count > 10 ? 10 : count;
        IConsensusLayerDepositManagerV1.ValidatorDeposit[] memory deposits =
            new IConsensusLayerDepositManagerV1.ValidatorDeposit[](effective);
        for (uint256 i = 0; i < effective; ++i) {
            deposits[i] = IConsensusLayerDepositManagerV1.ValidatorDeposit({
                pubkey: LibBytes.slice(TEST_PUBLIC_KEYS, i * 48, 48),
                signature: LibBytes.slice(TEST_SIGNATURES, i * 96, 96),
                depositAmount: amount,
                operatorIndex: operatorIndex
            });
        }
        return deposits;
    }

    /// @dev Create a single ValidatorDeposit with an invalid 49-byte public key
    function _createDepositWithBadPubkey()
        internal
        pure
        returns (IConsensusLayerDepositManagerV1.ValidatorDeposit[] memory)
    {
        IConsensusLayerDepositManagerV1.ValidatorDeposit[] memory deposits =
            new IConsensusLayerDepositManagerV1.ValidatorDeposit[](1);
        deposits[0] = IConsensusLayerDepositManagerV1.ValidatorDeposit({
            pubkey: LibBytes.slice(TEST_PUBLIC_KEYS, 0, 49),
            signature: LibBytes.slice(TEST_SIGNATURES, 0, 96),
            depositAmount: 32 ether,
            operatorIndex: 0
        });
        return deposits;
    }

    /// @dev Create a single ValidatorDeposit with an invalid 97-byte signature
    function _createDepositWithBadSignature()
        internal
        pure
        returns (IConsensusLayerDepositManagerV1.ValidatorDeposit[] memory)
    {
        IConsensusLayerDepositManagerV1.ValidatorDeposit[] memory deposits =
            new IConsensusLayerDepositManagerV1.ValidatorDeposit[](1);
        deposits[0] = IConsensusLayerDepositManagerV1.ValidatorDeposit({
            pubkey: LibBytes.slice(TEST_PUBLIC_KEYS, 0, 48),
            signature: LibBytes.slice(TEST_SIGNATURES, 0, 97),
            depositAmount: 32 ether,
            operatorIndex: 0
        });
        return deposits;
    }

    /// @dev Create deposits from raw keys (pubkey+signature concatenated per validator)
    function _createDepositsFromRawKeys(bytes memory rawKeys, uint256 count, uint256 operatorIndex)
        internal
        pure
        returns (IConsensusLayerDepositManagerV1.ValidatorDeposit[] memory)
    {
        return _createDepositsFromRawKeys(rawKeys, count, operatorIndex, 32 ether);
    }

    function _createDepositsFromRawKeys(bytes memory rawKeys, uint256 count, uint256 operatorIndex, uint256 amount)
        internal
        pure
        returns (IConsensusLayerDepositManagerV1.ValidatorDeposit[] memory)
    {
        uint256 validatorSize = 48 + 96;
        IConsensusLayerDepositManagerV1.ValidatorDeposit[] memory deposits =
            new IConsensusLayerDepositManagerV1.ValidatorDeposit[](count);
        for (uint256 i = 0; i < count; ++i) {
            deposits[i] = IConsensusLayerDepositManagerV1.ValidatorDeposit({
                pubkey: LibBytes.slice(rawKeys, i * validatorSize, 48),
                signature: LibBytes.slice(rawKeys, i * validatorSize + 48, 96),
                depositAmount: amount,
                operatorIndex: operatorIndex
            });
        }
        return deposits;
    }

    /// @dev Concatenate two ValidatorDeposit arrays
    function _concatDeposits(
        IConsensusLayerDepositManagerV1.ValidatorDeposit[] memory a,
        IConsensusLayerDepositManagerV1.ValidatorDeposit[] memory b
    ) internal pure returns (IConsensusLayerDepositManagerV1.ValidatorDeposit[] memory) {
        IConsensusLayerDepositManagerV1.ValidatorDeposit[] memory result =
            new IConsensusLayerDepositManagerV1.ValidatorDeposit[](a.length + b.length);
        for (uint256 i = 0; i < a.length; ++i) {
            result[i] = a[i];
        }
        for (uint256 i = 0; i < b.length; ++i) {
            result[a.length + i] = b[i];
        }
        return result;
    }
}

contract ConsensusLayerDepositManagerV1Tests is ValidatorDepositHelper {
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
        vm.deal(address(depositManager), 31.9 ether);
        ConsensusLayerDepositManagerV1ExposeInitializer(address(depositManager)).sudoSyncBalance();
        vm.expectRevert(abi.encodeWithSignature("DepositAmountTooLow(uint256,uint256)", 31.9 ether, 32 ether));
        vm.prank(address(0x1));
        IConsensusLayerDepositManagerV1.ValidatorDeposit[] memory deposits =
            new IConsensusLayerDepositManagerV1.ValidatorDeposit[](1);
        deposits[0] = IConsensusLayerDepositManagerV1.ValidatorDeposit({
            pubkey: LibBytes.slice(TEST_PUBLIC_KEYS, 0, 48),
            signature: LibBytes.slice(TEST_SIGNATURES, 0, 96),
            depositAmount: 31.9 ether,
            operatorIndex: 0
        });
        depositManager.depositToConsensusLayer(deposits, bytes32(0));
    }

    function testDepositTenValidators() public {
        vm.deal(address(depositManager), 320 ether);
        ConsensusLayerDepositManagerV1ExposeInitializer(address(depositManager)).sudoSyncBalance();
        assert(address(depositManager).balance == 320 ether);
        vm.prank(address(0x1));
        depositManager.depositToConsensusLayer(_createDeposits(10), bytes32(0));
        assert(address(depositManager).balance == 0);
    }

    function testDepositLessThanMaxDepositableCount() public {
        vm.deal(address(depositManager), 640 ether);
        ConsensusLayerDepositManagerV1ExposeInitializer(address(depositManager)).sudoSyncBalance();
        assert(address(depositManager).balance == 640 ether);
        vm.prank(address(0x1));
        depositManager.depositToConsensusLayer(_createDeposits(10), bytes32(0));
        assert(address(depositManager).balance == 320 ether);
    }
}

contract ConsensusLayerDepositManagerV1ErrorTests is ValidatorDepositHelper {
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

    // For InconsistentPublicKeys - deposit with 49-byte pubkey
    function testInconsistentPublicKey() public {
        vm.deal(address(depositManager), 32 ether);
        ConsensusLayerDepositManagerV1ExposeInitializer(address(depositManager)).sudoSyncBalance();
        vm.expectRevert(abi.encodeWithSignature("InconsistentPublicKeys()"));
        vm.prank(address(0x1));
        depositManager.depositToConsensusLayer(_createDepositWithBadPubkey(), bytes32(0));
    }

    // For InconsistentSignatures - deposit with 97-byte signature
    function testInconsistentSignature() public {
        vm.deal(address(depositManager), 32 ether);
        ConsensusLayerDepositManagerV1ExposeInitializer(address(depositManager)).sudoSyncBalance();
        vm.expectRevert(abi.encodeWithSignature("InconsistentSignatures()"));
        vm.prank(address(0x1));
        depositManager.depositToConsensusLayer(_createDepositWithBadSignature(), bytes32(0));
    }

    function testEmptyDepositsArray() public {
        vm.deal(address(depositManager), 32 ether);
        ConsensusLayerDepositManagerV1ExposeInitializer(address(depositManager)).sudoSyncBalance();
        IConsensusLayerDepositManagerV1.ValidatorDeposit[] memory empty =
            new IConsensusLayerDepositManagerV1.ValidatorDeposit[](0);
        vm.expectRevert(abi.encodeWithSignature("EmptyDepositsArray()"));
        vm.prank(address(0x1));
        depositManager.depositToConsensusLayer(empty, bytes32(0));
    }

    function testDepositsExceedCommittedBalance() public {
        // Fund with only 2 deposits worth of ETH
        vm.deal(address(depositManager), 2 * 32 ether);
        ConsensusLayerDepositManagerV1ExposeInitializer(address(depositManager)).sudoSyncBalance();
        // Try to deposit 5 validators when only 2 can be funded
        vm.expectRevert(
            abi.encodeWithSignature("DepositsExceedCommittedBalance(uint256,uint256)", 5 * 32 ether, 2 * 32 ether)
        );
        vm.prank(address(0x1));
        depositManager.depositToConsensusLayer(_createDeposits(5), bytes32(0));
    }

    /// @notice Fund with exactly 2 deposits (64 ETH). Request 3 deposits.
    ///         Verify DepositsExceedCommittedBalance().
    function testDepositsExceedCommittedBalanceByOne() public {
        vm.deal(address(depositManager), 2 * 32 ether);
        ConsensusLayerDepositManagerV1ExposeInitializer(address(depositManager)).sudoSyncBalance();
        vm.expectRevert(
            abi.encodeWithSignature("DepositsExceedCommittedBalance(uint256,uint256)", 3 * 32 ether, 2 * 32 ether)
        );
        vm.prank(address(0x1));
        depositManager.depositToConsensusLayer(_createDeposits(3), bytes32(0));
    }

    /// @notice Fund with 3 deposits. Request exactly 3 deposits. Verify it succeeds (no revert).
    function testDepositsExactlyMatchCommittedBalance() public {
        vm.deal(address(depositManager), 3 * 32 ether);
        ConsensusLayerDepositManagerV1ExposeInitializer(address(depositManager)).sudoSyncBalance();
        vm.prank(address(0x1));
        depositManager.depositToConsensusLayer(_createDeposits(3), bytes32(0));
        assertEq(address(depositManager).balance, 0, "balance should be 0");
    }
}

/// @notice Integration tests for the full deposit flow: Keeper -> DepositManager -> DepositContract
contract ConsensusLayerDepositManagerV1FullDepositFlowTests is ValidatorDepositHelper, BytesGenerator {
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

    /// @dev Full flow: single operator, keeper deposits, registry funded and deposited balance updated
    function testFullDepositFlowSingleOperator() public {
        bytes memory rawKeys = genBytes((48 + 96) * 5);
        vm.startPrank(admin);
        registry.addOperator("Op0", admin);
        registry.addValidators(0, 5, rawKeys);
        uint256[] memory indexes = new uint256[](1);
        indexes[0] = 0;
        uint32[] memory limits = new uint32[](1);
        limits[0] = 5;
        registry.setOperatorLimits(indexes, limits, block.number);
        vm.stopPrank();

        uint256 toDeposit = 2;
        vm.deal(address(depositManager), toDeposit * 32 ether);
        ConsensusLayerDepositManagerV1UsesRegistry(address(depositManager)).sudoSyncBalance();

        IConsensusLayerDepositManagerV1.ValidatorDeposit[] memory deposits =
            _createDepositsFromRawKeys(rawKeys, toDeposit, 0);

        bytes32 depositRoot = depositContract.get_deposit_root();
        vm.prank(keeper);
        depositManager.depositToConsensusLayer(deposits, depositRoot);

        assertEq(
            depositManager.getDepositedBalance(), toDeposit * 32 ether, "incorrect deposited balance"
        );
        assertEq(address(depositManager).balance, 0, "manager balance after deposit");
    }

    /// @dev Full flow: three operators with middle one inactive; deposit only to op0 and op2
    function testFullDepositFlowWithInactiveOperatorInMiddle() public {
        bytes memory keys0 = genBytes((48 + 96) * 5);
        bytes memory keys2 = genBytes((48 + 96) * 5);
        vm.startPrank(admin);
        registry.addOperator("Op0", admin);
        registry.addValidators(0, 5, keys0);
        registry.addOperator("Op1", admin);
        registry.addValidators(1, 5, genBytes((48 + 96) * 5));
        registry.addOperator("Op2", admin);
        registry.addValidators(2, 5, keys2);
        uint256[] memory indexes = new uint256[](3);
        indexes[0] = 0;
        indexes[1] = 1;
        indexes[2] = 2;
        uint32[] memory limits = new uint32[](3);
        limits[0] = 5;
        limits[1] = 5;
        limits[2] = 5;
        registry.setOperatorLimits(indexes, limits, block.number);
        registry.setOperatorStatus(1, false);
        vm.stopPrank();

        uint256 fromOp0 = 2;
        uint256 fromOp2 = 3;
        uint256 total = fromOp0 + fromOp2;
        vm.deal(address(depositManager), total * 32 ether);
        ConsensusLayerDepositManagerV1UsesRegistry(address(depositManager)).sudoSyncBalance();

        IConsensusLayerDepositManagerV1.ValidatorDeposit[] memory depositsOp0 =
            _createDepositsFromRawKeys(keys0, fromOp0, 0);
        IConsensusLayerDepositManagerV1.ValidatorDeposit[] memory depositsOp2 =
            _createDepositsFromRawKeys(keys2, fromOp2, 2);
        IConsensusLayerDepositManagerV1.ValidatorDeposit[] memory deposits = _concatDeposits(depositsOp0, depositsOp2);

        bytes32 depositRoot = depositContract.get_deposit_root();
        vm.prank(keeper);
        depositManager.depositToConsensusLayer(deposits, depositRoot);

        assertEq(
            depositManager.getDepositedBalance(), total * 32 ether, "deposited balance"
        );
    }

    /// @dev Only keeper can call depositToConsensusLayer
    function testFullDepositFlowOnlyKeeperCanDeposit() public {
        bytes memory rawKeys = genBytes((48 + 96) * 2);
        vm.startPrank(admin);
        registry.addOperator("Op0", admin);
        registry.addValidators(0, 2, rawKeys);
        uint256[] memory indexes = new uint256[](1);
        indexes[0] = 0;
        uint32[] memory limits = new uint32[](1);
        limits[0] = 2;
        registry.setOperatorLimits(indexes, limits, block.number);
        vm.stopPrank();

        vm.deal(address(depositManager), 2 * 32 ether);
        ConsensusLayerDepositManagerV1UsesRegistry(address(depositManager)).sudoSyncBalance();

        IConsensusLayerDepositManagerV1.ValidatorDeposit[] memory deposits =
            _createDepositsFromRawKeys(rawKeys, 1, 0);

        bytes32 depositRoot = depositContract.get_deposit_root();
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSignature("OnlyKeeper()"));
        depositManager.depositToConsensusLayer(deposits, depositRoot);
    }

    /// @dev Sequential deposits: first 2 validators, then 3 more from same operator
    function testFullDepositFlowSequentialDeposits() public {
        bytes memory rawKeys = genBytes((48 + 96) * 10);
        vm.startPrank(admin);
        registry.addOperator("Op0", admin);
        registry.addValidators(0, 10, rawKeys);
        uint256[] memory indexes = new uint256[](1);
        indexes[0] = 0;
        uint32[] memory limits = new uint32[](1);
        limits[0] = 10;
        registry.setOperatorLimits(indexes, limits, block.number);
        vm.stopPrank();

        vm.deal(address(depositManager), 5 * 32 ether);
        ConsensusLayerDepositManagerV1UsesRegistry(address(depositManager)).sudoSyncBalance();

        IConsensusLayerDepositManagerV1.ValidatorDeposit[] memory deposits1 =
            _createDepositsFromRawKeys(rawKeys, 2, 0);

        bytes32 depositRoot = depositContract.get_deposit_root();
        vm.prank(keeper);
        depositManager.depositToConsensusLayer(deposits1, depositRoot);

        assertEq(depositManager.getDepositedBalance(), 2 * 32 ether, "deposited after first");
        assertEq(address(depositManager).balance, 3 * 32 ether, "remaining balance");

        // Create deposits for keys at offset 2 (next 3 validators)
        uint256 validatorSize = 48 + 96;
        IConsensusLayerDepositManagerV1.ValidatorDeposit[] memory deposits2 =
            new IConsensusLayerDepositManagerV1.ValidatorDeposit[](3);
        for (uint256 i = 0; i < 3; ++i) {
            deposits2[i] = IConsensusLayerDepositManagerV1.ValidatorDeposit({
                pubkey: LibBytes.slice(rawKeys, (i + 2) * validatorSize, 48),
                signature: LibBytes.slice(rawKeys, (i + 2) * validatorSize + 48, 96),
                depositAmount: 32 ether,
                operatorIndex: 0
            });
        }
        vm.prank(keeper);
        depositManager.depositToConsensusLayer(deposits2, depositRoot);

        assertEq(depositManager.getDepositedBalance(), 5 * 32 ether, "deposited after second");
        assertEq(address(depositManager).balance, 0, "balance drained");
    }
}

contract ConsensusLayerDepositManagerV1WithdrawalCredentialError is ValidatorDepositHelper {
    bytes32 internal withdrawalCredentials = bytes32(uint256(1));

    ConsensusLayerDepositManagerV1 internal depositManager;
    IDepositContract internal depositContract;

    function setUp() public {
        depositContract = new DepositContractMock();

        depositManager = new ConsensusLayerDepositManagerV1ExposeInitializer();
        vm.store(
            address(depositManager),
            bytes32(uint256(keccak256("river.state.depositContractAddress")) - 1),
            bytes32(uint256(uint160(address(depositContract))))
        );
        LibImplementationUnbricker.unbrick(vm, address(depositManager));
    }

    function testInvalidWithdrawalCredential() public {
        vm.deal(address(depositManager), 32 ether);
        ConsensusLayerDepositManagerV1ExposeInitializer(address(depositManager)).sudoSyncBalance();
        ConsensusLayerDepositManagerV1ExposeInitializer(address(depositManager)).setKeeper(address(0x1));
        vm.expectRevert(abi.encodeWithSignature("InvalidWithdrawalCredentials()"));
        vm.prank(address(0x1));
        depositManager.depositToConsensusLayer(_createDeposits(1), bytes32(0));
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

    function _onDepositsComplete(IConsensusLayerDepositManagerV1.ValidatorDeposit[] calldata) internal override {}

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

contract ConsensusLayerDepositManagerV1ValidKeysTest is Test {
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

    function _createValidKeyDeposit()
        internal
        view
        returns (IConsensusLayerDepositManagerV1.ValidatorDeposit[] memory)
    {
        IConsensusLayerDepositManagerV1.ValidatorDeposit[] memory deposits =
            new IConsensusLayerDepositManagerV1.ValidatorDeposit[](1);
        deposits[0] = IConsensusLayerDepositManagerV1.ValidatorDeposit({
            pubkey: ConsensusLayerDepositManagerV1ValidKeys(address(depositManager))._publicKeys(),
            signature: ConsensusLayerDepositManagerV1ValidKeys(address(depositManager))._signatures(),
            depositAmount: 32 ether,
            operatorIndex: 0
        });
        return deposits;
    }

    function testDepositValidKey() external {
        vm.deal(address(depositManager), 32 ether);
        ConsensusLayerDepositManagerV1ValidKeys(address(depositManager)).sudoSyncBalance();
        vm.store(
            address(depositManager),
            bytes32(uint256(keccak256("river.state.KeeperAddress")) - 1),
            bytes32(uint256(uint160(address(0x1))))
        );
        vm.startPrank(address(0x1));
        depositManager.depositToConsensusLayer(_createValidKeyDeposit(), depositContract.get_deposit_root());
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
        depositManager.depositToConsensusLayer(_createValidKeyDeposit(), bytes32(0));
    }
}

contract ConsensusLayerDepositManagerV1InvalidDepositContract is Test {
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

    function _createValidKeyDeposit()
        internal
        view
        returns (IConsensusLayerDepositManagerV1.ValidatorDeposit[] memory)
    {
        IConsensusLayerDepositManagerV1.ValidatorDeposit[] memory deposits =
            new IConsensusLayerDepositManagerV1.ValidatorDeposit[](1);
        deposits[0] = IConsensusLayerDepositManagerV1.ValidatorDeposit({
            pubkey: ConsensusLayerDepositManagerV1ValidKeys(address(depositManager))._publicKeys(),
            signature: ConsensusLayerDepositManagerV1ValidKeys(address(depositManager))._signatures(),
            depositAmount: 32 ether,
            operatorIndex: 0
        });
        return deposits;
    }

    function testDepositInvalidDepositContract() external {
        vm.deal(address(depositManager), 32 ether);
        ConsensusLayerDepositManagerV1ValidKeys(address(depositManager)).sudoSyncBalance();
        vm.expectRevert(abi.encodeWithSignature("ErrorOnDeposit()"));
        vm.prank(address(0x1));
        depositManager.depositToConsensusLayer(_createValidKeyDeposit(), bytes32(0));
    }
}

contract ConsensusLayerDepositManagerV1KeeperTest is Test {
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

    function _createValidKeyDeposit()
        internal
        view
        returns (IConsensusLayerDepositManagerV1.ValidatorDeposit[] memory)
    {
        IConsensusLayerDepositManagerV1.ValidatorDeposit[] memory deposits =
            new IConsensusLayerDepositManagerV1.ValidatorDeposit[](1);
        deposits[0] = IConsensusLayerDepositManagerV1.ValidatorDeposit({
            pubkey: ConsensusLayerDepositManagerV1ValidKeys(address(depositManager))._publicKeys(),
            signature: ConsensusLayerDepositManagerV1ValidKeys(address(depositManager))._signatures(),
            depositAmount: 32 ether,
            operatorIndex: 0
        });
        return deposits;
    }

    function testDepositValidKeeper() external {
        vm.deal(address(depositManager), 32 ether);
        ConsensusLayerDepositManagerV1ValidKeys(address(depositManager)).sudoSyncBalance();
        vm.store(
            address(depositManager),
            bytes32(uint256(keccak256("river.state.KeeperAddress")) - 1),
            bytes32(uint256(uint160(address(0x1))))
        );
        vm.startPrank(address(0x1));
        depositManager.depositToConsensusLayer(_createValidKeyDeposit(), depositContract.get_deposit_root());
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
        depositManager.depositToConsensusLayer(_createValidKeyDeposit(), depositRoot);
    }
}
