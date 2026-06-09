// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "forge-std/Test.sol";

import "../../src/AttestationVerifier.1.sol";
import "../../src/Initializable.sol";
import "../../src/components/ConsensusLayerDepositManager.1.sol";
import "../../src/interfaces/IAttestationVerifier.1.sol";
import "../../src/interfaces/IDepositDataBuffer.sol";
import "../../src/interfaces/IOperatorRegistry.1.sol";
import "../../src/interfaces/IWithdraw.1.sol";
import "../../src/libraries/LibErrors.sol";
import "../../src/libraries/LibFundingDeltas.sol";
import "../../src/libraries/BLS12_381.sol";
import "../../src/state/shared/AttestationVerifierAddress.sol";
import "../utils/LibImplementationUnbricker.sol";
import "../mocks/DepositContractEnhancedMock.sol";

// ---------------------------------------------------------------------------
// Mock DepositDataBuffer — no real implementation exists; stores batches by ID
// ---------------------------------------------------------------------------

contract MockDepositDataBuffer is IDepositDataBuffer {
    mapping(bytes32 => DepositObject) internal _batches;
    mapping(bytes32 => bool) internal _exists;

    function submitDepositData(bytes32 depositDataBufferId, DepositObject calldata batch) external {
        if (_exists[depositDataBufferId]) revert DepositDataBufferIdAlreadyExists(depositDataBufferId);
        _exists[depositDataBufferId] = true;
        DepositObject storage stored = _batches[depositDataBufferId];
        for (uint256 i = 0; i < batch.deposits.length; i++) {
            stored.deposits.push(batch.deposits[i]);
        }
        for (uint256 i = 0; i < batch.topUps.length; i++) {
            stored.topUps.push(batch.topUps[i]);
        }
        emit DepositDataSubmitted(depositDataBufferId, batch.deposits.length, batch.topUps.length);
    }

    function getDepositData(bytes32 depositDataBufferId) external view returns (DepositObject memory) {
        if (!_exists[depositDataBufferId]) revert DepositDataBufferIdNotFound(depositDataBufferId);
        return _batches[depositDataBufferId];
    }

    function getWriter() external pure returns (address) {
        return address(0);
    }

    function getAdmin() external pure returns (address) {
        return address(0);
    }
}

contract MockPrePectraOperatorsRegistry {
    mapping(uint256 => uint256) internal _funded;
    mapping(uint256 => mapping(uint256 => bytes)) internal _pubkeys;

    function setPrePectraFundedValidatorCount(uint256 operatorIndex, uint256 funded) external {
        _funded[operatorIndex] = funded;
    }

    function setPrePectraValidatorPubkey(uint256 operatorIndex, uint256 keyIndex, bytes calldata pubkey) external {
        _pubkeys[operatorIndex][keyIndex] = pubkey;
    }

    function getPrePectraFundedValidatorCount(uint256 operatorIndex) external view returns (uint256) {
        return _funded[operatorIndex];
    }

    function getPrePectraValidatorPubkeys(uint256 operatorIndex, uint256 startIndex, uint256 stopIndex)
        external
        view
        returns (bytes[] memory pubkeys)
    {
        pubkeys = new bytes[](stopIndex - startIndex);
        for (uint256 i = startIndex; i < stopIndex; ++i) {
            pubkeys[i - startIndex] = _pubkeys[operatorIndex][i];
        }
    }
}

// ---------------------------------------------------------------------------
// Test harness — mirrors RiverV1's wiring for the deposit-execution side. The
// attestation+BLS validation now lives in AttestationVerifierV1 (a sibling
// contract); the harness delegates to it via AttestationVerifierAddress.
//
// Only _incrementFundedETH is stubbed (records values for assertions) because
// the real implementation requires the full OperatorsRegistry. _updateFundedETHFromBuffer
// is the real River implementation so that FundedValidatorKeys event emission is
// covered end-to-end.
// ---------------------------------------------------------------------------

contract AttestationDepositHarness is ConsensusLayerDepositManagerV1 {
    address internal immutable _admin;

    /// @dev Records funded ETH per operator index after each deposit batch, indexed by
    ///      operatorIndex. Each test gets a fresh harness via setUp, so no reset needed.
    mapping(uint256 => uint256) public lastFundedETH;

    /// @dev Operator-count bound used by LibFundingDeltas.build. Default well above any
    ///      operator index used by existing tests; tests that exercise the InvalidOperatorIndex
    ///      revert path can shrink it via sudoSetOperatorCount.
    uint256 public harnessOperatorCount = 1024;

    address internal operatorsRegistry;

    constructor(address admin_) {
        _admin = admin_;
    }

    /// @notice Exposes the harness's admin so the AttestationVerifier's
    ///         `onlyRiverAdmin` cross-contract lookup (IAdministrable.getAdmin) works.
    function getAdmin() external view returns (address) {
        return _admin;
    }

    function getOperatorsRegistry() external view returns (address) {
        return operatorsRegistry;
    }

    function _getRiverAdmin() internal view override returns (address) {
        return _admin;
    }

    function _setCommittedBalance(uint256 v) internal override {
        CommittedBalance.set(v);
    }

    function _getSlashingContainmentMode() internal pure override returns (bool) {
        return false;
    }

    /// @dev Recording stub — stores funded ETH per operator for test assertions.
    function _incrementFundedETH(IOperatorsRegistryV1.OperatorFundingDelta[] memory deltas) internal override {
        for (uint256 i = 0; i < deltas.length; i++) {
            lastFundedETH[deltas[i].operatorIndex] = deltas[i].fundedETH;
        }
    }

    /// @dev Delegates bucketing to LibFundingDeltas — the exact same code path River uses —
    ///      then forwards to the recording stub and emits FundedValidatorKeys per delta
    ///      (simulating what the real registry emits).
    function _updateFundedETHFromBuffer(
        IDepositDataBuffer.Deposit[] memory deposits,
        IDepositDataBuffer.TopUp[] memory topUps
    ) internal override {
        if (deposits.length == 0 && topUps.length == 0) return;
        IOperatorsRegistryV1.OperatorFundingDelta[] memory deltas =
            LibFundingDeltas.build(deposits, topUps, harnessOperatorCount);
        _incrementFundedETH(deltas);
        for (uint256 i = 0; i < deltas.length; i++) {
            emit IOperatorsRegistryV1.FundedValidatorKeys(deltas[i].operatorIndex, deltas[i].newPublicKeys, false);
        }
    }

    // -- Public admin helpers for test setup ----------------------------------

    function initialize(address depositContract_, bytes32 wc_) external {
        initConsensusLayerDepositManagerV1(depositContract_, wc_);
    }

    function sudoSetKeeper(address k) external {
        _setKeeper(k);
    }

    function sudoSetCommittedBalance(uint256 v) external {
        CommittedBalance.set(v);
    }

    function sudoSetAttestationVerifier(address v) external {
        AttestationVerifierAddress.set(v);
    }

    function sudoSetOperatorsRegistry(address v) external {
        operatorsRegistry = v;
    }

    function sudoSetOperatorCount(uint256 c) external {
        harnessOperatorCount = c;
    }

    receive() external payable {}
}

// ---------------------------------------------------------------------------
// End-to-end attestation deposit test
//
// Mocking strategy:
//   - BLS verification (verifyBLSDeposit) is mocked via vm.mockCall on the
//     AttestationVerifier address because EIP-2537 precompiles do not exist
//     in Foundry's EVM (without --evm-version prague + a vector).
//   - DepositDataBuffer is a minimal mock because no real implementation exists.
//   - Everything else runs real code:
//       * DepositContractEnhancedMock validates depositDataRoot, field lengths,
//         amounts, and maintains a real Merkle tree
//       * EIP-712 attestation signatures are real (generated via vm.sign)
//       * Operator metadata parsing, WC matching, balance accounting, and
//         FundedValidatorKeys event emission all run production logic
// ---------------------------------------------------------------------------

contract ConsensusLayerDepositManagerAttestationTest is Test {
    AttestationDepositHarness internal dm;
    AttestationVerifierV1 internal validator;
    MockDepositDataBuffer internal buffer;
    MockPrePectraOperatorsRegistry internal prePectraRegistry;
    DepositContractEnhancedMock internal depositContract;

    address internal admin = address(0xAD);
    address internal keeper = address(0xBEEF);
    bytes32 internal withdrawalCredentials = bytes32(uint256(0x010000000000000000000000CAFEBABE));

    uint256 internal rootAttesterPk1 = 0xA1;
    uint256 internal rootAttesterPk2 = 0xA2;
    uint256 internal rootAttesterPk3 = 0xA3;
    address internal rootAttester1;
    address internal rootAttester2;
    address internal rootAttester3;

    // EIP-712 constants (must match AttestationVerifierV1)
    bytes32 internal constant EIP712_DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 internal constant NAME_HASH = keccak256("DepositToConsensusLayerValidation");
    bytes32 internal constant VERSION_HASH = keccak256("1");
    bytes32 internal constant ATTEST_TYPEHASH =
        keccak256("Attest(bytes32 depositDataBufferId,bytes32 depositRootHash)");

    // Validator-scoped storage slots (must match contracts/src/state/attestationVerifier/*)
    bytes32 internal constant VALIDATOR_DOMAIN_SEPARATOR_SLOT =
        bytes32(uint256(keccak256("attestationVerifier.state.domainSeparator")) - 1);
    bytes32 internal constant VALIDATOR_DEPOSIT_DOMAIN_SLOT =
        bytes32(uint256(keccak256("attestationVerifier.state.depositDomain")) - 1);
    bytes32 internal constant VALIDATOR_ROOT_ATTESTATION_QUORUM_SLOT =
        bytes32(uint256(keccak256("attestationVerifier.state.rootAttestationQuorum")) - 1);
    bytes32 internal constant PECTRA_VALIDATOR_PUBKEY_LOOKUP_SLOT =
        bytes32(uint256(keccak256("attestationVerifier.state.pectraValidatorPubkeyLookup")) - 1);

    event MigratedPrePectraValidatorPubkeys(uint256 indexed operatorIndex, uint256 startIndex, uint256 stopIndex);
    event RemovedPrePectraValidatorPubkeys(bytes[] pubkeys);
    event AddedPectraValidatorPubkeys(bytes[] pubkeys);
    event RemovedPectraValidatorPubkeys(bytes[] pubkeys);
    event FundedValidatorKeys(uint256 indexed operatorIndex, bytes[] publicKeys, bool deferred);
    event SetInFlightETH(uint256 oldInFlightETH, uint256 newInFlightETH);
    event SetTotalDepositedETH(uint256 oldTotalDepositedETH, uint256 newTotalDepositedETH);
    event PubkeyFunded(bytes32 indexed depositDataBufferId, uint256 indexed operatorIdx, bytes pubkey, uint256 amount);
    event TopUp(bytes32 indexed depositDataBufferId, uint256 indexed operatorIdx, bytes pubkey, uint256 amount);

    function _emptyDepositY() internal pure returns (BLS12_381.DepositY memory) {
        return BLS12_381.DepositY({
            pubkeyY: BLS12_381.Fp({a: bytes32(0), b: bytes32(0)}),
            signatureY: BLS12_381.Fp2({c0_a: bytes32(0), c0_b: bytes32(0), c1_a: bytes32(0), c1_b: bytes32(0)})
        });
    }

    /// @dev Non-zero placeholder DepositY for initial deposits. The BLS path is mocked in
    ///      these tests (EIP-2537 precompiles aren't enabled in Foundry), so any non-zero
    ///      value works — the contract only needs to distinguish it from the zero sentinel
    ///      that marks top-ups.
    function _nonZeroDepositY(uint256 seed) internal pure returns (BLS12_381.DepositY memory) {
        return BLS12_381.DepositY({
            pubkeyY: BLS12_381.Fp({a: bytes32(uint256(seed) + 1), b: bytes32(0)}),
            signatureY: BLS12_381.Fp2({c0_a: bytes32(0), c0_b: bytes32(0), c1_a: bytes32(0), c1_b: bytes32(0)})
        });
    }

    /// @dev Mark a pubkey as initial-deposited directly via vm.store, bypassing the
    ///      `recordNewlyFundedPubkeys` path. Used by tests that need a seeded mapping but want
    ///      to stay focused on the BLS-skip / membership behaviour (rather than running a
    ///      full prior batch). The stored value matches the PectraValidatorPubkeyLookup library's
    ///      boolean-membership scheme.
    function _seedFundedPubkey(bytes memory pubkey) internal {
        bytes32 slot = keccak256(abi.encode(PECTRA_VALIDATOR_PUBKEY_LOOKUP_SLOT, pubkey));
        vm.store(address(validator), slot, bytes32(uint256(1)));
    }

    function setUp() public {
        rootAttester1 = vm.addr(rootAttesterPk1);
        rootAttester2 = vm.addr(rootAttesterPk2);
        rootAttester3 = vm.addr(rootAttesterPk3);

        depositContract = new DepositContractEnhancedMock();
        buffer = new MockDepositDataBuffer();
        prePectraRegistry = new MockPrePectraOperatorsRegistry();

        // 1. Deploy and init the harness (River-shaped).
        dm = new AttestationDepositHarness(admin);
        LibImplementationUnbricker.unbrick(vm, address(dm));
        dm.initialize(address(depositContract), withdrawalCredentials);
        dm.sudoSetKeeper(keeper);
        dm.sudoSetOperatorsRegistry(address(prePectraRegistry));

        // 2. Deploy and init the AttestationVerifier. The validator's EIP-712
        //    domain separator binds verifyingContract to the harness's address
        //    so root attester signing tooling stays River-anchored.
        address[] memory rootAttesters = new address[](3);
        rootAttesters[0] = rootAttester1;
        rootAttesters[1] = rootAttester2;
        rootAttesters[2] = rootAttester3;

        address[] memory consolidationCommitteeAttesters = new address[](1);
        consolidationCommitteeAttesters[0] = makeAddr("consolidationCommitteeAttesterStub");

        validator = new AttestationVerifierV1();
        LibImplementationUnbricker.unbrick(vm, address(validator));
        validator.initAttestationVerifierV1(
            address(dm), address(buffer), rootAttesters, 2, bytes4(0), consolidationCommitteeAttesters, 1
        );

        // 3. Wire the validator address into the harness.
        dm.sudoSetAttestationVerifier(address(validator));

        // 4. Fund the harness and set committed balance.
        vm.deal(address(dm), 128 ether);
        dm.sudoSetCommittedBalance(128 ether);

        // 5. Mock BLS verification on the validator address (EIP-2537 precompiles are
        //    not enabled in Foundry's default EVM). verifyBLSDeposit is called via
        //    staticcall from validate; mocking returns success.
        vm.mockCall(address(validator), abi.encodeWithSelector(validator.verifyBLSDeposit.selector), bytes(""));
    }

    // -----------------------------------------------------------------------
    // Helpers
    // -----------------------------------------------------------------------

    /// @dev Generate a deterministic 48-byte pubkey (valid length for deposit contract).
    function _fakePubkey(uint256 seed) internal pure returns (bytes memory) {
        return abi.encodePacked(sha256(abi.encode("pubkey", seed)), bytes16(0));
    }

    /// @dev Generate a deterministic 96-byte signature (valid length for deposit contract).
    function _fakeSignature(uint256 seed) internal pure returns (bytes memory) {
        return abi.encodePacked(sha256(abi.encode("sig", seed)), sha256(abi.encode("sig2", seed)), bytes32(0));
    }

    /// @dev Build an initial Deposit with properly-sized fields. BLS verification path runs.
    function _makeDeposit(uint256 opIdx, uint256 seed) internal pure returns (IDepositDataBuffer.Deposit memory) {
        return IDepositDataBuffer.Deposit({
            pubkey: _fakePubkey(seed),
            signature: _fakeSignature(seed),
            amount: 32 ether,
            operatorIdx: opIdx,
            depositY: _nonZeroDepositY(seed)
        });
    }

    /// @dev Build a TopUp. BLS verification path skipped; pubkey must already be in
    ///      `PectraValidatorPubkeyLookup`. No signature field — consumer hardcodes 96 zero bytes.
    function _makeTopUpDeposit(uint256 opIdx, uint256 seed) internal pure returns (IDepositDataBuffer.TopUp memory) {
        return IDepositDataBuffer.TopUp({pubkey: _fakePubkey(seed), amount: 32 ether, operatorIdx: opIdx});
    }

    function _seedPrePectraValidator(uint256 operatorIdx, uint256 keyIndex, uint256 seed)
        internal
        returns (bytes memory)
    {
        bytes memory pubkey = _fakePubkey(seed);
        prePectraRegistry.setPrePectraValidatorPubkey(operatorIdx, keyIndex, pubkey);
        return pubkey;
    }

    /// @dev Convenience: build a DepositObject from a Deposit[] (no top-ups).
    function _batchOf(IDepositDataBuffer.Deposit[] memory deposits)
        internal
        pure
        returns (IDepositDataBuffer.DepositObject memory batch)
    {
        batch.deposits = deposits;
        // batch.topUps stays default-initialized as an empty array
    }

    /// @dev Convenience: build a DepositObject from a TopUp[] (no initial deposits).
    function _batchOfTopUps(IDepositDataBuffer.TopUp[] memory topUps)
        internal
        pure
        returns (IDepositDataBuffer.DepositObject memory batch)
    {
        batch.topUps = topUps;
    }

    /// @dev Convenience: build a DepositObject from both arrays.
    function _batchOf(IDepositDataBuffer.Deposit[] memory deposits, IDepositDataBuffer.TopUp[] memory topUps)
        internal
        pure
        returns (IDepositDataBuffer.DepositObject memory batch)
    {
        batch.deposits = deposits;
        batch.topUps = topUps;
    }

    /// @dev Sign an EIP-712 attestation digest with the given private key.
    ///      Note: verifyingContract is the harness (River), NOT the validator.
    function _signAttestation(uint256 pk, bytes32 bufferId, bytes32 rootHash) internal view returns (bytes memory) {
        bytes32 domainSep =
            keccak256(abi.encode(EIP712_DOMAIN_TYPEHASH, NAME_HASH, VERSION_HASH, block.chainid, address(dm)));
        bytes32 structHash = keccak256(abi.encode(ATTEST_TYPEHASH, bufferId, rootHash));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSep, structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
        return abi.encodePacked(r, s, v);
    }

    /// @dev Submit a prebuilt batch to buffer, sign attestations, and return calldata.
    function _prepareDeposit(IDepositDataBuffer.DepositObject memory batch)
        internal
        returns (bytes32 bufferId, bytes32 rootHash, bytes[] memory sigs)
    {
        bufferId = keccak256(abi.encode(batch));
        buffer.submitDepositData(bufferId, batch);

        rootHash = depositContract.get_deposit_root();

        sigs = new bytes[](2);
        sigs[0] = _signAttestation(rootAttesterPk1, bufferId, rootHash);
        sigs[1] = _signAttestation(rootAttesterPk2, bufferId, rootHash);
    }

    /// @dev Submit an initial-deposits-only batch.
    function _prepareDeposit(IDepositDataBuffer.Deposit[] memory deposits)
        internal
        returns (bytes32 bufferId, bytes32 rootHash, bytes[] memory sigs)
    {
        return _prepareDeposit(_batchOf(deposits));
    }

    /// @dev Submit a mixed batch (initials + top-ups).
    function _prepareDeposit(IDepositDataBuffer.Deposit[] memory deposits, IDepositDataBuffer.TopUp[] memory topUps)
        internal
        returns (bytes32 bufferId, bytes32 rootHash, bytes[] memory sigs)
    {
        return _prepareDeposit(_batchOf(deposits, topUps));
    }

    /// @dev Submit a top-ups-only batch.
    function _prepareTopUps(IDepositDataBuffer.TopUp[] memory topUps)
        internal
        returns (bytes32 bufferId, bytes32 rootHash, bytes[] memory sigs)
    {
        return _prepareDeposit(_batchOfTopUps(topUps));
    }

    // -----------------------------------------------------------------------
    // Happy-path tests
    // -----------------------------------------------------------------------

    function testSuccessfulDeposit_threeDeposits_twoOperators() public {
        // Arrange: 3 deposits — 2 for operator 0, 1 for operator 1
        IDepositDataBuffer.Deposit[] memory deposits = new IDepositDataBuffer.Deposit[](3);
        deposits[0] = _makeDeposit(0, 10);
        deposits[1] = _makeDeposit(0, 11);
        deposits[2] = _makeDeposit(1, 20);

        (bytes32 bufferId, bytes32 rootHash, bytes[] memory sigs) = _prepareDeposit(deposits);

        // Expect: FundedValidatorKeys for operator 0 with 2 keys
        bytes[] memory op0Keys = new bytes[](2);
        op0Keys[0] = deposits[0].pubkey;
        op0Keys[1] = deposits[1].pubkey;
        vm.expectEmit(true, false, false, true);
        emit FundedValidatorKeys(0, op0Keys, false);

        // Expect: FundedValidatorKeys for operator 1 with 1 key
        bytes[] memory op1Keys = new bytes[](1);
        op1Keys[0] = deposits[2].pubkey;
        vm.expectEmit(true, false, false, true);
        emit FundedValidatorKeys(1, op1Keys, false);

        // Expect: balance events
        vm.expectEmit(true, true, false, true);
        emit SetInFlightETH(0, 96 ether);
        vm.expectEmit(true, true, false, true);
        emit SetTotalDepositedETH(0, 96 ether);

        // Act
        vm.prank(keeper);
        dm.depositToConsensusLayerWithAttestation(bufferId, rootHash, sigs);

        // Assert: balances
        assertEq(dm.getCommittedBalance(), 32 ether, "committed balance should decrease by 96 ETH");
        assertEq(dm.getTotalDepositedETH(), 96 ether, "total deposited should be 96 ETH");
        assertEq(address(dm).balance, 32 ether, "ETH balance should decrease by 96 ETH");

        // Assert: funded ETH per operator
        assertEq(dm.lastFundedETH(0), 64 ether, "operator 0 funded 64 ETH");
        assertEq(dm.lastFundedETH(1), 32 ether, "operator 1 funded 32 ETH");

        // Assert: deposit contract received 3 deposits
        assertEq(depositContract.deposit_count(), 3, "deposit contract should have 3 deposits");
    }

    function testSuccessfulDeposit_singleDeposit_nonZeroOperator() public {
        IDepositDataBuffer.Deposit[] memory deposits = new IDepositDataBuffer.Deposit[](1);
        deposits[0] = _makeDeposit(5, 42);

        (bytes32 bufferId, bytes32 rootHash, bytes[] memory sigs) = _prepareDeposit(deposits);

        // Expect: FundedValidatorKeys for operator 5
        bytes[] memory opKeys = new bytes[](1);
        opKeys[0] = deposits[0].pubkey;
        vm.expectEmit(true, false, false, true);
        emit FundedValidatorKeys(5, opKeys, false);

        vm.prank(keeper);
        dm.depositToConsensusLayerWithAttestation(bufferId, rootHash, sigs);

        assertEq(dm.getCommittedBalance(), 96 ether);
        assertEq(dm.getTotalDepositedETH(), 32 ether);
        assertEq(dm.lastFundedETH(5), 32 ether);
        assertEq(depositContract.deposit_count(), 1);
    }

    function testSuccessfulDeposit_depositRootAdvancesPerDeposit() public {
        // First batch
        IDepositDataBuffer.Deposit[] memory batch1 = new IDepositDataBuffer.Deposit[](1);
        batch1[0] = _makeDeposit(0, 100);

        (bytes32 bid1, bytes32 root1, bytes[] memory sigs1) = _prepareDeposit(batch1);

        vm.prank(keeper);
        dm.depositToConsensusLayerWithAttestation(bid1, root1, sigs1);

        bytes32 rootAfterFirst = depositContract.get_deposit_root();
        assertTrue(rootAfterFirst != root1, "deposit root should change after deposit");

        // Second batch — must use updated root
        IDepositDataBuffer.Deposit[] memory batch2 = new IDepositDataBuffer.Deposit[](1);
        batch2[0] = _makeDeposit(1, 200);

        bytes32 bid2 = keccak256(abi.encode(_batchOf(batch2)));
        buffer.submitDepositData(bid2, _batchOf(batch2));

        bytes32 root2 = depositContract.get_deposit_root();
        assertEq(root2, rootAfterFirst, "root hash should match current deposit contract state");

        bytes[] memory sigs2 = new bytes[](2);
        sigs2[0] = _signAttestation(rootAttesterPk1, bid2, root2);
        sigs2[1] = _signAttestation(rootAttesterPk2, bid2, root2);

        vm.prank(keeper);
        dm.depositToConsensusLayerWithAttestation(bid2, root2, sigs2);

        assertEq(depositContract.deposit_count(), 2, "should have 2 total deposits");
        assertEq(dm.getTotalDepositedETH(), 64 ether);
        assertEq(dm.getCommittedBalance(), 64 ether);
    }

    // -----------------------------------------------------------------------
    // Revert tests
    // -----------------------------------------------------------------------

    function testRevert_notKeeper() public {
        vm.prank(address(0x999));
        vm.expectRevert(IConsensusLayerDepositManagerV1.OnlyKeeper.selector);
        dm.depositToConsensusLayerWithAttestation(bytes32(0), bytes32(0), new bytes[](0));
    }

    function testRevert_zeroWithdrawalCredentials() public {
        // Zero out the harness WC via vm.store (the setter rejects zero)
        bytes32 wcSlot = bytes32(uint256(keccak256("river.state.withdrawalCredentials")) - 1);
        vm.store(address(dm), wcSlot, bytes32(0));

        vm.prank(keeper);
        vm.expectRevert(IConsensusLayerDepositManagerV1.InvalidWithdrawalCredentials.selector);
        dm.depositToConsensusLayerWithAttestation(bytes32(0), bytes32(0), new bytes[](0));
    }

    function testRevert_insufficientAttestations() public {
        IDepositDataBuffer.Deposit[] memory deposits = new IDepositDataBuffer.Deposit[](1);
        deposits[0] = _makeDeposit(0, 0);

        bytes32 bufferId = keccak256(abi.encode(_batchOf(deposits)));
        buffer.submitDepositData(bufferId, _batchOf(deposits));

        bytes32 rootHash = depositContract.get_deposit_root();

        // Only 1 signature but quorum is 2
        bytes[] memory sigs = new bytes[](1);
        sigs[0] = _signAttestation(rootAttesterPk1, bufferId, rootHash);

        vm.prank(keeper);
        vm.expectRevert(abi.encodeWithSelector(IAttestationVerifierV1.InsufficientAttestations.selector, 1, 2));
        dm.depositToConsensusLayerWithAttestation(bufferId, rootHash, sigs);
    }

    function testRevert_staleDepositRoot() public {
        IDepositDataBuffer.Deposit[] memory deposits = new IDepositDataBuffer.Deposit[](1);
        deposits[0] = _makeDeposit(0, 0);

        bytes32 bufferId = keccak256(abi.encode(_batchOf(deposits)));
        buffer.submitDepositData(bufferId, _batchOf(deposits));

        // Sign over a stale root that won't match the deposit contract
        bytes32 staleRoot = bytes32(uint256(0xDEAD));
        bytes[] memory sigs = new bytes[](2);
        sigs[0] = _signAttestation(rootAttesterPk1, bufferId, staleRoot);
        sigs[1] = _signAttestation(rootAttesterPk2, bufferId, staleRoot);

        bytes32 actualRoot = depositContract.get_deposit_root();
        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSelector(IAttestationVerifierV1.DepositRootMismatch.selector, staleRoot, actualRoot)
        );
        dm.depositToConsensusLayerWithAttestation(bufferId, staleRoot, sigs);
    }

    function testRevert_notEnoughFunds() public {
        dm.sudoSetCommittedBalance(32 ether);

        IDepositDataBuffer.Deposit[] memory deposits = new IDepositDataBuffer.Deposit[](2);
        deposits[0] = _makeDeposit(0, 0);
        deposits[1] = _makeDeposit(0, 1);

        (bytes32 bufferId, bytes32 rootHash, bytes[] memory sigs) = _prepareDeposit(deposits);

        vm.prank(keeper);
        vm.expectRevert(IAttestationVerifierV1.NotEnoughFunds.selector);
        dm.depositToConsensusLayerWithAttestation(bufferId, rootHash, sigs);
    }

    function testRevert_duplicateRootAttesterSignatures() public {
        IDepositDataBuffer.Deposit[] memory deposits = new IDepositDataBuffer.Deposit[](1);
        deposits[0] = _makeDeposit(0, 0);

        bytes32 bufferId = keccak256(abi.encode(_batchOf(deposits)));
        buffer.submitDepositData(bufferId, _batchOf(deposits));
        bytes32 rootHash = depositContract.get_deposit_root();

        // Two signatures from the same root attester — should only count as 1
        bytes[] memory sigs = new bytes[](2);
        sigs[0] = _signAttestation(rootAttesterPk1, bufferId, rootHash);
        sigs[1] = _signAttestation(rootAttesterPk1, bufferId, rootHash);

        vm.prank(keeper);
        vm.expectRevert(abi.encodeWithSelector(IAttestationVerifierV1.InsufficientAttestations.selector, 1, 2));
        dm.depositToConsensusLayerWithAttestation(bufferId, rootHash, sigs);
    }

    function testRevert_nonRootAttesterSignature() public {
        IDepositDataBuffer.Deposit[] memory deposits = new IDepositDataBuffer.Deposit[](1);
        deposits[0] = _makeDeposit(0, 0);

        bytes32 bufferId = keccak256(abi.encode(_batchOf(deposits)));
        buffer.submitDepositData(bufferId, _batchOf(deposits));
        bytes32 rootHash = depositContract.get_deposit_root();

        // One valid root attester + one non-attester
        uint256 nonRootAttesterPk = 0xBAD;
        bytes[] memory sigs = new bytes[](2);
        sigs[0] = _signAttestation(rootAttesterPk1, bufferId, rootHash);
        sigs[1] = _signAttestation(nonRootAttesterPk, bufferId, rootHash);

        vm.prank(keeper);
        vm.expectRevert(abi.encodeWithSelector(IAttestationVerifierV1.InsufficientAttestations.selector, 1, 2));
        dm.depositToConsensusLayerWithAttestation(bufferId, rootHash, sigs);
    }

    // Regression test for the defense-in-depth bufferId check in validateDeposits().
    // A malicious or buggy DepositDataBuffer may store (id, deposits) where
    // id != keccak256(abi.encode(deposits)). The on-chain validator must catch this
    // and revert with BufferIdMismatch so the root attesters' signed commitment is
    // always binding on the deposits that are actually executed.
    function testRevert_bufferIdDoesNotMatchDeposits() public {
        IDepositDataBuffer.Deposit[] memory depositsSigned = new IDepositDataBuffer.Deposit[](1);
        depositsSigned[0] = _makeDeposit(0, 1);

        IDepositDataBuffer.Deposit[] memory depositsActual = new IDepositDataBuffer.Deposit[](1);
        depositsActual[0] = _makeDeposit(0, 999); // different pubkey seed

        bytes32 signedId = keccak256(abi.encode(_batchOf(depositsSigned)));
        bytes32 actualId = keccak256(abi.encode(_batchOf(depositsActual)));
        assertTrue(signedId != actualId, "test precondition: the two batches must hash differently");

        // Malicious buffer: store `depositsActual` under `signedId`.
        buffer.submitDepositData(signedId, _batchOf(depositsActual));

        bytes32 rootHash = depositContract.get_deposit_root();
        bytes[] memory sigs = new bytes[](2);
        sigs[0] = _signAttestation(rootAttesterPk1, signedId, rootHash);
        sigs[1] = _signAttestation(rootAttesterPk2, signedId, rootHash);

        vm.prank(keeper);
        vm.expectRevert(abi.encodeWithSelector(IAttestationVerifierV1.BufferIdMismatch.selector, signedId, actualId));
        dm.depositToConsensusLayerWithAttestation(signedId, rootHash, sigs);
    }

    // An uninitialized cached EIP-712 domain separator must never be used — bytes32(0) would
    // let any signer produce a "valid" digest that ECDSA cannot tell apart from real ones.
    function testRevert_zeroDomainSeparator() public {
        // Domain separator now lives on the validator's storage.
        vm.store(address(validator), VALIDATOR_DOMAIN_SEPARATOR_SLOT, bytes32(0));

        IDepositDataBuffer.Deposit[] memory deposits = new IDepositDataBuffer.Deposit[](1);
        deposits[0] = _makeDeposit(0, 0);
        (bytes32 bufferId, bytes32 rootHash, bytes[] memory sigs) = _prepareDeposit(deposits);

        vm.prank(keeper);
        vm.expectRevert(IAttestationVerifierV1.ZeroDomainSeparator.selector);
        dm.depositToConsensusLayerWithAttestation(bufferId, rootHash, sigs);
    }

    /// @dev The setter rejects a zero root quorum, but validateDeposits() also defends
    ///      against corrupted/uninitialized quorum storage. With a zero quorum, a batch
    ///      could otherwise pass with no meaningful root-attester approval.
    function testRevert_validate_zeroRootQuorumStorage() public {
        vm.store(address(validator), VALIDATOR_ROOT_ATTESTATION_QUORUM_SLOT, bytes32(0));

        IDepositDataBuffer.Deposit[] memory deposits = new IDepositDataBuffer.Deposit[](1);
        deposits[0] = _makeDeposit(0, 901);
        bytes32 bufferId = keccak256(abi.encode(_batchOf(deposits)));
        buffer.submitDepositData(bufferId, _batchOf(deposits));
        bytes32 rootHash = depositContract.get_deposit_root();

        bytes[] memory sigs = new bytes[](2);
        sigs[0] = _signAttestation(rootAttesterPk1, bufferId, rootHash);
        sigs[1] = _signAttestation(rootAttesterPk2, bufferId, rootHash);

        vm.prank(keeper);
        vm.expectRevert(IAttestationVerifierV1.ZeroQuorum.selector);
        dm.depositToConsensusLayerWithAttestation(bufferId, rootHash, sigs);
    }

    // verifyBLSDeposit is only callable via the internal self-staticcall trampoline in
    // _verifyBLSSignatures. Any external caller must hit the OnlySelfCall guard so future
    // additions of state or events to this function cannot become world-callable. The
    // ZeroDepositDomain path is exercised via the proper validateDeposits() flow in
    // testInitial_blsPathReached_revertsOnZeroDepositDomain below.
    function testRevert_verifyBLSDeposit_onlySelfCall() public {
        // Un-mock so the real function body and its guard run.
        vm.clearMockedCalls();

        bytes memory pk = _fakePubkey(0);
        bytes memory sig = _fakeSignature(0);
        BLS12_381.DepositY memory dy = _emptyDepositY();

        vm.expectRevert(IAttestationVerifierV1.OnlySelfCall.selector);
        validator.verifyBLSDeposit(pk, sig, 32 ether, dy, withdrawalCredentials);
    }

    /// @dev Once the cheap checks and root-attester quorum pass, initial deposits must enter
    ///      the real BLS verifier. This clears the BLS success mock and supplies a 48-byte
    ///      pubkey with invalid compression flags, proving the verifier call is reached and
    ///      its revert is bubbled back through validateDeposits().
    function testRevert_initialBLSVerifierRejectsInvalidCompressedPubkey() public {
        vm.clearMockedCalls();

        IDepositDataBuffer.Deposit[] memory deposits = new IDepositDataBuffer.Deposit[](1);
        deposits[0] = _makeDeposit(0, 902);
        deposits[0].pubkey[0] = bytes1(uint8(0)); // invalid compressed BLS component header

        (bytes32 bufferId, bytes32 rootHash, bytes[] memory sigs) = _prepareDeposit(deposits);

        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSelector(BLS12_381.InvalidCompressedComponent.selector, BLS12_381.Component.PubKey)
        );
        dm.depositToConsensusLayerWithAttestation(bufferId, rootHash, sigs);
    }

    // -----------------------------------------------------------------------
    // Top-up tests — BLS verification must be skipped for entries with all-zero depositY.
    // Authorization for top-ups is delegated to the root (the attestation
    // quorum signs over keccak256(abi.encode(deposits)), so the root attesters are
    // attesting to each entry's depositY-encoded classification).
    // -----------------------------------------------------------------------

    // Top-up entries must never enter the BLS verification path. Proven here by zeroing
    // the cached deposit domain on the validator: if the path were entered, the real
    // verifyBLSDeposit body would short-circuit with ZeroDepositDomain. The BLS success
    // mock is cleared first so the real code runs.
    function testTopUp_skipsBLSVerification() public {
        vm.clearMockedCalls();
        vm.store(address(validator), VALIDATOR_DEPOSIT_DOMAIN_SLOT, bytes32(0));

        IDepositDataBuffer.TopUp[] memory topUps = new IDepositDataBuffer.TopUp[](2);
        topUps[0] = _makeTopUpDeposit(0, 50);
        topUps[1] = _makeTopUpDeposit(1, 51);

        // Seed the mapping so the top-up membership check passes; without it the call
        // would revert with TopUpPubkeyNotFunded before reaching the BLS branch.
        _seedFundedPubkey(topUps[0].pubkey);
        _seedFundedPubkey(topUps[1].pubkey);

        (bytes32 bufferId, bytes32 rootHash, bytes[] memory sigs) = _prepareTopUps(topUps);

        vm.prank(keeper);
        dm.depositToConsensusLayerWithAttestation(bufferId, rootHash, sigs);

        assertEq(depositContract.deposit_count(), 2);
        assertEq(dm.lastFundedETH(0), 32 ether);
        assertEq(dm.lastFundedETH(1), 32 ether);
        assertEq(dm.getTotalDepositedETH(), 64 ether);
    }

    // The inverse: under the same zeroed-domain setup, an initial deposit (non-zero depositY)
    // must enter the real BLS path and revert with ZeroDepositDomain. Proves the gate is
    // default-deny on the depositY-encoded classification and that the BLS path is reached.
    function testInitial_blsPathReached_revertsOnZeroDepositDomain() public {
        vm.clearMockedCalls();
        vm.store(address(validator), VALIDATOR_DEPOSIT_DOMAIN_SLOT, bytes32(0));

        IDepositDataBuffer.Deposit[] memory deposits = new IDepositDataBuffer.Deposit[](1);
        deposits[0] = _makeDeposit(0, 60);

        (bytes32 bufferId, bytes32 rootHash, bytes[] memory sigs) = _prepareDeposit(deposits);

        vm.prank(keeper);
        vm.expectRevert(IAttestationVerifierV1.ZeroDepositDomain.selector);
        dm.depositToConsensusLayerWithAttestation(bufferId, rootHash, sigs);
    }

    // Mixed batch: a single initial deposit hitting the failing BLS path must reject the
    // entire batch, even when paired with top-ups that would otherwise pass.
    function testMixed_initialFailure_rejectsWholeBatch() public {
        vm.clearMockedCalls();
        vm.store(address(validator), VALIDATOR_DEPOSIT_DOMAIN_SLOT, bytes32(0));

        IDepositDataBuffer.Deposit[] memory deposits = new IDepositDataBuffer.Deposit[](1);
        deposits[0] = _makeDeposit(1, 71); // initial — BLS path entered, reverts on zero domain
        IDepositDataBuffer.TopUp[] memory topUps = new IDepositDataBuffer.TopUp[](1);
        topUps[0] = _makeTopUpDeposit(0, 70);

        // Seed only the top-up's pubkey: the initial entry must still reach the BLS path
        // so we can assert the batch is rejected on its failure (not on the top-up's
        // membership check).
        _seedFundedPubkey(topUps[0].pubkey);

        (bytes32 bufferId, bytes32 rootHash, bytes[] memory sigs) = _prepareDeposit(deposits, topUps);

        vm.prank(keeper);
        vm.expectRevert(IAttestationVerifierV1.ZeroDepositDomain.selector);
        dm.depositToConsensusLayerWithAttestation(bufferId, rootHash, sigs);
    }

    // The bufferId binding (keccak256(abi.encode(batch))) must cover the container shape:
    // a batch attested as N initials must not be reusable against a shape with one of those
    // initials downgraded to a top-up. Under the new types, initials and top-ups live in
    // disjoint arrays in DepositObject, so this is structurally enforced by the keccak of
    // the container — tampering with classification flips array membership, which flips
    // the hash.
    function testRevert_bufferIdMismatch_isTopUpTampered() public {
        // Signed batch: 1 initial deposit for operator 0.
        IDepositDataBuffer.Deposit[] memory depositsSigned = new IDepositDataBuffer.Deposit[](1);
        depositsSigned[0] = _makeDeposit(0, 80);

        // Tampered batch: same pubkey content moved to the top-ups array.
        IDepositDataBuffer.TopUp[] memory topUpsActual = new IDepositDataBuffer.TopUp[](1);
        topUpsActual[0] = _makeTopUpDeposit(0, 80);

        bytes32 signedId = keccak256(abi.encode(_batchOf(depositsSigned)));
        bytes32 actualId = keccak256(abi.encode(_batchOfTopUps(topUpsActual)));
        assertTrue(signedId != actualId, "test precondition: moving entry between arrays must change the bufferId");

        // Malicious buffer: store the top-up version under the initial-deposit's signedId.
        buffer.submitDepositData(signedId, _batchOfTopUps(topUpsActual));

        bytes32 rootHash = depositContract.get_deposit_root();
        bytes[] memory sigs = new bytes[](2);
        sigs[0] = _signAttestation(rootAttesterPk1, signedId, rootHash);
        sigs[1] = _signAttestation(rootAttesterPk2, signedId, rootHash);

        vm.prank(keeper);
        vm.expectRevert(abi.encodeWithSelector(IAttestationVerifierV1.BufferIdMismatch.selector, signedId, actualId));
        dm.depositToConsensusLayerWithAttestation(signedId, rootHash, sigs);
    }

    // Top-ups must still count toward the operator's fundedETH and appear in newPublicKeys
    // exactly like initial deposits — LibFundingDeltas has no branch on deposit kind.
    function testTopUp_fundingDeltas_accountIdenticallyToInitials() public {
        // Mock from setUp() is still active: BLS verification succeeds for the initial deposit.

        IDepositDataBuffer.Deposit[] memory deposits = new IDepositDataBuffer.Deposit[](1);
        deposits[0] = _makeDeposit(0, 90); // initial
        IDepositDataBuffer.TopUp[] memory topUps = new IDepositDataBuffer.TopUp[](1);
        topUps[0] = _makeTopUpDeposit(0, 91); // top-up for same operator

        // Seed the top-up's pubkey so the membership check passes; the initial entry will
        // populate the mapping for seed 90 via the real recordNewlyFundedPubkeys callback.
        _seedFundedPubkey(topUps[0].pubkey);

        (bytes32 bufferId, bytes32 rootHash, bytes[] memory sigs) = _prepareDeposit(deposits, topUps);

        bytes[] memory opKeys = new bytes[](2);
        opKeys[0] = deposits[0].pubkey;
        opKeys[1] = topUps[0].pubkey;
        vm.expectEmit(true, false, false, true);
        emit FundedValidatorKeys(0, opKeys, false);

        vm.prank(keeper);
        dm.depositToConsensusLayerWithAttestation(bufferId, rootHash, sigs);

        assertEq(dm.lastFundedETH(0), 64 ether, "both initial and top-up bump fundedETH");
        assertEq(depositContract.deposit_count(), 2);
    }

    // -----------------------------------------------------------------------
    // Option 5 — on-chain pubkey-ownership check for top-ups
    // -----------------------------------------------------------------------

    /// @dev Top-up to a pubkey that's not in the initial-deposit mapping must revert. This
    ///      is the defense-in-depth check against malicious root attesters marking an attacker
    ///      pubkey as a top-up to bypass BLS verification.
    function testTopUp_pubkeyNotFunded_reverts() public {
        IDepositDataBuffer.TopUp[] memory topUps = new IDepositDataBuffer.TopUp[](1);
        topUps[0] = _makeTopUpDeposit(0, 100);

        (bytes32 bufferId, bytes32 rootHash, bytes[] memory sigs) = _prepareTopUps(topUps);

        vm.prank(keeper);
        vm.expectRevert(abi.encodeWithSelector(IAttestationVerifierV1.TopUpPubkeyNotFunded.selector, topUps[0].pubkey));
        dm.depositToConsensusLayerWithAttestation(bufferId, rootHash, sigs);
    }

    /// @dev A successful initial deposit must record the pubkey in the lookup and emit
    ///      `PubkeyFunded`. Future top-ups against this pubkey will then pass the
    ///      membership check.
    function testPubkeyFunded_recordsPubkey() public {
        uint256 operatorIdx = 4;
        IDepositDataBuffer.Deposit[] memory deposits = new IDepositDataBuffer.Deposit[](1);
        deposits[0] = _makeDeposit(operatorIdx, 110);

        (bytes32 bufferId, bytes32 rootHash, bytes[] memory sigs) = _prepareDeposit(deposits);

        vm.expectEmit(true, true, false, true);
        emit PubkeyFunded(bufferId, operatorIdx, deposits[0].pubkey, deposits[0].amount);

        vm.prank(keeper);
        dm.depositToConsensusLayerWithAttestation(bufferId, rootHash, sigs);

        assertTrue(validator.isPubkeyFunded(deposits[0].pubkey), "pubkey should be in the lookup");
    }

    /// @dev End-to-end: an initial deposit in batch A records the pubkey; a top-up for that
    ///      same pubkey in batch B passes the membership check and executes.
    function testTopUp_succeedsAfterFundedInPriorBatch() public {
        // Batch A — initial deposit for pubkey X.
        IDepositDataBuffer.Deposit[] memory batchA = new IDepositDataBuffer.Deposit[](1);
        batchA[0] = _makeDeposit(0, 120);
        (bytes32 bidA, bytes32 rootA, bytes[] memory sigsA) = _prepareDeposit(batchA);

        vm.prank(keeper);
        dm.depositToConsensusLayerWithAttestation(bidA, rootA, sigsA);
        assertTrue(validator.isPubkeyFunded(batchA[0].pubkey));

        // Batch B — top-up for the same pubkey X. Must succeed.
        IDepositDataBuffer.TopUp[] memory batchB = new IDepositDataBuffer.TopUp[](1);
        batchB[0] = _makeTopUpDeposit(0, 120); // same seed → same pubkey

        bytes32 bidB = keccak256(abi.encode(_batchOfTopUps(batchB)));
        buffer.submitDepositData(bidB, _batchOfTopUps(batchB));

        bytes32 rootB = depositContract.get_deposit_root();
        bytes[] memory sigsB = new bytes[](2);
        sigsB[0] = _signAttestation(rootAttesterPk1, bidB, rootB);
        sigsB[1] = _signAttestation(rootAttesterPk2, bidB, rootB);

        vm.prank(keeper);
        dm.depositToConsensusLayerWithAttestation(bidB, rootB, sigsB);

        assertEq(depositContract.deposit_count(), 2, "both deposits executed");
        assertEq(dm.getTotalDepositedETH(), 64 ether, "total deposited reflects both initial and top-up");
    }

    function testMigratePrePectraValidatorPubkeys_adminMigratesRangeAndIsIdempotent() public {
        uint256 operatorIdx = 7;
        prePectraRegistry.setPrePectraFundedValidatorCount(operatorIdx, 4);
        bytes memory pk1 = _seedPrePectraValidator(operatorIdx, 1, 610);
        bytes memory pk2 = _seedPrePectraValidator(operatorIdx, 2, 611);

        assertFalse(validator.isPubkeyFunded(pk1), "precondition key 1");
        assertFalse(validator.isPubkeyFunded(pk2), "precondition key 2");

        vm.expectEmit(true, false, false, true);
        emit MigratedPrePectraValidatorPubkeys(operatorIdx, 1, 3);

        vm.prank(admin);
        validator.migratePrePectraValidatorPubkeys(operatorIdx, 1, 3);

        assertTrue(validator.isPrePectraValidatorPubkeyFunded(pk1), "migrated pre-Pectra key 1");
        assertTrue(validator.isPrePectraValidatorPubkeyFunded(pk2), "migrated pre-Pectra key 2");
        assertFalse(validator.isPubkeyFunded(pk1), "migrated key 1 not runtime-funded");
        assertFalse(validator.isPubkeyFunded(pk2), "migrated key 2 not runtime-funded");

        vm.prank(admin);
        validator.migratePrePectraValidatorPubkeys(operatorIdx, 1, 3);

        assertTrue(validator.isPrePectraValidatorPubkeyFunded(pk1), "remigrated pre-Pectra key 1");
        assertTrue(validator.isPrePectraValidatorPubkeyFunded(pk2), "remigrated pre-Pectra key 2");
        assertFalse(validator.isPubkeyFunded(pk1), "remigrated key 1 not runtime-funded");
        assertFalse(validator.isPubkeyFunded(pk2), "remigrated key 2 not runtime-funded");
    }

    function testMigratePrePectraValidatorPubkeys_revertsWhenUnauthorized() public {
        address stranger = makeAddr("stranger");

        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.Unauthorized.selector, stranger));
        validator.migratePrePectraValidatorPubkeys(0, 0, 1);
    }

    function testMigratePrePectraValidatorPubkeys_revertsWhenMigratedPubkeyLengthInvalid() public {
        uint256 operatorIdx = 4;
        prePectraRegistry.setPrePectraFundedValidatorCount(operatorIdx, 1);
        prePectraRegistry.setPrePectraValidatorPubkey(operatorIdx, 0, hex"1234");

        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAttestationVerifierV1.InvalidPrePectraMigrationPubkeyLength.selector, operatorIdx, 0, 2
            )
        );
        validator.migratePrePectraValidatorPubkeys(operatorIdx, 0, 1);
    }

    function testValidateSelfConsolidation_riverBuildsOneSelfRequestPerMigratedPubkey() public {
        uint256 operatorIdx = 8;
        prePectraRegistry.setPrePectraFundedValidatorCount(operatorIdx, 2);
        bytes memory pk0 = _seedPrePectraValidator(operatorIdx, 0, 650);
        bytes memory pk1 = _seedPrePectraValidator(operatorIdx, 1, 651);

        vm.prank(admin);
        validator.migratePrePectraValidatorPubkeys(operatorIdx, 0, 2);

        bytes[] memory pubkeys = new bytes[](2);
        pubkeys[0] = pk0;
        pubkeys[1] = pk1;

        vm.expectEmit(false, false, false, true);
        emit RemovedPrePectraValidatorPubkeys(pubkeys);
        vm.expectEmit(false, false, false, true);
        emit AddedPectraValidatorPubkeys(pubkeys);

        vm.prank(address(dm));
        IWithdrawV1.ConsolidationRequest[] memory requests = validator.validateSelfConsolidation(pubkeys);

        assertEq(requests.length, 2, "request count");
        assertEq(requests[0].srcPubkeys.length, 1, "request 0 source count");
        assertEq(requests[0].srcPubkeys[0], pk0, "request 0 source");
        assertEq(requests[0].targetPubkey, pk0, "request 0 target");
        assertEq(requests[1].srcPubkeys.length, 1, "request 1 source count");
        assertEq(requests[1].srcPubkeys[0], pk1, "request 1 source");
        assertEq(requests[1].targetPubkey, pk1, "request 1 target");

        assertFalse(validator.isPrePectraValidatorPubkeyFunded(pk0), "pk0 cleared from pre-Pectra");
        assertFalse(validator.isPrePectraValidatorPubkeyFunded(pk1), "pk1 cleared from pre-Pectra");
        assertTrue(validator.isPubkeyFunded(pk0), "pk0 added to post-Pectra");
        assertTrue(validator.isPubkeyFunded(pk1), "pk1 added to post-Pectra");
    }

    function testValidateSelfConsolidation_revertsWhenCallerNotRiver() public {
        uint256 operatorIdx = 9;
        prePectraRegistry.setPrePectraFundedValidatorCount(operatorIdx, 1);
        bytes memory pubkey = _seedPrePectraValidator(operatorIdx, 0, 652);

        vm.prank(admin);
        validator.migratePrePectraValidatorPubkeys(operatorIdx, 0, 1);

        bytes[] memory pubkeys = new bytes[](1);
        pubkeys[0] = pubkey;

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.Unauthorized.selector, admin));
        validator.validateSelfConsolidation(pubkeys);
    }

    function testValidateSelfConsolidation_revertsWhenBatchEmpty() public {
        bytes[] memory pubkeys = new bytes[](0);

        vm.prank(address(dm));
        vm.expectRevert(abi.encodeWithSelector(IAttestationVerifierV1.InvalidSelfConsolidationEmptyPubkeys.selector));
        validator.validateSelfConsolidation(pubkeys);
    }

    function testValidateSelfConsolidation_revertsWhenPubkeyLengthInvalid() public {
        bytes[] memory pubkeys = new bytes[](1);
        pubkeys[0] = hex"1234";

        vm.prank(address(dm));
        vm.expectRevert(
            abi.encodeWithSelector(
                IAttestationVerifierV1.InvalidSelfConsolidationPubkeyLength.selector, uint256(0), uint256(2)
            )
        );
        validator.validateSelfConsolidation(pubkeys);
    }

    function testValidateSelfConsolidation_revertsWhenPubkeyNotFunded() public {
        bytes memory pubkey = _fakePubkey(653);
        bytes[] memory pubkeys = new bytes[](1);
        pubkeys[0] = pubkey;

        vm.prank(address(dm));
        vm.expectRevert(
            abi.encodeWithSelector(IAttestationVerifierV1.PrePectraValidatorPubkeyNotFunded.selector, pubkey)
        );
        validator.validateSelfConsolidation(pubkeys);
    }

    function testRemovePrePectraValidatorPubkeys_adminRemovesSubsetAndEmits() public {
        uint256 operatorIdx = 5;
        prePectraRegistry.setPrePectraFundedValidatorCount(operatorIdx, 3);
        bytes memory pk0 = _seedPrePectraValidator(operatorIdx, 0, 630);
        bytes memory pk1 = _seedPrePectraValidator(operatorIdx, 1, 631);
        bytes memory pk2 = _seedPrePectraValidator(operatorIdx, 2, 632);

        vm.prank(admin);
        validator.migratePrePectraValidatorPubkeys(operatorIdx, 0, 3);

        assertTrue(validator.isPrePectraValidatorPubkeyFunded(pk0), "precondition key 0");
        assertTrue(validator.isPrePectraValidatorPubkeyFunded(pk1), "precondition key 1");
        assertTrue(validator.isPrePectraValidatorPubkeyFunded(pk2), "precondition key 2");

        bytes[] memory pubkeys = new bytes[](2);
        pubkeys[0] = pk0;
        pubkeys[1] = pk2;

        // Governance may need to roll back a partial migration. Removing a subset must
        // clear only the named pubkeys and leave unrelated migrated keys available.
        vm.expectEmit(false, false, false, true);
        emit RemovedPrePectraValidatorPubkeys(pubkeys);

        vm.prank(admin);
        validator.removePrePectraValidatorPubkeys(pubkeys);

        assertFalse(validator.isPrePectraValidatorPubkeyFunded(pk0), "removed key 0");
        assertTrue(validator.isPrePectraValidatorPubkeyFunded(pk1), "unremoved key 1");
        assertFalse(validator.isPrePectraValidatorPubkeyFunded(pk2), "removed key 2");
    }

    function testRemovePrePectraValidatorPubkeys_revertsWhenUnauthorized() public {
        address stranger = makeAddr("prePectraRemovalStranger");
        bytes[] memory pubkeys = new bytes[](1);
        pubkeys[0] = _fakePubkey(640);

        // The removal hook has the same governance blast radius as migration, so it must
        // use the River admin check instead of allowing arbitrary callers to clear keys.
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.Unauthorized.selector, stranger));
        validator.removePrePectraValidatorPubkeys(pubkeys);
    }

    function testRemovePrePectraValidatorPubkeys_revertsWhenBatchEmpty() public {
        bytes[] memory pubkeys = new bytes[](0);

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(IAttestationVerifierV1.InvalidPrePectraRemovalEmptyPubkeys.selector));
        validator.removePrePectraValidatorPubkeys(pubkeys);
    }

    function testRemovePrePectraValidatorPubkeys_revertsWhenPubkeyLengthInvalid() public {
        bytes[] memory pubkeys = new bytes[](1);
        pubkeys[0] = hex"1234";

        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAttestationVerifierV1.InvalidPrePectraRemovalPubkeyLength.selector, uint256(0), uint256(2)
            )
        );
        validator.removePrePectraValidatorPubkeys(pubkeys);
    }

    function testRemovePrePectraValidatorPubkeys_revertsWhenPubkeyNotFunded() public {
        bytes memory pubkey = _fakePubkey(641);
        bytes[] memory pubkeys = new bytes[](1);
        pubkeys[0] = pubkey;

        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(IAttestationVerifierV1.PrePectraValidatorPubkeyNotFunded.selector, pubkey)
        );
        validator.removePrePectraValidatorPubkeys(pubkeys);
    }

    function testTopUp_migratedPrePectraPubkeyStillRevertsInValidate() public {
        uint256 operatorIdx = 3;
        uint256 seed = 620;
        prePectraRegistry.setPrePectraFundedValidatorCount(operatorIdx, 1);
        bytes memory pubkey = _seedPrePectraValidator(operatorIdx, 0, seed);

        vm.prank(admin);
        validator.migratePrePectraValidatorPubkeys(operatorIdx, 0, 1);
        assertTrue(validator.isPrePectraValidatorPubkeyFunded(pubkey), "pre-Pectra lookup migration");
        assertFalse(validator.isPubkeyFunded(pubkey), "runtime lookup still empty");

        IDepositDataBuffer.TopUp[] memory topUps = new IDepositDataBuffer.TopUp[](1);
        topUps[0] = _makeTopUpDeposit(operatorIdx, seed);
        (bytes32 bufferId, bytes32 rootHash, bytes[] memory sigs) = _prepareTopUps(topUps);

        vm.prank(keeper);
        vm.expectRevert(abi.encodeWithSelector(IAttestationVerifierV1.TopUpPubkeyNotFunded.selector, topUps[0].pubkey));
        dm.depositToConsensusLayerWithAttestation(bufferId, rootHash, sigs);
    }

    /// @dev Re-using a processed `depositDataBufferId` must revert with `DepositDataBufferIdAlreadyProcessed`.
    function testRevert_replay_processedBufferId() public {
        IDepositDataBuffer.TopUp[] memory topUps = new IDepositDataBuffer.TopUp[](1);
        topUps[0] = _makeTopUpDeposit(0, 160);
        _seedFundedPubkey(topUps[0].pubkey);

        (bytes32 bufferId, bytes32 rootHash, bytes[] memory sigs) = _prepareTopUps(topUps);

        vm.prank(keeper);
        dm.depositToConsensusLayerWithAttestation(bufferId, rootHash, sigs);
        assertTrue(validator.isDepositDataBufferIdProcessed(bufferId), "id should be marked processed");

        uint256 depositCountBefore = depositContract.deposit_count();
        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSelector(IAttestationVerifierV1.DepositDataBufferIdAlreadyProcessed.selector, bufferId)
        );
        dm.depositToConsensusLayerWithAttestation(bufferId, rootHash, sigs);
        assertEq(
            depositContract.deposit_count(), depositCountBefore, "no deposit should reach the beacon contract on replay"
        );
    }

    /// @dev Re-using a processed `depositDataBufferId` from an initial-deposit-only batch
    ///      must revert with `DepositDataBufferIdAlreadyProcessed`.
    function testRevert_replay_processedBufferId_initialDeposit() public {
        IDepositDataBuffer.Deposit[] memory deposits = new IDepositDataBuffer.Deposit[](1);
        deposits[0] = _makeDeposit(0, 1);

        (bytes32 bufferId, bytes32 rootHash, bytes[] memory sigs) = _prepareDeposit(deposits);

        vm.prank(keeper);
        dm.depositToConsensusLayerWithAttestation(bufferId, rootHash, sigs);
        assertTrue(validator.isDepositDataBufferIdProcessed(bufferId), "id should be marked processed");

        uint256 depositCountBefore = depositContract.deposit_count();
        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSelector(IAttestationVerifierV1.DepositDataBufferIdAlreadyProcessed.selector, bufferId)
        );
        dm.depositToConsensusLayerWithAttestation(bufferId, rootHash, sigs);
        assertEq(
            depositContract.deposit_count(), depositCountBefore, "no deposit should reach the beacon contract on replay"
        );
    }

    /// @dev Re-using a processed `depositDataBufferId` from a mixed batch (one initial deposit
    ///      and one top-up against an unrelated funded pubkey) must revert with
    ///      `DepositDataBufferIdAlreadyProcessed`.
    function testRevert_replay_processedBufferId_mixedBatch() public {
        IDepositDataBuffer.Deposit[] memory deposits = new IDepositDataBuffer.Deposit[](1);
        deposits[0] = _makeDeposit(0, 1);
        IDepositDataBuffer.TopUp[] memory topUps = new IDepositDataBuffer.TopUp[](1);
        topUps[0] = _makeTopUpDeposit(0, 2);
        _seedFundedPubkey(topUps[0].pubkey);

        (bytes32 bufferId, bytes32 rootHash, bytes[] memory sigs) = _prepareDeposit(deposits, topUps);

        vm.prank(keeper);
        dm.depositToConsensusLayerWithAttestation(bufferId, rootHash, sigs);
        assertTrue(validator.isDepositDataBufferIdProcessed(bufferId), "id should be marked processed");

        uint256 depositCountBefore = depositContract.deposit_count();
        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSelector(IAttestationVerifierV1.DepositDataBufferIdAlreadyProcessed.selector, bufferId)
        );
        dm.depositToConsensusLayerWithAttestation(bufferId, rootHash, sigs);
        assertEq(
            depositContract.deposit_count(), depositCountBefore, "no deposit should reach the beacon contract on replay"
        );
    }

    /// @dev The step-0 processed-ID check has precedence over the attestation/rootHash check:
    ///      an attacker holding a quorum cannot bypass replay by re-signing the same bufferId
    ///      against a different rootHash. The replay must revert with
    ///      `DepositDataBufferIdAlreadyProcessed`, not `DepositRootMismatch` or a quorum error.
    function testRevert_replay_processedBufferId_differentRootHashAndSigs() public {
        IDepositDataBuffer.Deposit[] memory deposits = new IDepositDataBuffer.Deposit[](1);
        deposits[0] = _makeDeposit(0, 1);

        (bytes32 bufferId, bytes32 rootHash, bytes[] memory sigs) = _prepareDeposit(deposits);

        vm.prank(keeper);
        dm.depositToConsensusLayerWithAttestation(bufferId, rootHash, sigs);
        assertTrue(validator.isDepositDataBufferIdProcessed(bufferId), "id should be marked processed");

        bytes32 attackerRootHash = keccak256("attacker-chosen-root");
        bytes[] memory attackerSigs = new bytes[](2);
        attackerSigs[0] = _signAttestation(rootAttesterPk1, bufferId, attackerRootHash);
        attackerSigs[1] = _signAttestation(rootAttesterPk2, bufferId, attackerRootHash);

        uint256 depositCountBefore = depositContract.deposit_count();
        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSelector(IAttestationVerifierV1.DepositDataBufferIdAlreadyProcessed.selector, bufferId)
        );
        dm.depositToConsensusLayerWithAttestation(bufferId, attackerRootHash, attackerSigs);
        assertEq(
            depositContract.deposit_count(), depositCountBefore, "no deposit should reach the beacon contract on replay"
        );
    }

    /// @dev `markDepositDataBufferIdProcessed` is gated by `onlyRiver`.
    function testRevert_markDepositDataBufferIdProcessed_notRiver() public {
        bytes32 bufferId = keccak256("some-id");
        address stranger = address(0xC0FFEE);
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.Unauthorized.selector, stranger));
        validator.markDepositDataBufferIdProcessed(bufferId);
    }

    /// @dev Same-batch initial + top-up for the SAME pubkey must revert. The top-up check
    ///      runs during validateDeposits() before the deposit executes, so the mapping is empty at
    ///      that moment and TopUpPubkeyNotFunded fires.
    function testSameBatch_initialAndTopUpSamePubkey_reverts() public {
        IDepositDataBuffer.Deposit[] memory deposits = new IDepositDataBuffer.Deposit[](1);
        deposits[0] = _makeDeposit(0, 130); // initial
        IDepositDataBuffer.TopUp[] memory topUps = new IDepositDataBuffer.TopUp[](1);
        topUps[0] = _makeTopUpDeposit(0, 130); // top-up for same pubkey (same seed)

        (bytes32 bufferId, bytes32 rootHash, bytes[] memory sigs) = _prepareDeposit(deposits, topUps);

        vm.prank(keeper);
        vm.expectRevert(abi.encodeWithSelector(IAttestationVerifierV1.TopUpPubkeyNotFunded.selector, topUps[0].pubkey));
        dm.depositToConsensusLayerWithAttestation(bufferId, rootHash, sigs);
    }

    /// @dev Initial deposit for a pubkey that's already in the lookup (e.g., re-deposit after
    ///      a prior batch) must revert in `validateDeposits()` with PubkeyAlreadyFunded before any
    ///      `IDepositContract.deposit{}()` call runs. Uses the test helper to seed the mapping
    ///      directly; submitting two identical batches through the real buffer would collide on
    ///      bufferId before the mapping check fires.
    function testRevert_doubleInitial_acrossBatches() public {
        IDepositDataBuffer.Deposit[] memory deposits = new IDepositDataBuffer.Deposit[](1);
        deposits[0] = _makeDeposit(0, 140);

        // Simulate a prior batch having already recorded this pubkey.
        _seedFundedPubkey(deposits[0].pubkey);

        (bytes32 bufferId, bytes32 rootHash, bytes[] memory sigs) = _prepareDeposit(deposits);

        uint256 depositCountBefore = depositContract.deposit_count();
        vm.prank(keeper);
        vm.expectRevert(abi.encodeWithSelector(IAttestationVerifierV1.PubkeyAlreadyFunded.selector, deposits[0].pubkey));
        dm.depositToConsensusLayerWithAttestation(bufferId, rootHash, sigs);
        assertEq(depositContract.deposit_count(), depositCountBefore, "no deposit should reach the beacon contract");
    }

    /// @dev Same-batch duplicate-initial (two entries with the same pubkey, both flagged as
    ///      initials via non-zero depositY) must revert in `validateDeposits()` with PubkeyAlreadyFunded
    ///      before any deposit is sent to the beacon contract. Catches the producer-bug class where
    ///      the dup is intra-batch and not yet recorded on-chain — the on-chain lookup is empty for
    ///      this pubkey at validate-time, so the inner per-batch scan is what fires.
    function testRevert_sameBatch_duplicateInitial_failsBeforeDeposit() public {
        IDepositDataBuffer.Deposit[] memory deposits = new IDepositDataBuffer.Deposit[](2);
        deposits[0] = _makeDeposit(0, 150);
        deposits[1] = _makeDeposit(0, 150); // same operator + same seed → same pubkey, both initials

        (bytes32 bufferId, bytes32 rootHash, bytes[] memory sigs) = _prepareDeposit(deposits);

        uint256 depositCountBefore = depositContract.deposit_count();
        vm.prank(keeper);
        vm.expectRevert(abi.encodeWithSelector(IAttestationVerifierV1.PubkeyAlreadyFunded.selector, deposits[1].pubkey));
        dm.depositToConsensusLayerWithAttestation(bufferId, rootHash, sigs);
        assertEq(depositContract.deposit_count(), depositCountBefore, "no deposit should reach the beacon contract");
    }

    /// @dev `recordNewlyFundedPubkeys` is gated by `onlyRiver` (msg.sender == RiverAddress.get()).
    ///      Any other caller must revert with LibErrors.Unauthorized.
    function testRevert_recordNewlyFundedPubkeys_notRiver() public {
        bytes[] memory pubkeys = new bytes[](1);
        pubkeys[0] = _fakePubkey(0xDEAD);

        address stranger = address(0xC0FFEE);
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.Unauthorized.selector, stranger));
        validator.recordNewlyFundedPubkeys(pubkeys);
    }

    /// @dev `validateDeposits()` must fail-fast on out-of-range or mis-aligned `amount` rather than
    ///      deferring to the per-deposit check inside `_depositValidator`. Tests all three
    ///      branches: below minimum (1 ether), above maximum (2048 ether), and non-gwei-aligned.
    function testRevert_validate_invalidDepositAmount() public {
        // Below minimum (0 wei).
        IDepositDataBuffer.Deposit[] memory deposits = new IDepositDataBuffer.Deposit[](1);
        deposits[0] = _makeDeposit(0, 400);
        deposits[0].amount = 0;
        (bytes32 bufferId, bytes32 rootHash, bytes[] memory sigs) = _prepareDeposit(deposits);
        vm.prank(keeper);
        vm.expectRevert(abi.encodeWithSelector(IAttestationVerifierV1.InvalidDepositAmount.selector, 0, 0));
        dm.depositToConsensusLayerWithAttestation(bufferId, rootHash, sigs);

        // Above maximum (2048 ether + 1 gwei).
        deposits[0] = _makeDeposit(0, 401);
        deposits[0].amount = 2048 ether + 1 gwei;
        (bufferId, rootHash, sigs) = _prepareDeposit(deposits);
        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSelector(IAttestationVerifierV1.InvalidDepositAmount.selector, 0, 2048 ether + 1 gwei)
        );
        dm.depositToConsensusLayerWithAttestation(bufferId, rootHash, sigs);

        // Not gwei-aligned (32 ether + 1 wei).
        deposits[0] = _makeDeposit(0, 402);
        deposits[0].amount = 32 ether + 1;
        (bufferId, rootHash, sigs) = _prepareDeposit(deposits);
        vm.prank(keeper);
        vm.expectRevert(abi.encodeWithSelector(IAttestationVerifierV1.InvalidDepositAmount.selector, 0, 32 ether + 1));
        dm.depositToConsensusLayerWithAttestation(bufferId, rootHash, sigs);
    }

    /// @dev Two top-ups for the same pubkey within one batch are Pectra-legal under 0x02
    ///      compounding withdrawal credentials. Both entries must succeed because the
    ///      in-batch duplicate scan only applies to initial deposits — top-ups are exempt.
    function testTopUp_sameBatch_twoTopUpsForSamePubkey_succeeds() public {
        IDepositDataBuffer.TopUp[] memory topUps = new IDepositDataBuffer.TopUp[](2);
        topUps[0] = _makeTopUpDeposit(0, 300);
        topUps[1] = _makeTopUpDeposit(0, 300); // same seed → same pubkey, both top-ups

        // Seed the pubkey so the membership check passes for both entries.
        _seedFundedPubkey(topUps[0].pubkey);

        (bytes32 bufferId, bytes32 rootHash, bytes[] memory sigs) = _prepareTopUps(topUps);

        uint256 depositCountBefore = depositContract.deposit_count();
        vm.prank(keeper);
        dm.depositToConsensusLayerWithAttestation(bufferId, rootHash, sigs);

        assertEq(
            depositContract.deposit_count(), depositCountBefore + 2, "both top-ups for the same pubkey should execute"
        );
    }

    /// @dev Documented trade-off post-removal of operator-bind: `PectraValidatorPubkeyLookup`
    ///      records membership only (no operator association), so a top-up whose
    ///      `operatorIdx` differs from the original initial-deposit operator is credited
    ///      to whoever is mentioned in the deposit data buffer.
    function testTopUp_operatorIdxMismatch_creditedAsBuffered() public {
        IDepositDataBuffer.TopUp[] memory topUps = new IDepositDataBuffer.TopUp[](1);
        topUps[0] = _makeTopUpDeposit(5, 200); // buffer says operator 5

        // Seed the pubkey via the membership-only lookup (no operator tracked).
        _seedFundedPubkey(topUps[0].pubkey);

        (bytes32 bufferId, bytes32 rootHash, bytes[] memory sigs) = _prepareTopUps(topUps);

        vm.prank(keeper);
        dm.depositToConsensusLayerWithAttestation(bufferId, rootHash, sigs);

        assertEq(dm.lastFundedETH(5), 32 ether, "operator 5 credited as recorded by the buffer");
        assertEq(dm.lastFundedETH(3), 0, "operator 3 not credited - the lookup tracks membership only");
    }

    /// @dev The `onlyRiver` modifier compares msg.sender against the River CONTRACT address
    ///      (RiverAddress.get()), NOT the River admin EOA. Calling as the admin must still
    ///      revert with `LibErrors.Unauthorized(admin)`. Documents the distinction from
    ///      `onlyRiverAdmin` so future refactors don't conflate the two gates.
    function testRevert_recordNewlyFundedPubkeys_notRiverAdmin() public {
        bytes[] memory pubkeys = new bytes[](1);
        pubkeys[0] = _fakePubkey(0xBEEF);

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.Unauthorized.selector, admin));
        validator.recordNewlyFundedPubkeys(pubkeys);
    }

    /// @dev A successful top-up must emit `TopUp` with both indexed topics (bufferId,
    ///      operatorIdx) and the non-indexed data (pubkey, amount). Mirrors the
    ///      `testPubkeyFunded_recordsPubkey` expectEmit pattern.
    function testTopUp_emitsTopUpEvent() public {
        uint256 operatorIdx = 7;
        IDepositDataBuffer.TopUp[] memory topUps = new IDepositDataBuffer.TopUp[](1);
        topUps[0] = _makeTopUpDeposit(operatorIdx, 222);

        _seedFundedPubkey(topUps[0].pubkey);

        (bytes32 bufferId, bytes32 rootHash, bytes[] memory sigs) = _prepareTopUps(topUps);

        vm.expectEmit(true, true, false, true);
        emit TopUp(bufferId, operatorIdx, topUps[0].pubkey, topUps[0].amount);

        vm.prank(keeper);
        dm.depositToConsensusLayerWithAttestation(bufferId, rootHash, sigs);
    }

    // setRootAttester must reject calls that would leave the attester's status unchanged so the
    // admin cannot silently no-op when intending to flip a flag.
    function testRevert_setRootAttesterStatusUnchanged() public {
        // rootAttester1 was registered in setUp(); re-adding must revert
        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(IAttestationVerifierV1.RootAttesterStatusUnchanged.selector, rootAttester1, true)
        );
        validator.setRootAttester(rootAttester1, true);

        // an unregistered address being removed must also revert
        address stranger = address(0xC0FFEE);
        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(IAttestationVerifierV1.RootAttesterStatusUnchanged.selector, stranger, false)
        );
        validator.setRootAttester(stranger, false);
    }

    // -----------------------------------------------------------------------
    // View functions
    // -----------------------------------------------------------------------

    /// @dev Test every external view on the verifier returns the value configured at init.
    function testViews_returnConfiguredValues() public {
        assertEq(validator.getRiver(), address(dm));
        assertEq(validator.getDepositDataBuffer(), address(buffer));
        assertEq(validator.getRootAttesterCount(), 3);
        assertEq(validator.getRootAttestationQuorum(), 2);
        assertTrue(validator.isRootAttester(rootAttester1));
        assertTrue(validator.isRootAttester(rootAttester2));
        assertTrue(validator.isRootAttester(rootAttester3));
        assertFalse(validator.isRootAttester(address(0xDEAD)));
        // Cross-check the domain separator against an independently-recomputed value rather
        // than just !=0, so a future drift in NAME_HASH / VERSION_HASH / TYPEHASH wording
        // breaks the test instead of silently agreeing with the contract.
        bytes32 expectedDomainSeparator =
            keccak256(abi.encode(EIP712_DOMAIN_TYPEHASH, NAME_HASH, VERSION_HASH, block.chainid, address(dm)));
        assertEq(validator.getDomainSeparator(), expectedDomainSeparator, "domain separator drift");
        // DEPOSIT_DOMAIN was set at init from a zero genesis fork version; just check it was set.
        assertTrue(validator.DEPOSIT_DOMAIN() != bytes32(0));
    }

    // -----------------------------------------------------------------------
    // validateDeposits() length / empty-batch reverts
    // -----------------------------------------------------------------------

    /// @dev A deposit with a mis-sized pubkey must revert in validateDeposits() before the BLS path.
    function testRevert_validate_invalidPubkeyLength() public {
        IDepositDataBuffer.Deposit[] memory deposits = new IDepositDataBuffer.Deposit[](1);
        deposits[0] = _makeDeposit(0, 700);
        deposits[0].pubkey = new bytes(47); // off by one
        (bytes32 bufferId, bytes32 rootHash, bytes[] memory sigs) = _prepareDeposit(deposits);
        vm.prank(keeper);
        vm.expectRevert(abi.encodeWithSelector(IAttestationVerifierV1.InvalidPubkeyLength.selector, 0, 47));
        dm.depositToConsensusLayerWithAttestation(bufferId, rootHash, sigs);
    }

    /// @dev A deposit with a mis-sized signature must revert in validateDeposits() before the BLS path.
    function testRevert_validate_invalidSignatureLength() public {
        IDepositDataBuffer.Deposit[] memory deposits = new IDepositDataBuffer.Deposit[](1);
        deposits[0] = _makeDeposit(0, 701);
        deposits[0].signature = new bytes(95); // off by one
        (bytes32 bufferId, bytes32 rootHash, bytes[] memory sigs) = _prepareDeposit(deposits);
        vm.prank(keeper);
        vm.expectRevert(abi.encodeWithSelector(IAttestationVerifierV1.InvalidSignatureLength.selector, 0, 95));
        dm.depositToConsensusLayerWithAttestation(bufferId, rootHash, sigs);
    }

    /// @dev An empty deposit batch must revert with NoDeposits before any further processing.
    function testRevert_validate_noDeposits() public {
        IDepositDataBuffer.Deposit[] memory deposits = new IDepositDataBuffer.Deposit[](0);
        bytes32 bufferId = keccak256(abi.encode(_batchOf(deposits)));
        buffer.submitDepositData(bufferId, _batchOf(deposits));
        bytes32 rootHash = depositContract.get_deposit_root();
        bytes[] memory sigs = new bytes[](2);
        sigs[0] = _signAttestation(rootAttesterPk1, bufferId, rootHash);
        sigs[1] = _signAttestation(rootAttesterPk2, bufferId, rootHash);
        vm.prank(keeper);
        vm.expectRevert(IAttestationVerifierV1.NoDeposits.selector);
        dm.depositToConsensusLayerWithAttestation(bufferId, rootHash, sigs);
    }

    // -----------------------------------------------------------------------
    // Admin setters — happy paths + onlyRiverAdmin gate
    // -----------------------------------------------------------------------

    /// @dev Admin can register a new attester; count increments; the attester becomes recognised.
    function testSetRootAttester_addAndRemove() public {
        address newAttester = address(0xFEED);
        assertFalse(validator.isRootAttester(newAttester));

        vm.prank(admin);
        validator.setRootAttester(newAttester, true);
        assertTrue(validator.isRootAttester(newAttester));
        assertEq(validator.getRootAttesterCount(), 4);

        // Removing brings us back to 3.
        vm.prank(admin);
        validator.setRootAttester(newAttester, false);
        assertFalse(validator.isRootAttester(newAttester));
        assertEq(validator.getRootAttesterCount(), 3);
    }

    /// @dev Non-admin caller must be rejected by onlyRiverAdmin.
    function testRevert_setRootAttester_unauthorized() public {
        address stranger = address(0xC0FFEE);
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.Unauthorized.selector, stranger));
        validator.setRootAttester(address(0xFEED), true);
    }

    /// @dev Cannot remove an attester if doing so would leave fewer attesters than the configured quorum.
    function testRevert_setRootAttester_wouldUnderQuorum() public {
        // quorum=2, 3 attesters; remove one → 2 (still ok), remove another → 1 < 2 (rejects).
        vm.prank(admin);
        validator.setRootAttester(rootAttester3, false);
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(IAttestationVerifierV1.QuorumExceedsRootAttesterCount.selector, 2, 1));
        validator.setRootAttester(rootAttester2, false);
    }

    /// @dev setRootAttestationQuorum happy path: drop quorum to 1, then back to 2.
    function testSetRootAttestationQuorum_happyPath() public {
        vm.prank(admin);
        validator.setRootAttestationQuorum(1);
        assertEq(validator.getRootAttestationQuorum(), 1);

        vm.prank(admin);
        validator.setRootAttestationQuorum(2);
        assertEq(validator.getRootAttestationQuorum(), 2);
    }

    function testRevert_setRootAttestationQuorum_zero() public {
        vm.prank(admin);
        vm.expectRevert(IAttestationVerifierV1.ZeroQuorum.selector);
        validator.setRootAttestationQuorum(0);
    }

    function testRevert_setRootAttestationQuorum_exceedsAttesterCount() public {
        // 3 attesters; quorum > 3 is rejected.
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(IAttestationVerifierV1.QuorumExceedsRootAttesterCount.selector, 4, 3));
        validator.setRootAttestationQuorum(4);
    }

    function testRevert_setRootAttestationQuorum_unauthorized() public {
        address stranger = address(0xC0FFEE);
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.Unauthorized.selector, stranger));
        validator.setRootAttestationQuorum(1);
    }

    /// @dev Admin can rotate the DepositDataBuffer address.
    function testSetDepositDataBuffer_happyPath() public {
        address newBuffer = address(0xBABE);
        vm.prank(admin);
        validator.setDepositDataBuffer(newBuffer);
        assertEq(validator.getDepositDataBuffer(), newBuffer);
    }

    function testRevert_setDepositDataBuffer_unauthorized() public {
        address stranger = address(0xC0FFEE);
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.Unauthorized.selector, stranger));
        validator.setDepositDataBuffer(address(0xBABE));
    }

    // -----------------------------------------------------------------------
    // CLDM view functions
    // -----------------------------------------------------------------------

    /// @dev Test every CLDM external view returns the value configured during setUp.
    function testCLDM_viewFunctions() public {
        assertEq(dm.getCommittedBalance(), 128 ether);
        assertEq(dm.getBalanceToDeposit(), 0);
        assertEq(dm.getWithdrawalCredentials(), withdrawalCredentials);
        assertEq(dm.getTotalDepositedETH(), 0);
        assertEq(dm.getKeeper(), keeper);
        assertEq(dm.getAttestationVerifier(), address(validator));
    }

    // -----------------------------------------------------------------------
    // initAttestationVerifierV1 — input validation
    // -----------------------------------------------------------------------

    /// @dev Cannot init with an empty attester array.
    function testRevert_init_emptyAttesterArray() public {
        AttestationVerifierV1 freshValidator = new AttestationVerifierV1();
        LibImplementationUnbricker.unbrick(vm, address(freshValidator));
        address[] memory empty = new address[](0);
        vm.expectRevert(LibErrors.InvalidArgument.selector);
        freshValidator.initAttestationVerifierV1(address(dm), address(buffer), empty, 1, bytes4(0), empty, 1);
    }

    /// @dev Cannot init with a root quorum of zero. This is distinct from an empty
    ///      attester set: a populated committee with quorum=0 would make signatures optional.
    function testRevert_init_zeroRootQuorum() public {
        AttestationVerifierV1 freshValidator = new AttestationVerifierV1();
        LibImplementationUnbricker.unbrick(vm, address(freshValidator));
        address[] memory rootAttesters = new address[](1);
        rootAttesters[0] = rootAttester1;
        address[] memory consolidationAttesters = new address[](1);
        consolidationAttesters[0] = makeAddr("consolidation-attester");

        vm.expectRevert(IAttestationVerifierV1.ZeroQuorum.selector);
        freshValidator.initAttestationVerifierV1(
            address(dm), address(buffer), rootAttesters, 0, bytes4(0), consolidationAttesters, 1
        );
    }

    /// @dev Cannot init with more root attesters than the defensive cap. The empty-array
    ///      case exercises the same top-level InvalidArgument revert but a different
    ///      production risk: unbounded storage growth and a larger quorum-dedup surface.
    function testRevert_init_tooManyRootAttesters() public {
        AttestationVerifierV1 freshValidator = new AttestationVerifierV1();
        LibImplementationUnbricker.unbrick(vm, address(freshValidator));
        address[] memory tooManyRootAttesters = new address[](validator.MAX_ROOT_ATTESTERS() + 1);
        for (uint256 i = 0; i < tooManyRootAttesters.length; i++) {
            tooManyRootAttesters[i] = address(uint160(0xB000 + i));
        }
        address[] memory consolidationAttesters = new address[](1);
        consolidationAttesters[0] = makeAddr("consolidation-attester");

        vm.expectRevert(LibErrors.InvalidArgument.selector);
        freshValidator.initAttestationVerifierV1(
            address(dm), address(buffer), tooManyRootAttesters, 1, bytes4(0), consolidationAttesters, 1
        );
    }

    /// @dev Cannot init with a quorum strictly greater than the attester count.
    function testRevert_init_quorumExceedsAttesterCount() public {
        AttestationVerifierV1 freshValidator = new AttestationVerifierV1();
        LibImplementationUnbricker.unbrick(vm, address(freshValidator));
        address[] memory attesters = new address[](2);
        attesters[0] = rootAttester1;
        attesters[1] = rootAttester2;
        vm.expectRevert(abi.encodeWithSelector(IAttestationVerifierV1.QuorumExceedsRootAttesterCount.selector, 3, 2));
        freshValidator.initAttestationVerifierV1(address(dm), address(buffer), attesters, 3, bytes4(0), attesters, 3);
    }

    /// @dev Cannot add an attester that would push the total past MAX_ROOT_ATTESTERS.
    ///      Fills the registry to the cap (32), then tries to add one more.
    function testRevert_setRootAttester_exceedsMax() public {
        uint256 max = validator.MAX_ROOT_ATTESTERS();
        // setUp already registered 3 attesters; add up to the cap.
        for (uint256 i = 3; i < max; ++i) {
            vm.prank(admin);
            validator.setRootAttester(address(uint160(0x1000 + i)), true);
        }
        assertEq(validator.getRootAttesterCount(), max);
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(IAttestationVerifierV1.TooManyRootAttesters.selector, max + 1, max));
        validator.setRootAttester(address(uint160(0x9999)), true);
    }

    // -----------------------------------------------------------------------
    // G-1: TooManySignatures bound
    // -----------------------------------------------------------------------

    /// @dev `validateDeposits()` rejects a signature array longer than MAX_SIGNATURES (20) before any
    ///      recovery work runs — bounds the O(n^2) dedup loop. Sig content doesn't matter
    ///      since the length check fires first.
    function testRevert_validate_tooManySignatures() public {
        IDepositDataBuffer.Deposit[] memory deposits = new IDepositDataBuffer.Deposit[](1);
        deposits[0] = _makeDeposit(0, 800);
        (bytes32 bufferId, bytes32 rootHash,) = _prepareDeposit(deposits);

        uint256 max = validator.MAX_SIGNATURES();
        bytes[] memory tooMany = new bytes[](max + 1);
        for (uint256 i = 0; i < max + 1; i++) {
            tooMany[i] = new bytes(65); // any 65-byte blob; length check fires before recovery
        }
        vm.prank(keeper);
        vm.expectRevert(abi.encodeWithSelector(IAttestationVerifierV1.TooManySignatures.selector, max + 1, max));
        dm.depositToConsensusLayerWithAttestation(bufferId, rootHash, tooMany);
    }

    // -----------------------------------------------------------------------
    // G-2: QuorumExceedsMaxSignatures — both code paths
    // -----------------------------------------------------------------------

    /// @dev Cannot init with a quorum > MAX_SIGNATURES, even when the attester count would
    ///      allow it. The MAX_SIGNATURES check at init fires before the attester-count check.
    function testRevert_init_quorumExceedsMaxSignatures() public {
        AttestationVerifierV1 fresh = new AttestationVerifierV1();
        LibImplementationUnbricker.unbrick(vm, address(fresh));
        // Need attesterCount > MAX_SIGNATURES so the attester-count check doesn't fire first.
        uint256 max = validator.MAX_SIGNATURES();
        address[] memory atts = new address[](max + 5);
        for (uint256 i = 0; i < max + 5; i++) {
            atts[i] = address(uint160(0x9000 + i));
        }
        vm.expectRevert(
            abi.encodeWithSelector(IAttestationVerifierV1.QuorumExceedsMaxSignatures.selector, max + 1, max)
        );
        fresh.initAttestationVerifierV1(address(dm), address(buffer), atts, max + 1, bytes4(0), atts, max + 1);
    }

    /// @dev Admin cannot set quorum > MAX_SIGNATURES via the post-init setter. Distinct code
    ///      path from the init-time check above.
    function testRevert_setRootAttestationQuorum_exceedsMaxSignatures() public {
        // Grow attester count past MAX_SIGNATURES so the attester-count check doesn't fire first.
        uint256 max = validator.MAX_SIGNATURES();
        for (uint256 i = 3; i <= max; i++) {
            vm.prank(admin);
            validator.setRootAttester(address(uint160(0xA000 + i)), true);
        }
        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(IAttestationVerifierV1.QuorumExceedsMaxSignatures.selector, max + 1, max)
        );
        validator.setRootAttestationQuorum(max + 1);
    }

    // -----------------------------------------------------------------------
    // G-3: _recover negative branches
    // -----------------------------------------------------------------------

    /// @dev A short signature (length != 65) and an out-of-range `v` after normalization must
    ///      be silently skipped by `_recover` (return address(0) → the dedup loop continues)
    ///      AND must not contribute to `validCount`. We raise quorum to 3 so that the 2 valid
    ///      sigs alone are insufficient — if the 2 bad sigs were ever miscounted as valid
    ///      (validCount=4), the call would succeed; with them properly skipped (validCount=2)
    ///      it must revert with `InsufficientAttestations(2, 3)`.
    function testRecover_silentlySkipsBadSigs() public {
        // Raise quorum above the number of valid sigs we'll provide so the assertion is tight.
        vm.prank(admin);
        validator.setRootAttestationQuorum(3);

        IDepositDataBuffer.Deposit[] memory deposits = new IDepositDataBuffer.Deposit[](1);
        deposits[0] = _makeDeposit(0, 850);
        bytes32 bufferId = keccak256(abi.encode(_batchOf(deposits)));
        buffer.submitDepositData(bufferId, _batchOf(deposits));
        bytes32 rootHash = depositContract.get_deposit_root();

        bytes[] memory sigs = new bytes[](4);
        // sigs[0]: length != 65 → silent skip via the length check
        sigs[0] = bytes("short");
        // sigs[1]: 65 bytes with v=2 → normalised to 29, outside {27,28} → silent skip
        bytes memory badV = new bytes(65);
        badV[64] = bytes1(uint8(2));
        sigs[1] = badV;
        // sigs[2] / sigs[3]: two valid signatures — only 2 of 4 will count toward quorum
        sigs[2] = _signAttestation(rootAttesterPk1, bufferId, rootHash);
        sigs[3] = _signAttestation(rootAttesterPk2, bufferId, rootHash);

        vm.prank(keeper);
        vm.expectRevert(abi.encodeWithSelector(IAttestationVerifierV1.InsufficientAttestations.selector, 2, 3));
        dm.depositToConsensusLayerWithAttestation(bufferId, rootHash, sigs);
    }

    /// @dev A signature can be exactly 65 bytes and have a normalized v, yet still fail
    ///      inside ECDSA.tryRecover (here r=s=0). The verifier must treat that as
    ///      address(0), skip it, and continue counting only valid unique root attesters.
    function testRecover_skipsTryRecoverErrors() public {
        vm.prank(admin);
        validator.setRootAttestationQuorum(3);

        IDepositDataBuffer.Deposit[] memory deposits = new IDepositDataBuffer.Deposit[](1);
        deposits[0] = _makeDeposit(0, 852);
        bytes32 bufferId = keccak256(abi.encode(_batchOf(deposits)));
        buffer.submitDepositData(bufferId, _batchOf(deposits));
        bytes32 rootHash = depositContract.get_deposit_root();

        bytes memory invalidButWellSized = new bytes(65);
        invalidButWellSized[64] = bytes1(uint8(27));

        bytes[] memory sigs = new bytes[](3);
        sigs[0] = invalidButWellSized;
        sigs[1] = _signAttestation(rootAttesterPk1, bufferId, rootHash);
        sigs[2] = _signAttestation(rootAttesterPk2, bufferId, rootHash);

        vm.prank(keeper);
        vm.expectRevert(abi.encodeWithSelector(IAttestationVerifierV1.InsufficientAttestations.selector, 2, 3));
        dm.depositToConsensusLayerWithAttestation(bufferId, rootHash, sigs);
    }

    /// @dev The `v < 27 ? v += 27` normalization branch must accept legacy v=0/1 encodings
    ///      from EIP-2098-style tooling. Sign normally then rewrite v to (v-27), submit, and
    ///      assert the deposit succeeds (i.e. signer was correctly recovered).
    function testRecover_normalizesLegacyVZero() public {
        IDepositDataBuffer.Deposit[] memory deposits = new IDepositDataBuffer.Deposit[](1);
        deposits[0] = _makeDeposit(0, 851);
        bytes32 bufferId = keccak256(abi.encode(_batchOf(deposits)));
        buffer.submitDepositData(bufferId, _batchOf(deposits));
        bytes32 rootHash = depositContract.get_deposit_root();

        bytes[] memory sigs = new bytes[](2);
        sigs[0] = _signAttestation_legacyV(rootAttesterPk1, bufferId, rootHash);
        sigs[1] = _signAttestation_legacyV(rootAttesterPk2, bufferId, rootHash);

        vm.prank(keeper);
        dm.depositToConsensusLayerWithAttestation(bufferId, rootHash, sigs);
        assertEq(depositContract.deposit_count(), 1, "legacy v=0/1 signatures were normalised + accepted");
    }

    /// @dev Helper that mirrors `_signAttestation` but encodes `v` as `v - 27` (i.e. 0 or 1),
    ///      exercising the `if (v < 27) v += 27;` branch in `_recover`.
    function _signAttestation_legacyV(uint256 pk, bytes32 bufferId, bytes32 rootHash)
        internal
        view
        returns (bytes memory)
    {
        bytes32 structHash = keccak256(abi.encode(ATTEST_TYPEHASH, bufferId, rootHash));
        bytes32 domainSep =
            keccak256(abi.encode(EIP712_DOMAIN_TYPEHASH, NAME_HASH, VERSION_HASH, block.chainid, address(dm)));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSep, structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
        return abi.encodePacked(r, s, uint8(v - 27));
    }

    // -----------------------------------------------------------------------
    // G-4: init idempotency
    // -----------------------------------------------------------------------

    /// @dev `initAttestationVerifierV1` is `init(0)`-gated; a second call must revert via the
    ///      Initializable modifier (current stored version is 1, modifier expects 0).
    function testRevert_init_cannotBeCalledTwice() public {
        address[] memory atts = new address[](2);
        atts[0] = makeAddr("a");
        atts[1] = makeAddr("b");
        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector, 0, 1));
        validator.initAttestationVerifierV1(address(dm), address(buffer), atts, 1, bytes4(0), atts, 1);
    }

    // -----------------------------------------------------------------------
    // DepositObject refactor — new invariants introduced by splitting Deposit / TopUp
    // -----------------------------------------------------------------------

    /// @dev Top-ups carry no signature in the buffer; ConsensusLayerDepositManager hardcodes a
    ///      96-byte zero buffer when forwarding the call to the official deposit contract.
    ///      Asserted by inspecting the `DepositEvent` log emitted by the deposit contract mock.
    function testTopUp_passesZeroSignatureToDepositContract() public {
        bytes memory pk = _fakePubkey(900);
        _seedFundedPubkey(pk);

        IDepositDataBuffer.TopUp[] memory topUps = new IDepositDataBuffer.TopUp[](1);
        topUps[0] = IDepositDataBuffer.TopUp({pubkey: pk, amount: 32 ether, operatorIdx: 0});
        (bytes32 bufferId, bytes32 rootHash, bytes[] memory sigs) = _prepareTopUps(topUps);

        vm.recordLogs();
        vm.prank(keeper);
        dm.depositToConsensusLayerWithAttestation(bufferId, rootHash, sigs);

        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 depositEventTopic = keccak256("DepositEvent(bytes,bytes,bytes,bytes,bytes)");
        bool depositEventFound = false;
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].emitter == address(depositContract) && logs[i].topics[0] == depositEventTopic) {
                (,,, bytes memory recordedSignature,) = abi.decode(logs[i].data, (bytes, bytes, bytes, bytes, bytes));
                assertEq(recordedSignature.length, 96, "signature length");
                assertEq(recordedSignature, new bytes(96), "top-up signature must be 96 zero bytes");
                depositEventFound = true;
                break;
            }
        }
        assertTrue(depositEventFound, "DepositEvent must be emitted by the deposit contract");
    }

    /// @dev The `recordNewlyFundedPubkeys` callback must contain only initial-deposit pubkeys.
    ///      Including a top-up pubkey would pollute `PectraValidatorPubkeyLookup` with already-funded
    ///      keys (harmless but a state-purity regression).
    function testRecordNewlyFundedPubkeys_excludesTopUps() public {
        bytes memory topUpPk = _fakePubkey(910);
        _seedFundedPubkey(topUpPk);

        IDepositDataBuffer.Deposit[] memory deposits = new IDepositDataBuffer.Deposit[](2);
        deposits[0] = _makeDeposit(0, 911);
        deposits[1] = _makeDeposit(1, 912);
        IDepositDataBuffer.TopUp[] memory topUps = new IDepositDataBuffer.TopUp[](1);
        topUps[0] = IDepositDataBuffer.TopUp({pubkey: topUpPk, amount: 32 ether, operatorIdx: 0});

        bytes[] memory expectedPubkeys = new bytes[](2);
        expectedPubkeys[0] = deposits[0].pubkey;
        expectedPubkeys[1] = deposits[1].pubkey;
        vm.expectCall(
            address(validator), abi.encodeCall(IAttestationVerifierV1.recordNewlyFundedPubkeys, (expectedPubkeys))
        );

        (bytes32 bufferId, bytes32 rootHash, bytes[] memory sigs) = _prepareDeposit(deposits, topUps);

        vm.expectEmit(false, false, false, true, address(validator));
        emit AddedPectraValidatorPubkeys(expectedPubkeys);

        vm.prank(keeper);
        dm.depositToConsensusLayerWithAttestation(bufferId, rootHash, sigs);

        assertTrue(validator.isPubkeyFunded(deposits[0].pubkey), "deposit 0 pubkey recorded in post-Pectra lookup");
        assertTrue(validator.isPubkeyFunded(deposits[1].pubkey), "deposit 1 pubkey recorded in post-Pectra lookup");
    }

    /// @dev `LibFundingDeltas.build` aggregates fundedETH across BOTH the deposits[] and
    ///      topUps[] sub-arrays. A regression that iterates only one would lose ETH from the
    ///      per-operator delta. This test exercises a single operator receiving both initials
    ///      and a top-up in the same batch and asserts the harness's recorded delta matches
    ///      the full sum.
    function testFundingDelta_aggregatesAcrossDepositsAndTopUps() public {
        bytes memory topUpPk = _fakePubkey(920);
        _seedFundedPubkey(topUpPk);

        IDepositDataBuffer.Deposit[] memory deposits = new IDepositDataBuffer.Deposit[](2);
        deposits[0] = _makeDeposit(0, 921);
        deposits[1] = _makeDeposit(0, 922);
        IDepositDataBuffer.TopUp[] memory topUps = new IDepositDataBuffer.TopUp[](1);
        topUps[0] = IDepositDataBuffer.TopUp({pubkey: topUpPk, amount: 8 ether, operatorIdx: 0});

        (bytes32 bufferId, bytes32 rootHash, bytes[] memory sigs) = _prepareDeposit(deposits, topUps);
        vm.prank(keeper);
        dm.depositToConsensusLayerWithAttestation(bufferId, rootHash, sigs);

        assertEq(dm.lastFundedETH(0), 32 ether + 32 ether + 8 ether, "delta must include top-up amount");
    }

    /// @dev A container with both sub-arrays empty must revert NoDeposits. The check
    ///      `depositCount == 0 && topUpCount == 0` is now a logical AND across two array
    ///      lengths; a regression that drops either conjunct would accept a half-empty batch.
    function testRevert_emptyContainer_revertsNoDeposits() public {
        IDepositDataBuffer.DepositObject memory batch;
        bytes32 bufferId = keccak256(abi.encode(batch));
        buffer.submitDepositData(bufferId, batch);
        bytes32 rootHash = depositContract.get_deposit_root();

        bytes[] memory sigs = new bytes[](2);
        sigs[0] = _signAttestation(rootAttesterPk1, bufferId, rootHash);
        sigs[1] = _signAttestation(rootAttesterPk2, bufferId, rootHash);

        vm.prank(keeper);
        vm.expectRevert(IAttestationVerifierV1.NoDeposits.selector);
        dm.depositToConsensusLayerWithAttestation(bufferId, rootHash, sigs);
    }

    // -----------------------------------------------------------------------
    // validateDeposits() top-up length / amount reverts
    // -----------------------------------------------------------------------

    /// @dev A top-up with a mis-sized pubkey must revert in validateDeposits()'s top-up loop with
    ///      InvalidPubkeyLength. Mirrors the initial-deposit pubkey-length check, exercising
    ///      the separate top-up validation path.
    function testRevert_validate_topUp_invalidPubkeyLength() public {
        IDepositDataBuffer.TopUp[] memory topUps = new IDepositDataBuffer.TopUp[](1);
        topUps[0] = _makeTopUpDeposit(0, 710);
        topUps[0].pubkey = new bytes(47); // off by one
        (bytes32 bufferId, bytes32 rootHash, bytes[] memory sigs) = _prepareTopUps(topUps);
        vm.prank(keeper);
        vm.expectRevert(abi.encodeWithSelector(IAttestationVerifierV1.InvalidPubkeyLength.selector, 0, 47));
        dm.depositToConsensusLayerWithAttestation(bufferId, rootHash, sigs);
    }

    /// @dev A top-up amount outside the [1 ether, 2048 ether] gwei-aligned range must revert in
    ///      validateDeposits()'s top-up loop with InvalidDepositAmount. The amount bound is checked
    ///      before the funded-membership check, so no pubkey seeding is required.
    function testRevert_validate_topUp_invalidDepositAmount() public {
        // Below minimum (0 wei).
        IDepositDataBuffer.TopUp[] memory topUps = new IDepositDataBuffer.TopUp[](1);
        topUps[0] = _makeTopUpDeposit(0, 711);
        topUps[0].amount = 0;
        (bytes32 bufferId, bytes32 rootHash, bytes[] memory sigs) = _prepareTopUps(topUps);
        vm.prank(keeper);
        vm.expectRevert(abi.encodeWithSelector(IAttestationVerifierV1.InvalidDepositAmount.selector, 0, 0));
        dm.depositToConsensusLayerWithAttestation(bufferId, rootHash, sigs);

        // Not gwei-aligned (32 ether + 1 wei).
        topUps[0] = _makeTopUpDeposit(0, 712);
        topUps[0].amount = 32 ether + 1;
        (bufferId, rootHash, sigs) = _prepareTopUps(topUps);
        vm.prank(keeper);
        vm.expectRevert(abi.encodeWithSelector(IAttestationVerifierV1.InvalidDepositAmount.selector, 0, 32 ether + 1));
        dm.depositToConsensusLayerWithAttestation(bufferId, rootHash, sigs);
    }

    // -----------------------------------------------------------------------
    // LibFundingDeltas.build operator-index bound (reached via the deposit flow)
    // -----------------------------------------------------------------------

    /// @dev An initial deposit whose operatorIdx is >= the registered operator count must revert
    ///      with LibFundingDeltas.InvalidOperatorIndex once aggregation runs in
    ///      _updateFundedETHFromBuffer. Shrinks the harness operator count to force the bound.
    function testRevert_build_invalidOperatorIndex_deposit() public {
        dm.sudoSetOperatorCount(1); // only operator 0 is in range

        IDepositDataBuffer.Deposit[] memory deposits = new IDepositDataBuffer.Deposit[](1);
        deposits[0] = _makeDeposit(5, 720); // operatorIdx 5 is out of range
        (bytes32 bufferId, bytes32 rootHash, bytes[] memory sigs) = _prepareDeposit(deposits);

        vm.prank(keeper);
        vm.expectRevert(abi.encodeWithSelector(LibFundingDeltas.InvalidOperatorIndex.selector, 5, 1));
        dm.depositToConsensusLayerWithAttestation(bufferId, rootHash, sigs);
    }

    /// @dev A top-up whose operatorIdx is >= the registered operator count must revert with
    ///      LibFundingDeltas.InvalidOperatorIndex via the top-up bucketing pass. Exercises the
    ///      second (top-up) index-bound branch in LibFundingDeltas.build.
    function testRevert_build_invalidOperatorIndex_topUp() public {
        dm.sudoSetOperatorCount(1); // only operator 0 is in range

        IDepositDataBuffer.TopUp[] memory topUps = new IDepositDataBuffer.TopUp[](1);
        topUps[0] = _makeTopUpDeposit(5, 721); // operatorIdx 5 is out of range
        _seedFundedPubkey(topUps[0].pubkey); // pass the funded-membership check first
        (bytes32 bufferId, bytes32 rootHash, bytes[] memory sigs) = _prepareTopUps(topUps);

        vm.prank(keeper);
        vm.expectRevert(abi.encodeWithSelector(LibFundingDeltas.InvalidOperatorIndex.selector, 5, 1));
        dm.depositToConsensusLayerWithAttestation(bufferId, rootHash, sigs);
    }
}
