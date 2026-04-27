// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "forge-std/Test.sol";

import "../../src/components/ConsensusLayerDepositManager.1.sol";
import "../../src/interfaces/IDepositDataBuffer.sol";
import "../../src/libraries/BLS12_381.sol";
import "../utils/LibImplementationUnbricker.sol";
import "../mocks/DepositContractEnhancedMock.sol";

// ---------------------------------------------------------------------------
// Mock DepositDataBuffer — no real implementation exists; stores batches by ID
// ---------------------------------------------------------------------------

contract MockDepositDataBuffer is IDepositDataBuffer {
    mapping(bytes32 => DepositObject[]) internal _batches;
    mapping(bytes32 => bool) internal _exists;

    function submitDepositData(bytes32 depositDataBufferId, DepositObject[] calldata deposits) external {
        if (_exists[depositDataBufferId]) revert DepositDataBufferIdAlreadyExists(depositDataBufferId);
        _exists[depositDataBufferId] = true;
        for (uint256 i = 0; i < deposits.length; i++) {
            _batches[depositDataBufferId].push(deposits[i]);
        }
        emit DepositDataSubmitted(depositDataBufferId, deposits.length);
    }

    function getDepositData(bytes32 depositDataBufferId) external view returns (DepositObject[] memory) {
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

// ---------------------------------------------------------------------------
// Test harness — extends ConsensusLayerDepositManagerV1 with the real
// _updateFundedETHFromBuffer logic (mirrors River.1.sol) so we can
// verify FundedValidatorKeys event emission end-to-end.
//
// Only _incrementFundedETH is stubbed (records values for assertions) because
// the real implementation requires the full OperatorsRegistry.
// ---------------------------------------------------------------------------

contract AttestationDepositHarness is ConsensusLayerDepositManagerV1 {
    address internal immutable _admin;

    /// @dev Stores the last fundedETH array passed to _incrementFundedETH for assertions.
    uint256[] public lastFundedETH;

    constructor(address admin_) {
        _admin = admin_;
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
    function _incrementFundedETH(uint256[] memory fundedETH, bytes[][] memory) internal override {
        delete lastFundedETH;
        for (uint256 i = 0; i < fundedETH.length; i++) {
            lastFundedETH.push(fundedETH[i]);
        }
    }

    /// @dev Real implementation from River.1.sol — groups pubkeys by operator and emits events.
    function _updateFundedETHFromBuffer(IDepositDataBuffer.DepositObject[] memory deposits) internal override {
        if (deposits.length == 0) return;

        uint256 len = deposits.length;
        uint256 highestOpIdx = 0;

        uint256[] memory opIndices = new uint256[](len);
        for (uint256 i = 0; i < len; i++) {
            opIndices[i] = _parseOperatorIndex(deposits[i].metadata);
            if (opIndices[i] > highestOpIdx) highestOpIdx = opIndices[i];
        }

        uint256 buckets = highestOpIdx + 1;
        uint256[] memory fundedETH = new uint256[](buckets);
        uint256[] memory counts = new uint256[](buckets);
        for (uint256 i = 0; i < len; i++) {
            counts[opIndices[i]]++;
        }

        bytes[][] memory perOpKeys = new bytes[][](buckets);
        uint256[] memory cursors = new uint256[](buckets);
        for (uint256 j = 0; j < buckets; j++) {
            if (counts[j] > 0) {
                perOpKeys[j] = new bytes[](counts[j]);
            }
        }

        for (uint256 i = 0; i < len; i++) {
            uint256 opIdx = opIndices[i];
            fundedETH[opIdx] += deposits[i].amount;
            perOpKeys[opIdx][cursors[opIdx]++] = deposits[i].pubkey;
        }

        _incrementFundedETH(fundedETH, perOpKeys);

        for (uint256 j = 0; j < buckets; j++) {
            if (counts[j] > 0) {
                emit FundedValidatorKeys(j, perOpKeys[j], false);
            }
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

    function sudoSetDepositDomain(bytes32 d) external {
        DepositDomainValue.set(d);
    }

    receive() external payable {}
}

// ---------------------------------------------------------------------------
// End-to-end attestation deposit test
//
// Mocking strategy:
//   - BLS verification (verifyBLSDeposit) is mocked via vm.mockCall because
//     EIP-2537 precompiles do not exist in Foundry's EVM.
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
    MockDepositDataBuffer internal buffer;
    DepositContractEnhancedMock internal depositContract;

    address internal admin = address(0xAD);
    address internal keeper = address(0xBEEF);
    bytes32 internal withdrawalCredentials = bytes32(uint256(0x010000000000000000000000CAFEBABE));

    uint256 internal attesterPk1 = 0xA1;
    uint256 internal attesterPk2 = 0xA2;
    uint256 internal attesterPk3 = 0xA3;
    address internal attester1;
    address internal attester2;
    address internal attester3;

    // EIP-712 constants (must match DepositToConsensusLayerValidation)
    bytes32 internal constant EIP712_DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 internal constant NAME_HASH = keccak256("DepositToConsensusLayerValidation");
    bytes32 internal constant VERSION_HASH = keccak256("1");
    bytes32 internal constant ATTEST_TYPEHASH =
        keccak256("Attest(bytes32 depositDataBufferId,bytes32 depositRootHash)");

    event FundedValidatorKeys(uint256 indexed operatorIndex, bytes[] publicKeys, bool deferred);
    event DepositsExecutedWithAttestation(
        bytes32 indexed depositDataBufferId, bytes32 indexed depositRootHash, uint256 totalAmount
    );
    event SetInFlightETH(uint256 oldInFlightETH, uint256 newInFlightETH);
    event SetTotalDepositedETH(uint256 oldTotalDepositedETH, uint256 newTotalDepositedETH);

    function _emptyDepositY() internal pure returns (BLS12_381.DepositY memory) {
        return BLS12_381.DepositY({
            pubkeyY: BLS12_381.Fp({a: bytes32(0), b: bytes32(0)}),
            signatureY: BLS12_381.Fp2({c0_a: bytes32(0), c0_b: bytes32(0), c1_a: bytes32(0), c1_b: bytes32(0)})
        });
    }

    function setUp() public {
        attester1 = vm.addr(attesterPk1);
        attester2 = vm.addr(attesterPk2);
        attester3 = vm.addr(attesterPk3);

        depositContract = new DepositContractEnhancedMock();
        buffer = new MockDepositDataBuffer();

        dm = new AttestationDepositHarness(admin);
        LibImplementationUnbricker.unbrick(vm, address(dm));

        dm.initialize(address(depositContract), withdrawalCredentials);
        dm.sudoSetKeeper(keeper);
        dm.sudoSetDepositDomain(bytes32(uint256(1)));

        vm.startPrank(admin);
        dm.setDepositDataBuffer(address(buffer));
        // threshold must be strictly less than attester count
        dm.setAttester(attester1, true);
        dm.setAttester(attester2, true);
        dm.setAttester(attester3, true);
        dm.setAttestationThreshold(2);
        vm.stopPrank();

        // Cache the EIP-712 domain separator (mirrors initRiverV1_3 for proxy deployments)
        bytes32 domainSepSlot = bytes32(uint256(keccak256("river.state.domainSeparator")) - 1);
        bytes32 domainSep =
            keccak256(abi.encode(EIP712_DOMAIN_TYPEHASH, NAME_HASH, VERSION_HASH, block.chainid, address(dm)));
        vm.store(address(dm), domainSepSlot, domainSep);

        // Fund the harness and set committed balance
        vm.deal(address(dm), 128 ether);
        dm.sudoSetCommittedBalance(128 ether);

        // Mock BLS verification — the ONLY mock besides the buffer.
        // EIP-2537 precompiles (Pectra) are not available in Foundry.
        // verifyBLSDeposit is called via staticcall from validate(); mocking it
        // returns success (empty returndata) for any input.
        vm.mockCall(address(dm), abi.encodeWithSelector(dm.verifyBLSDeposit.selector), bytes(""));
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

    /// @dev Encode "operator:N" as left-aligned bytes32.
    function _operatorMetadata(uint256 opIdx) internal pure returns (bytes32) {
        bytes memory prefix = "operator:";
        bytes memory digits;
        if (opIdx == 0) {
            digits = "0";
        } else {
            uint256 temp = opIdx;
            uint256 n = 0;
            while (temp > 0) {
                n++;
                temp /= 10;
            }
            digits = new bytes(n);
            temp = opIdx;
            for (uint256 i = n; i > 0; i--) {
                digits[i - 1] = bytes1(uint8(48 + temp % 10));
                temp /= 10;
            }
        }
        bytes memory full = abi.encodePacked(prefix, digits);
        bytes32 result;
        assembly {
            result := mload(add(full, 32))
        }
        return result;
    }

    /// @dev Build a DepositObject with properly-sized fields.
    function _makeDeposit(uint256 opIdx, uint256 seed) internal view returns (IDepositDataBuffer.DepositObject memory) {
        return IDepositDataBuffer.DepositObject({
            pubkey: _fakePubkey(seed),
            signature: _fakeSignature(seed),
            amount: 32 ether,
            withdrawalCredentials: abi.encode(withdrawalCredentials),
            depositDataRoot: bytes32(0), // not checked by _depositValidator (it recomputes)
            metadata: _operatorMetadata(opIdx)
        });
    }

    /// @dev Sign an EIP-712 attestation digest with the given private key.
    function _signAttestation(uint256 pk, bytes32 bufferId, bytes32 rootHash) internal view returns (bytes memory) {
        bytes32 domainSep =
            keccak256(abi.encode(EIP712_DOMAIN_TYPEHASH, NAME_HASH, VERSION_HASH, block.chainid, address(dm)));
        bytes32 structHash = keccak256(abi.encode(ATTEST_TYPEHASH, bufferId, rootHash));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSep, structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
        return abi.encodePacked(r, s, v);
    }

    /// @dev Submit deposits to buffer, sign attestations, and return all calldata.
    function _prepareDeposit(IDepositDataBuffer.DepositObject[] memory deposits)
        internal
        returns (bytes32 bufferId, bytes32 rootHash, bytes[] memory sigs, BLS12_381.DepositY[] memory depositYs)
    {
        bufferId = keccak256(abi.encode(deposits));
        buffer.submitDepositData(bufferId, deposits);

        rootHash = depositContract.get_deposit_root();

        sigs = new bytes[](2);
        sigs[0] = _signAttestation(attesterPk1, bufferId, rootHash);
        sigs[1] = _signAttestation(attesterPk2, bufferId, rootHash);

        depositYs = new BLS12_381.DepositY[](deposits.length);
        for (uint256 i = 0; i < deposits.length; i++) {
            depositYs[i] = _emptyDepositY();
        }
    }

    // -----------------------------------------------------------------------
    // Happy-path tests
    // -----------------------------------------------------------------------

    function testSuccessfulDeposit_threeDeposits_twoOperators() public {
        // Arrange: 3 deposits — 2 for operator 0, 1 for operator 1
        IDepositDataBuffer.DepositObject[] memory deposits = new IDepositDataBuffer.DepositObject[](3);
        deposits[0] = _makeDeposit(0, 10);
        deposits[1] = _makeDeposit(0, 11);
        deposits[2] = _makeDeposit(1, 20);

        (bytes32 bufferId, bytes32 rootHash, bytes[] memory sigs, BLS12_381.DepositY[] memory depositYs) =
            _prepareDeposit(deposits);

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

        // Expect: final event
        vm.expectEmit(true, true, false, true);
        emit DepositsExecutedWithAttestation(bufferId, rootHash, 96 ether);

        // Act
        vm.prank(keeper);
        dm.depositToConsensusLayerWithAttestation(bufferId, rootHash, sigs, depositYs);

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
        IDepositDataBuffer.DepositObject[] memory deposits = new IDepositDataBuffer.DepositObject[](1);
        deposits[0] = _makeDeposit(5, 42);

        (bytes32 bufferId, bytes32 rootHash, bytes[] memory sigs, BLS12_381.DepositY[] memory depositYs) =
            _prepareDeposit(deposits);

        // Expect: FundedValidatorKeys for operator 5
        bytes[] memory opKeys = new bytes[](1);
        opKeys[0] = deposits[0].pubkey;
        vm.expectEmit(true, false, false, true);
        emit FundedValidatorKeys(5, opKeys, false);

        vm.prank(keeper);
        dm.depositToConsensusLayerWithAttestation(bufferId, rootHash, sigs, depositYs);

        assertEq(dm.getCommittedBalance(), 96 ether);
        assertEq(dm.getTotalDepositedETH(), 32 ether);
        assertEq(dm.lastFundedETH(5), 32 ether);
        assertEq(depositContract.deposit_count(), 1);
    }

    function testSuccessfulDeposit_depositRootAdvancesPerDeposit() public {
        // First batch
        IDepositDataBuffer.DepositObject[] memory batch1 = new IDepositDataBuffer.DepositObject[](1);
        batch1[0] = _makeDeposit(0, 100);

        (bytes32 bid1, bytes32 root1, bytes[] memory sigs1, BLS12_381.DepositY[] memory ys1) = _prepareDeposit(batch1);

        vm.prank(keeper);
        dm.depositToConsensusLayerWithAttestation(bid1, root1, sigs1, ys1);

        bytes32 rootAfterFirst = depositContract.get_deposit_root();
        assertTrue(rootAfterFirst != root1, "deposit root should change after deposit");

        // Second batch — must use updated root
        IDepositDataBuffer.DepositObject[] memory batch2 = new IDepositDataBuffer.DepositObject[](1);
        batch2[0] = _makeDeposit(1, 200);

        bytes32 bid2 = keccak256(abi.encode(batch2));
        buffer.submitDepositData(bid2, batch2);

        bytes32 root2 = depositContract.get_deposit_root();
        assertEq(root2, rootAfterFirst, "root hash should match current deposit contract state");

        bytes[] memory sigs2 = new bytes[](2);
        sigs2[0] = _signAttestation(attesterPk1, bid2, root2);
        sigs2[1] = _signAttestation(attesterPk2, bid2, root2);

        BLS12_381.DepositY[] memory ys2 = new BLS12_381.DepositY[](1);
        ys2[0] = _emptyDepositY();

        vm.prank(keeper);
        dm.depositToConsensusLayerWithAttestation(bid2, root2, sigs2, ys2);

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
        dm.depositToConsensusLayerWithAttestation(bytes32(0), bytes32(0), new bytes[](0), new BLS12_381.DepositY[](0));
    }

    function testRevert_zeroWithdrawalCredentials() public {
        // Deploy a fresh harness, init with valid WC, then zero it out via vm.store
        AttestationDepositHarness dm2 = new AttestationDepositHarness(admin);
        LibImplementationUnbricker.unbrick(vm, address(dm2));
        dm2.initialize(address(depositContract), withdrawalCredentials);
        dm2.sudoSetKeeper(keeper);

        // WithdrawalCredentials.set() rejects zero, so clear it directly
        bytes32 wcSlot = bytes32(uint256(keccak256("river.state.withdrawalCredentials")) - 1);
        vm.store(address(dm2), wcSlot, bytes32(0));

        vm.prank(keeper);
        vm.expectRevert(IConsensusLayerDepositManagerV1.InvalidWithdrawalCredentials.selector);
        dm2.depositToConsensusLayerWithAttestation(bytes32(0), bytes32(0), new bytes[](0), new BLS12_381.DepositY[](0));
    }

    function testRevert_insufficientAttestations() public {
        IDepositDataBuffer.DepositObject[] memory deposits = new IDepositDataBuffer.DepositObject[](1);
        deposits[0] = _makeDeposit(0, 0);

        bytes32 bufferId = keccak256(abi.encode(deposits));
        buffer.submitDepositData(bufferId, deposits);

        bytes32 rootHash = depositContract.get_deposit_root();

        // Only 1 signature but threshold is 2
        bytes[] memory sigs = new bytes[](1);
        sigs[0] = _signAttestation(attesterPk1, bufferId, rootHash);

        BLS12_381.DepositY[] memory depositYs = new BLS12_381.DepositY[](1);
        depositYs[0] = _emptyDepositY();

        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSelector(DepositToConsensusLayerValidation.InsufficientAttestations.selector, 1, 2)
        );
        dm.depositToConsensusLayerWithAttestation(bufferId, rootHash, sigs, depositYs);
    }

    function testRevert_staleDepositRoot() public {
        IDepositDataBuffer.DepositObject[] memory deposits = new IDepositDataBuffer.DepositObject[](1);
        deposits[0] = _makeDeposit(0, 0);

        bytes32 bufferId = keccak256(abi.encode(deposits));
        buffer.submitDepositData(bufferId, deposits);

        // Sign over a stale root that won't match the deposit contract
        bytes32 staleRoot = bytes32(uint256(0xDEAD));
        bytes[] memory sigs = new bytes[](2);
        sigs[0] = _signAttestation(attesterPk1, bufferId, staleRoot);
        sigs[1] = _signAttestation(attesterPk2, bufferId, staleRoot);

        BLS12_381.DepositY[] memory depositYs = new BLS12_381.DepositY[](1);
        depositYs[0] = _emptyDepositY();

        bytes32 actualRoot = depositContract.get_deposit_root();
        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSelector(
                DepositToConsensusLayerValidation.DepositRootMismatch.selector, staleRoot, actualRoot
            )
        );
        dm.depositToConsensusLayerWithAttestation(bufferId, staleRoot, sigs, depositYs);
    }

    function testRevert_withdrawalCredentialsMismatch() public {
        IDepositDataBuffer.DepositObject[] memory deposits = new IDepositDataBuffer.DepositObject[](1);
        deposits[0] = IDepositDataBuffer.DepositObject({
            pubkey: _fakePubkey(0),
            signature: _fakeSignature(0),
            amount: 32 ether,
            withdrawalCredentials: abi.encode(bytes32(uint256(0xDEAD))), // wrong WC
            depositDataRoot: bytes32(0),
            metadata: _operatorMetadata(0)
        });

        (bytes32 bufferId, bytes32 rootHash, bytes[] memory sigs, BLS12_381.DepositY[] memory depositYs) =
            _prepareDeposit(deposits);

        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSelector(
                IConsensusLayerDepositManagerV1.WithdrawalCredentialsMismatch.selector,
                0,
                withdrawalCredentials,
                bytes32(uint256(0xDEAD))
            )
        );
        dm.depositToConsensusLayerWithAttestation(bufferId, rootHash, sigs, depositYs);
    }

    function testRevert_notEnoughFunds() public {
        dm.sudoSetCommittedBalance(32 ether);

        IDepositDataBuffer.DepositObject[] memory deposits = new IDepositDataBuffer.DepositObject[](2);
        deposits[0] = _makeDeposit(0, 0);
        deposits[1] = _makeDeposit(0, 1);

        (bytes32 bufferId, bytes32 rootHash, bytes[] memory sigs, BLS12_381.DepositY[] memory depositYs) =
            _prepareDeposit(deposits);

        vm.prank(keeper);
        vm.expectRevert(IConsensusLayerDepositManagerV1.NotEnoughFunds.selector);
        dm.depositToConsensusLayerWithAttestation(bufferId, rootHash, sigs, depositYs);
    }

    function testRevert_duplicateAttesterSignatures() public {
        IDepositDataBuffer.DepositObject[] memory deposits = new IDepositDataBuffer.DepositObject[](1);
        deposits[0] = _makeDeposit(0, 0);

        bytes32 bufferId = keccak256(abi.encode(deposits));
        buffer.submitDepositData(bufferId, deposits);
        bytes32 rootHash = depositContract.get_deposit_root();

        // Two signatures from the same attester — should only count as 1
        bytes[] memory sigs = new bytes[](2);
        sigs[0] = _signAttestation(attesterPk1, bufferId, rootHash);
        sigs[1] = _signAttestation(attesterPk1, bufferId, rootHash);

        BLS12_381.DepositY[] memory depositYs = new BLS12_381.DepositY[](1);
        depositYs[0] = _emptyDepositY();

        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSelector(DepositToConsensusLayerValidation.InsufficientAttestations.selector, 1, 2)
        );
        dm.depositToConsensusLayerWithAttestation(bufferId, rootHash, sigs, depositYs);
    }

    function testRevert_nonAttesterSignature() public {
        IDepositDataBuffer.DepositObject[] memory deposits = new IDepositDataBuffer.DepositObject[](1);
        deposits[0] = _makeDeposit(0, 0);

        bytes32 bufferId = keccak256(abi.encode(deposits));
        buffer.submitDepositData(bufferId, deposits);
        bytes32 rootHash = depositContract.get_deposit_root();

        // One valid attester + one non-attester
        uint256 nonAttesterPk = 0xBAD;
        bytes[] memory sigs = new bytes[](2);
        sigs[0] = _signAttestation(attesterPk1, bufferId, rootHash);
        sigs[1] = _signAttestation(nonAttesterPk, bufferId, rootHash);

        BLS12_381.DepositY[] memory depositYs = new BLS12_381.DepositY[](1);
        depositYs[0] = _emptyDepositY();

        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSelector(DepositToConsensusLayerValidation.InsufficientAttestations.selector, 1, 2)
        );
        dm.depositToConsensusLayerWithAttestation(bufferId, rootHash, sigs, depositYs);
    }

    function testRevert_invalidOperatorMetadata() public {
        IDepositDataBuffer.DepositObject[] memory deposits = new IDepositDataBuffer.DepositObject[](1);
        deposits[0] = IDepositDataBuffer.DepositObject({
            pubkey: _fakePubkey(0),
            signature: _fakeSignature(0),
            amount: 32 ether,
            withdrawalCredentials: abi.encode(withdrawalCredentials),
            depositDataRoot: bytes32(0),
            metadata: bytes32("bad_metadata") // not "operator:N" format
        });

        (bytes32 bufferId, bytes32 rootHash, bytes[] memory sigs, BLS12_381.DepositY[] memory depositYs) =
            _prepareDeposit(deposits);

        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSelector(
                IConsensusLayerDepositManagerV1.InvalidOperatorMetadata.selector, bytes32("bad_metadata")
            )
        );
        dm.depositToConsensusLayerWithAttestation(bufferId, rootHash, sigs, depositYs);
    }

    // Regression test for the defense-in-depth bufferId check added to validate().
    // A malicious or buggy DepositDataBuffer may store (id, deposits) where
    // id != keccak256(abi.encode(deposits)). The on-chain validator must catch this
    // and revert with BufferIdMismatch so the attesters' signed commitment is
    // always binding on the deposits that are actually executed.
    function testRevert_bufferIdDoesNotMatchDeposits() public {
        // Build two distinct batches. We will register deposits_actual under
        // the id of deposits_signed, simulating a tampered/broken buffer.
        IDepositDataBuffer.DepositObject[] memory depositsSigned = new IDepositDataBuffer.DepositObject[](1);
        depositsSigned[0] = _makeDeposit(0, 1);

        IDepositDataBuffer.DepositObject[] memory depositsActual = new IDepositDataBuffer.DepositObject[](1);
        depositsActual[0] = _makeDeposit(0, 999); // different pubkey seed

        bytes32 signedId = keccak256(abi.encode(depositsSigned));
        bytes32 actualId = keccak256(abi.encode(depositsActual));
        assertTrue(signedId != actualId, "test precondition: the two batches must hash differently");

        // Malicious buffer: store `depositsActual` under `signedId`.
        buffer.submitDepositData(signedId, depositsActual);

        bytes32 rootHash = depositContract.get_deposit_root();
        bytes[] memory sigs = new bytes[](2);
        sigs[0] = _signAttestation(attesterPk1, signedId, rootHash);
        sigs[1] = _signAttestation(attesterPk2, signedId, rootHash);

        BLS12_381.DepositY[] memory depositYs = new BLS12_381.DepositY[](1);
        depositYs[0] = _emptyDepositY();

        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSelector(DepositToConsensusLayerValidation.BufferIdMismatch.selector, signedId, actualId)
        );
        dm.depositToConsensusLayerWithAttestation(signedId, rootHash, sigs, depositYs);
    }

    // An uninitialized cached EIP-712 domain separator must never be used — bytes32(0) would
    // let any signer produce a "valid" digest that ECDSA cannot tell apart from real ones.
    function testRevert_zeroDomainSeparator() public {
        bytes32 domainSepSlot = bytes32(uint256(keccak256("river.state.domainSeparator")) - 1);
        vm.store(address(dm), domainSepSlot, bytes32(0));

        IDepositDataBuffer.DepositObject[] memory deposits = new IDepositDataBuffer.DepositObject[](1);
        deposits[0] = _makeDeposit(0, 0);
        (bytes32 bufferId, bytes32 rootHash, bytes[] memory sigs, BLS12_381.DepositY[] memory depositYs) =
            _prepareDeposit(deposits);

        vm.prank(keeper);
        vm.expectRevert(DepositToConsensusLayerValidation.ZeroDomainSeparator.selector);
        dm.depositToConsensusLayerWithAttestation(bufferId, rootHash, sigs, depositYs);
    }

    // An uninitialized BLS deposit domain must never reach the pairing check — bytes32(0) is
    // a valid-looking domain the attackers could sign against if the guard were missing.
    function testRevert_zeroDepositDomain() public {
        // Un-mock verifyBLSDeposit so the real guard inside the function body runs.
        vm.clearMockedCalls();
        dm.sudoSetDepositDomain(bytes32(0));

        bytes memory pk = _fakePubkey(0);
        bytes memory sig = _fakeSignature(0);
        BLS12_381.DepositY memory dy = _emptyDepositY();

        vm.expectRevert(DepositToConsensusLayerValidation.ZeroDepositDomain.selector);
        dm.verifyBLSDeposit(pk, sig, 32 ether, dy, withdrawalCredentials);
    }

    // setAttester must reject calls that would leave the attester's status unchanged so the
    // admin cannot silently no-op when intending to flip a flag.
    function testRevert_setAttesterStatusUnchanged() public {
        // attester1 was registered in setUp(); re-adding must revert
        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(DepositToConsensusLayerValidation.AttesterStatusUnchanged.selector, attester1, true)
        );
        dm.setAttester(attester1, true);

        // an unregistered address being removed must also revert
        address stranger = address(0xDEAD);
        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(DepositToConsensusLayerValidation.AttesterStatusUnchanged.selector, stranger, false)
        );
        dm.setAttester(stranger, false);
    }
}
