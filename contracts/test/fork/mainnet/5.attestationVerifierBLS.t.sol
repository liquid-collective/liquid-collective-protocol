// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "forge-std/Test.sol";

import "../../../src/AttestationVerifier.1.sol";
import "../../../src/components/ConsensusLayerDepositManager.1.sol";
import "../../../src/interfaces/IDepositDataBuffer.sol";
import "../../../src/interfaces/IOperatorRegistry.1.sol";
import "../../../src/libraries/BLS12_381.sol";
import "../../../src/state/river/CommittedBalance.sol";
import "../../../src/state/river/DepositContractAddress.sol";
import "../../../src/state/shared/AttestationVerifierAddress.sol";
import "../../mocks/DepositContractEnhancedMock.sol";
import "../../utils/LibImplementationUnbricker.sol";

contract RealBLSForkDepositDataBuffer is IDepositDataBuffer {
    mapping(bytes32 => DepositObject) internal _batches;
    mapping(bytes32 => uint256) internal _nonce;
    mapping(bytes32 => bool) internal _exists;
    mapping(bytes32 => bool) internal _processed;
    address internal _processor;
    uint256 public lastQueuedIdx;

    constructor(address processor) {
        _processor = processor;
    }

    function submitDepositData(bytes32 depositDataBufferId, DepositObject calldata batch) external {
        if (_exists[depositDataBufferId]) revert DepositDataBufferIdAlreadyExists(depositDataBufferId);
        uint256 nonce = lastQueuedIdx;
        _exists[depositDataBufferId] = true;
        _nonce[depositDataBufferId] = nonce;
        DepositObject storage stored = _batches[depositDataBufferId];
        for (uint256 i = 0; i < batch.deposits.length; ++i) {
            stored.deposits.push(batch.deposits[i]);
        }
        for (uint256 i = 0; i < batch.topUps.length; ++i) {
            stored.topUps.push(batch.topUps[i]);
        }
        emit DepositDataSubmitted(depositDataBufferId, nonce, batch.deposits.length, batch.topUps.length);
        ++lastQueuedIdx;
    }

    function getDepositData(bytes32 depositDataBufferId) external view returns (DepositObject memory, uint256 nonce) {
        if (!_exists[depositDataBufferId]) revert DepositDataBufferIdNotFound(depositDataBufferId);
        return (_batches[depositDataBufferId], _nonce[depositDataBufferId]);
    }

    function markDepositDataProcessed(bytes32 depositDataBufferId) external {
        if (msg.sender != _processor) revert OnlyProcessor();
        if (!_exists[depositDataBufferId]) revert DepositDataBufferIdNotFound(depositDataBufferId);
        if (_processed[depositDataBufferId]) revert DepositDataAlreadyProcessed(depositDataBufferId);
        _processed[depositDataBufferId] = true;
        emit DepositDataProcessed(depositDataBufferId);
    }

    function isDepositDataProcessed(bytes32 depositDataBufferId) external view returns (bool) {
        return _processed[depositDataBufferId];
    }

    function setProducer(address) external {}

    function setProcessor(address newProcessor) external {
        _processor = newProcessor;
        emit SetProcessor(newProcessor);
    }

    function getProducer() external pure returns (address) {
        return address(0);
    }

    function proposeAdmin(address) external {}

    function acceptAdmin() external {}

    function getAdmin() external pure returns (address) {
        return address(0);
    }

    function getPendingAdmin() external pure returns (address) {
        return address(0);
    }

    function getProcessor() external view returns (address) {
        return _processor;
    }
}

contract RealBLSForkDepositHarness is ConsensusLayerDepositManagerV1 {
    address internal immutable _admin;

    constructor(address admin_) {
        _admin = admin_;
    }

    function getAdmin() external view returns (address) {
        return _admin;
    }

    function initialize(address depositContract_, bytes32 withdrawalCredentials_) external {
        initConsensusLayerDepositManagerV1(depositContract_, withdrawalCredentials_);
    }

    function sudoSetKeeper(address keeper_) external {
        _setKeeper(keeper_);
    }

    function sudoSetCommittedBalance(uint256 value) external {
        CommittedBalance.set(value);
    }

    function sudoSetAttestationVerifier(address verifier_) external {
        AttestationVerifierAddress.set(verifier_);
    }

    function sudoSetDepositContract(address depositContract_) external {
        DepositContractAddress.set(depositContract_);
    }

    function _getRiverAdmin() internal view override returns (address) {
        return _admin;
    }

    function _incrementFundedETH(IOperatorsRegistryV1.OperatorFundingDelta[] memory) internal pure override {}

    function _setCommittedBalance(uint256 newCommittedBalance) internal override {
        CommittedBalance.set(newCommittedBalance);
    }

    function _updateFundedETHFromBuffer(IDepositDataBuffer.Deposit[] memory, IDepositDataBuffer.TopUp[] memory)
        internal
        pure
        override
    {}

    function _getSlashingContainmentMode() internal pure override returns (bool) {
        return false;
    }

    receive() external payable {}
}

/// @dev Shared fixture and helpers for the real BLS mainnet-fork regression tests.
abstract contract AttestationVerifierRealBLSForkBase is Test {
    bool internal _skip;

    RealBLSForkDepositHarness internal dm;
    AttestationVerifierV1 internal verifier;
    RealBLSForkDepositDataBuffer internal buffer;
    DepositContractEnhancedMock internal depositContract;

    address internal admin = address(0xAD);
    address internal keeper = address(0xBEEF);
    bytes32 internal withdrawalCredentials = 0x02000000000000000000000000000000000000000000000000000000CAFEBABE;

    uint256 internal rootAttesterPk1 = 0xA1;
    uint256 internal rootAttesterPk2 = 0xA2;
    address internal rootAttester1;
    address internal rootAttester2;

    bytes32 internal constant EIP712_DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 internal constant NAME_HASH = keccak256("DepositToConsensusLayerValidation");
    bytes32 internal constant VERSION_HASH = keccak256("1");
    bytes32 internal constant ATTEST_TYPEHASH =
        keccak256("Attest(bytes32 depositDataBufferId,bytes32 depositRootHash)");

    function setUp() public virtual {
        try vm.envString("MAINNET_FORK_RPC_URL") returns (string memory rpcUrl) {
            vm.createSelectFork(rpcUrl);
            console.log("5.attestationVerifierBLS.t.sol is active");
        } catch {
            _skip = true;
            return;
        }

        rootAttester1 = vm.addr(rootAttesterPk1);
        rootAttester2 = vm.addr(rootAttesterPk2);

        depositContract = new DepositContractEnhancedMock();
        dm = new RealBLSForkDepositHarness(admin);
        LibImplementationUnbricker.unbrick(vm, address(dm));
        dm.initialize(address(depositContract), withdrawalCredentials);
        dm.sudoSetKeeper(keeper);
        buffer = new RealBLSForkDepositDataBuffer(address(dm));

        address[] memory rootAttesters = new address[](2);
        rootAttesters[0] = rootAttester1;
        rootAttesters[1] = rootAttester2;

        address[] memory consolidationCommitteeAttesters = new address[](1);
        consolidationCommitteeAttesters[0] = makeAddr("consolidationCommitteeAttester");

        verifier = new AttestationVerifierV1();
        LibImplementationUnbricker.unbrick(vm, address(verifier));
        verifier.initAttestationVerifierV1(
            address(dm), address(buffer), rootAttesters, 2, bytes4(0), consolidationCommitteeAttesters, 1
        );
        dm.sudoSetAttestationVerifier(address(verifier));

        vm.deal(address(dm), 128 ether);
        dm.sudoSetCommittedBalance(128 ether);
    }

    modifier shouldSkip() {
        if (!_skip) {
            _;
        }
    }

    function _prepareDeposit(IDepositDataBuffer.Deposit memory deposit)
        internal
        returns (bytes32 bufferId, bytes32 rootHash, bytes[] memory sigs)
    {
        IDepositDataBuffer.DepositObject memory batch;
        batch.deposits = new IDepositDataBuffer.Deposit[](1);
        batch.deposits[0] = deposit;

        bufferId = keccak256(abi.encode(batch, buffer.lastQueuedIdx()));
        buffer.submitDepositData(bufferId, batch);
        rootHash = depositContract.get_deposit_root();

        sigs = new bytes[](2);
        sigs[0] = _signAttestation(rootAttesterPk1, bufferId, rootHash);
        sigs[1] = _signAttestation(rootAttesterPk2, bufferId, rootHash);
    }

    function _signAttestation(uint256 pk, bytes32 bufferId, bytes32 rootHash) internal view returns (bytes memory) {
        bytes32 domainSep =
            keccak256(abi.encode(EIP712_DOMAIN_TYPEHASH, NAME_HASH, VERSION_HASH, block.chainid, address(dm)));
        bytes32 structHash = keccak256(abi.encode(ATTEST_TYPEHASH, bufferId, rootHash));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSep, structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
        return abi.encodePacked(r, s, v);
    }

    function _validBLSDeposit() internal pure returns (IDepositDataBuffer.Deposit memory) {
        return IDepositDataBuffer.Deposit({
            pubkey: hex"a4e8f4a4f81f855f46512af8cdcbc9ae8a7eb395a75f135e5569b758a8d92349681a0358500f2d41f4578d3f7ffaa90f",
            signature: hex"89f0c238a39ebc397af7e659d343530ca146c394b69cb084925c28674fb0ff1201ee606a228741e472ddeeb895749726101c82baff01d4fc91a4108e61c3610f9e22a5fb2068de544e341051b676a5029b8751e7a330e1b4b9d40dada5f420b2",
            amount: 32 ether,
            operatorIdx: 0,
            depositY: BLS12_381.DepositY({
                pubkeyY: BLS12_381.Fp({
                    a: 0x000000000000000000000000000000000fd3ac7ce4abd5dbfb31b2ff1138bab5,
                    b: 0xe8ad04dd0955bf4acb36a7efca65908778da1c90dfef588841e8b73c7926e3e2
                }),
                signatureY: BLS12_381.Fp2({
                    c0_a: 0x000000000000000000000000000000000a9a5b8a151b666cb5369f4aac229682,
                    c0_b: 0xd7ef9230dbf78708d10dfa7f7ee06435b3a2fbad7ebbe5f196d493077d1bd152,
                    c1_a: 0x000000000000000000000000000000000bca41b8aba8f2a22209fa9bffd453b9,
                    c1_b: 0x685b1ef04fbfc994aa4a3c5909de04ede846d8c8dc82b877ca2a525df0325ced
                })
            })
        });
    }
}

/// @notice Fork-gated regression coverage for issue #499: the initial-deposit path
///         must execute the real BLS12-381/EIP-2537 pairing verification, not a Foundry mock.
contract AttestationVerifierRealBLSForkTest is AttestationVerifierRealBLSForkBase {
    function testInitialDeposit_executesRealBLSVerification() external shouldSkip {
        IDepositDataBuffer.Deposit memory deposit = _validBLSDeposit();
        (bytes32 bufferId, bytes32 rootHash, bytes[] memory sigs) = _prepareDeposit(deposit);

        vm.prank(keeper);
        dm.depositToConsensusLayerWithAttestation(bufferId, rootHash, sigs);

        assertEq(depositContract.deposit_count(), 1, "deposit should execute");
        assertEq(dm.getCommittedBalance(), 96 ether, "committed balance should decrease");
        assertEq(dm.getTotalDepositedETH(), 32 ether, "total deposited should increase");
        assertTrue(buffer.isDepositDataProcessed(bufferId), "buffer id should be processed");
        assertTrue(verifier.isPubkeyFunded(deposit.pubkey), "pubkey should be marked funded");
    }

    function testInitialDeposit_rejectsTamperedBLSMessage() external shouldSkip {
        IDepositDataBuffer.Deposit memory deposit = _validBLSDeposit();
        deposit.amount = 33 ether;
        (bytes32 bufferId, bytes32 rootHash, bytes[] memory sigs) = _prepareDeposit(deposit);

        vm.expectRevert(BLS12_381.InvalidSignature.selector);
        vm.prank(keeper);
        dm.depositToConsensusLayerWithAttestation(bufferId, rootHash, sigs);
    }
}
