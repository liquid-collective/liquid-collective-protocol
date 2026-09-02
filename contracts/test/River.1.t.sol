//SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.34;

import "forge-std/Test.sol";

import "./OperatorAllocationTestBase.sol";
import "./utils/UserFactory.sol";
import "./utils/BytesGenerator.sol";
import "./utils/LibImplementationUnbricker.sol";
import "./utils/RiverV1WithLegacyInit.sol";
import "./mocks/DepositContractMock.sol";

import "../src/libraries/LibAllowlistMasks.sol";
import "../src/libraries/BLS12_381.sol";
import "../src/Allowlist.1.sol";
import "../src/AttestationVerifier.1.sol";
import "../src/River.1.sol";
import "../src/state/river/LastConsensusLayerReport.sol";
import "../src/interfaces/components/IOracleManager.1.sol";
import "../src/interfaces/IRiver.1.sol";
import "../src/interfaces/IDepositContract.sol";
import "../src/interfaces/components/IConsensusLayerDepositManager.1.sol";
import "../src/interfaces/IDepositDataBuffer.sol";
import "../src/Withdraw.1.sol";
import "../src/interfaces/IWithdraw.1.sol";
import "../src/Oracle.1.sol";
import "../src/ELFeeRecipient.1.sol";
import "../src/OperatorsRegistry.1.sol";
import "../src/CoverageFund.1.sol";
import "../src/ConsolidationCoverageFund.1.sol";
import "../src/ExternalConsolidationRecipientMapping.1.sol";
import "../src/RedeemManager.1.sol";

import "./utils/LegacyInit.sol";

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

contract OperatorsRegistryWithOverridesV1 is OperatorsRegistryV1WithLegacyInit {
    function sudoReportExitedETH(uint256[] calldata exitedETH) external {
        _setExitedETH(exitedETH);
    }

    function sudoSetFunded(uint256 _index, uint256 _funded) external {
        OperatorsV3.Operator storage operator = OperatorsV3.get(_index);
        operator.funded = _funded * 32 ether;
    }

    function sudoSetRawExitedETH(uint256[] memory value) external {
        OperatorsV3.setRawExitedETH(value);
    }

    function sudoSetActiveCLETH(uint256 _index, uint256 _activeCLETH) external {
        OperatorsV3.Operator storage op = OperatorsV3.get(_index);
        op.activeCLETH = _activeCLETH;
    }

    function sudoSetRequestedExits(uint256 _index, uint256 _requestedExits) external {
        OperatorsV3.Operator storage op = OperatorsV3.get(_index);
        op.requestedExits = _requestedExits;
    }
}

// OperatorsRegistryWithOverridesV1 removed: _setStoppedValidatorCounts no longer exists

contract RiverV1ForceCommittable is RiverV1WithLegacyInit {
    function debug_moveDepositToCommitted() external {
        _setCommittedBalance(CommittedBalance.get() + BalanceToDeposit.get());
        _setBalanceToDeposit(0);
    }

    function sudoSetSlashingContainmentMode(bool _enabled) external {
        IOracleManagerV1.StoredConsensusLayerReport storage report = LastConsensusLayerReport.get();
        report.slashingContainmentMode = _enabled;
    }

    function sudoSetValidatorsBalance(uint256 _validatorsBalance) external {
        IOracleManagerV1.StoredConsensusLayerReport storage report = LastConsensusLayerReport.get();
        report.validatorsBalance = _validatorsBalance;
    }
}

abstract contract RiverV1TestBase is OperatorAllocationTestBase, BytesGenerator {
    UserFactory internal uf = new UserFactory();

    RiverV1ForceCommittable internal river;
    IDepositContract internal deposit;
    WithdrawV1WithLegacyInit internal withdraw;
    OracleV1WithLegacyInit internal oracle;
    ELFeeRecipientV1WithLegacyInit internal elFeeRecipient;
    CoverageFundV1WithLegacyInit internal coverageFund;
    ConsolidationCoverageFundV1 internal consolidationCoverageFund;
    ExternalConsolidationRecipientMappingV1 internal externalConsolidationRecipientMapping;
    AllowlistV1WithLegacyInit internal allowlist;
    OperatorsRegistryWithOverridesV1 internal operatorsRegistry;

    MockDepositDataBuffer internal depositBuffer;
    AttestationVerifierV1 internal attestationVerifier;

    uint256 internal consolidationCommitteeAttesterPk1 = 0xC1;
    uint256 internal consolidationCommitteeAttesterPk2 = 0xC2;
    address internal consolidationCommitteeAttester1;
    address internal consolidationCommitteeAttester2;
    uint256 internal rootAttesterPk1 = 0xA1;
    uint256 internal rootAttesterPk2 = 0xA2;
    uint256 internal rootAttesterPk3 = 0xA3;
    address internal rootAttester1;
    address internal rootAttester2;
    address internal rootAttester3;

    // EIP-712 constants (must match DepositToConsensusLayerValidation)
    bytes32 internal constant EIP712_DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 internal constant NAME_HASH = keccak256("DepositToConsensusLayerValidation");
    bytes32 internal constant VERSION_HASH = keccak256("1");
    bytes32 internal constant ATTEST_TYPEHASH =
        keccak256("Attest(bytes32 depositDataBufferId,bytes32 depositRootHash)");
    bytes32 internal constant CONSOLIDATION_NAME_HASH = keccak256("ConsolidationValidation");
    bytes32 internal constant ATTEST_CONSOLIDATION_TYPEHASH = keccak256(
        "AttestConsolidation(address withdrawalAddress,bytes[] sourcePubkeys,bytes[] targetPubkeys,uint256 totalAmount)"
    );

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
    address internal keeper;
    address internal consolidator;

    string internal operatorOneName = "NodeMasters";
    string internal operatorTwoName = "StakePros";

    uint256 internal operatorOneIndex;
    uint256 internal operatorTwoIndex;
    uint256 internal _pubkeySeedCursor;

    event PulledELFees(uint256 amount);
    event SetELFeeRecipient(address indexed elFeeRecipient);
    event SetCollector(address indexed collector);
    event SetCoverageFund(address indexed coverageFund);
    event SetConsolidationCoverageFund(address indexed consolidationCoverageFund);
    event SetAllowlist(address indexed allowlist);
    event SetGlobalFee(uint256 fee);
    event SetOperatorsRegistry(address indexed operatorsRegistry);
    event SetKeeper(address indexed keeper);
    event SetConsolidator(address indexed consolidator);

    uint64 constant epochsPerFrame = 225;
    uint64 constant slotsPerEpoch = 32;
    uint64 constant secondsPerSlot = 12;
    uint64 constant epochsUntilFinal = 4;

    uint128 constant maxDailyNetCommittableAmount = 3200 ether;
    uint128 constant maxDailyRelativeCommittableAmount = 2000;

    function _emptyDepositY() internal pure returns (BLS12_381.DepositY memory) {
        return BLS12_381.DepositY({
            pubkeyY: BLS12_381.Fp({a: bytes32(0), b: bytes32(0)}),
            signatureY: BLS12_381.Fp2({c0_a: bytes32(0), c0_b: bytes32(0), c1_a: bytes32(0), c1_b: bytes32(0)})
        });
    }

    /// @dev Non-zero placeholder DepositY for initial deposits. BLS is mocked in these tests,
    ///      so the value only needs to differ from the zero sentinel used for top-ups.
    function _nonZeroDepositY(uint256 seed) internal pure returns (BLS12_381.DepositY memory) {
        return BLS12_381.DepositY({
            pubkeyY: BLS12_381.Fp({a: bytes32(uint256(seed) + 1), b: bytes32(0)}),
            signatureY: BLS12_381.Fp2({c0_a: bytes32(0), c0_b: bytes32(0), c1_a: bytes32(0), c1_b: bytes32(0)})
        });
    }

    bytes32 constant withdrawalCredentials = 0x0200000000000000000000000000000000000000000000000000000000000000;

    function setUp() public virtual {
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
        keeper = makeAddr("keeper");
        consolidator = makeAddr("consolidator");
        consolidationCommitteeAttester1 = vm.addr(consolidationCommitteeAttesterPk1);
        consolidationCommitteeAttester2 = vm.addr(consolidationCommitteeAttesterPk2);
        rootAttester1 = vm.addr(rootAttesterPk1);
        rootAttester2 = vm.addr(rootAttesterPk2);
        rootAttester3 = vm.addr(rootAttesterPk3);

        vm.warp(857034746);

        elFeeRecipient = new ELFeeRecipientV1WithLegacyInit();
        LibImplementationUnbricker.unbrick(vm, address(elFeeRecipient));
        coverageFund = new CoverageFundV1WithLegacyInit();
        LibImplementationUnbricker.unbrick(vm, address(coverageFund));
        consolidationCoverageFund = new ConsolidationCoverageFundV1();
        LibImplementationUnbricker.unbrick(vm, address(consolidationCoverageFund));
        externalConsolidationRecipientMapping = new ExternalConsolidationRecipientMappingV1();
        LibImplementationUnbricker.unbrick(vm, address(externalConsolidationRecipientMapping));
        oracle = new OracleV1WithLegacyInit();
        LibImplementationUnbricker.unbrick(vm, address(oracle));
        allowlist = new AllowlistV1WithLegacyInit();
        LibImplementationUnbricker.unbrick(vm, address(allowlist));
        deposit = new DepositContractMock();
        LibImplementationUnbricker.unbrick(vm, address(deposit));
        withdraw = new WithdrawV1WithLegacyInit();
        LibImplementationUnbricker.unbrick(vm, address(withdraw));
        river = new RiverV1ForceCommittable();
        LibImplementationUnbricker.unbrick(vm, address(river));
        operatorsRegistry = new OperatorsRegistryWithOverridesV1();
        LibImplementationUnbricker.unbrick(vm, address(operatorsRegistry));
        depositBuffer = new MockDepositDataBuffer();

        allowlist.initAllowlistV1(admin, allower);
        allowlist.initAllowlistV1_1(denier);
        operatorsRegistry.initOperatorsRegistryV1(admin, address(river));
        elFeeRecipient.initELFeeRecipientV1(address(river));
        coverageFund.initCoverageFundV1(address(river));
        consolidationCoverageFund.initConsolidationCoverageFundV1(address(river));
        externalConsolidationRecipientMapping.initExternalConsolidationRecipientMappingV1(address(river));
    }

    // -----------------------------------------------------------------------
    // Attestation-based deposit helpers
    // -----------------------------------------------------------------------

    /// @dev Sign an EIP-712 attestation digest with the given private key.
    function _signAttestation(uint256 pk, bytes32 bufferId, bytes32 rootHash) internal view returns (bytes memory) {
        bytes32 domainSep =
            keccak256(abi.encode(EIP712_DOMAIN_TYPEHASH, NAME_HASH, VERSION_HASH, block.chainid, address(river)));
        bytes32 structHash = keccak256(abi.encode(ATTEST_TYPEHASH, bufferId, rootHash));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSep, structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
        return abi.encodePacked(r, s, v);
    }

    /// @dev Generate a deterministic 48-byte pubkey.
    function _fakePubkey(uint256 seed) internal pure returns (bytes memory) {
        return abi.encodePacked(sha256(abi.encode("pubkey", seed)), bytes16(0));
    }

    /// @dev Generate a deterministic 96-byte signature.
    function _fakeSignature(uint256 seed) internal pure returns (bytes memory) {
        return abi.encodePacked(sha256(abi.encode("sig", seed)), sha256(abi.encode("sig2", seed)), bytes32(0));
    }

    function _hashBytesArray(bytes[] memory arr) internal pure returns (bytes32) {
        bytes32[] memory hashes = new bytes32[](arr.length);
        for (uint256 i = 0; i < arr.length; i++) {
            hashes[i] = keccak256(arr[i]);
        }
        return keccak256(abi.encodePacked(hashes));
    }

    function _consolidationDigest(
        address withdrawalAddress,
        bytes[] memory sources,
        bytes[] memory targets,
        uint256 totalAmount
    ) internal view returns (bytes32) {
        bytes32 domainSep = keccak256(
            abi.encode(EIP712_DOMAIN_TYPEHASH, CONSOLIDATION_NAME_HASH, VERSION_HASH, block.chainid, address(river))
        );
        bytes32 structHash = keccak256(
            abi.encode(
                ATTEST_CONSOLIDATION_TYPEHASH,
                withdrawalAddress,
                _hashBytesArray(sources),
                _hashBytesArray(targets),
                totalAmount
            )
        );
        return keccak256(abi.encodePacked("\x19\x01", domainSep, structHash));
    }

    function _signConsolidation(uint256 pk, bytes32 digest) internal view returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
        return abi.encodePacked(r, s, v);
    }

    function _buildConsolidation(address withdrawalAddress, uint256 totalAmount, uint256 seed)
        internal
        view
        returns (IAttestationVerifierV1.ConsolidationObject memory consolidation)
    {
        bytes[] memory sources = new bytes[](1);
        sources[0] = _fakePubkey(seed);
        bytes[] memory targets = new bytes[](1);
        targets[0] = _fakePubkey(seed + 1000);
        bytes32 digest = _consolidationDigest(withdrawalAddress, sources, targets, totalAmount);

        bytes[] memory sigs = new bytes[](2);
        sigs[0] = _signConsolidation(consolidationCommitteeAttesterPk1, digest);
        sigs[1] = _signConsolidation(consolidationCommitteeAttesterPk2, digest);

        consolidation = IAttestationVerifierV1.ConsolidationObject({
            withdrawalAddress: withdrawalAddress,
            sourcePubkeys: sources,
            targetPubkeys: targets,
            totalAmount: totalAmount,
            signatures: sigs
        });
    }

    function _allowConsolidation(address _who) internal {
        address[] memory allowees = new address[](1);
        allowees[0] = _who;
        uint256[] memory permissions = new uint256[](1);
        permissions[0] = LibAllowlistMasks.CONSOLIDATE_MASK;

        vm.prank(allower);
        allowlist.setAllowPermissions(allowees, permissions);
    }

    function _denyAccount(address _who) internal {
        address[] memory toBeDenied = new address[](1);
        toBeDenied[0] = _who;
        uint256[] memory permissions = new uint256[](1);
        permissions[0] = LibAllowlistMasks.DENY_MASK;

        vm.prank(denier);
        allowlist.setDenyPermissions(toBeDenied, permissions);
    }

    /// @dev Replacement for the old depositToConsensusLayerWithDepositRoot.
    ///      Builds deposit objects, submits to buffer, signs, and calls new function.
    function _depositToConsensusLayer(uint256[] memory opIndices, uint32[] memory counts) internal {
        bytes32 wc = river.getWithdrawalCredentials();

        // Count total deposits
        uint256 total = 0;
        for (uint256 i = 0; i < counts.length; i++) {
            total += counts[i];
        }

        // Build deposit objects. Seed pubkeys/signatures off the contract-level cursor so
        // repeated invocations within the same test produce a fresh bufferId.
        IDepositDataBuffer.DepositObject memory batch;
        batch.deposits = new IDepositDataBuffer.Deposit[](total);
        // batch.topUps is left as a default empty array.
        uint256 idx = 0;
        uint256 seedBase = _pubkeySeedCursor;
        for (uint256 i = 0; i < opIndices.length; i++) {
            for (uint256 j = 0; j < counts[i]; j++) {
                uint256 seed = seedBase + idx;
                batch.deposits[idx] = IDepositDataBuffer.Deposit({
                    pubkey: _fakePubkey(seed),
                    signature: _fakeSignature(seed),
                    amount: 32 ether,
                    operatorIdx: opIndices[i],
                    depositY: _nonZeroDepositY(seed)
                });
                idx++;
            }
        }
        _pubkeySeedCursor = seedBase + total;

        bytes32 bufferId = keccak256(abi.encode(batch));
        depositBuffer.submitDepositData(bufferId, batch);

        bytes32 rootHash = deposit.get_deposit_root();

        bytes[] memory sigs = new bytes[](2);
        sigs[0] = _signAttestation(rootAttesterPk1, bufferId, rootHash);
        sigs[1] = _signAttestation(rootAttesterPk2, bufferId, rootHash);

        // The new function requires keeper, not admin
        address currentKeeper = river.getKeeper();
        vm.prank(currentKeeper);
        river.depositToConsensusLayerWithAttestation(bufferId, rootHash, sigs);
    }

    /// @dev Single-operator convenience overload.
    function _depositToConsensusLayer(uint256 opIndex, uint32 count) internal {
        uint256[] memory idx = new uint256[](1);
        idx[0] = opIndex;
        uint32[] memory cnt = new uint32[](1);
        cnt[0] = count;
        _depositToConsensusLayer(idx, cnt);
    }

    /// @dev Build attestation deposit args for a single-operator, single-deposit batch.
    ///      Returns args ready to pass into river.depositToConsensusLayerWithAttestation
    ///      so the caller can place vm.expectRevert immediately before that call.
    function _buildSingleDepositArgs(uint256 opIndex)
        internal
        returns (bytes32 bufferId, bytes32 rootHash, bytes[] memory sigs)
    {
        IDepositDataBuffer.DepositObject memory batch;
        batch.deposits = new IDepositDataBuffer.Deposit[](1);
        uint256 seed = _pubkeySeedCursor;
        batch.deposits[0] = IDepositDataBuffer.Deposit({
            pubkey: _fakePubkey(seed),
            signature: _fakeSignature(seed),
            amount: 32 ether,
            operatorIdx: opIndex,
            depositY: _nonZeroDepositY(seed)
        });
        _pubkeySeedCursor = seed + 1;

        bufferId = keccak256(abi.encode(batch));
        depositBuffer.submitDepositData(bufferId, batch);
        rootHash = deposit.get_deposit_root();

        sigs = new bytes[](2);
        sigs[0] = _signAttestation(rootAttesterPk1, bufferId, rootHash);
        sigs[1] = _signAttestation(rootAttesterPk2, bufferId, rootHash);
    }
}

contract RiverV1InitializationTests is RiverV1TestBase {
    function testInitialization() public {
        bytes32 withdrawalCredentials = withdraw.getCredentials();
        vm.expectEmit(true, true, true, true);
        emit SetCollector(collector);
        vm.expectEmit(true, true, true, true);
        emit SetGlobalFee(500);
        vm.expectEmit(true, true, true, true);
        emit SetELFeeRecipient(address(elFeeRecipient));
        vm.expectEmit(true, true, true, true);
        emit SetAllowlist(address(allowlist));
        vm.expectEmit(true, true, true, true);
        emit SetOperatorsRegistry(address(operatorsRegistry));
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
    }
}

contract RiverV1Tests is RiverV1TestBase {
    bytes32 constant CONSOLIDATOR_ADDRESS_SLOT = bytes32(uint256(keccak256("river.state.consolidatorAddress")) - 1);

    function setUp() public override {
        super.setUp();
        bytes32 withdrawalCredentials = withdraw.getCredentials();
        vm.expectEmit(true, true, true, true);
        emit SetOperatorsRegistry(address(operatorsRegistry));
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
        river.setKeeper(keeper);
        oracle.addMember(oracleMember, 1);
        // ===================

        operatorOneIndex = operatorsRegistry.addOperator(operatorOneName, operatorOne);
        operatorTwoIndex = operatorsRegistry.addOperator(operatorTwoName, operatorTwo);

        vm.stopPrank();

        // Deploy + initialize the AttestationVerifier sibling. The validator's EIP-712
        // domain separator binds verifyingContract to River's address.
        address[] memory _initRootAttesters = new address[](3);
        _initRootAttesters[0] = rootAttester1;
        _initRootAttesters[1] = rootAttester2;
        _initRootAttesters[2] = rootAttester3;
        address[] memory _initConsolidationCommitteeAttesters = new address[](1);
        _initConsolidationCommitteeAttesters[0] = makeAddr("consolidationCommitteeAttesterStub");
        attestationVerifier = new AttestationVerifierV1();
        LibImplementationUnbricker.unbrick(vm, address(attestationVerifier));
        attestationVerifier.initAttestationVerifierV1(
            address(river),
            address(depositBuffer),
            _initRootAttesters,
            2,
            bytes4(0),
            _initConsolidationCommitteeAttesters,
            1
        );
        // Wire validator address into River's storage (these tests skip initRiverV1_3
        // because they don't require the V1_3 accounting migration).
        vm.store(
            address(river),
            bytes32(uint256(keccak256("river.state.attestationVerifierAddress")) - 1),
            bytes32(uint256(uint160(address(attestationVerifier))))
        );

        // Mock BLS verification on the validator (EIP-2537 precompiles not enabled in Foundry).
        vm.mockCall(
            address(attestationVerifier),
            abi.encodeWithSelector(attestationVerifier.verifyBLSDeposit.selector),
            bytes("")
        );

        // Pre-initialize the exited ETH array so _setExitedETH can safely access per-operator slots.
        uint256 opCount = operatorsRegistry.getOperatorCount();
        operatorsRegistry.sudoSetRawExitedETH(new uint256[](opCount + 1));
    }

    function testVersion() external {
        assertEq(river.version(), "1.3.0");
    }

    function testOnlyAdminCanSetKeeper() public {
        assert(river.getKeeper() == keeper);
        vm.prank(admin);
        vm.expectEmit(true, true, true, true);
        emit SetKeeper(admin);
        river.setKeeper(admin);
        assert(river.getKeeper() == admin);

        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", address(this)));
        river.setKeeper(address(0));
    }

    function testSetKeeperViaInterface() public {
        vm.prank(admin);
        IRiverV1(payable(address(river))).setKeeper(keeper);
        assert(river.getKeeper() == keeper);
    }

    function testOnlyAdminCanSetConsolidator() public {
        address newConsolidator = makeAddr("newConsolidator");
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", bob));
        river.setConsolidator(newConsolidator);

        assertEq(_storedConsolidator(), address(0));
        assertEq(river.getConsolidator(), address(0));
    }

    function testSetConsolidatorZero() public {
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSignature("InvalidZeroAddress()"));
        river.setConsolidator(address(0));
    }

    function testSetConsolidatorEmitsAndStores() public {
        vm.prank(admin);
        vm.expectEmit(true, true, true, true);
        emit SetConsolidator(consolidator);
        river.setConsolidator(consolidator);

        assertEq(_storedConsolidator(), consolidator);
        assertEq(river.getConsolidator(), consolidator);
    }

    function testSetConsolidatorRotation() public {
        address newConsolidator = makeAddr("newConsolidator");

        vm.startPrank(admin);
        river.setConsolidator(consolidator);
        assertEq(_storedConsolidator(), consolidator);
        assertEq(river.getConsolidator(), consolidator);

        vm.expectEmit(true, true, true, true);
        emit SetConsolidator(newConsolidator);
        river.setConsolidator(newConsolidator);
        vm.stopPrank();

        assertEq(_storedConsolidator(), newConsolidator);
        assertEq(river.getConsolidator(), newConsolidator);
    }

    function _storedConsolidator() internal view returns (address) {
        return address(uint160(uint256(vm.load(address(river), CONSOLIDATOR_ADDRESS_SLOT))));
    }

    function testInit2(uint128 depositTotal, uint96 committedBalance) public {
        vm.assume(depositTotal > committedBalance && committedBalance > 0);
        RedeemManagerV1WithLegacyInit redeemManager;
        redeemManager = new RedeemManagerV1WithLegacyInit();
        LibImplementationUnbricker.unbrick(vm, address(redeemManager));
        redeemManager.initializeRedeemManagerV1(address(river));

        river.initRiverV1_1(
            address(redeemManager),
            epochsPerFrame,
            slotsPerEpoch,
            secondsPerSlot,
            0,
            epochsUntilFinal,
            1000,
            500,
            maxDailyNetCommittableAmount,
            maxDailyRelativeCommittableAmount
        );
        _allow(joe);
        vm.deal(joe, depositTotal);
        vm.prank(joe);
        river.deposit{value: committedBalance}();
        river.debug_moveDepositToCommitted();
        vm.prank(joe);
        river.deposit{value: depositTotal - committedBalance}();
        IConsensusLayerDepositManagerV1 castedRiver = IConsensusLayerDepositManagerV1(address(river));
        uint256 balanceBefore = castedRiver.getBalanceToDeposit();
        uint256 committedBefore = castedRiver.getCommittedBalance();
        uint256 dust = committedBefore % 32 ether;

        river.initRiverV1_2();

        uint256 balanceAfter = castedRiver.getBalanceToDeposit();
        uint256 committedAfter = castedRiver.getCommittedBalance();
        assertEq(balanceBefore + dust, balanceAfter);
        assertEq(committedBefore - dust, committedAfter);
        assertEq(committedAfter % 32 ether, 0);
    }

    event SetMaxDailyCommittableAmounts(uint256 maxNetAmount, uint256 maxRelativeAmount);

    function testSetDailyCommittableLimits(uint128 net, uint128 relative) public {
        DailyCommittableLimits.DailyCommittableLimitsStruct memory dcl =
            DailyCommittableLimits.DailyCommittableLimitsStruct({
                maxDailyRelativeCommittableAmount: relative, minDailyNetCommittableAmount: net
            });
        vm.prank(admin);
        vm.expectEmit(true, true, true, true);
        emit SetMaxDailyCommittableAmounts(net, relative);
        river.setDailyCommittableLimits(dcl);

        dcl = river.getDailyCommittableLimits();

        assertEq(dcl.minDailyNetCommittableAmount, net);
        assertEq(dcl.maxDailyRelativeCommittableAmount, relative);
    }

    function testSetDailyCommittableLimitsUnauthorized(uint128 net, uint128 relative) public {
        DailyCommittableLimits.DailyCommittableLimitsStruct memory dcl =
            DailyCommittableLimits.DailyCommittableLimitsStruct({
                maxDailyRelativeCommittableAmount: relative, minDailyNetCommittableAmount: net
            });
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", address(this)));
        river.setDailyCommittableLimits(dcl);
    }

    function testSetELFeeRecipient(uint256 _newELFeeRecipientSalt) public {
        address newELFeeRecipient = uf._new(_newELFeeRecipientSalt);
        vm.startPrank(admin);
        assert(river.getELFeeRecipient() == address(elFeeRecipient));
        vm.expectEmit(true, true, true, true);
        emit SetELFeeRecipient(newELFeeRecipient);
        river.setELFeeRecipient(newELFeeRecipient);
        assert(river.getELFeeRecipient() == newELFeeRecipient);
        vm.stopPrank();
    }

    function testSetELFeeRecipientUnauthorized(uint256 _newELFeeRecipientSalt) public {
        address newELFeeRecipient = uf._new(_newELFeeRecipientSalt);
        assert(river.getELFeeRecipient() == address(elFeeRecipient));
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", address(this)));
        river.setELFeeRecipient(newELFeeRecipient);
    }

    function testSendCLFunds(uint256 amount) public {
        vm.deal(address(withdraw), amount);

        assertEq(address(river).balance, 0);
        assertEq(address(withdraw).balance, amount);

        vm.prank(address(withdraw));
        river.sendCLFunds{value: amount}();

        assertEq(address(river).balance, amount);
        assertEq(address(withdraw).balance, 0);
    }

    function testSendCLFundsUnauthorized(uint256 _invalidAddressSalt) public {
        address invalidAddress = uf._new(_invalidAddressSalt);
        vm.startPrank(invalidAddress);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", invalidAddress));
        river.sendCLFunds();
        vm.stopPrank();
    }

    function testSendELFundsUnauthorized(uint256 _invalidAddressSalt) public {
        address invalidAddress = uf._new(_invalidAddressSalt);
        vm.startPrank(invalidAddress);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", invalidAddress));
        river.sendELFees();
        vm.stopPrank();
    }

    function testSetELFeeRecipientZero() public {
        vm.startPrank(admin);
        assert(river.getELFeeRecipient() == address(elFeeRecipient));
        vm.expectRevert(abi.encodeWithSignature("InvalidZeroAddress()"));
        river.setELFeeRecipient(address(0));
        vm.stopPrank();
    }

    function testSetCoverageFund(uint256 _newCoverageFundSalt) public {
        address newCoverageFund = uf._new(_newCoverageFundSalt);
        vm.startPrank(admin);
        assert(river.getCoverageFund() == address(coverageFund));
        vm.expectEmit(true, true, true, true);
        emit SetCoverageFund(newCoverageFund);
        river.setCoverageFund(newCoverageFund);
        assert(river.getCoverageFund() == newCoverageFund);
        vm.stopPrank();
    }

    function testSetCoverageFundUnauthorized(uint256 _newCoverageFundSalt) public {
        address newCoverageFund = uf._new(_newCoverageFundSalt);
        assert(river.getCoverageFund() == address(coverageFund));
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", address(this)));
        river.setCoverageFund(newCoverageFund);
    }

    function testSetCoverageFundZero() public {
        vm.startPrank(admin);
        assert(river.getCoverageFund() == address(coverageFund));
        vm.expectRevert(abi.encodeWithSignature("InvalidZeroAddress()"));
        river.setCoverageFund(address(0));
    }

    function testSetConsolidationCoverageFund(uint256 _newConsolidationCoverageFundSalt) public {
        address newConsolidationCoverageFund = uf._new(_newConsolidationCoverageFundSalt);
        vm.startPrank(admin);
        river.setConsolidationCoverageFund(address(consolidationCoverageFund));
        assert(river.getConsolidationCoverageFund() == address(consolidationCoverageFund));
        vm.expectEmit(true, true, true, true);
        emit SetConsolidationCoverageFund(newConsolidationCoverageFund);
        river.setConsolidationCoverageFund(newConsolidationCoverageFund);
        assert(river.getConsolidationCoverageFund() == newConsolidationCoverageFund);
        vm.stopPrank();
    }

    function testSetConsolidationCoverageFundUnauthorized(uint256 _newConsolidationCoverageFundSalt) public {
        address newConsolidationCoverageFund = uf._new(_newConsolidationCoverageFundSalt);
        vm.startPrank(admin);
        river.setConsolidationCoverageFund(address(consolidationCoverageFund));
        vm.stopPrank();
        assert(river.getConsolidationCoverageFund() == address(consolidationCoverageFund));
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", address(this)));
        river.setConsolidationCoverageFund(newConsolidationCoverageFund);
    }

    function testSetConsolidationCoverageFundZero() public {
        vm.startPrank(admin);
        vm.expectRevert(abi.encodeWithSignature("InvalidZeroAddress()"));
        river.setConsolidationCoverageFund(address(0));
        vm.stopPrank();
    }

    function testSendConsolidationCoverageFundsUnauthorized(uint256 _invalidAddressSalt) public {
        address invalidAddress = uf._new(_invalidAddressSalt);
        vm.startPrank(admin);
        river.setConsolidationCoverageFund(address(consolidationCoverageFund));
        vm.stopPrank();
        vm.startPrank(invalidAddress);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", invalidAddress));
        river.sendConsolidationCoverageFunds();
        vm.stopPrank();
    }

    function testSendCoverageFundsUnauthorized(uint256 _invalidAddressSalt) public {
        address invalidAddress = uf._new(_invalidAddressSalt);
        vm.startPrank(invalidAddress);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", invalidAddress));
        river.sendCoverageFunds();
        vm.stopPrank();
    }

    function testGetOperatorsRegistry() public view {
        assert(river.getOperatorsRegistry() == address(operatorsRegistry));
    }

    function testSetCollector() public {
        vm.startPrank(admin);
        assert(river.getCollector() == collector);
        vm.expectEmit(true, true, true, true);
        emit SetCollector(newCollector);
        river.setCollector(newCollector);
        assert(river.getCollector() == newCollector);
        vm.stopPrank();
    }

    function testSetCollectorUnauthorized() public {
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", address(this)));
        river.setCollector(newCollector);
    }

    function testSetAllowlist() public {
        vm.startPrank(admin);
        assert(river.getAllowlist() == address(allowlist));
        vm.expectEmit(true, true, true, true);
        emit SetAllowlist(newAllowlist);
        river.setAllowlist(newAllowlist);
        assert(river.getAllowlist() == newAllowlist);
        vm.stopPrank();
    }

    function testSetAllowlistUnauthorized() public {
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", address(this)));
        river.setAllowlist(newAllowlist);
    }

    function testSetGlobalFee() public {
        vm.startPrank(admin);
        vm.expectEmit(true, true, true, true);
        emit SetGlobalFee(5000);
        river.setGlobalFee(5000);
        vm.stopPrank();
        assert(river.getGlobalFee() == 5000);
    }

    function testSetGlobalFeeHigherThanBase() public {
        vm.startPrank(admin);
        vm.expectRevert(abi.encodeWithSignature("InvalidFee()"));
        river.setGlobalFee(100001);
        vm.stopPrank();
    }

    function testSetGlobalFeeUnauthorized() public {
        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", bob));
        river.setGlobalFee(5000);
        vm.stopPrank();
    }

    function testGetAdministrator() public {
        vm.startPrank(bob);
        assert(river.getAdmin() == admin);
        vm.stopPrank();
    }

    event SetMetadataURI(string metadataURI);

    function testSetMetadataURI(string memory _metadataURI) public {
        vm.assume(bytes(_metadataURI).length > 0);
        vm.startPrank(admin);
        assertEq(river.getMetadataURI(), "");
        vm.expectEmit(true, true, true, true);
        emit SetMetadataURI(_metadataURI);
        river.setMetadataURI(_metadataURI);
        assertEq(river.getMetadataURI(), _metadataURI);
        vm.stopPrank();
    }

    function testSetMetadataURIEmpty() public {
        vm.startPrank(admin);
        vm.expectRevert(abi.encodeWithSignature("InvalidEmptyString()"));
        river.setMetadataURI("");
        vm.stopPrank();
    }

    function testSetMetadataURIUnauthorized(string memory _metadataURI, uint256 _salt) public {
        address unauthorized = uf._new(_salt);
        vm.prank(unauthorized);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", unauthorized));
        river.setMetadataURI(_metadataURI);
    }

    function _rawPermissions(address _who, uint256 _mask) internal {
        address[] memory allowees = new address[](1);
        allowees[0] = _who;
        uint256[] memory statuses = new uint256[](1);
        statuses[0] = _mask;

        vm.startPrank(allower);
        allowlist.setAllowPermissions(allowees, statuses);
        vm.stopPrank();
    }

    function _allow(address _who) internal {
        address[] memory allowees = new address[](1);
        allowees[0] = _who;
        uint256[] memory permissions = new uint256[](1);
        permissions[0] = LibAllowlistMasks.REDEEM_MASK | LibAllowlistMasks.DEPOSIT_MASK;

        vm.startPrank(allower);
        allowlist.setAllowPermissions(allowees, permissions);
        vm.stopPrank();
    }

    function _deny(address _who, bool _status) internal {
        address[] memory toBeDenied = new address[](1);
        toBeDenied[0] = _who;
        uint256[] memory permissions = new uint256[](1);
        permissions[0] = _status ? LibAllowlistMasks.DENY_MASK : 0;
        allowlist.getDenier();
        vm.startPrank(denier);
        allowlist.setDenyPermissions(toBeDenied, permissions);
        vm.stopPrank();
    }

    function testUnauthorizedDeposit() public {
        vm.deal(joe, 100 ether);

        vm.startPrank(joe);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", joe));
        river.deposit{value: 100 ether}();
        vm.stopPrank();
    }

    // Testing regular parameters
    function testUserDeposits() public {
        vm.deal(joe, 100 ether);
        vm.deal(bob, 1000 ether);

        _allow(joe);
        _allow(bob);

        vm.startPrank(joe);
        river.deposit{value: 100 ether}();
        vm.stopPrank();
        vm.startPrank(bob);
        river.deposit{value: 1000 ether}();
        vm.stopPrank();
        assert(river.balanceOfUnderlying(joe) == 100 ether);
        assert(river.balanceOfUnderlying(bob) == 1000 ether);
        assert(river.getTotalDepositedETH() == 0);
        assert(river.totalUnderlyingSupply() == 1100 ether);

        river.debug_moveDepositToCommitted();

        // Deposit 17 validators from each operator = 34 total
        {
            uint256[] memory indexes = new uint256[](2);
            indexes[0] = operatorOneIndex;
            indexes[1] = operatorTwoIndex;
            uint32[] memory counts = new uint32[](2);
            counts[0] = 17;
            counts[1] = 17;
            _depositToConsensusLayer(indexes, counts);
        }

        OperatorsV3.Operator memory op1 = operatorsRegistry.getOperator(operatorOneIndex);
        OperatorsV3.Operator memory op2 = operatorsRegistry.getOperator(operatorTwoIndex);

        assert(op1.funded == 17 * 32 ether);
        assert(op2.funded == 17 * 32 ether);

        assert(river.getTotalDepositedETH() == 34 * 32 ether);
        assert(river.totalUnderlyingSupply() == 1100 ether);
        assert(address(river).balance == (1000 ether + 100 ether) - (32 ether * 34));
        assert(river.balanceOfUnderlying(joe) == 100 ether);
        assert(river.balanceOfUnderlying(bob) == 1000 ether);
    }

    // Testing regular parameters
    function testUserDepositsForAnotherUser() public {
        vm.deal(bob, 1100 ether);
        vm.deal(joe, 100 ether);

        _allow(joe);
        _allow(bob);

        vm.startPrank(bob);
        river.depositAndTransfer{value: 100 ether}(joe);
        vm.stopPrank();
        vm.startPrank(bob);
        river.deposit{value: 1000 ether}();
        vm.stopPrank();
        assert(river.balanceOfUnderlying(joe) == 100 ether);
        assert(river.balanceOfUnderlying(bob) == 1000 ether);
        assert(river.getTotalDepositedETH() == 0);
        assert(river.totalUnderlyingSupply() == 1100 ether);

        river.debug_moveDepositToCommitted();

        // Deposit 17 validators from each operator = 34 total
        {
            uint256[] memory indexes = new uint256[](2);
            indexes[0] = operatorOneIndex;
            indexes[1] = operatorTwoIndex;
            uint32[] memory counts = new uint32[](2);
            counts[0] = 17;
            counts[1] = 17;
            _depositToConsensusLayer(indexes, counts);
        }

        OperatorsV3.Operator memory op1 = operatorsRegistry.getOperator(operatorOneIndex);
        OperatorsV3.Operator memory op2 = operatorsRegistry.getOperator(operatorTwoIndex);

        assert(op1.funded == 17 * 32 ether);
        assert(op2.funded == 17 * 32 ether);

        assert(river.getTotalDepositedETH() == 34 * 32 ether);
        assert(river.totalUnderlyingSupply() == 1100 ether);
        assert(address(river).balance == (1000 ether + 100 ether) - (32 ether * 34));
        assert(river.balanceOfUnderlying(joe) == 100 ether);
        assert(river.balanceOfUnderlying(bob) == 1000 ether);
    }

    // Testing regular parameters
    function testDeniedUser() public {
        vm.deal(joe, 200 ether);
        vm.deal(bob, 1100 ether);

        _allow(joe);
        _allow(bob);

        vm.startPrank(joe);
        river.deposit{value: 100 ether}();
        vm.stopPrank();
        vm.startPrank(bob);
        river.deposit{value: 1000 ether}();
        vm.stopPrank();

        _deny(joe, true);
        vm.startPrank(joe);
        vm.expectRevert(abi.encodeWithSignature("Denied(address)", joe));
        river.deposit{value: 100 ether}();
        vm.stopPrank();

        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSignature("Denied(address)", joe));
        river.depositAndTransfer{value: 100 ether}(joe);
        vm.stopPrank();
    }

    function testOnTransferFailsForAllowlistDenied() public {
        vm.deal(joe, 100 ether);
        vm.deal(bob, 1000 ether);

        _allow(joe);
        _allow(bob);

        vm.startPrank(joe);
        river.deposit{value: 100 ether}();
        vm.stopPrank();

        assert(river.balanceOfUnderlying(joe) == 100 ether);

        // A user present on denied allow list can't send
        _deny(joe, true);
        vm.startPrank(joe);
        vm.expectRevert(abi.encodeWithSignature("Denied(address)", joe));
        river.transfer(bob, 100 ether);
        vm.stopPrank();

        // A user present on denied allow list can't receive
        _deny(joe, false);
        _allow(joe);
        _deny(bob, true);
        vm.startPrank(joe);
        vm.expectRevert(abi.encodeWithSignature("Denied(address)", bob));
        river.transfer(bob, 100 ether);
        vm.stopPrank();
    }

    // Testing regular parameters
    function testUserDepositsFullAllowance() public {
        vm.deal(joe, 100 ether);
        vm.deal(bob, 1000 ether);

        _allow(joe);
        _allow(bob);

        vm.startPrank(joe);
        river.deposit{value: 100 ether}();
        vm.stopPrank();
        vm.startPrank(bob);
        river.deposit{value: 1000 ether}();
        vm.stopPrank();
        assert(river.balanceOfUnderlying(joe) == 100 ether);
        assert(river.balanceOfUnderlying(bob) == 1000 ether);
        assert(river.getTotalDepositedETH() == 0);
        assert(river.totalUnderlyingSupply() == 1100 ether);

        river.debug_moveDepositToCommitted();

        // Deposit 17 validators from each operator = 34 total
        {
            uint256[] memory indexes = new uint256[](2);
            indexes[0] = operatorOneIndex;
            indexes[1] = operatorTwoIndex;
            uint32[] memory counts = new uint32[](2);
            counts[0] = 17;
            counts[1] = 17;
            _depositToConsensusLayer(indexes, counts);
        }

        OperatorsV3.Operator memory op1 = operatorsRegistry.getOperator(operatorOneIndex);
        OperatorsV3.Operator memory op2 = operatorsRegistry.getOperator(operatorTwoIndex);

        assert(op1.funded == 17 * 32 ether);
        assert(op2.funded == 17 * 32 ether);

        assert(river.getTotalDepositedETH() == 34 * 32 ether);
        assert(river.totalUnderlyingSupply() == 1100 ether);
        assert(address(river).balance == (1000 ether + 100 ether) - (32 ether * 34));
        assert(river.balanceOfUnderlying(joe) == 100 ether);
        assert(river.balanceOfUnderlying(bob) == 1000 ether);

        vm.startPrank(joe);
        river.transfer(bob, 100 ether);
        vm.stopPrank();

        assert(river.balanceOfUnderlying(joe) == 0);
        assert(river.balanceOfUnderlying(bob) == 1100 ether);
    }

    // Testing operator fee split when operators have different validator counts, and how keys are selected
    // based on which operator has the lowest key count
    function testUserDepositsUnconventionalDeposits() public {
        vm.deal(joe, 100 ether);
        vm.deal(bob, 1000 ether);

        _allow(joe);
        _allow(bob);

        vm.startPrank(joe);
        river.deposit{value: 100 ether}();
        vm.stopPrank();
        vm.startPrank(bob);
        river.deposit{value: 1000 ether}();
        vm.stopPrank();
        assert(river.balanceOfUnderlying(joe) == 100 ether);
        assert(river.balanceOfUnderlying(bob) == 1000 ether);
        assert(river.getTotalDepositedETH() == 0);
        assert(river.totalUnderlyingSupply() == 1100 ether);

        river.debug_moveDepositToCommitted();

        // Deposit 17 validators from each operator = 34 total
        {
            uint256[] memory indexes = new uint256[](2);
            indexes[0] = operatorOneIndex;
            indexes[1] = operatorTwoIndex;
            uint32[] memory counts = new uint32[](2);
            counts[0] = 17;
            counts[1] = 17;
            _depositToConsensusLayer(indexes, counts);
        }

        OperatorsV3.Operator memory op1 = operatorsRegistry.getOperator(operatorOneIndex);
        OperatorsV3.Operator memory op2 = operatorsRegistry.getOperator(operatorTwoIndex);

        assert(op1.funded == 17 * 32 ether);
        assert(op2.funded == 17 * 32 ether);

        assert(river.getTotalDepositedETH() == 34 * 32 ether);
        assert(river.totalUnderlyingSupply() == 1100 ether);
        assert(address(river).balance == (1000 ether + 100 ether) - (32 ether * 34));
        assert(river.balanceOfUnderlying(joe) == 100 ether);
        assert(river.balanceOfUnderlying(bob) == 1000 ether);
    }

    // Testing sequential deposits to different operators
    function testUserDepositsSequentialOperators() public {
        vm.deal(joe, 100 ether);
        vm.deal(bob, 1000 ether);

        _allow(joe);
        _allow(bob);

        vm.startPrank(joe);
        river.deposit{value: 100 ether}();
        vm.stopPrank();
        vm.startPrank(bob);
        river.deposit{value: 1000 ether}();
        vm.stopPrank();
        assert(river.balanceOfUnderlying(joe) == 100 ether);
        assert(river.balanceOfUnderlying(bob) == 1000 ether);
        assert(river.getTotalDepositedETH() == 0);
        assert(river.totalUnderlyingSupply() == 1100 ether);

        river.debug_moveDepositToCommitted();

        // First deposit: 20 validators from operator 1
        _depositToConsensusLayer(operatorOneIndex, 20);

        // Second deposit: 10 validators from operator 2
        _depositToConsensusLayer(operatorTwoIndex, 10);

        OperatorsV3.Operator memory op1 = operatorsRegistry.getOperator(operatorOneIndex);
        OperatorsV3.Operator memory op2 = operatorsRegistry.getOperator(operatorTwoIndex);

        assert(op1.funded == 20 * 32 ether);
        assert(op2.funded == 10 * 32 ether);

        assert(river.getTotalDepositedETH() == 30 * 32 ether);
        assert(river.totalUnderlyingSupply() == 1100 ether);
        assert(address(river).balance == (1000 ether + 100 ether) - (32 ether * 30));
        assert(river.balanceOfUnderlying(joe) == 100 ether);
        assert(river.balanceOfUnderlying(bob) == 1000 ether);
    }

    // Reverts when the attested batch targets an inactive operator. The check fires inside
    // OperatorsRegistry.incrementFundedETH (LibFundingDeltas.build is pure aggregation and does
    // not enforce operator-status invariants), before any _depositValidator call leaves River.
    function testDepositRevertsForInactiveOperator() public {
        vm.deal(bob, 1000 ether);
        _allow(bob);
        vm.prank(bob);
        river.deposit{value: 1000 ether}();
        river.debug_moveDepositToCommitted();

        vm.prank(admin);
        operatorsRegistry.setOperatorStatus(operatorOneIndex, false);

        (bytes32 bufferId, bytes32 rootHash, bytes[] memory sigs) = _buildSingleDepositArgs(operatorOneIndex);

        vm.prank(river.getKeeper());
        vm.expectRevert(abi.encodeWithSelector(IOperatorsRegistryV1.InactiveOperator.selector, operatorOneIndex));
        river.depositToConsensusLayerWithAttestation(bufferId, rootHash, sigs);

        assertEq(river.getTotalDepositedETH(), 0);
    }

    function testDepositSucceedsForOperatorWithPendingExitRequests() public {
        vm.deal(bob, 1000 ether);
        _allow(bob);
        vm.prank(bob);
        river.deposit{value: 1000 ether}();
        river.debug_moveDepositToCommitted();

        // No exitedETH is recorded for this operator yet, so the exit request is still pending.
        operatorsRegistry.sudoSetRequestedExits(operatorOneIndex, 32 ether);

        (bytes32 bufferId, bytes32 rootHash, bytes[] memory sigs) = _buildSingleDepositArgs(operatorOneIndex);

        vm.prank(river.getKeeper());
        river.depositToConsensusLayerWithAttestation(bufferId, rootHash, sigs);

        assertEq(river.getTotalDepositedETH(), 32 ether);
        assertEq(operatorsRegistry.getOperator(operatorOneIndex).funded, 32 ether);
        assertEq(operatorsRegistry.getOperator(operatorOneIndex).requestedExits, 32 ether);
    }

    // Deposits also continue to work when the operator's requested exits have already been
    // fulfilled in the registry's exitedETH accounting.
    function testDepositSucceedsWhenExitsAreFulfilled() public {
        vm.deal(bob, 1000 ether);
        _allow(bob);
        vm.prank(bob);
        river.deposit{value: 1000 ether}();
        river.debug_moveDepositToCommitted();

        operatorsRegistry.sudoSetRequestedExits(operatorOneIndex, 32 ether);

        // exitedETH layout: [total, op0, op1, ...]. Mark operator one's exit as fulfilled.
        uint256 opCount = operatorsRegistry.getOperatorCount();
        uint256[] memory exitedETH = new uint256[](opCount + 1);
        exitedETH[0] = 32 ether;
        exitedETH[operatorOneIndex + 1] = 32 ether;
        operatorsRegistry.sudoSetRawExitedETH(exitedETH);

        (bytes32 bufferId, bytes32 rootHash, bytes[] memory sigs) = _buildSingleDepositArgs(operatorOneIndex);

        vm.prank(river.getKeeper());
        river.depositToConsensusLayerWithAttestation(bufferId, rootHash, sigs);

        assertEq(river.getTotalDepositedETH(), 32 ether);
    }

    function _debugMaxIncrease(uint256 annualAprUpperBound, uint256 _prevTotalEth, uint256 _timeElapsed)
        internal
        pure
        returns (uint256)
    {
        return (_prevTotalEth * annualAprUpperBound * _timeElapsed) / uint256(10000 * 365 days);
    }

    function testDepositBlockedInSlashingContainmentMode() public {
        vm.deal(bob, 1 ether);
        _allow(bob);
        river.sudoSetSlashingContainmentMode(true);
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSignature("SlashingContainmentModeEnabled()"));
        river.deposit{value: 1 ether}();
    }

    function testSendRedeemManagerUnauthorizedCall() public {
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", address(this)));
        river.sendRedeemManagerExceedingFunds();
    }

    function testRequestRedeemBlockedInSlashingContainmentMode() public {
        vm.deal(bob, 1 ether);
        _allow(bob);
        vm.prank(bob);
        river.deposit{value: 1 ether}();

        river.sudoSetSlashingContainmentMode(true);

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSignature("SlashingContainmentModeEnabled()"));
        river.requestRedeem(1 ether, bob);
    }

    function testDepositAllowedWhenSlashingModeOff() public {
        vm.deal(bob, 1 ether);
        _allow(bob);
        river.sudoSetSlashingContainmentMode(false);
        vm.prank(bob);
        river.deposit{value: 1 ether}();
        assertGt(river.balanceOf(bob), 0);
    }

    function testDepositAndTransferBlockedInSlashingContainmentMode() public {
        vm.deal(bob, 1 ether);
        _allow(bob);
        river.sudoSetSlashingContainmentMode(true);
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSignature("SlashingContainmentModeEnabled()"));
        river.depositAndTransfer{value: 1 ether}(joe);
    }

    function testReceiveBlockedInSlashingContainmentMode() public {
        vm.deal(bob, 1 ether);
        _allow(bob);
        river.sudoSetSlashingContainmentMode(true);
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSignature("SlashingContainmentModeEnabled()"));
        address(river).call{value: 1 ether}("");
    }

    // Slashing containment is a panic-mode lever; the keeper-driven attestation deposit path must
    // honour it just like the user-deposit, requestRedeem, receive, and depositAndTransfer paths.
    function testDepositToConsensusLayerWithAttestationBlockedInSlashingContainmentMode() public {
        vm.deal(bob, 1000 ether);
        _allow(bob);
        vm.prank(bob);
        river.deposit{value: 1000 ether}();
        river.debug_moveDepositToCommitted();

        river.sudoSetSlashingContainmentMode(true);

        (bytes32 bufferId, bytes32 rootHash, bytes[] memory sigs) = _buildSingleDepositArgs(operatorOneIndex);

        vm.prank(river.getKeeper());
        vm.expectRevert(abi.encodeWithSignature("SlashingContainmentModeEnabled()"));
        river.depositToConsensusLayerWithAttestation(bufferId, rootHash, sigs);
    }

    function testRequestRedeemAllowedWhenSlashingModeOff() public {
        RedeemManagerV1WithLegacyInit redeemManager = new RedeemManagerV1WithLegacyInit();
        LibImplementationUnbricker.unbrick(vm, address(redeemManager));
        redeemManager.initializeRedeemManagerV1(address(river));
        river.initRiverV1_1(
            address(redeemManager),
            epochsPerFrame,
            slotsPerEpoch,
            secondsPerSlot,
            0,
            epochsUntilFinal,
            1000,
            500,
            maxDailyNetCommittableAmount,
            maxDailyRelativeCommittableAmount
        );

        vm.deal(bob, 1 ether);
        _allow(bob);
        vm.prank(bob);
        river.deposit{value: 1 ether}();
        river.sudoSetSlashingContainmentMode(false);
        uint256 balance = river.balanceOf(bob);
        vm.prank(bob);
        uint32 redeemRequestId = river.requestRedeem(balance, bob);
        assertEq(redeemRequestId, 0);
    }

    function testClaimRedeemRequestsAllowedWhenSlashingModeOff() public {
        RedeemManagerV1WithLegacyInit redeemManager = new RedeemManagerV1WithLegacyInit();
        LibImplementationUnbricker.unbrick(vm, address(redeemManager));
        redeemManager.initializeRedeemManagerV1(address(river));
        river.initRiverV1_1(
            address(redeemManager),
            epochsPerFrame,
            slotsPerEpoch,
            secondsPerSlot,
            0,
            epochsUntilFinal,
            1000,
            500,
            maxDailyNetCommittableAmount,
            maxDailyRelativeCommittableAmount
        );

        river.sudoSetSlashingContainmentMode(false);
        uint32[] memory ids = new uint32[](0);
        uint32[] memory events = new uint32[](0);
        uint8[] memory claimStatuses = river.claimRedeemRequests(ids, events);
        assertEq(claimStatuses.length, 0);
    }

    function testClaimRedeemRequestsAllowedInSlashingContainmentMode() public {
        RedeemManagerV1WithLegacyInit redeemManager = new RedeemManagerV1WithLegacyInit();
        LibImplementationUnbricker.unbrick(vm, address(redeemManager));
        redeemManager.initializeRedeemManagerV1(address(river));
        river.initRiverV1_1(
            address(redeemManager),
            epochsPerFrame,
            slotsPerEpoch,
            secondsPerSlot,
            0,
            epochsUntilFinal,
            1000,
            500,
            maxDailyNetCommittableAmount,
            maxDailyRelativeCommittableAmount
        );

        // Set up a real redeem request while slashing mode is off
        uint256 amount = 1 ether;
        vm.deal(bob, amount);
        _allow(bob);
        vm.prank(bob);
        river.deposit{value: amount}();
        uint256 lsETHBalance = river.balanceOf(bob);

        vm.prank(bob);
        river.requestRedeem(lsETHBalance, bob);

        // Fund the withdrawal event via the RedeemManager (called as river)
        vm.deal(address(river), amount);
        vm.prank(address(river));
        redeemManager.reportWithdraw{value: amount}(lsETHBalance);

        // Enable slashing containment mode and claim
        river.sudoSetSlashingContainmentMode(true);

        uint32[] memory ids = new uint32[](1);
        uint32[] memory events = new uint32[](1);
        ids[0] = 0;
        events[0] = 0;

        uint256 bobBalanceBefore = bob.balance;
        uint8[] memory claimStatuses = river.claimRedeemRequests(ids, events);

        assertEq(claimStatuses.length, 1);
        assertEq(claimStatuses[0], 0); // CLAIM_FULLY_CLAIMED
        assertGt(bob.balance - bobBalanceBefore, 0);
    }

    function testDepositUnblockedAfterSlashingModeToggleOff() public {
        vm.deal(bob, 1 ether);
        _allow(bob);
        river.sudoSetSlashingContainmentMode(true);
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSignature("SlashingContainmentModeEnabled()"));
        river.deposit{value: 1 ether}();

        river.sudoSetSlashingContainmentMode(false);
        vm.prank(bob);
        river.deposit{value: 1 ether}();
        assertGt(river.balanceOf(bob), 0);
    }

    function testRequestRedeemDeniedRecipient(uint256 _salt, uint256 _salt2) external {
        vm.assume(_salt != _salt2);
        address user = uf._new(_salt);
        _allow(user);
        uint128 amount = uint128(bound(_salt, 1, type(uint128).max));
        address recipient = uf._new(_salt2);
        _deny(recipient, true);

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSignature("RecipientIsDenied()"));
        river.requestRedeem(amount, recipient);
    }

    /// Asserts that depositToConsensusLayer triggers the padding else-branch in River._incrementFundedETH
    /// when an entry has zero pubkeys: by adding a 3rd operator and allocating only to operator 1, the
    /// padding loop encounters publicKeys[0] with length 0.
    function testIncrementFundedETHEmptyPublicKeysBranch() public {
        // Add a third operator so registry.getOperatorCount() > allocations array length.
        vm.prank(admin);
        operatorsRegistry.addOperator("ThirdOp", makeAddr("operatorThree"));
        // Re-size the exited ETH backing array so getExitedETHAtIndex stays in bounds.
        operatorsRegistry.sudoSetRawExitedETH(new uint256[](operatorsRegistry.getOperatorCount() + 1));

        vm.deal(joe, 100 ether);
        _allow(joe);
        vm.prank(joe);
        river.deposit{value: 100 ether}();
        river.debug_moveDepositToCommitted();

        // Allocate only to operator at index 1 (operatorTwoIndex). This makes the buffer aggregation build
        // publicKeys with length 2 where publicKeys[0] is empty (no allocations).
        // Then in River._incrementFundedETH, _fundedETH.length (2) < operatorCount (3), padding triggers,
        // while the registry still receives the empty key bucket for operator 0.
        _depositToConsensusLayer(operatorTwoIndex, 2);

        OperatorsV3.Operator memory op2 = operatorsRegistry.getOperator(operatorTwoIndex);
        assertEq(op2.funded, 2 * 32 ether);
    }
}

contract RiverV1TestsReport_HEAVY_FUZZING is RiverV1TestBase {
    RedeemManagerV1WithLegacyInit redeemManager;

    function setUp() public override {
        super.setUp();
        bytes32 withdrawalCredentials = withdraw.getCredentials();
        redeemManager = new RedeemManagerV1WithLegacyInit();
        LibImplementationUnbricker.unbrick(vm, address(redeemManager));
        redeemManager.initializeRedeemManagerV1(address(river));
        vm.expectEmit(true, true, true, true);
        emit SetOperatorsRegistry(address(operatorsRegistry));
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
        river.initRiverV1_1(
            address(redeemManager),
            epochsPerFrame,
            slotsPerEpoch,
            secondsPerSlot,
            0,
            epochsUntilFinal,
            1000,
            500,
            maxDailyNetCommittableAmount,
            maxDailyRelativeCommittableAmount
        );
        river.initRiverV1_2();
        withdraw.initializeWithdrawV1(address(river));
        oracle.initOracleV1(address(river), admin, 225, 32, 12, 0, 1000, 500);

        vm.startPrank(admin);

        oracle.addMember(oracleMember, 1);
        river.setCoverageFund(address(coverageFund));
        river.setKeeper(keeper);

        // Set up attestation infrastructure (threshold must be strictly less than attester count)
        // river.setDepositDataBuffer(address(depositBuffer));
        // river.setAttester(rootAttester1, true);
        // river.setAttester(rootAttester2, true);
        // river.setAttester(rootAttester3, true);
        // river.setAttestationQuorum(2);

        vm.stopPrank();

        // Deploy + initialize the AttestationVerifier sibling.
        address[] memory _initRootAttesters2 = new address[](3);
        _initRootAttesters2[0] = rootAttester1;
        _initRootAttesters2[1] = rootAttester2;
        _initRootAttesters2[2] = rootAttester3;
        address[] memory _initConsolidationCommitteeAttesters = new address[](1);
        _initConsolidationCommitteeAttesters[0] = makeAddr("consolidationCommitteeAttesterStub");
        attestationVerifier = new AttestationVerifierV1();
        LibImplementationUnbricker.unbrick(vm, address(attestationVerifier));
        attestationVerifier.initAttestationVerifierV1(
            address(river),
            address(depositBuffer),
            _initRootAttesters2,
            2,
            bytes4(0),
            _initConsolidationCommitteeAttesters,
            1
        );
        vm.store(
            address(river),
            bytes32(uint256(keccak256("river.state.attestationVerifierAddress")) - 1),
            bytes32(uint256(uint160(address(attestationVerifier))))
        );

        // Mock BLS verification on the validator (EIP-2537 precompiles not enabled in Foundry).
        vm.mockCall(
            address(attestationVerifier),
            abi.encodeWithSelector(attestationVerifier.verifyBLSDeposit.selector),
            bytes("")
        );
    }

    /// @dev Fills in the Pectra-era report fields that these pre-existing tests leave at their
    ///      zero defaults: `activeCLETHPerOperator` (must match current opCount, or `reportCLETH`
    ///      reverts with `InvalidEmptyArray`) and `totalDepositedActivatedETH` (must be monotonic
    ///      non-decreasing and absorb the current in-flight ETH, or the balance-bound checks in
    ///      `setConsensusLayerData` fire instead of the revert the test is asserting on).
    /// @dev Reads storage via `vm.load` rather than external getters so that inserting this helper
    ///      between `vm.prank`/`vm.expectRevert` and the report call does not consume those hooks
    ///      (which only target the next external call).
    function _fillReport(IOracleManagerV1.ConsensusLayerReport memory clr) internal view {
        if (clr.activeCLETHPerOperator.length == 0) {
            // OperatorsV3 storage: the Operator[] array length lives at OPERATORS_SLOT.
            uint256 opCount = uint256(
                vm.load(address(operatorsRegistry), bytes32(uint256(keccak256("river.state.v3.operators")) - 1))
            );
            if (opCount > 0) {
                clr.activeCLETHPerOperator = new uint256[](opCount);
            }
        }
        if (clr.totalDepositedActivatedETH == 0) {
            // StoredConsensusLayerReport.totalDepositedActivatedETH is the 7th field (offset 6)
            // from LAST_CONSENSUS_LAYER_REPORT_SLOT.
            uint256 lastReportBase = uint256(keccak256("river.state.lastConsensusLayerReport")) - 1;
            uint256 lastTotalDeposited = uint256(vm.load(address(river), bytes32(lastReportBase + 6)));
            uint256 inFlight =
                uint256(vm.load(address(river), bytes32(uint256(keccak256("river.state.inFlightDeposit")) - 1)));
            clr.totalDepositedActivatedETH = lastTotalDeposited + inFlight;
        }
    }

    function _rawPermissions(address _who, uint256 _mask) internal {
        address[] memory allowees = new address[](1);
        allowees[0] = _who;
        uint256[] memory statuses = new uint256[](1);
        statuses[0] = _mask;

        vm.startPrank(allower);
        allowlist.setAllowPermissions(allowees, statuses);
        vm.stopPrank();
    }

    function _allow(address _who) internal {
        address[] memory allowees = new address[](1);
        allowees[0] = _who;

        uint256[] memory permissions = new uint256[](1);
        permissions[0] = LibAllowlistMasks.REDEEM_MASK | LibAllowlistMasks.DEPOSIT_MASK;

        vm.startPrank(allower);
        allowlist.setAllowPermissions(allowees, permissions);
        vm.stopPrank();
    }

    function _next(uint256 _salt) internal pure returns (uint256 _newSalt) {
        return uint256(keccak256(abi.encode(_salt)));
    }

    function _performFakeDeposits(uint8 userCount, uint256 _salt)
        internal
        returns (address[] memory users, uint256 _newSalt)
    {
        users = new address[](userCount);
        for (uint256 idx = 0; idx < userCount; ++idx) {
            users[idx] = address(uint160(_salt));
            _allow(users[idx]);
            _salt = _next(_salt);
            uint256 amountToDeposit = bound(_salt, 1 ether, 100 ether);
            vm.deal(users[idx], amountToDeposit);
            vm.prank(users[idx]);
            river.deposit{value: amountToDeposit}();
            _salt = _next(_salt);

            uint256 amountToRedeem = bound(_salt, 0.1 ether, amountToDeposit / 2);
            if (_salt % 2 == 0) {
                vm.prank(users[idx]);
                river.approve(address(redeemManager), amountToRedeem);
                vm.prank(users[idx]);
                redeemManager.requestRedeem(amountToRedeem);
                _salt = _next(_salt);
            } else {
                vm.prank(users[idx]);
                river.requestRedeem(amountToRedeem, users[idx]);
                _salt = _next(_salt);
            }
        }
        _newSalt = _salt;

        river.debug_moveDepositToCommitted();
    }

    function _performDepositsToConsensusLayer(uint256 _salt)
        internal
        returns (uint256 depositCount, uint256 operatorCount, uint256 _newSalt)
    {
        uint256 maxDepositPossible = river.getCommittedBalance() / 32 ether;
        depositCount = bound(_salt, 1, LibUint256.min(maxDepositPossible, 200));
        _salt = _next(_salt);
        operatorCount = bound(_salt, 1, 100);
        _salt = _next(_salt);

        // Arrays to store operator info for allocation
        uint256[] memory operatorIndices = new uint256[](operatorCount);
        uint32[] memory operatorKeyCounts = new uint32[](operatorCount);

        uint256 rest = depositCount % operatorCount;
        for (uint256 idx = 0; idx < operatorCount; ++idx) {
            address operatorAddress = address(uint160(_salt));
            _salt = _next(_salt);
            string memory operatorName = string(abi.encode(_salt));
            _salt = _next(_salt);

            vm.prank(admin);
            uint256 operatorIndex = operatorsRegistry.addOperator(operatorName, operatorAddress);
            operatorIndices[idx] = operatorIndex;

            uint256 operatorKeyCount = (depositCount / operatorCount) + (rest > 0 ? 1 : 0);
            if (rest > 0) {
                --rest;
            }
            operatorKeyCounts[idx] = uint32(operatorKeyCount);
        }

        // Deposit via attestation
        _depositToConsensusLayer(operatorIndices, operatorKeyCounts);

        // Pre-initialize the exited ETH storage array so _setExitedETH can access
        // currentExitedETH[idx] without panicking when the first oracle report arrives.
        operatorsRegistry.sudoSetRawExitedETH(new uint256[](operatorCount + 1));

        _newSalt = _salt;
    }

    function _redeemAllSatisfiedRedeemRequests(uint256 _salt) internal returns (uint256) {
        uint256 redeemRequestCount = redeemManager.getRedeemRequestCount();
        uint32[] memory unresolvedRedeemRequestIds = new uint32[](redeemRequestCount);
        for (uint256 idx = 0; idx < redeemRequestCount; ++idx) {
            unresolvedRedeemRequestIds[idx] = uint32(idx);
        }

        int64[] memory resolutions;
        if (_salt % 2 == 0) {
            resolutions = redeemManager.resolveRedeemRequests(unresolvedRedeemRequestIds);
        } else {
            resolutions = river.resolveRedeemRequests(unresolvedRedeemRequestIds);
        }
        _salt = _next(_salt);

        uint256 satisfiedRedeemRequestCount = 0;
        for (uint256 idx = 0; idx < resolutions.length; ++idx) {
            if (resolutions[idx] >= 0) {
                ++satisfiedRedeemRequestCount;
            }
        }

        uint32[] memory redeemRequestIds = new uint32[](satisfiedRedeemRequestCount);
        uint32[] memory withdrawalEventIds = new uint32[](satisfiedRedeemRequestCount);
        uint256 savedIdx = 0;
        for (uint256 idx = 0; idx < resolutions.length; ++idx) {
            if (resolutions[idx] >= 0) {
                redeemRequestIds[savedIdx] = unresolvedRedeemRequestIds[idx];
                withdrawalEventIds[savedIdx] = uint32(uint64(resolutions[idx]));
                ++savedIdx;
            }
        }
        if (_salt % 2 == 0) {
            redeemManager.claimRedeemRequests(redeemRequestIds, withdrawalEventIds);
        } else {
            river.claimRedeemRequests(redeemRequestIds, withdrawalEventIds);
        }
        _salt = _next(_salt);

        if (_salt % 2 == 0) {
            resolutions = redeemManager.resolveRedeemRequests(unresolvedRedeemRequestIds);
        } else {
            resolutions = river.resolveRedeemRequests(unresolvedRedeemRequestIds);
        }
        for (uint256 idx = 0; idx < resolutions.length; ++idx) {
            assertTrue(resolutions[idx] < 0, "should not have satisfied requests left");
        }

        return _salt;
    }

    function _performPreAssertions(ReportingFuzzingVariables memory rfv) internal {
        assertEq(
            rfv.expected_pre_elFeeRecipientBalance,
            address(elFeeRecipient).balance,
            "failed pre elFeeRecipient balance check"
        );
        assertEq(
            rfv.expected_pre_coverageFundBalance, address(coverageFund).balance, "failed pre coverageFund balance check"
        );
        assertEq(
            rfv.expected_pre_exceedingBufferAmount,
            redeemManager.getBufferedExceedingEth(),
            "failed pre redeem manager exceeding amount check"
        );

        uint256 rebuiltTotalSupply = 0;
        for (uint256 idx = 0; idx < rfv.users.length; ++idx) {
            rebuiltTotalSupply += river.balanceOf(rfv.users[idx]);
        }
        rebuiltTotalSupply += river.balanceOf(collector);
        rebuiltTotalSupply += river.balanceOf(address(redeemManager));

        assertEq(rebuiltTotalSupply, river.totalSupply(), "failed to rebuild pre total supply");
    }

    function _performPostAssertions(ReportingFuzzingVariables memory rfv) internal {
        assertEq(
            rfv.expected_post_elFeeRecipientBalance,
            address(elFeeRecipient).balance,
            "failed post elFeeRecipient balance check"
        );
        assertEq(
            rfv.expected_post_coverageFundBalance,
            address(coverageFund).balance,
            "failed post coverageFund balance check"
        );
        assertEq(
            rfv.expected_post_exceedingBufferAmount,
            redeemManager.getBufferedExceedingEth(),
            "failed post redeem manager exceeding amount check"
        );
        assertEq(river.getBalanceToRedeem(), 0, "failed checking balance to redeem is empty");

        uint256 rebuiltTotalSupply = 0;
        for (uint256 idx = 0; idx < rfv.users.length; ++idx) {
            rebuiltTotalSupply += river.balanceOf(rfv.users[idx]);
        }
        rebuiltTotalSupply += river.balanceOf(collector);
        rebuiltTotalSupply += river.balanceOf(address(redeemManager));

        assertEq(rebuiltTotalSupply, river.totalSupply(), "failed to rebuild post total supply");
    }

    struct ReportingFuzzingVariables {
        address[] users;
        uint256 depositCount;
        uint256 scenario;
        uint256 operatorCount;
        CLSpec.CLSpecStruct cls;
        ReportBounds.ReportBoundsStruct rb;
        uint256 expected_pre_elFeeRecipientBalance;
        uint256 expected_pre_coverageFundBalance;
        uint256 expected_pre_exceedingBufferAmount;
        uint256 expected_post_elFeeRecipientBalance;
        uint256 expected_post_coverageFundBalance;
        uint256 expected_post_exceedingBufferAmount;
    }

    function _retrieveInitialReportingData(ReportingFuzzingVariables memory rfv, uint256 _salt)
        internal
        returns (IOracleManagerV1.ConsensusLayerReport memory clr, uint256 _newSalt)
    {
        clr.epoch = bound(_salt, 1_000, 1_000_000) * epochsPerFrame;
        _salt = _next(_salt);
        vm.warp((secondsPerSlot * slotsPerEpoch) * (clr.epoch + epochsUntilFinal));
        if (rfv.scenario == SCENARIO_REGULAR_REPORTING_PULL_EXCEEDING_BUFFER) {
            uint256 amountPerValidator = bound(_salt, 0, 1 ether);
            clr.validatorsBalance = rfv.depositCount * (32 ether + amountPerValidator);
        } else {
            clr.validatorsBalance = rfv.depositCount * 32 ether;
        }
        clr.validatorsCount = uint32(rfv.depositCount);

        clr.validatorsSkimmedBalance = 0;
        clr.validatorsExitedBalance = 0;
        clr.validatorsExitingBalance = clr.validatorsBalance; // ensures no exits will be requested before asserted report
        clr.totalDepositedActivatedETH = rfv.depositCount * 32 ether;
        // Use operatorCount+1 length so the second report (length N+1) doesn't shrink the array.
        clr.exitedETHPerOperator = new uint256[](rfv.operatorCount + 1);
        // Populate activeCLETH with the deposit distribution so every operator has active-CL headroom
        // for any stoppedTotalCount <= depositCount in subsequent scenario reports.
        clr.activeCLETHPerOperator = new uint256[](rfv.operatorCount);
        {
            uint256 restActiveCL = rfv.depositCount % rfv.operatorCount;
            for (uint256 idx = 0; idx < rfv.operatorCount; ++idx) {
                uint256 opDepositCount = rfv.depositCount / rfv.operatorCount + (restActiveCL > 0 ? 1 : 0);
                if (restActiveCL > 0) --restActiveCL;
                clr.activeCLETHPerOperator[idx] = opDepositCount * 32 ether;
            }
        }
        _newSalt = _salt;
    }

    function testReportingFuzzing(uint256 _salt) external {
        _salt = _next(_salt);

        IOracleManagerV1.ConsensusLayerReport memory clr;

        ReportingFuzzingVariables memory rfv;

        (rfv.users, _salt) = _performFakeDeposits(uint8(bound(_salt, 160, type(uint8).max)), _salt);
        console.log("User Count = ", rfv.users.length);
        (rfv.depositCount, rfv.operatorCount, _salt) = _performDepositsToConsensusLayer(_salt);
        console.log("Deposit Count = ", rfv.depositCount);

        rfv.scenario = _salt % 7;
        _salt = _next(_salt);

        rfv.cls = river.getCLSpec();
        rfv.rb = river.getReportBounds();

        (clr, _salt) = _retrieveInitialReportingData(rfv, _salt);

        vm.prank(oracleMember);
        _fillReport(clr);
        oracle.reportConsensusLayerData(clr);

        (clr, _salt) = _retrieveReportingData(rfv, _salt);

        _performPreAssertions(rfv);
        vm.prank(oracleMember);
        _fillReport(clr);
        oracle.reportConsensusLayerData(clr);

        _updateAssertions(clr, rfv, _salt);

        _performPostAssertions(rfv);

        // Scenario 6 leaves slashing containment mode active; disable it so
        // _redeemAllSatisfiedRedeemRequests can call river.claimRedeemRequests.
        if (rfv.scenario == SCENARIO_REGULAR_REPORTING_SLASHING_CONTAINMENT_ACTIVE) {
            river.sudoSetSlashingContainmentMode(false);
        }

        _salt = _redeemAllSatisfiedRedeemRequests(_salt);
    }

    uint256 internal constant SCENARIO_REGULAR_REPORTING_NOTHING_PULLED = 0;
    uint256 internal constant SCENARIO_REGULAR_REPORTING_PULL_EL_FEES = 1;
    uint256 internal constant SCENARIO_REGULAR_REPORTING_PULL_COVERAGE = 2;
    uint256 internal constant SCENARIO_REGULAR_REPORTING_PULL_EXCEEDING_BUFFER = 3;
    uint256 internal constant SCENARIO_REGULAR_REPORTING_PULL_HALF_EL_COVERAGE = 4;
    uint256 internal constant SCENARIO_REGULAR_REPORTING_REBALANCING_MODE_ACTIVE = 5;
    uint256 internal constant SCENARIO_REGULAR_REPORTING_SLASHING_CONTAINMENT_ACTIVE = 6;

    function _retrieveReportingData(ReportingFuzzingVariables memory rfv, uint256 _salt)
        internal
        returns (IOracleManagerV1.ConsensusLayerReport memory clr, uint256 _newSalt)
    {
        if (rfv.scenario == SCENARIO_REGULAR_REPORTING_NOTHING_PULLED) {
            console.log("playing SCENARIO_REGULAR_REPORTING_NOTHING_PULLED");
            return _retrieveScenario_REGULAR_REPORTING_NOTHING_PULLED(rfv, _salt);
        } else if (rfv.scenario == SCENARIO_REGULAR_REPORTING_PULL_EL_FEES) {
            console.log("playing SCENARIO_REGULAR_REPORTING_PULL_EL_FEES");
            return _retrieveScenario_REGULAR_REPORTING_PULL_EL_FEES(rfv, _salt);
        } else if (rfv.scenario == SCENARIO_REGULAR_REPORTING_PULL_COVERAGE) {
            console.log("playing SCENARIO_REGULAR_REPORTING_PULL_COVERAGE");
            return _retrieveScenario_REGULAR_REPORTING_PULL_COVERAGE(rfv, _salt);
        } else if (rfv.scenario == SCENARIO_REGULAR_REPORTING_PULL_EXCEEDING_BUFFER) {
            console.log("playing SCENARIO_REGULAR_REPORTING_PULL_EXCEEDING_BUFFER");
            return _retrieveScenario_REGULAR_REPORTING_PULL_EXCEEDING_BUFFER(rfv, _salt);
        } else if (rfv.scenario == SCENARIO_REGULAR_REPORTING_PULL_HALF_EL_COVERAGE) {
            console.log("playing SCENARIO_REGULAR_REPORTING_PULL_HALF_EL_COVERAGE");
            return _retrieveScenario_REGULAR_REPORTING_PULL_HALF_EL_COVERAGE(rfv, _salt);
        } else if (rfv.scenario == SCENARIO_REGULAR_REPORTING_REBALANCING_MODE_ACTIVE) {
            console.log("playing SCENARIO_REGULAR_REPORTING_REBALANCING_MODE_ACTIVE");
            return _retrieveScenario_REGULAR_REPORTING_REBALANCING_MODE_ACTIVE(rfv, _salt);
        } else if (rfv.scenario == SCENARIO_REGULAR_REPORTING_SLASHING_CONTAINMENT_ACTIVE) {
            console.log("playing SCENARIO_REGULAR_REPORTING_SLASHING_CONTAINMENT_ACTIVE");
            return _retrieveScenario_REGULAR_REPORTING_SLASHING_CONTAINMENT_ACTIVE(rfv, _salt);
        } else {
            revert();
        }
    }

    function _updateAssertions(
        IOracleManagerV1.ConsensusLayerReport memory clr,
        ReportingFuzzingVariables memory rfv,
        uint256 _salt
    ) internal {
        if (rfv.scenario == SCENARIO_REGULAR_REPORTING_NOTHING_PULLED) {
            return;
        } else if (rfv.scenario == SCENARIO_REGULAR_REPORTING_PULL_EL_FEES) {
            return;
        } else if (rfv.scenario == SCENARIO_REGULAR_REPORTING_PULL_COVERAGE) {
            return;
        } else if (rfv.scenario == SCENARIO_REGULAR_REPORTING_PULL_EXCEEDING_BUFFER) {
            return;
        } else if (rfv.scenario == SCENARIO_REGULAR_REPORTING_PULL_HALF_EL_COVERAGE) {
            return;
        } else if (rfv.scenario == SCENARIO_REGULAR_REPORTING_REBALANCING_MODE_ACTIVE) {
            return;
        } else if (rfv.scenario == SCENARIO_REGULAR_REPORTING_SLASHING_CONTAINMENT_ACTIVE) {
            return _updateAssertions_REGULAR_REPORTING_SLASHING_CONTAINMENT_ACTIVE(rfv, clr, _salt);
        } else {
            revert();
        }
    }

    function _retrieveScenario_REGULAR_REPORTING_NOTHING_PULLED(ReportingFuzzingVariables memory rfv, uint256 _salt)
        internal
        returns (IOracleManagerV1.ConsensusLayerReport memory clr, uint256 _newSalt)
    {
        uint256 expectedEpoch = river.getExpectedEpochId();
        clr.epoch = expectedEpoch + bound(_salt, 1, 1_000) * epochsPerFrame;
        _salt = _next(_salt);

        uint256 timeIntoTheFuture = bound(_salt, epochsUntilFinal * secondsPerSlot * slotsPerEpoch, 365 days);
        _salt = _next(_salt);
        vm.warp(timeIntoTheFuture + (secondsPerSlot * slotsPerEpoch) * clr.epoch);

        uint256 maxAllowedIncrease = debug_maxIncrease(
            rfv.rb,
            river.totalUnderlyingSupply(),
            debug_timeBetweenEpochs(rfv.cls, river.getLastCompletedEpochId(), clr.epoch)
        );

        uint256 stoppedTotalCount = bound(_salt, 0, rfv.depositCount);
        _salt = _next(_salt);
        uint256 exitingTotalCount = bound(_salt, 0, stoppedTotalCount);
        _salt = _next(_salt);

        uint256 totalIncrease = bound(_salt, 0, maxAllowedIncrease);
        _salt = _next(_salt);
        clr.validatorsSkimmedBalance = bound(_salt, 0, totalIncrease);
        _salt = _next(_salt);
        clr.validatorsBalance = (rfv.depositCount - (stoppedTotalCount - exitingTotalCount)) * 32 ether
            + (totalIncrease - clr.validatorsSkimmedBalance);

        clr.validatorsCount = uint32(rfv.depositCount);

        clr.validatorsExitedBalance = 32 ether * (stoppedTotalCount - exitingTotalCount);
        clr.validatorsExitingBalance = 32 ether * exitingTotalCount;

        vm.deal(address(withdraw), clr.validatorsSkimmedBalance + clr.validatorsExitedBalance);

        clr.exitedETHPerOperator = new uint256[](rfv.operatorCount + 1);

        clr.exitedETHPerOperator[0] = stoppedTotalCount * 32 ether;
        uint256 rest = stoppedTotalCount % rfv.operatorCount;
        for (uint256 idx = 0; idx < rfv.operatorCount; ++idx) {
            clr.exitedETHPerOperator[idx + 1] =
                uint256((stoppedTotalCount / rfv.operatorCount) + (rest > 0 ? 1 : 0)) * 32 ether;
            if (rest > 0) {
                --rest;
            }
        }

        clr.activeCLETHPerOperator = new uint256[](rfv.operatorCount);
        clr.rebalanceDepositToRedeemMode = false;
        clr.slashingContainmentMode = false;
        clr.totalDepositedActivatedETH = rfv.depositCount * 32 ether;

        rfv.expected_pre_elFeeRecipientBalance = 0;
        rfv.expected_pre_coverageFundBalance = 0;
        rfv.expected_pre_exceedingBufferAmount = 0;

        rfv.expected_post_elFeeRecipientBalance = 0;
        rfv.expected_post_coverageFundBalance = 0;
        rfv.expected_post_exceedingBufferAmount = 0;
        _newSalt = _salt;
    }

    function _retrieveScenario_REGULAR_REPORTING_PULL_EL_FEES(ReportingFuzzingVariables memory rfv, uint256 _salt)
        internal
        returns (IOracleManagerV1.ConsensusLayerReport memory clr, uint256 _newSalt)
    {
        uint256 expectedEpoch = river.getExpectedEpochId();
        clr.epoch = expectedEpoch + bound(_salt, 1, 1_000) * epochsPerFrame;
        _salt = _next(_salt);

        uint256 timeIntoTheFuture = bound(_salt, epochsUntilFinal * secondsPerSlot * slotsPerEpoch, 365 days);
        _salt = _next(_salt);
        vm.warp(timeIntoTheFuture + (secondsPerSlot * slotsPerEpoch) * clr.epoch);

        uint256 maxAllowedIncrease = debug_maxIncrease(
            rfv.rb,
            river.totalUnderlyingSupply(),
            debug_timeBetweenEpochs(rfv.cls, river.getLastCompletedEpochId(), clr.epoch)
        );

        uint256 stoppedTotalCount = bound(_salt, 0, rfv.depositCount);
        _salt = _next(_salt);
        uint256 exitingTotalCount = bound(_salt, 0, stoppedTotalCount);
        _salt = _next(_salt);

        uint256 totalIncrease = bound(_salt, 0, maxAllowedIncrease);
        _salt = _next(_salt);
        clr.validatorsSkimmedBalance = bound(_salt, 0, totalIncrease);
        _salt = _next(_salt);
        clr.validatorsBalance = (rfv.depositCount - (stoppedTotalCount - exitingTotalCount)) * 32 ether
            + (totalIncrease - clr.validatorsSkimmedBalance);

        clr.validatorsCount = uint32(rfv.depositCount);

        clr.validatorsExitedBalance = 32 ether * (stoppedTotalCount - exitingTotalCount);
        clr.validatorsExitingBalance = 32 ether * exitingTotalCount;

        vm.deal(address(withdraw), clr.validatorsSkimmedBalance + clr.validatorsExitedBalance);

        clr.exitedETHPerOperator = new uint256[](rfv.operatorCount + 1);

        clr.exitedETHPerOperator[0] = stoppedTotalCount * 32 ether;
        uint256 rest = stoppedTotalCount % rfv.operatorCount;
        for (uint256 idx = 0; idx < rfv.operatorCount; ++idx) {
            clr.exitedETHPerOperator[idx + 1] =
                uint256((stoppedTotalCount / rfv.operatorCount) + (rest > 0 ? 1 : 0)) * 32 ether;
            if (rest > 0) {
                --rest;
            }
        }

        clr.activeCLETHPerOperator = new uint256[](rfv.operatorCount);
        clr.rebalanceDepositToRedeemMode = false;
        clr.slashingContainmentMode = false;
        clr.totalDepositedActivatedETH = rfv.depositCount * 32 ether;

        uint256 remainingIncrease = maxAllowedIncrease - totalIncrease;
        vm.deal(address(elFeeRecipient), remainingIncrease);

        rfv.expected_pre_elFeeRecipientBalance = remainingIncrease;
        rfv.expected_pre_coverageFundBalance = 0;
        rfv.expected_pre_exceedingBufferAmount = 0;

        rfv.expected_post_elFeeRecipientBalance = 0;
        rfv.expected_post_coverageFundBalance = 0;
        rfv.expected_post_exceedingBufferAmount = 0;
        _newSalt = _salt;
    }

    function _retrieveScenario_REGULAR_REPORTING_PULL_COVERAGE(ReportingFuzzingVariables memory rfv, uint256 _salt)
        internal
        returns (IOracleManagerV1.ConsensusLayerReport memory clr, uint256 _newSalt)
    {
        uint256 expectedEpoch = river.getExpectedEpochId();
        clr.epoch = expectedEpoch + bound(_salt, 1, 1_000) * epochsPerFrame;
        _salt = _next(_salt);

        uint256 timeIntoTheFuture = bound(_salt, epochsUntilFinal * secondsPerSlot * slotsPerEpoch, 365 days);
        _salt = _next(_salt);
        vm.warp(timeIntoTheFuture + (secondsPerSlot * slotsPerEpoch) * clr.epoch);

        uint256 maxAllowedIncrease = debug_maxIncrease(
            rfv.rb,
            river.totalUnderlyingSupply(),
            debug_timeBetweenEpochs(rfv.cls, river.getLastCompletedEpochId(), clr.epoch)
        );

        uint256 stoppedTotalCount = bound(_salt, 0, rfv.depositCount);
        _salt = _next(_salt);
        uint256 exitingTotalCount = bound(_salt, 0, stoppedTotalCount);
        _salt = _next(_salt);

        uint256 totalIncrease = bound(_salt, 0, maxAllowedIncrease);
        _salt = _next(_salt);
        clr.validatorsSkimmedBalance = bound(_salt, 0, totalIncrease);
        _salt = _next(_salt);
        clr.validatorsBalance = (rfv.depositCount - (stoppedTotalCount - exitingTotalCount)) * 32 ether
            + (totalIncrease - clr.validatorsSkimmedBalance);

        clr.validatorsCount = uint32(rfv.depositCount);

        clr.validatorsExitedBalance = 32 ether * (stoppedTotalCount - exitingTotalCount);
        clr.validatorsExitingBalance = 32 ether * exitingTotalCount;

        vm.deal(address(withdraw), clr.validatorsSkimmedBalance + clr.validatorsExitedBalance);

        clr.exitedETHPerOperator = new uint256[](rfv.operatorCount + 1);

        clr.exitedETHPerOperator[0] = stoppedTotalCount * 32 ether;
        uint256 rest = stoppedTotalCount % rfv.operatorCount;
        for (uint256 idx = 0; idx < rfv.operatorCount; ++idx) {
            clr.exitedETHPerOperator[idx + 1] =
                uint256((stoppedTotalCount / rfv.operatorCount) + (rest > 0 ? 1 : 0)) * 32 ether;
            if (rest > 0) {
                --rest;
            }
        }

        clr.activeCLETHPerOperator = new uint256[](rfv.operatorCount);
        clr.rebalanceDepositToRedeemMode = false;
        clr.slashingContainmentMode = false;
        clr.totalDepositedActivatedETH = rfv.depositCount * 32 ether;

        uint256 remainingIncrease = maxAllowedIncrease - totalIncrease;
        address donator = uf._new(_salt);
        _salt = _next(_salt);
        _rawPermissions(donator, LibAllowlistMasks.DONATE_MASK);
        vm.deal(address(donator), remainingIncrease);
        vm.prank(donator);
        coverageFund.donate{value: remainingIncrease}();

        rfv.expected_pre_elFeeRecipientBalance = 0;
        rfv.expected_pre_coverageFundBalance = remainingIncrease;
        rfv.expected_pre_exceedingBufferAmount = 0;

        rfv.expected_post_elFeeRecipientBalance = 0;
        rfv.expected_post_coverageFundBalance = 0;
        rfv.expected_post_exceedingBufferAmount = 0;
        _newSalt = _salt;
    }

    function _retrieveScenario_REGULAR_REPORTING_PULL_EXCEEDING_BUFFER(
        ReportingFuzzingVariables memory rfv,
        uint256 _salt
    ) internal returns (IOracleManagerV1.ConsensusLayerReport memory clr, uint256 _newSalt) {
        uint256 expectedEpoch = river.getExpectedEpochId();
        clr.epoch = expectedEpoch + bound(_salt, 1, 1_000) * epochsPerFrame;
        _salt = _next(_salt);

        uint256 timeIntoTheFuture = bound(_salt, epochsUntilFinal * secondsPerSlot * slotsPerEpoch, 365 days);
        _salt = _next(_salt);
        vm.warp(timeIntoTheFuture + (secondsPerSlot * slotsPerEpoch) * clr.epoch);

        uint256 maxAllowedIncrease = debug_maxIncrease(
            rfv.rb,
            river.totalUnderlyingSupply(),
            debug_timeBetweenEpochs(rfv.cls, river.getLastCompletedEpochId(), clr.epoch)
        );

        uint256 stoppedTotalCount = bound(_salt, 0, rfv.depositCount);
        _salt = _next(_salt);
        uint256 exitingTotalCount = bound(_salt, 0, stoppedTotalCount);
        _salt = _next(_salt);

        uint256 totalIncrease = bound(_salt, 0, maxAllowedIncrease);
        _salt = _next(_salt);
        clr.validatorsSkimmedBalance = bound(_salt, 0, totalIncrease);
        _salt = _next(_salt);
        clr.validatorsBalance = (rfv.depositCount - (stoppedTotalCount - exitingTotalCount)) * 32 ether
            + (totalIncrease - clr.validatorsSkimmedBalance);

        clr.validatorsCount = uint32(rfv.depositCount);

        clr.validatorsExitedBalance = 32 ether * (stoppedTotalCount - exitingTotalCount);
        clr.validatorsExitingBalance = 32 ether * exitingTotalCount;

        vm.deal(address(withdraw), clr.validatorsSkimmedBalance + clr.validatorsExitedBalance);

        clr.exitedETHPerOperator = new uint256[](rfv.operatorCount + 1);

        clr.exitedETHPerOperator[0] = stoppedTotalCount * 32 ether;
        uint256 rest = stoppedTotalCount % rfv.operatorCount;
        for (uint256 idx = 0; idx < rfv.operatorCount; ++idx) {
            clr.exitedETHPerOperator[idx + 1] =
                uint256((stoppedTotalCount / rfv.operatorCount) + (rest > 0 ? 1 : 0)) * 32 ether;
            if (rest > 0) {
                --rest;
            }
        }

        clr.activeCLETHPerOperator = new uint256[](rfv.operatorCount);
        clr.rebalanceDepositToRedeemMode = false;
        clr.slashingContainmentMode = false;
        clr.totalDepositedActivatedETH = rfv.depositCount * 32 ether;

        _salt = _redeemAllSatisfiedRedeemRequests(_salt);

        rfv.expected_pre_elFeeRecipientBalance = 0;
        rfv.expected_pre_coverageFundBalance = 0;
        rfv.expected_pre_exceedingBufferAmount = redeemManager.getBufferedExceedingEth();

        rfv.expected_post_elFeeRecipientBalance = 0;
        rfv.expected_post_coverageFundBalance = 0;
        rfv.expected_post_exceedingBufferAmount = rfv.expected_pre_exceedingBufferAmount
            - LibUint256.min(rfv.expected_pre_exceedingBufferAmount, maxAllowedIncrease);
        _newSalt = _salt;
    }

    function _retrieveScenario_REGULAR_REPORTING_PULL_HALF_EL_COVERAGE(
        ReportingFuzzingVariables memory rfv,
        uint256 _salt
    ) internal returns (IOracleManagerV1.ConsensusLayerReport memory clr, uint256 _newSalt) {
        uint256 expectedEpoch = river.getExpectedEpochId();
        clr.epoch = expectedEpoch + bound(_salt, 1, 1_000) * epochsPerFrame;
        _salt = _next(_salt);

        uint256 timeIntoTheFuture = bound(_salt, epochsUntilFinal * secondsPerSlot * slotsPerEpoch, 365 days);
        _salt = _next(_salt);
        vm.warp(timeIntoTheFuture + (secondsPerSlot * slotsPerEpoch) * clr.epoch);

        uint256 stoppedTotalCount = bound(_salt, 0, rfv.depositCount);
        _salt = _next(_salt);
        uint256 exitingTotalCount = bound(_salt, 0, stoppedTotalCount);

        uint256 maxAllowedIncrease = debug_maxIncrease(
            rfv.rb,
            river.totalUnderlyingSupply(),
            debug_timeBetweenEpochs(rfv.cls, river.getLastCompletedEpochId(), clr.epoch)
        );
        uint256 totalIncrease = bound(_salt, 0, maxAllowedIncrease);
        _salt = _next(_salt);
        clr.validatorsSkimmedBalance = bound(_salt, 0, totalIncrease);
        _salt = _next(_salt);
        clr.validatorsBalance = (rfv.depositCount - (stoppedTotalCount - exitingTotalCount)) * 32 ether
            + (totalIncrease - clr.validatorsSkimmedBalance);
        {
            clr.validatorsCount = uint32(rfv.depositCount);

            clr.validatorsExitedBalance = 32 ether * (stoppedTotalCount - exitingTotalCount);
            clr.validatorsExitingBalance = 32 ether * exitingTotalCount;

            vm.deal(address(withdraw), clr.validatorsSkimmedBalance + clr.validatorsExitedBalance);

            clr.exitedETHPerOperator = new uint256[](rfv.operatorCount + 1);

            clr.exitedETHPerOperator[0] = stoppedTotalCount * 32 ether;
            uint256 rest = stoppedTotalCount % rfv.operatorCount;
            for (uint256 idx = 0; idx < rfv.operatorCount; ++idx) {
                clr.exitedETHPerOperator[idx + 1] =
                    uint256((stoppedTotalCount / rfv.operatorCount) + (rest > 0 ? 1 : 0)) * 32 ether;
                if (rest > 0) {
                    --rest;
                }
            }

            clr.activeCLETHPerOperator = new uint256[](rfv.operatorCount);
            clr.rebalanceDepositToRedeemMode = false;
            clr.slashingContainmentMode = false;
        }

        clr.totalDepositedActivatedETH = rfv.depositCount * 32 ether;
        uint256 remainingIncrease = maxAllowedIncrease - totalIncrease;
        uint256 elAmount = remainingIncrease / 2;
        uint256 coverageAmount = remainingIncrease - elAmount;
        vm.deal(address(elFeeRecipient), elAmount);

        address donator = uf._new(_salt);
        _salt = _next(_salt);
        _rawPermissions(donator, LibAllowlistMasks.DONATE_MASK);
        vm.deal(address(donator), coverageAmount);
        vm.prank(donator);
        coverageFund.donate{value: coverageAmount}();

        rfv.expected_pre_elFeeRecipientBalance = elAmount;
        rfv.expected_pre_coverageFundBalance = coverageAmount;
        rfv.expected_pre_exceedingBufferAmount = 0;

        rfv.expected_post_elFeeRecipientBalance = 0;
        rfv.expected_post_coverageFundBalance = 0;
        rfv.expected_post_exceedingBufferAmount = 0;
        _newSalt = _salt;
    }

    function _retrieveScenario_REGULAR_REPORTING_REBALANCING_MODE_ACTIVE(
        ReportingFuzzingVariables memory rfv,
        uint256 _salt
    ) internal returns (IOracleManagerV1.ConsensusLayerReport memory clr, uint256 _newSalt) {
        uint256 expectedEpoch = river.getExpectedEpochId();
        clr.epoch = expectedEpoch + bound(_salt, 1, 1_000) * epochsPerFrame;
        _salt = _next(_salt);

        uint256 timeIntoTheFuture = bound(_salt, epochsUntilFinal * secondsPerSlot * slotsPerEpoch, 365 days);
        _salt = _next(_salt);
        vm.warp(timeIntoTheFuture + (secondsPerSlot * slotsPerEpoch) * clr.epoch);

        uint256 maxAllowedIncrease = debug_maxIncrease(
            rfv.rb,
            river.totalUnderlyingSupply(),
            debug_timeBetweenEpochs(rfv.cls, river.getLastCompletedEpochId(), clr.epoch)
        );

        uint256 stoppedTotalCount = bound(_salt, 0, rfv.depositCount);
        _salt = _next(_salt);

        uint256 totalIncrease = bound(_salt, 0, maxAllowedIncrease);
        _salt = _next(_salt);
        clr.validatorsSkimmedBalance = bound(_salt, 0, totalIncrease);
        _salt = _next(_salt);
        clr.validatorsBalance = rfv.depositCount * 32 ether + (totalIncrease - clr.validatorsSkimmedBalance);

        clr.validatorsCount = uint32(rfv.depositCount);

        clr.validatorsExitedBalance = 0;
        clr.validatorsExitingBalance = 0;

        vm.deal(address(withdraw), clr.validatorsSkimmedBalance + clr.validatorsExitedBalance);

        clr.exitedETHPerOperator = new uint256[](rfv.operatorCount + 1);

        clr.exitedETHPerOperator[0] = stoppedTotalCount * 32 ether;
        uint256 rest = stoppedTotalCount % rfv.operatorCount;
        for (uint256 idx = 0; idx < rfv.operatorCount; ++idx) {
            clr.exitedETHPerOperator[idx + 1] =
                uint256((stoppedTotalCount / rfv.operatorCount) + (rest > 0 ? 1 : 0)) * 32 ether;
            if (rest > 0) {
                --rest;
            }
        }

        clr.activeCLETHPerOperator = new uint256[](rfv.operatorCount);
        clr.rebalanceDepositToRedeemMode = true;
        clr.slashingContainmentMode = false;
        clr.totalDepositedActivatedETH = rfv.depositCount * 32 ether;

        rfv.expected_pre_elFeeRecipientBalance = 0;
        rfv.expected_pre_coverageFundBalance = 0;
        rfv.expected_pre_exceedingBufferAmount = 0;

        rfv.expected_post_elFeeRecipientBalance = 0;
        rfv.expected_post_coverageFundBalance = 0;
        rfv.expected_post_exceedingBufferAmount = 0;

        _newSalt = _salt;
    }

    function _retrieveScenario_REGULAR_REPORTING_SLASHING_CONTAINMENT_ACTIVE(
        ReportingFuzzingVariables memory rfv,
        uint256 _salt
    ) internal returns (IOracleManagerV1.ConsensusLayerReport memory clr, uint256 _newSalt) {
        uint256 expectedEpoch = river.getExpectedEpochId();
        clr.epoch = expectedEpoch + bound(_salt, 1, 1_000) * epochsPerFrame;
        _salt = _next(_salt);

        uint256 timeIntoTheFuture = bound(_salt, epochsUntilFinal * secondsPerSlot * slotsPerEpoch, 365 days);
        _salt = _next(_salt);
        vm.warp(timeIntoTheFuture + (secondsPerSlot * slotsPerEpoch) * clr.epoch);

        uint256 maxAllowedIncrease = debug_maxIncrease(
            rfv.rb,
            river.totalUnderlyingSupply(),
            debug_timeBetweenEpochs(rfv.cls, river.getLastCompletedEpochId(), clr.epoch)
        );

        uint256 stoppedTotalCount = bound(_salt, 0, rfv.depositCount);
        _salt = _next(_salt);

        uint256 totalIncrease = bound(_salt, 0, maxAllowedIncrease);
        _salt = _next(_salt);
        clr.validatorsSkimmedBalance = bound(_salt, 0, totalIncrease);
        _salt = _next(_salt);
        clr.validatorsBalance = rfv.depositCount * 32 ether - (stoppedTotalCount * 32 ether)
            + (totalIncrease - clr.validatorsSkimmedBalance);

        clr.validatorsCount = uint32(rfv.depositCount);

        clr.validatorsExitedBalance = stoppedTotalCount * 32 ether;
        clr.validatorsExitingBalance = 0;

        vm.deal(address(withdraw), clr.validatorsSkimmedBalance + clr.validatorsExitedBalance);

        clr.exitedETHPerOperator = new uint256[](rfv.operatorCount + 1);

        clr.exitedETHPerOperator[0] = stoppedTotalCount * 32 ether;
        uint256 rest = stoppedTotalCount % rfv.operatorCount;
        for (uint256 idx = 0; idx < rfv.operatorCount; ++idx) {
            clr.exitedETHPerOperator[idx + 1] =
                uint256((stoppedTotalCount / rfv.operatorCount) + (rest > 0 ? 1 : 0)) * 32 ether;
            if (rest > 0) {
                --rest;
            }
        }

        clr.activeCLETHPerOperator = new uint256[](rfv.operatorCount);
        clr.rebalanceDepositToRedeemMode = false;
        clr.slashingContainmentMode = true;
        clr.totalDepositedActivatedETH = rfv.depositCount * 32 ether;

        rfv.expected_pre_elFeeRecipientBalance = 0;
        rfv.expected_pre_coverageFundBalance = 0;
        rfv.expected_pre_exceedingBufferAmount = 0;

        rfv.expected_post_elFeeRecipientBalance = 0;
        rfv.expected_post_coverageFundBalance = 0;
        rfv.expected_post_exceedingBufferAmount = 0;

        _newSalt = _salt;
    }

    function _updateAssertions_REGULAR_REPORTING_SLASHING_CONTAINMENT_ACTIVE(
        ReportingFuzzingVariables memory,
        IOracleManagerV1.ConsensusLayerReport memory clr,
        uint256
    ) internal {
        uint256[] memory exitedETHPerOperator = clr.exitedETHPerOperator;
        for (uint256 idx = 0; idx < operatorsRegistry.getOperatorCount(); ++idx) {
            OperatorsV3.Operator memory op = operatorsRegistry.getOperator(idx);
            if (exitedETHPerOperator.length - 1 > idx) {
                assertEq(op.requestedExits, exitedETHPerOperator[idx + 1]);
            } else {
                assertEq(op.requestedExits, 0);
            }
        }
    }

    function debug_maxIncrease(ReportBounds.ReportBoundsStruct memory rb, uint256 _prevTotalEth, uint256 _timeElapsed)
        internal
        pure
        returns (uint256)
    {
        return (_prevTotalEth * rb.annualAprUpperBound * _timeElapsed) / (LibBasisPoints.BASIS_POINTS_MAX * 365 days);
    }

    function debug_maxDecrease(ReportBounds.ReportBoundsStruct memory rb, uint256 _prevTotalEth)
        internal
        pure
        returns (uint256)
    {
        return (_prevTotalEth * rb.relativeLowerBound) / LibBasisPoints.BASIS_POINTS_MAX;
    }

    function debug_timeBetweenEpochs(CLSpec.CLSpecStruct memory cls, uint256 epochPast, uint256 epochNow)
        internal
        pure
        returns (uint256)
    {
        return (epochNow - epochPast) * (cls.secondsPerSlot * cls.slotsPerEpoch);
    }

    function _generateEmptyReport() internal pure returns (IOracleManagerV1.ConsensusLayerReport memory clr) {
        clr.exitedETHPerOperator = new uint256[](1);
        clr.exitedETHPerOperator[0] = 0;
        // _reportCLETH reverts with InvalidEmptyArray() if this is empty;
        // all callers first invoke _depositValidators which adds operator at index 0.
        clr.activeCLETHPerOperator = new uint256[](1);
    }

    function testReportingError_Unauthorized(uint256 _salt) external {
        address random = uf._new(_salt);
        IOracleManagerV1.ConsensusLayerReport memory clr = _generateEmptyReport();

        vm.prank(random);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", random));
        _fillReport(clr);
        river.setConsensusLayerData(clr);
    }

    function testReportingError_InvalidEpoch(uint256 _salt) external {
        IOracleManagerV1.ConsensusLayerReport memory clr = _generateEmptyReport();

        clr.epoch = (bound(_salt, 0, type(uint128).max) * epochsPerFrame) + 1;
        vm.warp((clr.epoch + epochsUntilFinal) * (secondsPerSlot * slotsPerEpoch));

        vm.prank(address(oracle));
        vm.expectRevert(abi.encodeWithSignature("InvalidEpoch(uint256)", clr.epoch));
        _fillReport(clr);
        river.setConsensusLayerData(clr);
    }

    function _depositValidators(uint256 count, uint256 _salt) internal returns (uint256) {
        address depositor = uf._new(_salt);
        _salt = _next(_salt);
        _allow(depositor);
        vm.deal(depositor, count * 32 ether);
        vm.prank(depositor);
        river.deposit{value: count * 32 ether}();

        address operator = uf._new(_salt);
        _salt = _next(_salt);
        string memory operatorName = string(abi.encode(_salt));
        _salt = _next(_salt);

        vm.prank(admin);
        uint256 operatorIndex = operatorsRegistry.addOperator(operatorName, operator);

        river.debug_moveDepositToCommitted();

        // Deposit via attestation for this single operator
        _depositToConsensusLayer(operatorIndex, uint32(count));

        return _salt;
    }

    function testReportingError_InvalidDecreasingValidatorsExitedBalance(uint256 _salt) external {
        uint8 depositCount = uint8(bound(_salt, 2, 32));
        IOracleManagerV1.ConsensusLayerReport memory clr = _generateEmptyReport();

        clr.epoch = bound(_salt, 1, type(uint128).max) * epochsPerFrame;
        vm.warp((clr.epoch + epochsUntilFinal) * (secondsPerSlot * slotsPerEpoch));
        _salt = _depositValidators(depositCount, _salt);

        clr.validatorsCount = depositCount;
        clr.validatorsBalance = 32 ether * (depositCount - 1);
        clr.validatorsExitingBalance = 0;
        clr.validatorsSkimmedBalance = 0;
        clr.validatorsExitedBalance = 32 ether;
        clr.totalDepositedActivatedETH = uint256(depositCount) * 32 ether;

        vm.deal(address(withdraw), 32 ether);

        vm.prank(address(oracle));
        _fillReport(clr);
        river.setConsensusLayerData(clr);

        clr.epoch += epochsPerFrame;
        vm.warp((clr.epoch + epochsUntilFinal) * (secondsPerSlot * slotsPerEpoch));
        clr.validatorsBalance = 32 ether * (depositCount);
        clr.validatorsExitedBalance = 0;

        vm.prank(address(oracle));
        vm.expectRevert(
            abi.encodeWithSignature("InvalidDecreasingValidatorsExitedBalance(uint256,uint256)", 32 ether, 0)
        );
        _fillReport(clr);
        river.setConsensusLayerData(clr);
    }

    function testReportingError_InvalidDecreasingValidatorsSkimmedBalance(uint256 _salt) external {
        uint8 depositCount = uint8(bound(_salt, 2, 32));
        IOracleManagerV1.ConsensusLayerReport memory clr = _generateEmptyReport();

        clr.epoch = bound(_salt, 1, type(uint128).max) * epochsPerFrame;
        vm.warp((clr.epoch + epochsUntilFinal) * (secondsPerSlot * slotsPerEpoch));
        _salt = _depositValidators(depositCount, _salt);

        clr.validatorsCount = depositCount;
        clr.validatorsBalance = 32 ether * (depositCount) - 1 ether;
        clr.validatorsExitingBalance = 0;
        clr.validatorsSkimmedBalance = 1 ether;
        clr.validatorsExitedBalance = 0;
        clr.totalDepositedActivatedETH = uint256(depositCount) * 32 ether;

        vm.deal(address(withdraw), 1 ether);

        vm.prank(address(oracle));
        _fillReport(clr);
        river.setConsensusLayerData(clr);

        clr.epoch += epochsPerFrame;
        vm.warp((clr.epoch + epochsUntilFinal) * (secondsPerSlot * slotsPerEpoch));
        clr.validatorsBalance = 32 ether * (depositCount) - 1 ether;
        clr.validatorsSkimmedBalance = 0;

        vm.prank(address(oracle));
        vm.expectRevert(
            abi.encodeWithSignature("InvalidDecreasingValidatorsSkimmedBalance(uint256,uint256)", 1 ether, 0)
        );
        _fillReport(clr);
        river.setConsensusLayerData(clr);
    }

    function testReportingError_TotalValidatorBalanceIncreaseOutOfBound(uint256 _salt) external {
        uint8 depositCount = uint8(bound(_salt, 2, 32));
        IOracleManagerV1.ConsensusLayerReport memory clr = _generateEmptyReport();

        clr.epoch = bound(_salt, 1, type(uint128).max) * epochsPerFrame;
        vm.warp((clr.epoch + epochsUntilFinal) * (secondsPerSlot * slotsPerEpoch));
        _salt = _depositValidators(depositCount, _salt);

        clr.validatorsCount = depositCount;
        clr.validatorsBalance = 32 ether * (depositCount);
        clr.validatorsExitingBalance = 0;
        clr.validatorsSkimmedBalance = 0;
        clr.validatorsExitedBalance = 0;
        clr.totalDepositedActivatedETH = uint256(depositCount) * 32 ether;

        _salt = _next(_salt);
        uint256 framesBetween = bound(_salt, 1, 1_000_000);
        uint256 timeBetween = framesBetween * secondsPerSlot * slotsPerEpoch * epochsPerFrame;
        uint256 maxIncrease = debug_maxIncrease(river.getReportBounds(), river.totalUnderlyingSupply(), timeBetween);

        console.log(maxIncrease);

        vm.prank(address(oracle));
        _fillReport(clr);
        river.setConsensusLayerData(clr);

        clr.epoch += framesBetween * epochsPerFrame;
        vm.warp((clr.epoch + epochsUntilFinal) * (secondsPerSlot * slotsPerEpoch));
        clr.validatorsBalance += maxIncrease + 1;

        vm.expectRevert(
            abi.encodeWithSignature(
                "TotalValidatorBalanceIncreaseOutOfBound(uint256,uint256,uint256,uint256)",
                32 ether * depositCount,
                32 ether * depositCount + maxIncrease + 1,
                timeBetween,
                river.getReportBounds().annualAprUpperBound
            )
        );
        vm.prank(address(oracle));
        _fillReport(clr);
        river.setConsensusLayerData(clr);
    }

    function testReportingError_TotalValidatorBalanceDecreaseOutOfBound(uint256 _salt) external {
        uint8 depositCount = uint8(bound(_salt, 2, 32));
        IOracleManagerV1.ConsensusLayerReport memory clr = _generateEmptyReport();

        clr.epoch = bound(_salt, 1, type(uint128).max) * epochsPerFrame;
        vm.warp((clr.epoch + epochsUntilFinal) * (secondsPerSlot * slotsPerEpoch));
        _salt = _depositValidators(depositCount, _salt);

        clr.validatorsCount = depositCount;
        clr.validatorsBalance = 32 ether * (depositCount);
        clr.validatorsExitingBalance = 0;
        clr.validatorsSkimmedBalance = 0;
        clr.validatorsExitedBalance = 0;
        clr.totalDepositedActivatedETH = uint256(depositCount) * 32 ether;

        _salt = _next(_salt);
        uint256 framesBetween = bound(_salt, 1, 1_000_000);
        uint256 timeBetween = framesBetween * secondsPerSlot * slotsPerEpoch * epochsPerFrame;
        uint256 maxDecrease = debug_maxDecrease(river.getReportBounds(), river.totalUnderlyingSupply());

        vm.prank(address(oracle));
        _fillReport(clr);
        river.setConsensusLayerData(clr);

        clr.epoch += framesBetween * epochsPerFrame;
        vm.warp((clr.epoch + epochsUntilFinal) * (secondsPerSlot * slotsPerEpoch));
        clr.validatorsBalance -= maxDecrease + 1;

        vm.expectRevert(
            abi.encodeWithSignature(
                "TotalValidatorBalanceDecreaseOutOfBound(uint256,uint256,uint256,uint256)",
                32 ether * depositCount,
                32 ether * depositCount - (maxDecrease + 1),
                timeBetween,
                river.getReportBounds().relativeLowerBound
            )
        );
        vm.prank(address(oracle));
        _fillReport(clr);
        river.setConsensusLayerData(clr);
    }

    function testReportingError_InvalidPulledClFundsAmount(uint256 _salt) external {
        uint8 depositCount = uint8(bound(_salt, 2, 32));
        uint256 skimmedAmount = bound(_salt, 1 ether, 100 ether);
        _salt = _next(_salt);
        uint256 notEnoughAmount = bound(_salt, 0, skimmedAmount - 1);
        IOracleManagerV1.ConsensusLayerReport memory clr = _generateEmptyReport();

        clr.epoch = bound(_salt, 1, type(uint128).max) * epochsPerFrame;
        vm.warp((clr.epoch + epochsUntilFinal) * (secondsPerSlot * slotsPerEpoch));
        _salt = _depositValidators(depositCount, _salt);

        clr.validatorsCount = depositCount;
        clr.validatorsBalance = 32 ether * (depositCount);
        clr.validatorsExitingBalance = 0;
        clr.validatorsSkimmedBalance = skimmedAmount;
        clr.validatorsExitedBalance = 0;
        clr.totalDepositedActivatedETH = uint256(depositCount) * 32 ether;

        vm.deal(address(withdraw), notEnoughAmount);

        vm.prank(address(oracle));
        vm.expectRevert(
            abi.encodeWithSignature("InvalidPulledClFundsAmount(uint256,uint256)", skimmedAmount, notEnoughAmount)
        );
        _fillReport(clr);
        river.setConsensusLayerData(clr);
    }

    function testReportingError_StoppedValidatorCountDecreasing(uint256 _salt) external {
        uint8 depositCount = uint8(bound(_salt, 2, 32));
        IOracleManagerV1.ConsensusLayerReport memory clr = _generateEmptyReport();

        _salt = _depositValidators(depositCount, _salt);
        // Pre-initialize storage so _setExitedETH can access currentExitedETH[1] without panicking,
        // and set activeCLETH so the operator has enough active-CL headroom (deltaExited = 2*32 ether).
        operatorsRegistry.sudoSetRawExitedETH(new uint256[](2));
        operatorsRegistry.sudoSetActiveCLETH(0, uint256(depositCount) * 32 ether);

        _salt = _next(_salt);
        uint256 framesBetween = bound(_salt, 1, 1_000_000);
        uint256 timeBetween = framesBetween * secondsPerSlot * slotsPerEpoch * epochsPerFrame;
        uint256 maxIncrease = debug_maxIncrease(river.getReportBounds(), river.totalUnderlyingSupply(), timeBetween);

        clr.validatorsCount = depositCount;
        clr.validatorsBalance = 32 ether * (depositCount);
        clr.validatorsExitingBalance = 0;
        clr.validatorsSkimmedBalance = maxIncrease;
        clr.validatorsExitedBalance = 0;
        clr.totalDepositedActivatedETH = uint256(depositCount) * 32 ether;
        clr.epoch = framesBetween * epochsPerFrame;
        clr.exitedETHPerOperator = new uint256[](2);
        clr.exitedETHPerOperator[0] = 2 * 32 ether;
        clr.exitedETHPerOperator[1] = 2 * 32 ether;
        vm.warp((clr.epoch + epochsUntilFinal) * (secondsPerSlot * slotsPerEpoch));

        vm.deal(address(withdraw), maxIncrease);

        vm.prank(address(oracle));
        _fillReport(clr);
        river.setConsensusLayerData(clr);

        clr.epoch += epochsPerFrame;
        clr.exitedETHPerOperator[0] = 1 * 32 ether;
        clr.exitedETHPerOperator[1] = 1 * 32 ether;
        vm.warp((clr.epoch + epochsUntilFinal) * (secondsPerSlot * slotsPerEpoch));

        vm.prank(address(oracle));
        vm.expectRevert(abi.encodeWithSignature("ExitedETHPerOperatorDecreased()"));
        _fillReport(clr);
        river.setConsensusLayerData(clr);
    }

    function _computeCommittedAmount(
        uint256 epochStart,
        uint256 epochReported,
        uint256 initialCommittedAmount,
        uint256 initialDepositAmount,
        uint256 extraBalanceToDeposit
    ) internal view returns (uint256) {
        uint256 period = (epochReported - epochStart) * slotsPerEpoch * secondsPerSlot;
        uint256 maxCommittedBalanceDailyIncrease = LibUint256.max(
            maxDailyNetCommittableAmount,
            ((river.totalUnderlyingSupply() - initialDepositAmount) * maxDailyRelativeCommittableAmount)
                / LibBasisPoints.BASIS_POINTS_MAX
        );
        uint256 maxCommittedBalanceIncrease = LibUint256.min(
            extraBalanceToDeposit,
            LibUint256.min(river.totalUnderlyingSupply(), (maxCommittedBalanceDailyIncrease * period) / 1 days)
        );

        maxCommittedBalanceIncrease = (maxCommittedBalanceIncrease / 1 gwei) * 1 gwei;

        return initialCommittedAmount + maxCommittedBalanceIncrease;
    }

    function testReportingSuccess_AssertCommittedAmountAfterSkimming(uint256 _salt) external {
        uint8 depositCount = uint8(bound(_salt, 2, 32));
        IOracleManagerV1.ConsensusLayerReport memory clr = _generateEmptyReport();

        _salt = _depositValidators(depositCount, _salt);

        _salt = _next(_salt);
        uint256 framesBetween = bound(_salt, 1, 1_000_000);
        uint256 timeBetween = framesBetween * secondsPerSlot * slotsPerEpoch * epochsPerFrame;
        uint256 maxIncrease = debug_maxIncrease(river.getReportBounds(), river.totalUnderlyingSupply(), timeBetween);

        clr.validatorsCount = depositCount;
        clr.validatorsBalance = 32 ether * (depositCount);
        clr.validatorsExitingBalance = 0;
        clr.validatorsSkimmedBalance = maxIncrease;
        clr.validatorsExitedBalance = 0;
        clr.totalDepositedActivatedETH = uint256(depositCount) * 32 ether;
        clr.epoch = framesBetween * epochsPerFrame;
        vm.warp((clr.epoch + epochsUntilFinal) * (secondsPerSlot * slotsPerEpoch));

        vm.deal(address(withdraw), maxIncrease);

        uint256 committedAmount = river.getCommittedBalance();
        uint256 depositAmount = river.getBalanceToDeposit();

        vm.prank(address(oracle));
        _fillReport(clr);
        river.setConsensusLayerData(clr);

        assertEq(
            river.getCommittedBalance(),
            _computeCommittedAmount(0, clr.epoch, committedAmount, depositAmount, maxIncrease)
        );
    }

    function testReportingSuccess_AssertCommittedAmountAfterELFees(uint256 _salt) external {
        uint8 depositCount = uint8(bound(_salt, 2, 32));
        IOracleManagerV1.ConsensusLayerReport memory clr = _generateEmptyReport();

        _salt = _depositValidators(depositCount, _salt);

        _salt = _next(_salt);
        uint256 framesBetween = bound(_salt, 1, 1_000_000);
        uint256 timeBetween = framesBetween * secondsPerSlot * slotsPerEpoch * epochsPerFrame;
        uint256 maxIncrease = debug_maxIncrease(river.getReportBounds(), river.totalUnderlyingSupply(), timeBetween);

        clr.validatorsCount = depositCount;
        clr.validatorsBalance = 32 ether * (depositCount);
        clr.validatorsExitingBalance = 0;
        clr.validatorsSkimmedBalance = 0;
        clr.validatorsExitedBalance = 0;
        clr.totalDepositedActivatedETH = uint256(depositCount) * 32 ether;
        clr.epoch = framesBetween * epochsPerFrame;
        vm.warp((clr.epoch + epochsUntilFinal) * (secondsPerSlot * slotsPerEpoch));

        vm.deal(address(elFeeRecipient), maxIncrease);

        uint256 committedAmount = river.getCommittedBalance();
        uint256 depositAmount = river.getBalanceToDeposit();

        vm.prank(address(oracle));
        _fillReport(clr);
        river.setConsensusLayerData(clr);

        assertEq(
            river.getCommittedBalance(),
            _computeCommittedAmount(0, clr.epoch, committedAmount, depositAmount, maxIncrease)
        );
    }

    function testReportingSuccess_AssertCommittedAmountAfterCoverage(uint256 _salt) external {
        uint8 depositCount = uint8(bound(_salt, 2, 32));
        IOracleManagerV1.ConsensusLayerReport memory clr = _generateEmptyReport();

        _salt = _depositValidators(depositCount, _salt);

        _salt = _next(_salt);
        uint256 framesBetween = bound(_salt, 1, 1_000_000);
        uint256 timeBetween = framesBetween * secondsPerSlot * slotsPerEpoch * epochsPerFrame;
        uint256 maxIncrease = debug_maxIncrease(river.getReportBounds(), river.totalUnderlyingSupply(), timeBetween);

        clr.validatorsCount = depositCount;
        clr.validatorsBalance = 32 ether * (depositCount);
        clr.validatorsExitingBalance = 0;
        clr.validatorsSkimmedBalance = 0;
        clr.validatorsExitedBalance = 0;
        clr.totalDepositedActivatedETH = uint256(depositCount) * 32 ether;
        clr.epoch = framesBetween * epochsPerFrame;
        vm.warp((clr.epoch + epochsUntilFinal) * (secondsPerSlot * slotsPerEpoch));

        address donator = uf._new(_salt);
        _salt = _next(_salt);
        _rawPermissions(donator, LibAllowlistMasks.DONATE_MASK);
        vm.deal(address(donator), maxIncrease);
        vm.prank(donator);
        coverageFund.donate{value: maxIncrease}();

        uint256 committedAmount = river.getCommittedBalance();
        uint256 depositAmount = river.getBalanceToDeposit();

        vm.prank(address(oracle));
        _fillReport(clr);
        river.setConsensusLayerData(clr);

        assertEq(
            river.getCommittedBalance(),
            _computeCommittedAmount(0, clr.epoch, committedAmount, depositAmount, maxIncrease)
        );
    }

    function testReportingSuccess_AssertCommittedAmountAfterMultiPulling(uint256 _salt) external {
        uint8 depositCount = uint8(bound(_salt, 2, 32));
        IOracleManagerV1.ConsensusLayerReport memory clr = _generateEmptyReport();

        _salt = _depositValidators(depositCount, _salt);

        _salt = _next(_salt);
        uint256 framesBetween = bound(_salt, 1, 1_000_000);
        uint256 timeBetween = framesBetween * secondsPerSlot * slotsPerEpoch * epochsPerFrame;
        uint256 maxIncrease = debug_maxIncrease(river.getReportBounds(), river.totalUnderlyingSupply(), timeBetween);

        clr.validatorsCount = depositCount;
        clr.validatorsBalance = 32 ether * (depositCount);
        clr.validatorsExitingBalance = 0;
        clr.validatorsSkimmedBalance = maxIncrease / 3;
        clr.validatorsExitedBalance = 0;
        clr.totalDepositedActivatedETH = uint256(depositCount) * 32 ether;
        clr.epoch = framesBetween * epochsPerFrame;
        vm.warp((clr.epoch + epochsUntilFinal) * (secondsPerSlot * slotsPerEpoch));

        vm.deal(address(elFeeRecipient), maxIncrease / 3);
        vm.deal(address(withdraw), maxIncrease / 3);

        address donator = uf._new(_salt);
        _salt = _next(_salt);
        _rawPermissions(donator, LibAllowlistMasks.DONATE_MASK);
        vm.deal(address(donator), maxIncrease - (maxIncrease / 3) * 2);
        vm.prank(donator);
        coverageFund.donate{value: maxIncrease - (maxIncrease / 3) * 2}();

        uint256 committedAmount = river.getCommittedBalance();
        uint256 depositAmount = river.getBalanceToDeposit();

        vm.prank(address(oracle));
        _fillReport(clr);
        river.setConsensusLayerData(clr);

        assertEq(
            river.getCommittedBalance(),
            _computeCommittedAmount(0, clr.epoch, committedAmount, depositAmount, maxIncrease)
        );
    }

    function testExternalViewFunctions() public {
        assertEq(block.timestamp, river.getTime());
        assertEq(address(redeemManager), river.getRedeemManager());
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// River coverage tests (100% for changed contracts, no CoverageGaps)
// ─────────────────────────────────────────────────────────────────────────────

contract RiverV1CoverageTests is RiverV1TestBase {
    RedeemManagerV1WithLegacyInit internal redeemManager;

    bytes32 constant DEPOSITED_VALIDATOR_COUNT_SLOT =
        bytes32(uint256(keccak256("river.state.depositedValidatorCount")) - 1);
    bytes32 constant IN_FLIGHT_DEPOSIT_SLOT = bytes32(uint256(keccak256("river.state.inFlightDeposit")) - 1);
    bytes32 constant BUFFERED_EXCEEDING_ETH_SLOT = bytes32(uint256(keccak256("river.state.bufferedExceedingEth")) - 1);
    bytes32 constant CONSOLIDATION_BUFFER_SLOT = bytes32(uint256(keccak256("river.state.consolidationBuffer")) - 1);
    bytes32 constant BALANCE_FOR_CONSOLIDATION_COVERAGE_SLOT =
        bytes32(uint256(keccak256("river.state.balanceForConsolidationCoverage")) - 1);
    bytes32 constant EXTERNAL_CONSOLIDATION_RECIPIENT_MAPPING_ADDRESS_SLOT =
        bytes32(uint256(keccak256("river.state.externalConsolidationRecipientMappingAddress")) - 1);
    bytes32 constant CONSOLIDATOR_ADDRESS_SLOT = bytes32(uint256(keccak256("river.state.consolidatorAddress")) - 1);

    event PulledConsolidationCoverageFunds(uint256 amount);
    event SetConsolidationBuffer(uint256 oldAmount, uint256 newAmount);
    event StoppedEarningExceededMarkableDemand(uint256 reportedLsETH, uint256 markedLsETH);

    // ── Layout-safe seeding of river's StoredConsensusLayerReport ──
    // Rather than hard-code a struct field's slot offset (which silently breaks on any reorder or
    // repack), each seeder writes the field then reads it back through the typed getter and asserts
    // it landed correctly, so a layout change fails loudly here instead of corrupting the test. The
    // base slot is taken from the state library itself, so there is a single source of truth (no
    // duplicated keccak literal). Note: forge-std's stdstore cannot be used for validatorsCount,
    // which shares a packed slot with two bools (stdstore reverts on packed slots).
    function _clrBaseSlot() private view returns (uint256 base) {
        IOracleManagerV1.StoredConsensusLayerReport storage r = LastConsensusLayerReport.get();
        // solhint-disable-next-line no-inline-assembly
        assembly {
            base := r.slot
        }
    }

    function _seedStoredValidatorsBalance(uint256 v) private {
        vm.store(address(river), bytes32(_clrBaseSlot() + 1), bytes32(v));
        assertEq(river.getCLValidatorTotalBalance(), v, "clr.validatorsBalance slot drifted");
    }

    function _seedStoredValidatorsCount(uint32 v) private {
        // validatorsCount is a uint32 packed at the low bytes of its slot; the two report-mode bools
        // sharing the slot are reset to false, matching the prior raw-store behaviour.
        vm.store(address(river), bytes32(_clrBaseSlot() + 5), bytes32(uint256(v)));
        assertEq(river.getCLValidatorCount(), v, "clr.validatorsCount slot drifted");
    }

    function _seedStoredTotalDepositedActivatedETH(uint256 v) private {
        vm.store(address(river), bytes32(_clrBaseSlot() + 6), bytes32(v));
        assertEq(
            river.getLastConsensusLayerReport().totalDepositedActivatedETH,
            v,
            "clr.totalDepositedActivatedETH slot drifted"
        );
    }

    function _seedStoredConsolidations(uint256 v) private {
        vm.store(address(river), bytes32(_clrBaseSlot() + 7), bytes32(v));
        assertEq(
            river.getLastConsensusLayerReport().totalExternalConsolidationETH,
            v,
            "clr.totalExternalConsolidationETH slot drifted"
        );
    }

    /// @dev Warp to a timestamp at which `epoch` is finalized, honoring the configured genesisTime so
    ///      these tests stay correct even if the River setup ever uses a non-zero genesisTime.
    function _warpToFinalizedEpoch(uint256 epoch) private {
        vm.warp(river.getCLSpec().genesisTime + (epoch + epochsUntilFinal) * slotsPerEpoch * secondsPerSlot);
    }

    /// @dev Helper: deploy and init an AttestationVerifier pointed at this test's River.
    function _deployValidatorFor(address _river) internal returns (AttestationVerifierV1 v) {
        address[] memory _rootAttesters_ = new address[](2);
        _rootAttesters_[0] = makeAddr("rootAttester1");
        _rootAttesters_[1] = makeAddr("rootAttester2");
        address[] memory _consolidationCommitteeAttesters_ = new address[](1);
        _consolidationCommitteeAttesters_[0] = makeAddr("consolidationCommitteeAttesterStub");
        v = new AttestationVerifierV1();
        LibImplementationUnbricker.unbrick(vm, address(v));
        v.initAttestationVerifierV1(
            _river, makeAddr("depositBuffer"), _rootAttesters_, 1, bytes4(0), _consolidationCommitteeAttesters_, 1
        );
    }

    /// Asserts that initRiverV1_3 sets in-flight deposit when reported validator count is less than deposited count.
    function testInitRiverV1_3WithInFlightValidators() public {
        _initRiverAndV1_2();
        // 10 deposited validators, 7 reported -> 3 in flight.
        vm.store(address(river), DEPOSITED_VALIDATOR_COUNT_SLOT, bytes32(uint256(10)));
        _seedStoredValidatorsCount(7);
        AttestationVerifierV1 v = _deployValidatorFor(address(river));
        bytes32 wc = withdraw.getCredentials();
        vm.prank(admin);
        river.initRiverV1_3(
            wc,
            address(consolidationCoverageFund),
            address(v),
            address(externalConsolidationRecipientMapping),
            consolidator
        );
        assertEq(river.getTotalDepositedETH(), 10 * 32 ether);
        assertEq(uint256(vm.load(address(river), IN_FLIGHT_DEPOSIT_SLOT)), 3 * 32 ether);
        assertEq(
            address(uint160(uint256(vm.load(address(river), EXTERNAL_CONSOLIDATION_RECIPIENT_MAPPING_ADDRESS_SLOT)))),
            address(externalConsolidationRecipientMapping)
        );
        assertEq(address(uint160(uint256(vm.load(address(river), CONSOLIDATOR_ADDRESS_SLOT)))), consolidator);
        assertEq(river.getConsolidator(), consolidator);
    }

    /// Asserts that initRiverV1_3 leaves in-flight deposit zero when reported count equals deposited count.
    function testInitRiverV1_3NoInFlight() public {
        _initRiverAndV1_2();
        vm.store(address(river), DEPOSITED_VALIDATOR_COUNT_SLOT, bytes32(uint256(5)));
        _seedStoredValidatorsCount(5);
        AttestationVerifierV1 v = _deployValidatorFor(address(river));
        bytes32 wc = withdraw.getCredentials();
        vm.prank(admin);
        river.initRiverV1_3(
            wc,
            address(consolidationCoverageFund),
            address(v),
            address(externalConsolidationRecipientMapping),
            consolidator
        );
        assertEq(river.getTotalDepositedETH(), 5 * 32 ether);
        assertEq(uint256(vm.load(address(river), IN_FLIGHT_DEPOSIT_SLOT)), 0);
        assertEq(
            address(uint160(uint256(vm.load(address(river), EXTERNAL_CONSOLIDATION_RECIPIENT_MAPPING_ADDRESS_SLOT)))),
            address(externalConsolidationRecipientMapping)
        );
    }

    /// Asserts that initRiverV1_3 reverts when the attestation verifier address is zero.
    function testInitRiverV1_3RevertsOnZeroVerifier() public {
        _initRiverAndV1_2();
        bytes32 wc = withdraw.getCredentials();
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSignature("InvalidAttestationVerifier()"));
        river.initRiverV1_3(
            wc,
            address(consolidationCoverageFund),
            address(0),
            address(externalConsolidationRecipientMapping),
            consolidator
        );
    }

    /// Asserts that initRiverV1_3 reverts when the attestation verifier address is an EOA (no code).
    function testInitRiverV1_3RevertsOnEoaVerifier() public {
        _initRiverAndV1_2();
        bytes32 wc = withdraw.getCredentials();
        address eoa = makeAddr("eoaVerifier");
        // sanity: makeAddr returns an address with no deployed code
        assertEq(eoa.code.length, 0);
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSignature("InvalidAttestationVerifier()"));
        river.initRiverV1_3(
            wc, address(consolidationCoverageFund), eoa, address(externalConsolidationRecipientMapping), consolidator
        );
    }

    /// Asserts that initRiverV1_3 reverts when the verifier is bound to a different River.
    function testInitRiverV1_3RevertsOnVerifierBoundToWrongRiver() public {
        _initRiverAndV1_2();
        AttestationVerifierV1 v = _deployValidatorFor(makeAddr("otherRiver"));
        bytes32 wc = withdraw.getCredentials();
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSignature("InvalidAttestationVerifier()"));
        river.initRiverV1_3(
            wc,
            address(consolidationCoverageFund),
            address(v),
            address(externalConsolidationRecipientMapping),
            consolidator
        );
    }

    /// Asserts that initRiverV1_3 rejects zero withdrawal credentials before storing V1_3 dependencies.
    function testInitRiverV1_3RevertsOnZeroWithdrawalCredentials() public {
        _initRiverAndV1_2();
        AttestationVerifierV1 v = _deployValidatorFor(address(river));
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSignature("InvalidWithdrawalCredentials()"));
        river.initRiverV1_3(
            bytes32(0),
            address(consolidationCoverageFund),
            address(v),
            address(externalConsolidationRecipientMapping),
            consolidator
        );
    }

    /// Asserts that initRiverV1_3 reverts when the external consolidation recipient mapping address is zero.
    function testInitRiverV1_3RevertsOnZeroExternalConsolidationRecipientMapping() public {
        _initRiverAndV1_2();
        AttestationVerifierV1 v = _deployValidatorFor(address(river));
        bytes32 wc = withdraw.getCredentials();
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSignature("InvalidZeroAddress()"));
        river.initRiverV1_3(wc, address(consolidationCoverageFund), address(v), address(0), consolidator);
    }

    /// Asserts that initRiverV1_3 reverts when the consolidator address is zero.
    function testInitRiverV1_3RevertsOnZeroConsolidator() public {
        _initRiverAndV1_2();
        AttestationVerifierV1 v = _deployValidatorFor(address(river));
        bytes32 wc = withdraw.getCredentials();
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSignature("InvalidZeroAddress()"));
        river.initRiverV1_3(
            wc,
            address(consolidationCoverageFund),
            address(v),
            address(externalConsolidationRecipientMapping),
            address(0)
        );
    }

    /// Asserts that AttestationVerifier init reverts on an empty root attester array.
    function testInitAttestationVerifierRevertsOnEmptyRootAttesters() public {
        _initRiverAndV1_2();
        address[] memory _consolidationCommitteeAttesters_ = new address[](1);
        _consolidationCommitteeAttesters_[0] = makeAddr("consolidationCommitteeAttesterStub");
        address[] memory _rootAttesters_ = new address[](0);
        AttestationVerifierV1 v = new AttestationVerifierV1();
        LibImplementationUnbricker.unbrick(vm, address(v));
        vm.expectRevert(abi.encodeWithSignature("InvalidArgument()"));
        v.initAttestationVerifierV1(
            address(river),
            makeAddr("depositBuffer"),
            _rootAttesters_,
            1,
            bytes4(0),
            _consolidationCommitteeAttesters_,
            1
        );
    }

    /// Asserts that AttestationVerifier init reverts when the root attesters array exceeds MAX_ROOT_ATTESTERS.
    function testInitAttestationVerifierRevertsOnTooManyRootAttesters() public {
        _initRiverAndV1_2();
        AttestationVerifierV1 v = new AttestationVerifierV1();
        LibImplementationUnbricker.unbrick(vm, address(v));
        uint256 tooMany = v.MAX_ROOT_ATTESTERS() + 1;
        address[] memory _rootAttesters_ = new address[](tooMany);
        for (uint256 i = 0; i < tooMany; i++) {
            _rootAttesters_[i] = address(uint160(i + 1));
        }
        address[] memory _consolidationCommitteeAttesters_ = new address[](1);
        _consolidationCommitteeAttesters_[0] = makeAddr("consolidationCommitteeAttesterStub");
        vm.expectRevert(abi.encodeWithSignature("InvalidArgument()"));
        v.initAttestationVerifierV1(
            address(river),
            makeAddr("depositBuffer"),
            _rootAttesters_,
            1,
            bytes4(0),
            _consolidationCommitteeAttesters_,
            1
        );
    }

    /// Asserts that initRiverV1_3 reverts when withdrawal credentials have an invalid prefix.
    function testInitRiverV1_3RevertsOnInvalidWithdrawalCredentialsPrefix() public {
        _initRiverAndV1_2();
        AttestationVerifierV1 v = _deployValidatorFor(address(river));
        bytes32 invalidCredentials =
            bytes32(uint256(0x0300000000000000000000000000000000000000000000000000000000000000));
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSignature("InvalidWithdrawalCredentialsPrefix()"));
        river.initRiverV1_3(
            invalidCredentials,
            address(consolidationCoverageFund),
            address(v),
            address(externalConsolidationRecipientMapping),
            consolidator
        );
    }

    /// Asserts that initRiverV1_3 accepts 0x02-prefixed withdrawal credentials.
    function testInitRiverV1_3AcceptsValidWithdrawalCredentials() public {
        _initRiverAndV1_2();
        AttestationVerifierV1 v = _deployValidatorFor(address(river));
        bytes32 validCredentials = bytes32(uint256(0x0200000000000000000000000000000000000000000000000000000000000000));
        vm.prank(admin);
        river.initRiverV1_3(
            validCredentials,
            address(consolidationCoverageFund),
            address(v),
            address(externalConsolidationRecipientMapping),
            consolidator
        );
        assertEq(river.getWithdrawalCredentials(), validCredentials);
    }

    /// Asserts that a consensus layer report succeeds when no coverage fund is configured (pull is skipped).
    function testPullCoverageFundsNoCoverageFund() public {
        _initRiverMinimalForReporting();
        address alice = makeAddr("alice");
        _allowDeposit(alice);
        vm.deal(alice, 32 ether);
        vm.prank(alice);
        river.deposit{value: 32 ether}();
        // Set last reported balance so the small increase is within bounds.
        _seedStoredValidatorsBalance(32 ether);
        uint256 epoch = epochsPerFrame;
        _warpToFinalizedEpoch(epoch);
        IOracleManagerV1.ConsensusLayerReport memory clr;
        clr.epoch = epoch;
        clr.validatorsBalance = 32 ether + 1 wei;
        clr.totalDepositedActivatedETH = 0;
        clr.exitedETHPerOperator = new uint256[](1);
        clr.activeCLETHPerOperator = new uint256[](1);
        vm.prank(address(oracle));
        river.setConsensusLayerData(clr);
    }

    /// Asserts that setConsensusLayerData reverts with ZeroMintedShares when balance increases but total supply is zero.
    function testOnEarningsZeroMintedSharesReverts() public {
        _initRiverMinimalForReporting();
        vm.store(address(river), IN_FLIGHT_DEPOSIT_SLOT, bytes32(uint256(32 ether)));
        uint256 epoch = epochsPerFrame;
        _warpToFinalizedEpoch(epoch);
        IOracleManagerV1.ConsensusLayerReport memory clr;
        clr.epoch = epoch;
        clr.validatorsBalance = 32 ether + 1 wei;
        clr.totalDepositedActivatedETH = 32 ether;
        clr.exitedETHPerOperator = new uint256[](1);
        vm.prank(address(oracle));
        vm.expectRevert(abi.encodeWithSignature("ZeroMintedShares()"));
        river.setConsensusLayerData(clr);
    }

    /// Asserts that when the redeem manager has buffered exceeding ETH, reporting pulls some of it and redeem manager balance decreases.
    function testPullRedeemManagerExceedingEthNonZero() public {
        _initRiverMinimalForReporting();
        address alice = makeAddr("alice");
        _allowDeposit(alice);
        vm.deal(alice, 32 ether);
        vm.prank(alice);
        river.deposit{value: 32 ether}();
        vm.store(address(redeemManager), BUFFERED_EXCEEDING_ETH_SLOT, bytes32(uint256(1 ether)));
        vm.deal(address(redeemManager), 1 ether);
        uint256 epoch = epochsPerFrame;
        _warpToFinalizedEpoch(epoch);
        IOracleManagerV1.ConsensusLayerReport memory clr;
        clr.epoch = epoch;
        clr.validatorsBalance = 0;
        clr.totalDepositedActivatedETH = 0;
        clr.exitedETHPerOperator = new uint256[](1);
        clr.activeCLETHPerOperator = new uint256[](1);
        uint256 rdmBefore = address(redeemManager).balance;
        vm.prank(address(oracle));
        river.setConsensusLayerData(clr);
        assertLt(address(redeemManager).balance, rdmBefore);
    }

    /// Asserts that with no consolidation coverage fund configured, a non-zero buffer triggers no pull and the buffer is left untouched.
    function testPullConsolidationCoverageFundsZeroAddress() public {
        _initRiverMinimalForReporting();
        // No setConsolidationCoverageFund call - address stays at zero.
        assertEq(river.getConsolidationCoverageFund(), address(0));

        vm.store(address(river), CONSOLIDATION_BUFFER_SLOT, bytes32(uint256(1 ether)));

        uint256 epoch = epochsPerFrame;
        _warpToFinalizedEpoch(epoch);
        IOracleManagerV1.ConsensusLayerReport memory clr;
        clr.epoch = epoch;
        clr.validatorsBalance = 0;
        clr.totalDepositedActivatedETH = 0;
        clr.exitedETHPerOperator = new uint256[](1);
        clr.activeCLETHPerOperator = new uint256[](1);
        vm.prank(address(oracle));
        river.setConsensusLayerData(clr);

        // Buffer slot must be untouched: _setConsolidationBuffer is only called if pulled > 0.
        assertEq(uint256(vm.load(address(river), CONSOLIDATION_BUFFER_SLOT)), 1 ether);
    }

    /// Asserts that when the consolidation coverage fund is configured but holds zero ETH, no pull happens and the buffer is untouched.
    function testPullConsolidationCoverageFundsZeroBalance() public {
        _initRiverMinimalForReporting();
        vm.prank(admin);
        river.setConsolidationCoverageFund(address(consolidationCoverageFund));
        assertEq(address(consolidationCoverageFund).balance, 0);

        vm.store(address(river), CONSOLIDATION_BUFFER_SLOT, bytes32(uint256(1 ether)));

        uint256 epoch = epochsPerFrame;
        _warpToFinalizedEpoch(epoch);
        IOracleManagerV1.ConsensusLayerReport memory clr;
        clr.epoch = epoch;
        clr.validatorsBalance = 0;
        clr.totalDepositedActivatedETH = 0;
        clr.exitedETHPerOperator = new uint256[](1);
        clr.activeCLETHPerOperator = new uint256[](1);
        vm.prank(address(oracle));
        river.setConsensusLayerData(clr);

        assertEq(uint256(vm.load(address(river), CONSOLIDATION_BUFFER_SLOT)), 1 ether);
    }

    /// Asserts the happy path: consolidation buffer fully drained when the fund holds enough ETH; BalanceToDeposit grows by the pulled amount.
    function testPullConsolidationCoverageFundsHappyPath() public {
        _initRiverMinimalForReporting();
        vm.prank(admin);
        river.setConsolidationCoverageFund(address(consolidationCoverageFund));

        uint256 buffer = 0.5 ether;
        vm.store(address(river), CONSOLIDATION_BUFFER_SLOT, bytes32(buffer));
        // Fund the consolidation coverage contract so pullCoverageFunds can transfer.
        vm.store(address(consolidationCoverageFund), BALANCE_FOR_CONSOLIDATION_COVERAGE_SLOT, bytes32(buffer));
        vm.deal(address(consolidationCoverageFund), buffer);

        uint256 committedBalanceBefore = river.getCommittedBalance();

        uint256 epoch = epochsPerFrame;
        _warpToFinalizedEpoch(epoch);
        IOracleManagerV1.ConsensusLayerReport memory clr;
        clr.epoch = epoch;
        clr.validatorsBalance = 0;
        clr.totalDepositedActivatedETH = 0;
        clr.exitedETHPerOperator = new uint256[](1);
        clr.activeCLETHPerOperator = new uint256[](1);

        vm.expectEmit(true, true, true, true, address(river));
        emit PulledConsolidationCoverageFunds(buffer);
        vm.expectEmit(true, true, true, true, address(river));
        emit SetConsolidationBuffer(buffer, 0);

        vm.prank(address(oracle));
        river.setConsensusLayerData(clr);

        assertEq(uint256(vm.load(address(river), CONSOLIDATION_BUFFER_SLOT)), 0);
        assertEq(river.getCommittedBalance(), committedBalanceBefore + buffer);
        assertEq(address(consolidationCoverageFund).balance, 0);
    }

    /// Asserts that when the fund holds less ETH than the buffer, the buffer is partially drained and the remainder kept.
    function testPullConsolidationCoverageFundsPartial() public {
        _initRiverMinimalForReporting();
        vm.prank(admin);
        river.setConsolidationCoverageFund(address(consolidationCoverageFund));

        uint256 buffer = 1 ether;
        uint256 available = 0.3 ether;
        vm.store(address(river), CONSOLIDATION_BUFFER_SLOT, bytes32(buffer));
        vm.store(address(consolidationCoverageFund), BALANCE_FOR_CONSOLIDATION_COVERAGE_SLOT, bytes32(available));
        vm.deal(address(consolidationCoverageFund), available);

        uint256 committedBalanceBefore = river.getCommittedBalance();

        uint256 epoch = epochsPerFrame;
        _warpToFinalizedEpoch(epoch);
        IOracleManagerV1.ConsensusLayerReport memory clr;
        clr.epoch = epoch;
        clr.validatorsBalance = 0;
        clr.totalDepositedActivatedETH = 0;
        clr.exitedETHPerOperator = new uint256[](1);
        clr.activeCLETHPerOperator = new uint256[](1);

        vm.expectEmit(true, true, true, true, address(river));
        emit PulledConsolidationCoverageFunds(available);
        vm.expectEmit(true, true, true, true, address(river));
        emit SetConsolidationBuffer(buffer, buffer - available);

        vm.prank(address(oracle));
        river.setConsensusLayerData(clr);

        assertEq(uint256(vm.load(address(river), CONSOLIDATION_BUFFER_SLOT)), buffer - available);
        assertEq(river.getCommittedBalance(), committedBalanceBefore + available);
    }

    /// Asserts that a report whose totalExternalConsolidationETH is UNCHANGED versus the last
    /// stored report leaves the consolidation buffer untouched. The reduction branch in
    /// LibOracleReporting.setConsensusLayerData uses a strict `>` comparison, so an equal report must not
    /// enter the reduction path.
    /// Asserts that the cumulative validatorsStoppedEarningBalance survives a real report round-trip
    /// through LibOracleReporting into LastConsensusLayerReport storage, and that it is readable back
    /// via getLastConsensusLayerReport. This is the anchor the redemption cap-raise reads its per-report
    /// delta from, so the value must persist even in a report where nothing else moves.
    function testReportStoppedEarningBalancePersistsAndAccumulates() public {
        _initRiverMinimalForReporting();

        assertEq(river.getLastConsensusLayerReport().validatorsStoppedEarningBalance, 0);

        uint256 epoch = epochsPerFrame;
        _warpToFinalizedEpoch(epoch);
        IOracleManagerV1.ConsensusLayerReport memory clr;
        clr.epoch = epoch;
        clr.validatorsStoppedEarningBalance = 32 ether;
        clr.totalDepositedActivatedETH = 0;
        clr.exitedETHPerOperator = new uint256[](1);
        clr.activeCLETHPerOperator = new uint256[](1);

        vm.prank(address(oracle));
        river.setConsensusLayerData(clr);

        assertEq(river.getLastConsensusLayerReport().validatorsStoppedEarningBalance, 32 ether);

        // a second report accumulates rather than replacing a per-interval delta
        uint256 nextEpoch = epoch + epochsPerFrame;
        _warpToFinalizedEpoch(nextEpoch);
        IOracleManagerV1.ConsensusLayerReport memory clr2;
        clr2.epoch = nextEpoch;
        clr2.validatorsStoppedEarningBalance = 96 ether;
        clr2.totalDepositedActivatedETH = 0;
        clr2.exitedETHPerOperator = new uint256[](1);
        clr2.activeCLETHPerOperator = new uint256[](1);

        vm.prank(address(oracle));
        river.setConsensusLayerData(clr2);

        assertEq(river.getLastConsensusLayerReport().validatorsStoppedEarningBalance, 96 ether);
    }

    /// Asserts the monotonicity guard fires end-to-end on the real River, not just on the bare
    /// OracleManager mock.
    function testReportingError_InvalidDecreasingValidatorsStoppedEarningBalance() public {
        _initRiverMinimalForReporting();

        uint256 epoch = epochsPerFrame;
        _warpToFinalizedEpoch(epoch);
        IOracleManagerV1.ConsensusLayerReport memory clr;
        clr.epoch = epoch;
        clr.validatorsStoppedEarningBalance = 64 ether;
        clr.totalDepositedActivatedETH = 0;
        clr.exitedETHPerOperator = new uint256[](1);
        clr.activeCLETHPerOperator = new uint256[](1);

        vm.prank(address(oracle));
        river.setConsensusLayerData(clr);

        uint256 nextEpoch = epoch + epochsPerFrame;
        _warpToFinalizedEpoch(nextEpoch);
        IOracleManagerV1.ConsensusLayerReport memory clr2;
        clr2.epoch = nextEpoch;
        clr2.validatorsStoppedEarningBalance = 63 ether;
        clr2.totalDepositedActivatedETH = 0;
        clr2.exitedETHPerOperator = new uint256[](1);
        clr2.activeCLETHPerOperator = new uint256[](1);

        vm.prank(address(oracle));
        vm.expectRevert(
            abi.encodeWithSelector(
                IOracleManagerV1.InvalidDecreasingValidatorsStoppedEarningBalance.selector, 64 ether, 63 ether
            )
        );
        river.setConsensusLayerData(clr2);
    }

    /// Asserts that a cumulative stopped-earning total ABOVE validatorsExitingBalance +
    /// validatorsExitedBalance is accepted. That comparison is deliberately not enforced: principal is
    /// counted at its balance when it crossed exit_epoch, and post-exit_epoch slashing can reduce what
    /// is eventually swept, so the sum is not an invariant. Reverting on it would brick the whole report
    /// — including redemption settlement, which runs later in the same call.
    function testReportStoppedEarningBalanceMayExceedExitingPlusExited() public {
        _initRiverMinimalForReporting();

        uint256 epoch = epochsPerFrame;
        _warpToFinalizedEpoch(epoch);
        IOracleManagerV1.ConsensusLayerReport memory clr;
        clr.epoch = epoch;
        clr.validatorsExitingBalance = 0;
        clr.validatorsExitedBalance = 0;
        clr.validatorsStoppedEarningBalance = 32 ether;
        clr.totalDepositedActivatedETH = 0;
        clr.exitedETHPerOperator = new uint256[](1);
        clr.activeCLETHPerOperator = new uint256[](1);

        vm.prank(address(oracle));
        river.setConsensusLayerData(clr);

        assertEq(river.getLastConsensusLayerReport().validatorsStoppedEarningBalance, 32 ether);
    }

    /// @dev Deposits `depositAmount`, queues `redeemAmount` of LsETH for redemption and returns the
    ///      largest CL balance increase this report may carry without tripping the upper reporting bound.
    ///      The pool rate is 1:1 on entry, so LsETH and ETH amounts coincide before the report.
    function _seedRedeemDemandAndBound(uint256 depositAmount, uint256 redeemAmount, uint256 epoch)
        private
        returns (uint256 maxIncrease)
    {
        address alice = makeAddr("alice");
        _allowDeposit(alice);
        vm.deal(alice, depositAmount);
        vm.prank(alice);
        river.deposit{value: depositAmount}();

        vm.prank(alice);
        river.approve(address(redeemManager), redeemAmount);
        vm.prank(alice);
        redeemManager.requestRedeem(redeemAmount);

        _warpToFinalizedEpoch(epoch);

        // mirrors LibOracleReporting._maxIncrease for a first report (last stored epoch is 0)
        uint256 elapsed = epoch * slotsPerEpoch * secondsPerSlot;
        maxIncrease = (river.totalUnderlyingSupply() * river.getReportBounds().annualAprUpperBound * elapsed)
            / (LibBasisPoints.BASIS_POINTS_MAX * 365 days);
        assertGt(maxIncrease, 0);
    }

    /// Asserts the rate mark is priced at the rate River held BEFORE the report was applied, not the one
    /// it ends the interval on. The report path values the stopped-earning delta at
    /// LibOracleReporting.setConsensusLayerData's pre-report snapshot — taken before _pullCLFunds, the
    /// stored-report update and the fee mint — and carries it to reportStoppedEarning as data. Principal
    /// that crossed exit_epoch must stop accruing pool rewards from that moment, so the demand it backs
    /// may not be credited with the interval during which it stopped earning.
    function testReportStoppedEarningMarksAtPreReportRate() public {
        _initRiverMinimalForReporting();

        uint256 epoch = epochsPerFrame;
        uint256 maxIncrease = _seedRedeemDemandAndBound(64 ether, 32 ether, epoch);

        uint256 preUnderlying = river.totalUnderlyingSupply();
        uint256 preSupply = river.totalSupply();

        // a real rewards interval: the CL balance grows within bound, so the rate genuinely moves
        uint256 reward = maxIncrease / 2;
        assertGt(reward, 0);
        uint256 stoppedEarningEth = 10 ether;

        IOracleManagerV1.ConsensusLayerReport memory clr;
        clr.epoch = epoch;
        clr.validatorsBalance = reward;
        clr.validatorsStoppedEarningBalance = stoppedEarningEth;
        clr.totalDepositedActivatedETH = 0;
        clr.exitedETHPerOperator = new uint256[](1);
        clr.activeCLETHPerOperator = new uint256[](1);

        vm.prank(address(oracle));
        river.setConsensusLayerData(clr);

        // the rate did move over the report, so pre and post are genuinely distinguishable
        assertGt(river.totalUnderlyingSupply() * preSupply, preUnderlying * river.totalSupply());

        assertEq(redeemManager.getRateMarkCount(), 1);
        RateMarkStack.RateMark memory mark = redeemManager.getRateMarkDetails(0);

        // the whole delta fits in the pending demand, so it is marked verbatim at the pre-report rate
        assertEq(mark.amount, (stoppedEarningEth * preSupply) / preUnderlying);
        assertEq(mark.markedEth, stoppedEarningEth);

        // and that is strictly less than what the interval's closing rate would have locked in
        assertLt(mark.markedEth, river.underlyingBalanceFromShares(mark.amount));
    }

    /// Slashing containment freezes new exit requests but leaves the rest of the report — including the
    /// rebase and the fee mint — running, so the mark must still be anchored to the pre-report rate.
    /// Suspending accrual here would penalise a queued redeemer twice.
    function testReportStoppedEarningMarksAtPreReportRateUnderSlashingContainment() public {
        _initRiverMinimalForReporting();

        uint256 epoch = epochsPerFrame;
        uint256 maxIncrease = _seedRedeemDemandAndBound(64 ether, 32 ether, epoch);

        uint256 preUnderlying = river.totalUnderlyingSupply();
        uint256 preSupply = river.totalSupply();
        uint256 stoppedEarningEth = 10 ether;

        IOracleManagerV1.ConsensusLayerReport memory clr;
        clr.epoch = epoch;
        clr.validatorsBalance = maxIncrease / 2;
        clr.validatorsStoppedEarningBalance = stoppedEarningEth;
        clr.slashingContainmentMode = true;
        clr.totalDepositedActivatedETH = 0;
        clr.exitedETHPerOperator = new uint256[](1);
        clr.activeCLETHPerOperator = new uint256[](1);

        vm.prank(address(oracle));
        river.setConsensusLayerData(clr);

        RateMarkStack.RateMark memory mark = redeemManager.getRateMarkDetails(0);
        assertEq(mark.amount, (stoppedEarningEth * preSupply) / preUnderlying);
        assertEq(mark.markedEth, stoppedEarningEth);
        assertLt(mark.markedEth, river.underlyingBalanceFromShares(mark.amount));
    }

    /// LibOracleReporting.setConsensusLayerData calls reportStoppedEarning strictly BEFORE
    /// _reportWithdrawToRedeemManager: settlement burns the corresponding shares and removes that
    /// LsETH from the redeem demand, so demand settled in the same report would otherwise never be
    /// marked and would be paid at its stale request-time rate instead of the rate its principal
    /// actually stopped earning at. Swapping the two calls leaves every other test in this suite
    /// green, because none of them ever settle the very slice they mark within the same report.
    /// This drives one oracle report that both marks and fully settles the same redeem request, and
    /// asserts the recipient is paid the mark's locked value -- strictly more than the request-time
    /// anchor -- proving the mark applied before the demand it covered was erased.
    function testMarkThenSettleSameReportPaysMarkRateForSettledSlice() public {
        _initRiverMinimalForReporting();

        // alice queues a redemption at the genesis 1:1 rate, before any report has ever landed, so
        // the request-time anchor is exactly 32 ether for 32 LsETH.
        uint256 epoch1 = epochsPerFrame;
        uint256 maxIncrease1 = _seedRedeemDemandAndBound(64 ether, 32 ether, epoch1);

        RedeemRequestAnchor.Anchor memory anchor = redeemManager.getRedeemRequestAnchor(0);
        assertEq(anchor.lsETHAtRequest, 32e18);
        assertEq(anchor.ethAtRequest, 32 ether);

        // an ordinary rewards-only report lands first, so the pool genuinely appreciates while the
        // request sits queued -- the yield the mark must let the redeemer keep.
        uint256 reward1 = maxIncrease1 / 2;
        assertGt(reward1, 0);
        IOracleManagerV1.ConsensusLayerReport memory clr1;
        clr1.epoch = epoch1;
        clr1.validatorsBalance = reward1;
        clr1.totalDepositedActivatedETH = 0;
        clr1.exitedETHPerOperator = new uint256[](1);
        clr1.activeCLETHPerOperator = new uint256[](1);
        vm.prank(address(oracle));
        river.setConsensusLayerData(clr1);

        // the second report both marks the entire pending request as stopped-earning AND settles it
        // in the same call -- the exact ordering the fix depends on.
        uint256 epoch2 = epoch1 + uint256(epochsPerFrame) * 1_000_000;
        _warpToFinalizedEpoch(epoch2);

        // over-report the stopped-earning delta so it exceeds the markable demand (32 LsETH) and is
        // clamped to exactly that demand, sidestepping any share/eth round-trip rounding on the
        // mark's own amount (mirrors testClampedMarkPreservesReportedRate's approach in the
        // RedeemManager suite).
        uint256 stoppedEarningEth = 40 ether;
        uint256 reportedLsETH = river.sharesFromUnderlyingBalance(stoppedEarningEth);
        assertGt(reportedLsETH, 32e18);

        // over-fund the exit so settlement is never capped by the available buffer: the withdrawal
        // event's LsETH leg then stays exactly equal to the outstanding demand, because
        // _reportWithdrawToRedeemManager only ever recomputes it (introducing rounding) when the
        // buffer falls short of the demand's value, which this deliberately avoids.
        uint256 exitedEth = 160 ether;
        vm.deal(address(withdraw), exitedEth);

        IOracleManagerV1.ConsensusLayerReport memory clr2;
        clr2.epoch = epoch2;
        clr2.validatorsBalance = reward1; // unchanged: no further staking reward this report
        clr2.validatorsExitedBalance = exitedEth;
        clr2.validatorsStoppedEarningBalance = stoppedEarningEth;
        clr2.totalDepositedActivatedETH = 0;
        clr2.exitedETHPerOperator = new uint256[](2);
        clr2.exitedETHPerOperator[0] = exitedEth;
        clr2.exitedETHPerOperator[1] = exitedEth;
        clr2.activeCLETHPerOperator = new uint256[](1);

        vm.expectEmit(true, true, true, true);
        emit StoppedEarningExceededMarkableDemand(reportedLsETH, 32e18);
        vm.prank(address(oracle));
        river.setConsensusLayerData(clr2);

        // the mark landed, covers the whole request, and is strictly richer than the request-time
        // value: the pool appreciation between request and mark was captured, not discarded.
        assertEq(redeemManager.getRateMarkCount(), 1);
        RateMarkStack.RateMark memory mark = redeemManager.getRateMarkDetails(0);
        assertEq(mark.height, 0);
        assertEq(mark.amount, 32e18);
        assertGt(mark.markedEth, anchor.ethAtRequest);

        // the same report produced a withdrawal event settling that exact slice. Its own
        // (self-referential, inflated) rate exceeds the mark's locked rate, so it is the cap --
        // not the withdrawal event -- that determines the payout.
        assertEq(redeemManager.getWithdrawalEventCount(), 1);
        WithdrawalStack.WithdrawalEvent memory we = redeemManager.getWithdrawalEventDetails(0);
        assertEq(we.height, 0);
        assertEq(we.amount, 32e18);
        assertGt(we.withdrawnEth, mark.markedEth);

        uint32[] memory ids = new uint32[](1);
        uint32[] memory eventIds = new uint32[](1);
        address alice = makeAddr("alice");
        uint256 before = alice.balance;
        redeemManager.claimRedeemRequests(ids, eventIds);
        uint256 received = alice.balance - before;

        // paid exactly the mark's locked value: strictly more than the request-time anchor, proving
        // the yield earned between request and mark survived the same-report settlement.
        assertEq(received, mark.markedEth);
        assertGt(received, anchor.ethAtRequest);
        assertEq(redeemManager.getBufferedExceedingEth(), we.withdrawnEth - mark.markedEth);
    }

    // ── Shared scaffolding for the end-to-end stopped-earning settlement tests below ──
    //
    // Every test in this block drives the real `setConsensusLayerData` pipeline: no direct calls into
    // the redeem manager, so the ordering inside LibOracleReporting (pull CL funds -> rebase -> fee mint
    // -> rebalance -> reportStoppedEarning -> reportWithdraw -> skim -> commit) is exercised as deployed.

    /// @dev 1000 frames between reports. Long enough that the upper reporting bound (10% APR) leaves room
    ///      for the multi-ETH rate moves these tests need, so every report stays inside the bound.
    uint256 private constant REPORT_GAP = uint256(epochsPerFrame) * 1000;
    /// @dev alice's pool deposit, and the LsETH she queues for redemption out of it.
    uint256 private constant SEED_DEPOSIT = 64 ether;
    uint256 private constant SEED_REDEEM_LSETH = 8e18;
    /// @dev CL rewards landed by the scaffold's first report. 16 < maxIncrease(64 ETH, 1000 frames) ~ 17.53.
    uint256 private constant SEED_CL_REWARD = 16 ether;

    /// @dev A blank, always-valid report body; callers override only the fields under test.
    ///      `exitedETHPerOperator` is `[total]` with no per-operator cells, i.e. "no exits reported".
    function _baseReport(uint256 epoch) private pure returns (IOracleManagerV1.ConsensusLayerReport memory clr) {
        clr.epoch = epoch;
        clr.totalDepositedActivatedETH = 0;
        clr.exitedETHPerOperator = new uint256[](1);
        clr.activeCLETHPerOperator = new uint256[](1);
    }

    /// @dev Same, but reporting the single operator's cumulative exited ETH. `_setExitedETH` requires
    ///      element 0 to be the sum of the per-operator cells, so both cells carry the same value, and
    ///      the array may never shrink again on a later report.
    function _exitReport(uint256 epoch, uint256 cumulativeExitedEth)
        private
        pure
        returns (IOracleManagerV1.ConsensusLayerReport memory clr)
    {
        clr = _baseReport(epoch);
        clr.validatorsExitedBalance = cumulativeExitedEth;
        clr.exitedETHPerOperator = new uint256[](2);
        clr.exitedETHPerOperator[0] = cumulativeExitedEth;
        clr.exitedETHPerOperator[1] = cumulativeExitedEth;
    }

    /// @dev Common scaffold. alice deposits 64 ETH and queues 8 LsETH at the genesis 1:1 rate, so her
    ///      anchor is exactly 8 ETH for 8e18 LsETH — a rate of one wei per 1e-18 LsETH, which is what
    ///      lets the tests below add a raw LsETH amount to an ETH amount when spelling out a blended cap.
    ///      One rewards-only report then lands 16 ETH of CL rewards, so by the time the report under test
    ///      runs the pool rate is strictly above her request rate and a mark taken at that rate is
    ///      distinguishable from both the anchor and the settling report's own rate.
    /// @return epoch1 The epoch of that first report. The report under test uses `epoch1 + REPORT_GAP`.
    function _seedAppreciatedRequest() private returns (uint256 epoch1) {
        _initRiverMinimalForReporting();
        epoch1 = REPORT_GAP;
        uint256 maxIncrease = _seedRedeemDemandAndBound(SEED_DEPOSIT, SEED_REDEEM_LSETH, epoch1);
        assertGt(maxIncrease, SEED_CL_REWARD, "seed reward must fit under the upper reporting bound");

        // the anchor is frozen at request time and never moves again; every expected payout below is
        // quoted against it
        RedeemRequestAnchor.Anchor memory anchor = redeemManager.getRedeemRequestAnchor(0);
        assertEq(anchor.lsETHAtRequest, SEED_REDEEM_LSETH);
        assertEq(anchor.ethAtRequest, 8 ether);

        IOracleManagerV1.ConsensusLayerReport memory clr = _baseReport(epoch1);
        clr.validatorsBalance = SEED_CL_REWARD; // pure rewards: no exit, no rebalance, no stopped earning
        vm.prank(address(oracle));
        river.setConsensusLayerData(clr);

        // 64 + 16 ETH, minus the 5% fee minted as shares: the request is now worth strictly more than
        // the 8 ETH it was opened at, and nothing has been marked or settled yet.
        assertGt(river.underlyingBalanceFromShares(SEED_REDEEM_LSETH), 8 ether);
        assertEq(redeemManager.getRateMarkCount(), 0);
        assertEq(redeemManager.getWithdrawalEventCount(), 0);
        // the whole deposit buffer was committed for staking, so any later rebalance has to be funded by
        // a fresh deposit — which is what makes "filled from the deposit buffer" unambiguous below.
        assertEq(river.getBalanceToDeposit(), 0);
    }

    /// @dev Refills River's deposit buffer with a fresh deposit from an unrelated account. Depositing at
    ///      the prevailing rate does not move that rate, so this only changes which buffer holds the ETH.
    function _refillDepositBuffer(uint256 amount) private {
        address filler = makeAddr("bufferFiller");
        _allowDeposit(filler);
        vm.deal(filler, amount);
        vm.prank(filler);
        river.deposit{value: amount}();
        assertEq(river.getBalanceToDeposit(), amount);
    }

    /// @dev Claims redeem request 0 starting at withdrawal event 0 and returns the ETH alice received.
    function _claimAlice(uint16 depth) private returns (uint256 received) {
        uint32[] memory ids = new uint32[](1);
        uint32[] memory eventIds = new uint32[](1);
        address alice = makeAddr("alice");
        uint256 balanceBefore = alice.balance;
        redeemManager.claimRedeemRequests(ids, eventIds, true, depth);
        received = alice.balance - balanceBefore;
    }

    /// @dev Mirrors LibOracleReporting._maxIncrease for a report covering `lastEpoch`..`epoch`. Must be
    ///      called on the state the report will see, i.e. after any warp and any deposit.
    function _maxIncreaseBetween(uint256 lastEpoch, uint256 epoch) private view returns (uint256) {
        uint256 elapsed = (epoch - lastEpoch) * slotsPerEpoch * secondsPerSlot;
        return (river.totalUnderlyingSupply() * river.getReportBounds().annualAprUpperBound * elapsed)
            / (LibBasisPoints.BASIS_POINTS_MAX * 365 days);
    }

    /// **Scenario:** a post-upgrade request is filled entirely out of the deposit buffer — rebalance mode
    /// on, no validator exit, no stopped-earning delta — while the pool rate has risen since the request
    /// was opened.
    /// **Expected:** nothing is marked, so `_sliceCap` values the whole slice at the request-time anchor
    /// rate and the redeemer is paid exactly `rate_at_request`. The withdrawal event was funded at the
    /// (higher) current rate, so the difference is redirected to `BufferedExceedingEth` rather than paid
    /// out. Rebalanced buffer ETH on its own never earns a redeemer any yield.
    function testDepositBufferFillWithoutMarkPaysRequestRate() public {
        uint256 epoch1 = _seedAppreciatedRequest();

        // fund the rebalance: 32 ETH is comfortably more than the ~9.9 ETH the 8 LsETH demand is now worth
        _refillDepositBuffer(32 ether);

        // report 2 carries no rewards of its own (validatorsBalance unchanged), so the rate it prices the
        // fill at is exactly the rate observable right now
        uint256 expectedFill = river.underlyingBalanceFromShares(SEED_REDEEM_LSETH);
        assertGt(expectedFill, 8 ether, "the pool must have appreciated since the request");

        uint256 epoch2 = epoch1 + REPORT_GAP;
        _warpToFinalizedEpoch(epoch2);
        IOracleManagerV1.ConsensusLayerReport memory clr = _baseReport(epoch2);
        clr.validatorsBalance = SEED_CL_REWARD;
        clr.rebalanceDepositToRedeemMode = true;
        vm.prank(address(oracle));
        river.setConsensusLayerData(clr);

        // no exit was ever reported and the withdraw contract was never funded, so every wei of this fill
        // came out of the deposit buffer
        assertEq(river.getLastConsensusLayerReport().validatorsExitedBalance, 0);
        assertEq(address(withdraw).balance, 0);

        // no stopped-earning delta means no mark, anywhere on the axis
        assertEq(redeemManager.getRateMarkCount(), 0);

        assertEq(redeemManager.getWithdrawalEventCount(), 1);
        WithdrawalStack.WithdrawalEvent memory we = redeemManager.getWithdrawalEventDetails(0);
        assertEq(we.height, 0);
        assertEq(we.amount, SEED_REDEEM_LSETH);
        assertEq(we.withdrawnEth, expectedFill);

        // paid the request-time anchor to the wei, not the richer rate the event was funded at
        uint256 received = _claimAlice(type(uint16).max);
        assertEq(received, 8 ether);
        assertEq(redeemManager.getBufferedExceedingEth(), expectedFill - 8 ether);
    }

    /// **Scenario:** identical to the test above — the fill is funded purely by a deposit-buffer rebalance,
    /// with no validator exit anywhere in the report — except that a stopped-earning delta is reported in
    /// that same report.
    /// **Expected:** the request IS marked and IS paid at the mark rate. Marks are positional, not
    /// source-attributed: `reportStoppedEarning` runs before `_reportWithdrawToRedeemManager` and places the
    /// mark at the head of unsettled demand regardless of which pot of ETH ends up paying, because ETH in
    /// River is fungible. The mark, priced at the pre-report rate, caps a payout the report would otherwise
    /// have made at the (higher) post-report rate.
    function testDepositBufferFillIsMarkedWhenStoppedEarningLandsSameReport() public {
        uint256 epoch1 = _seedAppreciatedRequest();
        _refillDepositBuffer(32 ether);

        // 12 ETH of principal crossed exit_epoch. Valued at the CURRENT (pre-report) rate that is ~9.7
        // LsETH, more than the 8 LsETH of markable demand, so the mark is clamped down to the demand and
        // its eth leg is scaled in the same proportion — preserving the locked rate exactly.
        uint256 stoppedEarningEth = 12 ether;
        uint256 reportedLsETH = river.sharesFromUnderlyingBalance(stoppedEarningEth);
        assertGt(reportedLsETH, SEED_REDEEM_LSETH);
        uint256 expectedMarkedEth = (stoppedEarningEth * SEED_REDEEM_LSETH) / reportedLsETH;

        uint256 epoch2 = epoch1 + REPORT_GAP;
        _warpToFinalizedEpoch(epoch2);
        IOracleManagerV1.ConsensusLayerReport memory clr = _baseReport(epoch2);
        // +8 ETH of fresh rewards in this report, so the rate the fill is priced at is strictly above the
        // rate the mark locks; without this the mark and the event would price identically and the test
        // could not tell which one bound.
        clr.validatorsBalance = SEED_CL_REWARD + 8 ether;
        clr.validatorsStoppedEarningBalance = stoppedEarningEth;
        clr.rebalanceDepositToRedeemMode = true;
        vm.expectEmit(true, true, true, true);
        emit StoppedEarningExceededMarkableDemand(reportedLsETH, SEED_REDEEM_LSETH);
        vm.prank(address(oracle));
        river.setConsensusLayerData(clr);

        // the fungibility property: no exit ETH existed in this report at all
        assertEq(river.getLastConsensusLayerReport().validatorsExitedBalance, 0);
        assertEq(address(withdraw).balance, 0);

        assertEq(redeemManager.getRateMarkCount(), 1);
        RateMarkStack.RateMark memory mark = redeemManager.getRateMarkDetails(0);
        assertEq(mark.height, 0, "mark sits at the head of unsettled demand");
        assertEq(mark.amount, SEED_REDEEM_LSETH);
        assertEq(mark.markedEth, expectedMarkedEth);
        assertGt(mark.markedEth, 8 ether, "the mark is richer than the request-time anchor");

        WithdrawalStack.WithdrawalEvent memory we = redeemManager.getWithdrawalEventDetails(0);
        assertEq(we.amount, SEED_REDEEM_LSETH);
        assertGt(we.withdrawnEth, mark.markedEth, "the cap, not the event, must be the binding constraint");

        uint256 received = _claimAlice(type(uint16).max);
        assertEq(received, mark.markedEth);
        assertEq(redeemManager.getBufferedExceedingEth(), we.withdrawnEth - mark.markedEth);
    }

    /// **Scenario:** one request is filled in two pieces — a small deposit-buffer rebalance settles the
    /// front of it with no stopped-earning delta, and a later exit-funded report settles the remainder
    /// while a stopped-earning delta lands.
    /// **Expected:** two withdrawal events. The first slice sits below every mark, so it keeps the
    /// request-time rate; the mark for the second report starts at the settled height (marks may only
    /// cover demand that is still unsettled) and covers the tail exactly, so the tail is paid at the mark
    /// rate. A claim with depth >= 2 walks both events and pays the blended sum.
    function testDepositFillThenExitFillPaysBlendedRequestAndMarkRates() public {
        uint256 epoch1 = _seedAppreciatedRequest();

        // only 4 ETH of buffer against a ~9.9 ETH demand: the rebalance can settle less than half of it
        _refillDepositBuffer(4 ether);

        uint256 epoch2 = epoch1 + REPORT_GAP;
        _warpToFinalizedEpoch(epoch2);
        IOracleManagerV1.ConsensusLayerReport memory clr2 = _baseReport(epoch2);
        clr2.validatorsBalance = SEED_CL_REWARD; // no rewards this report, so the rate does not move
        clr2.rebalanceDepositToRedeemMode = true;
        vm.prank(address(oracle));
        river.setConsensusLayerData(clr2);

        // partial fill, and nothing marked: the first slice will be valued at the anchor rate
        assertEq(redeemManager.getRateMarkCount(), 0);
        assertEq(redeemManager.getWithdrawalEventCount(), 1);
        WithdrawalStack.WithdrawalEvent memory we1 = redeemManager.getWithdrawalEventDetails(0);
        assertEq(we1.height, 0);
        assertEq(we1.withdrawnEth, 4 ether);
        assertLt(we1.amount, SEED_REDEEM_LSETH, "the deposit buffer must not have covered the request");

        // report 3: the exit sweep lands. Over-fund it so the remaining demand is settled in full and the
        // event's LsETH leg is exactly the outstanding demand (no re-derivation, hence no rounding).
        uint256 exitedEth = 12 ether;
        vm.deal(address(withdraw), exitedEth);

        uint256 stoppedEarningEth = 12 ether;
        uint256 reportedLsETH = river.sharesFromUnderlyingBalance(stoppedEarningEth);
        uint256 markable = SEED_REDEEM_LSETH - we1.amount;
        assertGt(reportedLsETH, markable, "the delta must over-cover, so the mark clamps to the tail");
        uint256 expectedMarkedEth = (stoppedEarningEth * markable) / reportedLsETH;

        uint256 epoch3 = epoch2 + REPORT_GAP;
        _warpToFinalizedEpoch(epoch3);
        IOracleManagerV1.ConsensusLayerReport memory clr3 = _exitReport(epoch3, exitedEth);
        // 16 - 12 swept out of the CL balance, +8 of fresh rewards: the settling rate ends up above the
        // pre-report rate the mark is priced at, so the mark binds on the tail.
        clr3.validatorsBalance = SEED_CL_REWARD - exitedEth + 8 ether;
        clr3.validatorsStoppedEarningBalance = stoppedEarningEth;
        vm.prank(address(oracle));
        river.setConsensusLayerData(clr3);

        assertEq(redeemManager.getWithdrawalEventCount(), 2);
        WithdrawalStack.WithdrawalEvent memory we2 = redeemManager.getWithdrawalEventDetails(1);
        assertEq(we2.height, we1.amount, "the second event starts where the first ended");
        assertEq(we2.amount, markable);

        // the mark starts at the settled height, not at 0: the already-settled slice keeps its own price
        assertEq(redeemManager.getRateMarkCount(), 1);
        RateMarkStack.RateMark memory mark = redeemManager.getRateMarkDetails(0);
        assertEq(mark.height, we1.amount);
        assertEq(mark.amount, markable);
        assertEq(mark.markedEth, expectedMarkedEth);
        assertGt(we2.withdrawnEth, mark.markedEth, "the cap must bind on the tail slice");

        // depth 2 lets the single claim walk both events. The anchor rate is exactly one wei per 1e-18
        // LsETH, so the unmarked front slice is worth `we1.amount` wei; the marked tail is worth the
        // mark's whole locked value because the mark covers it exactly.
        uint256 received = _claimAlice(2);
        assertEq(received, we1.amount + mark.markedEth);
        assertGt(received, 8 ether, "the blended payout beats a flat request-rate payout");
        assertEq(
            redeemManager.getBufferedExceedingEth(),
            (we1.withdrawnEth - we1.amount) + (we2.withdrawnEth - mark.markedEth)
        );
    }

    /// **Scenario:** a single report whose `BalanceToRedeem` is exit ETH PLUS rebalanced deposit ETH, all
    /// of it consumed by one request, with a stopped-earning delta smaller than that request.
    /// **Expected:** one blended withdrawal event. The mark is placed at the head of the demand and only
    /// covers as much of it as stopped earning, so the very same request is paid at the mark rate over its
    /// front and at the request-time rate over its tail. The gap above the mark is not a bug: it is exactly
    /// the LsETH whose backing principal never stopped earning.
    function testBlendedExitAndDepositFillMarksOnlyHeadSlice() public {
        uint256 epoch1 = _seedAppreciatedRequest();

        // 4 ETH of exit + up to 6 ETH of buffer against a ~9.9 ETH demand: neither source alone suffices
        uint256 exitedEth = 4 ether;
        vm.deal(address(withdraw), exitedEth);
        _refillDepositBuffer(6 ether);

        // a small delta: ~2.42 LsETH of the 8 LsETH request stopped earning, the rest did not
        uint256 stoppedEarningEth = 3 ether;
        uint256 expectedMarkAmount = river.sharesFromUnderlyingBalance(stoppedEarningEth);
        assertLt(expectedMarkAmount, SEED_REDEEM_LSETH, "the mark must not cover the whole request");
        uint256 expectedFill = river.underlyingBalanceFromShares(SEED_REDEEM_LSETH);

        uint256 epoch2 = epoch1 + REPORT_GAP;
        _warpToFinalizedEpoch(epoch2);
        IOracleManagerV1.ConsensusLayerReport memory clr = _exitReport(epoch2, exitedEth);
        // the swept ETH leaves validatorsBalance and reappears in BalanceToRedeem, so the pool is flat
        // over this report and the fill is priced at the same rate the mark locks
        clr.validatorsBalance = SEED_CL_REWARD - exitedEth;
        clr.validatorsStoppedEarningBalance = stoppedEarningEth;
        clr.rebalanceDepositToRedeemMode = true;
        vm.prank(address(oracle));
        river.setConsensusLayerData(clr);

        // one event, covering the request in full, funded by strictly more than the exit alone provided
        assertEq(redeemManager.getWithdrawalEventCount(), 1);
        WithdrawalStack.WithdrawalEvent memory we = redeemManager.getWithdrawalEventDetails(0);
        assertEq(we.height, 0);
        assertEq(we.amount, SEED_REDEEM_LSETH);
        assertEq(we.withdrawnEth, expectedFill);
        assertGt(we.withdrawnEth, exitedEth, "the exit alone could not have funded this event");

        assertEq(redeemManager.getRateMarkCount(), 1);
        RateMarkStack.RateMark memory mark = redeemManager.getRateMarkDetails(0);
        assertEq(mark.height, 0);
        assertEq(mark.amount, expectedMarkAmount);
        assertEq(mark.markedEth, stoppedEarningEth);
        assertLt(mark.amount, we.amount, "only the head slice is covered");

        // cap = marked head at the locked rate + unmarked tail at the anchor rate (one wei per 1e-18 LsETH)
        uint256 expectedPayout = mark.markedEth + (SEED_REDEEM_LSETH - mark.amount);
        assertLt(expectedPayout, we.withdrawnEth, "the cap must bind, otherwise this proves nothing");
        uint256 received = _claimAlice(type(uint16).max);
        assertEq(received, expectedPayout);
        assertGt(received, 8 ether, "the marked head earned more than the flat request rate");
        assertEq(redeemManager.getBufferedExceedingEth(), we.withdrawnEth - expectedPayout);
    }

    /// **Scenario:** the canonical positional-marking proof. Validators cross exit_epoch at report N, so a
    /// stopped-earning delta is reported then — but the sweep ETH does not land until report N+2. In
    /// between, at report N+1, a deposit-buffer rebalance fills the request.
    /// **Expected:** the mark taken at N still covers the position at N+1, so the deposit-funded fill is
    /// paid at the N mark rate. Marks are positions on the cumulative LsETH axis, and ETH in River is
    /// fungible; nothing ties a mark to the ETH that eventually settles it.
    function testMarkFromEarlierReportPricesLaterDepositBufferFill() public {
        uint256 epoch1 = _seedAppreciatedRequest();

        // ── report N: the principal stops earning, but nothing is available to settle with ──
        uint256 stoppedEarningEth = 12 ether;
        uint256 reportedLsETH = river.sharesFromUnderlyingBalance(stoppedEarningEth);
        assertGt(reportedLsETH, SEED_REDEEM_LSETH);
        uint256 expectedMarkedEth = (stoppedEarningEth * SEED_REDEEM_LSETH) / reportedLsETH;

        uint256 epochN = epoch1 + REPORT_GAP;
        _warpToFinalizedEpoch(epochN);
        IOracleManagerV1.ConsensusLayerReport memory clrN = _baseReport(epochN);
        clrN.validatorsBalance = SEED_CL_REWARD;
        clrN.validatorsStoppedEarningBalance = stoppedEarningEth;
        vm.prank(address(oracle));
        river.setConsensusLayerData(clrN);

        assertEq(redeemManager.getRateMarkCount(), 1);
        RateMarkStack.RateMark memory mark = redeemManager.getRateMarkDetails(0);
        assertEq(mark.height, 0);
        assertEq(mark.amount, SEED_REDEEM_LSETH);
        assertEq(mark.markedEth, expectedMarkedEth);
        // nothing settled: BalanceToRedeem was empty and rebalancing was off
        assertEq(redeemManager.getWithdrawalEventCount(), 0);

        // ── report N+1: a deposit-buffer rebalance fills the request, with no stopped-earning delta ──
        _refillDepositBuffer(32 ether);
        uint256 epochN1 = epochN + REPORT_GAP;
        _warpToFinalizedEpoch(epochN1);
        IOracleManagerV1.ConsensusLayerReport memory clrN1 = _baseReport(epochN1);
        clrN1.validatorsBalance = SEED_CL_REWARD + 8 ether; // fresh rewards push the fill rate above the mark
        clrN1.validatorsStoppedEarningBalance = stoppedEarningEth; // unchanged: no new delta
        clrN1.rebalanceDepositToRedeemMode = true;
        vm.prank(address(oracle));
        river.setConsensusLayerData(clrN1);

        assertEq(redeemManager.getRateMarkCount(), 1, "no second mark: the delta was already consumed");
        assertEq(redeemManager.getWithdrawalEventCount(), 1);
        WithdrawalStack.WithdrawalEvent memory we = redeemManager.getWithdrawalEventDetails(0);
        assertEq(we.amount, SEED_REDEEM_LSETH);
        assertGt(we.withdrawnEth, mark.markedEth);
        // still no CL ETH anywhere in the system: the fill was pure buffer ETH
        assertEq(river.getLastConsensusLayerReport().validatorsExitedBalance, 0);

        // ── report N+2: the sweep finally arrives, into a queue that no longer has demand ──
        uint256 exitedEth = 12 ether;
        vm.deal(address(withdraw), exitedEth);
        uint256 epochN2 = epochN1 + REPORT_GAP;
        _warpToFinalizedEpoch(epochN2);
        IOracleManagerV1.ConsensusLayerReport memory clrN2 = _exitReport(epochN2, exitedEth);
        clrN2.validatorsBalance = SEED_CL_REWARD + 8 ether - exitedEth;
        clrN2.validatorsStoppedEarningBalance = stoppedEarningEth;
        vm.prank(address(oracle));
        river.setConsensusLayerData(clrN2);

        assertEq(redeemManager.getWithdrawalEventCount(), 1, "the sweep settled nothing: demand was zero");
        assertEq(river.getBalanceToRedeem(), 0, "the sweep was skimmed back to the deposit balance");

        // the fill at N+1 was capped by the mark taken two reports earlier, not by the anchor
        uint256 received = _claimAlice(type(uint16).max);
        assertEq(received, mark.markedEth);
        assertGt(received, 8 ether);
        assertEq(redeemManager.getBufferedExceedingEth(), we.withdrawnEth - mark.markedEth);
    }

    /// **Scenario:** exit ETH arrives and settles a request in full, but `validatorsStoppedEarningBalance`
    /// is left unchanged — an exit that the oracle has not (yet) reported as having crossed exit_epoch.
    /// **Expected:** no mark is created and the redeemer is paid the flat request-time rate, with the
    /// surplus buffered. Pins that marking is driven purely by `validatorsStoppedEarningBalance` and never
    /// inferred from `validatorsExitedBalance`.
    function testExitFillWithoutStoppedEarningPaysRequestRate() public {
        uint256 epoch1 = _seedAppreciatedRequest();

        uint256 exitedEth = 12 ether;
        vm.deal(address(withdraw), exitedEth);
        uint256 expectedFill = river.underlyingBalanceFromShares(SEED_REDEEM_LSETH);
        assertGt(expectedFill, 8 ether);
        assertLt(expectedFill, exitedEth, "the exit must cover the demand in full");

        uint256 epoch2 = epoch1 + REPORT_GAP;
        _warpToFinalizedEpoch(epoch2);
        IOracleManagerV1.ConsensusLayerReport memory clr = _exitReport(epoch2, exitedEth);
        // swept ETH moves from validatorsBalance to BalanceToRedeem: the pool is flat over this report
        clr.validatorsBalance = SEED_CL_REWARD - exitedEth;
        // validatorsStoppedEarningBalance deliberately left at 0 while validatorsExitedBalance jumps
        vm.prank(address(oracle));
        river.setConsensusLayerData(clr);

        assertEq(river.getLastConsensusLayerReport().validatorsExitedBalance, exitedEth);
        assertEq(river.getLastConsensusLayerReport().validatorsStoppedEarningBalance, 0);
        assertEq(redeemManager.getRateMarkCount(), 0, "an exit alone must never create a mark");

        assertEq(redeemManager.getWithdrawalEventCount(), 1);
        WithdrawalStack.WithdrawalEvent memory we = redeemManager.getWithdrawalEventDetails(0);
        assertEq(we.amount, SEED_REDEEM_LSETH);
        assertEq(we.withdrawnEth, expectedFill);

        uint256 received = _claimAlice(type(uint16).max);
        assertEq(received, 8 ether, "unmarked demand is paid at exactly rate_at_request");
        assertEq(redeemManager.getBufferedExceedingEth(), expectedFill - 8 ether);
    }

    /// **Scenario:** exit ETH arrives in a report where the redeem queue holds no outstanding demand (the
    /// only request was already settled), and a stopped-earning delta is reported alongside it.
    /// **Expected:** `_skimExcessBalanceToRedeem` hands the whole exit back to the deposit balance, and the
    /// delta is discarded because `markable == 0` — the settled height has already reached the end of the
    /// queue, so there is no position left to mark. The stack must stay empty rather than accumulate a
    /// mark that would silently price the next request that gets queued.
    function testExitEthWithNoDemandSkimsBackAndDiscardsMark() public {
        uint256 epoch1 = _seedAppreciatedRequest();

        // report 2 settles the whole request out of the deposit buffer, unmarked
        _refillDepositBuffer(32 ether);
        uint256 epoch2 = epoch1 + REPORT_GAP;
        _warpToFinalizedEpoch(epoch2);
        IOracleManagerV1.ConsensusLayerReport memory clr2 = _baseReport(epoch2);
        clr2.validatorsBalance = SEED_CL_REWARD;
        clr2.rebalanceDepositToRedeemMode = true;
        vm.prank(address(oracle));
        river.setConsensusLayerData(clr2);

        assertEq(redeemManager.getRedeemDemand(), 0, "the queue must be fully settled");
        assertEq(redeemManager.getRateMarkCount(), 0);
        assertEq(redeemManager.getWithdrawalEventCount(), 1);

        // report 3: the sweep lands while a stopped-earning delta is reported
        uint256 exitedEth = 12 ether;
        vm.deal(address(withdraw), exitedEth);
        uint256 stoppedEarningEth = 12 ether;
        uint256 reportedLsETH = river.sharesFromUnderlyingBalance(stoppedEarningEth);
        uint256 depositSideBefore = river.getBalanceToDeposit() + river.getCommittedBalance();

        uint256 epoch3 = epoch2 + REPORT_GAP;
        _warpToFinalizedEpoch(epoch3);
        IOracleManagerV1.ConsensusLayerReport memory clr3 = _exitReport(epoch3, exitedEth);
        clr3.validatorsBalance = SEED_CL_REWARD - exitedEth;
        clr3.validatorsStoppedEarningBalance = stoppedEarningEth;
        // the whole delta is clamped away: markable is zero because the settled height already equals the
        // end of the queue, so the clamp event reports a marked amount of zero and nothing is pushed
        vm.expectEmit(true, true, true, true);
        emit StoppedEarningExceededMarkableDemand(reportedLsETH, 0);
        vm.prank(address(oracle));
        river.setConsensusLayerData(clr3);

        assertEq(redeemManager.getRateMarkCount(), 0, "markable == 0 must leave the stack empty");
        assertEq(redeemManager.getWithdrawalEventCount(), 1, "no demand, so no new withdrawal event");
        assertEq(river.getBalanceToRedeem(), 0, "the exit was skimmed out of the redeem balance");
        assertEq(
            river.getBalanceToDeposit() + river.getCommittedBalance(),
            depositSideBefore + exitedEth,
            "the exit landed on the deposit side in full"
        );
    }

    /// **Scenario:** slashing containment is active on a report whose `BalanceToRedeem` was already funded
    /// by the exit sweep pulled earlier in that same report, with a stopped-earning delta alongside.
    /// **Expected:** containment only suppresses forward-looking actions — it skips deposit-to-redeem
    /// rebalancing plus exit demand, and skips committing to deposit — but settlement out of the funds
    /// already in hand proceeds, and the demand it settles is still marked. Suspending accrual under
    /// containment would penalise a queued redeemer twice: once by the depressed rate, once by the longer
    /// wait containment causes.
    function testSlashingContainmentStillSettlesAndMarksFundedDemand() public {
        uint256 epoch1 = _seedAppreciatedRequest();

        uint256 exitedEth = 12 ether;
        vm.deal(address(withdraw), exitedEth);

        uint256 stoppedEarningEth = 12 ether;
        uint256 reportedLsETH = river.sharesFromUnderlyingBalance(stoppedEarningEth);
        uint256 expectedMarkedEth = (stoppedEarningEth * SEED_REDEEM_LSETH) / reportedLsETH;
        uint256 exitsDemandBefore = operatorsRegistry.getCurrentETHExitsDemand();
        uint256 committedBefore = river.getCommittedBalance();

        uint256 epoch2 = epoch1 + REPORT_GAP;
        _warpToFinalizedEpoch(epoch2);
        IOracleManagerV1.ConsensusLayerReport memory clr = _exitReport(epoch2, exitedEth);
        clr.validatorsBalance = SEED_CL_REWARD - exitedEth + 8 ether;
        clr.validatorsStoppedEarningBalance = stoppedEarningEth;
        clr.slashingContainmentMode = true;

        vm.expectEmit(true, true, true, true, address(river));
        emit IRiverV1.SkippedExitRequestsDueToSlashingContainment();
        vm.expectEmit(true, true, true, true, address(river));
        emit IRiverV1.SkippedCommitToDepositDueToSlashingContainment();
        vm.prank(address(oracle));
        river.setConsensusLayerData(clr);

        // forward-looking work really was skipped. `reportExitedETH` runs BEFORE the containment gate, so
        // the 12 ETH sweep is first booked as answering the standing exit demand left over from the seed
        // report and zeroes it; containment then returns before any NEW demand can be raised, which is why
        // this lands at exactly zero instead of being re-armed at the still-outstanding balance.
        assertGt(exitsDemandBefore, 0, "the seed report left a standing exit demand to observe");
        assertEq(operatorsRegistry.getCurrentETHExitsDemand(), 0, "containment must not raise new exit demand");
        assertEq(river.getCommittedBalance(), committedBefore, "nothing committed to deposit");

        // settlement out of the already-pulled exit ETH still happened, and it was still marked
        assertEq(redeemManager.getRateMarkCount(), 1);
        RateMarkStack.RateMark memory mark = redeemManager.getRateMarkDetails(0);
        assertEq(mark.height, 0);
        assertEq(mark.amount, SEED_REDEEM_LSETH);
        assertEq(mark.markedEth, expectedMarkedEth);

        assertEq(redeemManager.getWithdrawalEventCount(), 1);
        WithdrawalStack.WithdrawalEvent memory we = redeemManager.getWithdrawalEventDetails(0);
        assertEq(we.height, 0);
        assertEq(we.amount, SEED_REDEEM_LSETH);
        assertGt(we.withdrawnEth, mark.markedEth);

        uint256 received = _claimAlice(type(uint16).max);
        assertEq(received, mark.markedEth);
        assertGt(received, 8 ether, "containment did not cost the redeemer their accrued yield");
    }

    /// **Scenario:** a containment report marks and partially settles, then containment is switched off and
    /// a second stopped-earning delta lands.
    /// **Expected:** exit demand resumes on the second report, and the mark cursor is continuous across the
    /// containment gap. The second mark starts exactly where the first ended — no axis position is marked
    /// twice, and none is skipped — because `reportStoppedEarning` advances from
    /// `max(lastMarkEnd, settledHeight, floor)` and the containment report left the mark cursor ahead of
    /// the settled height.
    function testContainmentToggleOffResumesExitsWithContinuousMarkCursor() public {
        _initRiverMinimalForReporting();
        uint256 epochA = REPORT_GAP;
        uint256 maxIncrease = _seedRedeemDemandAndBound(SEED_DEPOSIT, SEED_REDEEM_LSETH, epochA);
        assertGt(maxIncrease, SEED_CL_REWARD);

        // ── report A: containment on. 4 ETH of sweep lands and 6 ETH of principal stops earning. ──
        uint256 exitedEth = 4 ether;
        vm.deal(address(withdraw), exitedEth);
        IOracleManagerV1.ConsensusLayerReport memory clrA = _exitReport(epochA, exitedEth);
        clrA.validatorsBalance = SEED_CL_REWARD - exitedEth;
        clrA.validatorsStoppedEarningBalance = 6 ether;
        clrA.slashingContainmentMode = true;
        vm.prank(address(oracle));
        river.setConsensusLayerData(clrA);

        // the pre-report rate was still the genesis 1:1, so 6 ETH marks exactly 6 LsETH
        assertEq(redeemManager.getRateMarkCount(), 1);
        RateMarkStack.RateMark memory mark1 = redeemManager.getRateMarkDetails(0);
        assertEq(mark1.height, 0);
        assertEq(mark1.amount, 6e18);
        assertEq(mark1.markedEth, 6 ether);

        // the 4 ETH in hand settled a slice smaller than the mark, so the cursor now sits ABOVE the
        // settled height — the case where taking max(cursor, settled) actually matters
        assertEq(redeemManager.getWithdrawalEventCount(), 1);
        WithdrawalStack.WithdrawalEvent memory we1 = redeemManager.getWithdrawalEventDetails(0);
        assertEq(we1.withdrawnEth, exitedEth);
        assertLt(we1.amount, mark1.amount);
        // containment skipped the exit-demand branch entirely
        assertEq(operatorsRegistry.getCurrentETHExitsDemand(), 0, "containment must not demand exits");

        // ── report B: containment off, a second delta lands, no new sweep ──
        uint256 epochB = epochA + REPORT_GAP;
        _warpToFinalizedEpoch(epochB);
        IOracleManagerV1.ConsensusLayerReport memory clrB = _exitReport(epochB, exitedEth);
        clrB.validatorsBalance = SEED_CL_REWARD - exitedEth; // flat report: no rewards, no new exit
        clrB.validatorsStoppedEarningBalance = 6 ether + 6 ether;
        vm.prank(address(oracle));
        river.setConsensusLayerData(clrB);

        assertEq(redeemManager.getRateMarkCount(), 2);
        RateMarkStack.RateMark memory mark2 = redeemManager.getRateMarkDetails(1);
        // continuity: starts exactly at the first mark's end, above the settled height, and the two marks
        // together tile the request exactly once
        assertEq(mark2.height, mark1.height + mark1.amount);
        assertGt(mark2.height, we1.amount);
        assertEq(mark2.amount, SEED_REDEEM_LSETH - mark1.amount);
        assertEq(mark1.amount + mark2.amount, SEED_REDEEM_LSETH);

        // exit demand resumed, sized at the still-outstanding demand valued at the current rate
        uint256 outstandingInEth = river.underlyingBalanceFromShares(redeemManager.getRedeemDemand());
        assertGt(outstandingInEth, 0);
        assertEq(operatorsRegistry.getCurrentETHExitsDemand(), outstandingInEth, "exit demand resumed");
    }

    /// **Scenario:** the redeem manager's `BufferedExceedingEth` is larger than a single report's APR
    /// headroom, across two consecutive one-day reports.
    /// **Expected:** `_pullRedeemManagerExceedingEth` is handed `availableAmountToUpperBound` as its max, so
    /// it pulls exactly the headroom and no more; the remainder stays buffered in the redeem manager and is
    /// pulled by the next report. Pulling the whole buffer at once would push the reported balance increase
    /// past the upper reporting bound.
    function testExceedingEthPullBoundedByAprHeadroomAcrossReports() public {
        _initRiverMinimalForReporting();
        address alice = makeAddr("alice");
        _allowDeposit(alice);
        vm.deal(alice, SEED_DEPOSIT);
        vm.prank(alice);
        river.deposit{value: SEED_DEPOSIT}();

        // 1 ETH buffered against a headroom of ~0.0175 ETH per one-day report
        uint256 buffered = 1 ether;
        vm.store(address(redeemManager), BUFFERED_EXCEEDING_ETH_SLOT, bytes32(buffered));
        vm.deal(address(redeemManager), buffered);

        uint256 epoch1 = epochsPerFrame; // exactly one day of reporting period
        _warpToFinalizedEpoch(epoch1);
        uint256 headroom1 = _maxIncreaseBetween(0, epoch1);
        assertGt(headroom1, 0);
        assertLt(headroom1, buffered, "the headroom must be the binding constraint");

        // a flat report: no CL movement, so rewards are zero and the whole headroom is available to pull
        IOracleManagerV1.ConsensusLayerReport memory clr1 = _baseReport(epoch1);
        vm.prank(address(oracle));
        river.setConsensusLayerData(clr1);

        assertEq(redeemManager.getBufferedExceedingEth(), buffered - headroom1, "pulled exactly the headroom");
        assertEq(address(redeemManager).balance, buffered - headroom1);

        uint256 epoch2 = epoch1 + epochsPerFrame;
        _warpToFinalizedEpoch(epoch2);
        // the first pull grew the pool, so this report's headroom is strictly larger
        uint256 headroom2 = _maxIncreaseBetween(epoch1, epoch2);
        assertGt(headroom2, headroom1);

        IOracleManagerV1.ConsensusLayerReport memory clr2 = _baseReport(epoch2);
        vm.prank(address(oracle));
        river.setConsensusLayerData(clr2);

        assertEq(redeemManager.getBufferedExceedingEth(), buffered - headroom1 - headroom2);
        assertGt(redeemManager.getBufferedExceedingEth(), 0, "the remainder is still buffered");
    }

    function testReportConsolidationsUnchangedKeepsBuffer() public {
        _initRiverMinimalForReporting();
        // No consolidation coverage fund configured, so the end-of-report pull path cannot touch the buffer.
        assertEq(river.getConsolidationCoverageFund(), address(0));

        uint256 buffer = 2 ether;
        uint256 storedConsolidations = 5 ether;
        vm.store(address(river), CONSOLIDATION_BUFFER_SLOT, bytes32(buffer));
        // Seed the last stored report's totalExternalConsolidationETH = X.
        _seedStoredConsolidations(storedConsolidations);

        uint256 epoch = epochsPerFrame;
        _warpToFinalizedEpoch(epoch);
        IOracleManagerV1.ConsensusLayerReport memory clr;
        clr.epoch = epoch;
        clr.validatorsBalance = 0;
        clr.totalDepositedActivatedETH = 0;
        // Same value as the stored report: no increase, so no reduction.
        clr.totalExternalConsolidationETH = storedConsolidations;
        clr.exitedETHPerOperator = new uint256[](1);
        clr.activeCLETHPerOperator = new uint256[](1);

        vm.prank(address(oracle));
        river.setConsensusLayerData(clr);

        // The buffer must be exactly what we seeded: the strict `>` branch was not taken and no coverage
        // pull occurred.
        assertEq(uint256(vm.load(address(river), CONSOLIDATION_BUFFER_SLOT)), buffer);
        assertEq(river.getBalanceToConsolidate(), buffer);
    }

    /// Asserts that when the reported consolidation increase exceeds the current buffer, the buffer reduction
    /// is capped at the buffer (ends at 0, no underflow) and the report succeeds. The excess is not separately
    /// booked because it is already reflected in the validatorsBalance increase.
    function testReportConsolidationsIncreaseCappedAtBuffer() public {
        _initRiverMinimalForReporting();
        assertEq(river.getConsolidationCoverageFund(), address(0));

        // Give the pool a backing so total supply > 0 (onEarnings won't revert with ZeroMintedShares).
        address alice = makeAddr("alice");
        _allowDeposit(alice);
        vm.deal(alice, 32 ether);
        vm.prank(alice);
        river.deposit{value: 32 ether}();

        uint256 buffer = 1 ether; // B
        vm.store(address(river), CONSOLIDATION_BUFFER_SLOT, bytes32(buffer));
        // Last stored consolidations = 0 (default) so the whole report value is the increase.
        // delta = 3 ether > B = 1 ether -> reduction capped at B.
        uint256 reportedConsolidations = 3 ether;

        // Seed a matching last stored validatorsBalance so the post-report balance stays within bounds.
        // pre  = oldVB(0) + buffer(B) + balanceToDeposit(32e) + ...
        // post = newVB(reportedConsolidations) + buffer(0) + balanceToDeposit(32e) + ...
        // The net increase (reportedConsolidations - B) is bounded by the APR upper bound over the elapsed
        // period; keep it tiny so we exercise the cap without tripping the bound.
        uint256 epoch = epochsPerFrame;
        _warpToFinalizedEpoch(epoch);
        IOracleManagerV1.ConsensusLayerReport memory clr;
        clr.epoch = epoch;
        // validatorsBalance increase must accommodate the APR bound. Choose the reported consolidation
        // amount minus the buffer to represent the net rewards, but keep the net small enough. Here we make
        // validatorsBalance exactly equal to the buffer B so the net underlying change is zero and the report
        // is trivially in bounds, while still forcing the increase (delta=3e) > buffer(1e) via the reported
        // consolidation field.
        clr.validatorsBalance = buffer;
        clr.totalDepositedActivatedETH = 0;
        clr.totalExternalConsolidationETH = reportedConsolidations;
        clr.exitedETHPerOperator = new uint256[](1);
        clr.activeCLETHPerOperator = new uint256[](1);

        // The reduction is capped: SetConsolidationBuffer(buffer, 0).
        vm.expectEmit(true, true, true, true, address(river));
        emit SetConsolidationBuffer(buffer, 0);

        vm.prank(address(oracle));
        river.setConsensusLayerData(clr);

        // Buffer capped to 0, no underflow, report succeeded.
        assertEq(uint256(vm.load(address(river), CONSOLIDATION_BUFFER_SLOT)), 0);
        assertEq(river.getBalanceToConsolidate(), 0);
        // Confirm the stored report recorded the full reported amount.
        assertEq(river.getLastConsensusLayerReport().totalExternalConsolidationETH, reportedConsolidations);
    }

    /// Regression guard: a report whose validatorsBalance increase is exactly matched by a consolidation
    /// increase must NOT be booked as rewards. The consolidation was already accounted for in the buffer when
    /// it happened; the buffer reduction offsets the validatorsBalance increase in totalUnderlyingSupply
    /// (which includes both), so the net change is zero, no fee shares are minted to the collector, and the
    /// APR upper-bound revert is not tripped.
    function testReportConsolidationsIncreaseNotBookedAsRewards() public {
        _initRiverMinimalForReporting();
        assertEq(river.getConsolidationCoverageFund(), address(0));

        // Backing so total supply > 0.
        address alice = makeAddr("alice");
        _allowDeposit(alice);
        vm.deal(alice, 32 ether);
        vm.prank(alice);
        river.deposit{value: 32 ether}();

        uint256 buffer = 4 ether; // B, already includes the consolidated funds
        vm.store(address(river), CONSOLIDATION_BUFFER_SLOT, bytes32(buffer));

        uint256 collectorSharesBefore = river.balanceOfUnderlying(collector);
        uint256 collectorRawSharesBefore = river.balanceOf(collector);
        uint256 totalSupplyBefore = river.totalSupply();
        uint256 totalUnderlyingBefore = river.totalUnderlyingSupply();

        uint256 epoch = epochsPerFrame;
        _warpToFinalizedEpoch(epoch);
        IOracleManagerV1.ConsensusLayerReport memory clr;
        clr.epoch = epoch;
        // validatorsBalance increases by exactly the consolidation delta (last stored VB = 0).
        clr.validatorsBalance = buffer;
        clr.totalDepositedActivatedETH = 0;
        // The consolidation increase (== buffer) offsets the validatorsBalance increase: buffer drops by
        // `buffer` at the same time validatorsBalance rises by `buffer`, so totalUnderlyingSupply is flat.
        clr.totalExternalConsolidationETH = buffer;
        clr.exitedETHPerOperator = new uint256[](1);
        clr.activeCLETHPerOperator = new uint256[](1);

        vm.prank(address(oracle));
        river.setConsensusLayerData(clr);

        // Buffer fully reduced by the reported increase.
        assertEq(uint256(vm.load(address(river), CONSOLIDATION_BUFFER_SLOT)), 0);
        assertEq(river.getBalanceToConsolidate(), 0);

        // The consolidation-offset portion must NOT be counted as rewards: no fee shares minted to the
        // collector, total supply unchanged, and the total underlying supply unchanged by the offset.
        assertEq(river.balanceOf(collector), collectorRawSharesBefore);
        assertEq(river.balanceOfUnderlying(collector), collectorSharesBefore);
        assertEq(river.totalSupply(), totalSupplyBefore);
        assertEq(river.totalUnderlyingSupply(), totalUnderlyingBefore);
    }

    /// Asserts that a report whose totalDepositedActivatedETH is LESS than the last stored report reverts with
    /// InvalidTotalDepositedActivatedETHDecrease. Covers LibOracleReporting.setConsensusLayerData L118.
    function testReportingError_InvalidTotalDepositedActivatedETHDecrease() public {
        _initRiverMinimalForReporting();

        uint256 lastDeposited = 64 ether;
        // Seed last stored report totalDepositedActivatedETH to a non-zero value.
        _seedStoredTotalDepositedActivatedETH(lastDeposited);

        uint256 epoch = epochsPerFrame;
        _warpToFinalizedEpoch(epoch);
        IOracleManagerV1.ConsensusLayerReport memory clr;
        clr.epoch = epoch;
        // New value strictly below the stored one triggers the decrease revert.
        uint256 newDeposited = 32 ether;
        clr.totalDepositedActivatedETH = newDeposited;
        clr.exitedETHPerOperator = new uint256[](1);
        clr.activeCLETHPerOperator = new uint256[](1);

        vm.prank(address(oracle));
        vm.expectRevert(
            abi.encodeWithSignature(
                "InvalidTotalDepositedActivatedETHDecrease(uint256,uint256)", lastDeposited, newDeposited
            )
        );
        river.setConsensusLayerData(clr);
    }

    /// Asserts that a report whose totalDepositedActivatedETH increase exceeds the current in-flight ETH reverts
    /// with InvalidTotalDepositedActivatedETHIncrease. Covers LibOracleReporting.setConsensusLayerData L129.
    function testReportingError_InvalidTotalDepositedActivatedETHIncrease() public {
        _initRiverMinimalForReporting();

        // Last stored report totalDepositedActivatedETH = 0 (default), so the increase equals the reported value.
        uint256 inFlight = 32 ether;
        vm.store(address(river), IN_FLIGHT_DEPOSIT_SLOT, bytes32(inFlight));

        uint256 epoch = epochsPerFrame;
        _warpToFinalizedEpoch(epoch);
        IOracleManagerV1.ConsensusLayerReport memory clr;
        clr.epoch = epoch;
        // Increase (newDeposited - 0) is strictly greater than the in-flight ETH.
        uint256 newDeposited = inFlight + 1 ether;
        clr.totalDepositedActivatedETH = newDeposited;
        clr.exitedETHPerOperator = new uint256[](1);
        clr.activeCLETHPerOperator = new uint256[](1);

        vm.prank(address(oracle));
        // The revert reports (currentInFlightETH, newTotalDepositedActivatedETH).
        vm.expectRevert(
            abi.encodeWithSignature(
                "InvalidTotalDepositedActivatedETHIncrease(uint256,uint256)", inFlight, newDeposited
            )
        );
        river.setConsensusLayerData(clr);
    }

    /// Asserts that a report whose validatorsCount is LESS than the last stored report reverts with
    /// InvalidValidatorCountReport. Covers LibOracleReporting.setConsensusLayerData L136.
    function testReportingError_InvalidValidatorCountReport() public {
        _initRiverMinimalForReporting();

        // Seed validatorsCount to a value higher than the one we will report.
        uint32 lastCount = 5;
        _seedStoredValidatorsCount(lastCount);

        uint256 epoch = epochsPerFrame;
        _warpToFinalizedEpoch(epoch);
        IOracleManagerV1.ConsensusLayerReport memory clr;
        clr.epoch = epoch;
        uint32 newCount = 3; // strictly less than lastCount -> revert
        clr.validatorsCount = newCount;
        clr.totalDepositedActivatedETH = 0;
        clr.exitedETHPerOperator = new uint256[](1);
        clr.activeCLETHPerOperator = new uint256[](1);

        vm.prank(address(oracle));
        // The revert reports (reportedValidatorCount, lastReportedValidatorCount).
        vm.expectRevert(abi.encodeWithSignature("InvalidValidatorCountReport(uint256,uint256)", newCount, lastCount));
        river.setConsensusLayerData(clr);
    }

    /// Asserts that a report whose totalExternalConsolidationETH is LESS than the last stored report
    /// reverts with InvalidTotalConsolidationsAmountReportedDecrease. Covers
    /// LibOracleReporting.setConsensusLayerData L144-145.
    function testReportingError_InvalidTotalConsolidationsAmountReportedDecrease() public {
        _initRiverMinimalForReporting();

        uint256 lastConsolidations = 5 ether;
        // Seed last stored report totalExternalConsolidationETH.
        _seedStoredConsolidations(lastConsolidations);

        uint256 epoch = epochsPerFrame;
        _warpToFinalizedEpoch(epoch);
        IOracleManagerV1.ConsensusLayerReport memory clr;
        clr.epoch = epoch;
        clr.totalDepositedActivatedETH = 0;
        uint256 newConsolidations = 2 ether; // strictly less than stored -> revert
        clr.totalExternalConsolidationETH = newConsolidations;
        clr.exitedETHPerOperator = new uint256[](1);
        clr.activeCLETHPerOperator = new uint256[](1);

        vm.prank(address(oracle));
        // The revert reports (lastTotalConsolidationsAmountReported, newTotalConsolidationsAmountReported).
        vm.expectRevert(
            abi.encodeWithSignature(
                "InvalidTotalConsolidationsAmountReportedDecrease(uint256,uint256)",
                lastConsolidations,
                newConsolidations
            )
        );
        river.setConsensusLayerData(clr);
    }

    /// Asserts the WITHIN-BOUND balance-DECREASE (loss) accounting path: a report whose post-report underlying
    /// balance is LESS than the pre-report balance but whose decrease stays within the allowed lower bound must
    /// SUCCEED (no revert) and mint NO reward fee shares to the collector (a loss produces no rewards).
    /// Covers LibOracleReporting.setConsensusLayerData L264 (the loss branch of availableAmountToUpperBound).
    function testReportingSuccess_WithinBoundBalanceDecreaseMintsNoRewards() public {
        _initRiverMinimalForReporting();
        // No coverage / EL fees available, so availableAmountToUpperBound cannot be consumed by pulls and the
        // loss branch is exercised without any reward being booked.
        assertEq(river.getConsolidationCoverageFund(), address(0));

        address alice = makeAddr("alice");
        _allowDeposit(alice);
        vm.deal(alice, 32 ether);
        vm.prank(alice);
        river.deposit{value: 32 ether}();

        // Seed the last stored report validatorsBalance so this report represents a modest loss.
        uint256 lastValidatorsBalance = 32 ether;
        _seedStoredValidatorsBalance(lastValidatorsBalance);

        uint256 epoch = epochsPerFrame;
        _warpToFinalizedEpoch(epoch);

        // Compute the maximum allowed decrease for the current pre-report underlying supply and keep the loss
        // strictly within it so the lower-bound revert is not tripped.
        uint256 preUnderlying = river.totalUnderlyingSupply();
        uint256 maxDecrease =
            (preUnderlying * river.getReportBounds().relativeLowerBound) / LibBasisPoints.BASIS_POINTS_MAX;
        assertGt(maxDecrease, 0);
        uint256 loss = maxDecrease / 2;
        assertGt(loss, 0);

        IOracleManagerV1.ConsensusLayerReport memory clr;
        clr.epoch = epoch;
        // validatorsBalance drops by `loss` relative to the last stored report: post < pre, within bound.
        clr.validatorsBalance = lastValidatorsBalance - loss;
        clr.totalDepositedActivatedETH = 0;
        clr.exitedETHPerOperator = new uint256[](1);
        clr.activeCLETHPerOperator = new uint256[](1);

        uint256 collectorSharesBefore = river.balanceOf(collector);
        uint256 totalSupplyBefore = river.totalSupply();

        // Must succeed: the decrease is within bound, so no TotalValidatorBalanceDecreaseOutOfBound revert.
        vm.prank(address(oracle));
        river.setConsensusLayerData(clr);

        // A loss produces no rewards: no fee shares minted to the collector, total supply unchanged.
        assertEq(river.balanceOf(collector), collectorSharesBefore);
        assertEq(river.totalSupply(), totalSupplyBefore);
        // And the loss was actually applied.
        assertLt(river.totalUnderlyingSupply(), preUnderlying);
    }

    function _initRiverAndV1_2() internal {
        super.setUp();
        redeemManager = new RedeemManagerV1WithLegacyInit();
        LibImplementationUnbricker.unbrick(vm, address(redeemManager));
        bytes32 wc = withdraw.getCredentials();
        river.initRiverV1(
            address(deposit),
            address(elFeeRecipient),
            wc,
            address(oracle),
            admin,
            address(allowlist),
            address(operatorsRegistry),
            collector,
            500
        );
        river.initRiverV1_1(
            address(redeemManager),
            epochsPerFrame,
            slotsPerEpoch,
            secondsPerSlot,
            0,
            epochsUntilFinal,
            1000,
            500,
            maxDailyNetCommittableAmount,
            maxDailyRelativeCommittableAmount
        );
        river.initRiverV1_2();
        withdraw.initializeWithdrawV1(address(river));
        oracle.initOracleV1(address(river), admin, epochsPerFrame, slotsPerEpoch, secondsPerSlot, 0, 1000, 500);
        vm.prank(admin);
        oracle.addMember(oracleMember, 1);
        vm.prank(admin);
        river.setKeeper(keeper);
        redeemManager.initializeRedeemManagerV1(address(river));
    }

    function _initRiverMinimalForReporting() internal {
        super.setUp();
        redeemManager = new RedeemManagerV1WithLegacyInit();
        LibImplementationUnbricker.unbrick(vm, address(redeemManager));
        bytes32 wc = withdraw.getCredentials();
        river.initRiverV1(
            address(deposit),
            address(elFeeRecipient),
            wc,
            address(oracle),
            admin,
            address(allowlist),
            address(operatorsRegistry),
            collector,
            500
        );
        river.initRiverV1_1(
            address(redeemManager),
            epochsPerFrame,
            slotsPerEpoch,
            secondsPerSlot,
            0,
            epochsUntilFinal,
            1000,
            500,
            maxDailyNetCommittableAmount,
            maxDailyRelativeCommittableAmount
        );
        river.initRiverV1_2();
        withdraw.initializeWithdrawV1(address(river));
        oracle.initOracleV1(address(river), admin, epochsPerFrame, slotsPerEpoch, secondsPerSlot, 0, 1000, 500);
        vm.prank(admin);
        oracle.addMember(oracleMember, 1);
        vm.prank(admin);
        river.setKeeper(keeper);
        redeemManager.initializeRedeemManagerV1(address(river));
        // Add one operator so _reportCLETH(activeCLETHPerOperator) doesn't revert InvalidEmptyArray.
        vm.prank(admin);
        operatorsRegistry.addOperator("MinimalOp", admin);
    }

    function _allowDeposit(address _who) internal {
        address[] memory allowees = new address[](1);
        allowees[0] = _who;
        uint256[] memory permissions = new uint256[](1);
        permissions[0] = LibAllowlistMasks.REDEEM_MASK | LibAllowlistMasks.DEPOSIT_MASK;
        vm.prank(allower);
        allowlist.setAllowPermissions(allowees, permissions);
    }
}

// --- Mocks for River Pectra (withdraw/consolidate) tests ---

contract MockELWithdrawalForRiver {
    uint256 public fee = 1 gwei;

    function setFee(uint256 _fee) external {
        fee = _fee;
    }

    fallback(bytes calldata) external payable returns (bytes memory) {
        return abi.encode(fee);
    }
}

contract MockELConsolidationForRiver {
    uint256 public fee = 1 gwei;

    function setFee(uint256 _fee) external {
        fee = _fee;
    }

    fallback(bytes calldata) external payable returns (bytes memory) {
        return abi.encode(fee);
    }
}

contract RiverV1PectraTests is RiverV1TestBase {
    event PectraWithdrawRequested(
        bytes[] pubkeys, uint64[] amount, uint256 maxFeePerWithdrawal, address excessFeeRecipient, uint256 valueSent
    );
    event PectraConsolidationRequested(
        IWithdrawV1.ConsolidationRequest[] requests,
        uint256 maxFeePerConsolidation,
        address excessFeeRecipient,
        uint256 valueSent
    );

    MockELWithdrawalForRiver internal mockWithdrawal;
    MockELConsolidationForRiver internal mockConsolidation;

    bytes internal constant VALID_PUBKEY_48 =
        hex"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";
    bytes32 internal constant PECTRA_VALIDATOR_PUBKEY_LOOKUP_SLOT =
        bytes32(uint256(keccak256("attestationVerifier.state.pectraValidatorPubkeyLookup")) - 1);
    bytes32 internal constant PRE_PECTRA_VALIDATOR_PUBKEY_LOOKUP_SLOT =
        bytes32(uint256(keccak256("attestationVerifier.state.prePectraValidatorPubkeyLookup")) - 1);

    function setUp() public override {
        super.setUp();
        bytes32 withdrawalCredentials = withdraw.getCredentials();
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

        address[] memory _initRootAttesters = new address[](3);
        _initRootAttesters[0] = rootAttester1;
        _initRootAttesters[1] = rootAttester2;
        _initRootAttesters[2] = rootAttester3;
        address[] memory _initConsolidationCommitteeAttesters = new address[](1);
        _initConsolidationCommitteeAttesters[0] = makeAddr("consolidationCommitteeAttesterStub");
        attestationVerifier = new AttestationVerifierV1();
        LibImplementationUnbricker.unbrick(vm, address(attestationVerifier));
        attestationVerifier.initAttestationVerifierV1(
            address(river),
            address(depositBuffer),
            _initRootAttesters,
            2,
            bytes4(0),
            _initConsolidationCommitteeAttesters,
            1
        );
        vm.store(
            address(river),
            bytes32(uint256(keccak256("river.state.attestationVerifierAddress")) - 1),
            bytes32(uint256(uint160(address(attestationVerifier))))
        );

        withdraw.initializeWithdrawV1(address(river));
        mockWithdrawal = new MockELWithdrawalForRiver();
        mockConsolidation = new MockELConsolidationForRiver();
        withdraw.initWithdrawV1_1(
            address(mockWithdrawal),
            address(mockConsolidation),
            address(operatorsRegistry),
            address(attestationVerifier)
        );
        _seedValidatorPubkey(VALID_PUBKEY_48);
        vm.startPrank(admin);
        river.setKeeper(keeper);
        river.setConsolidator(consolidator);
        vm.stopPrank();
    }

    function _seedValidatorPubkey(bytes memory pubkey) internal {
        bytes32 slot = keccak256(abi.encode(PECTRA_VALIDATOR_PUBKEY_LOOKUP_SLOT, pubkey));
        vm.store(address(attestationVerifier), slot, bytes32(uint256(1)));
    }

    function _seedPrePectraPubkey(bytes memory pubkey) internal {
        bytes32 slot = keccak256(abi.encode(PRE_PECTRA_VALIDATOR_PUBKEY_LOOKUP_SLOT, pubkey));
        vm.store(address(attestationVerifier), slot, bytes32(uint256(1)));
    }

    function _consolidationPubkey(uint256 seed) internal pure returns (bytes memory) {
        return abi.encodePacked(sha256(abi.encode("river-consolidation", seed)), bytes16(0));
    }

    function testRiverConsolidateAsConsolidatorEmitsEventAndForwards() public {
        bytes[] memory srcPubkeys = new bytes[](1);
        srcPubkeys[0] = VALID_PUBKEY_48;
        IWithdrawV1.ConsolidationRequest[] memory requests = new IWithdrawV1.ConsolidationRequest[](1);
        requests[0] = IWithdrawV1.ConsolidationRequest({srcPubkeys: srcPubkeys, targetPubkey: VALID_PUBKEY_48});
        uint256 valueSent = 5 gwei;
        vm.deal(consolidator, valueSent);

        vm.prank(consolidator);
        vm.expectEmit(true, true, true, true);
        emit PectraConsolidationRequested(requests, 1 gwei, consolidator, valueSent);
        river.consolidate{value: valueSent}(requests, 1 gwei);

        assertEq(address(mockConsolidation).balance, 1 gwei);
        assertEq(consolidator.balance, valueSent - 1 gwei);
    }

    function testRiverSelfConsolidationAsConsolidatorValidatesAndForwardsPrePectraPubkeys() public {
        bytes memory pk0 = _consolidationPubkey(60);
        bytes memory pk1 = _consolidationPubkey(61);
        _seedPrePectraPubkey(pk0);
        _seedPrePectraPubkey(pk1);

        bytes[] memory pubkeys = new bytes[](2);
        pubkeys[0] = pk0;
        pubkeys[1] = pk1;

        IWithdrawV1.ConsolidationRequest[] memory requests = new IWithdrawV1.ConsolidationRequest[](2);
        requests[0] = IWithdrawV1.ConsolidationRequest({srcPubkeys: new bytes[](1), targetPubkey: pk0});
        requests[0].srcPubkeys[0] = pk0;
        requests[1] = IWithdrawV1.ConsolidationRequest({srcPubkeys: new bytes[](1), targetPubkey: pk1});
        requests[1].srcPubkeys[0] = pk1;

        uint256 valueSent = 5 gwei;
        vm.deal(consolidator, valueSent);

        vm.expectCall(address(mockConsolidation), 1 gwei, bytes.concat(pk0, pk0));
        vm.expectCall(address(mockConsolidation), 1 gwei, bytes.concat(pk1, pk1));
        vm.prank(consolidator);
        vm.expectEmit(true, true, true, true);
        emit PectraConsolidationRequested(requests, 1 gwei, consolidator, valueSent);
        river.selfConsolidation{value: valueSent}(pubkeys, 1 gwei);

        assertEq(address(mockConsolidation).balance, 2 gwei);
        assertEq(consolidator.balance, valueSent - 2 gwei);
    }

    function testRiverConsolidateNonConsolidatorReverts() public {
        bytes[] memory srcPubkeys = new bytes[](1);
        srcPubkeys[0] = VALID_PUBKEY_48;
        IWithdrawV1.ConsolidationRequest[] memory requests = new IWithdrawV1.ConsolidationRequest[](1);
        requests[0] = IWithdrawV1.ConsolidationRequest({srcPubkeys: srcPubkeys, targetPubkey: VALID_PUBKEY_48});
        vm.deal(bob, 1 gwei);

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSignature("OnlyConsolidator()"));
        river.consolidate{value: 1 gwei}(requests, 1 gwei);
    }

    function testRiverConsolidateKeeperRevertsWhenNotConsolidator() public {
        bytes[] memory srcPubkeys = new bytes[](1);
        srcPubkeys[0] = VALID_PUBKEY_48;
        IWithdrawV1.ConsolidationRequest[] memory requests = new IWithdrawV1.ConsolidationRequest[](1);
        requests[0] = IWithdrawV1.ConsolidationRequest({srcPubkeys: srcPubkeys, targetPubkey: VALID_PUBKEY_48});
        vm.deal(keeper, 1 gwei);

        vm.prank(keeper);
        vm.expectRevert(abi.encodeWithSignature("OnlyConsolidator()"));
        river.consolidate{value: 1 gwei}(requests, 1 gwei);
    }

    function testRiverSelfConsolidationNonConsolidatorReverts() public {
        bytes[] memory pubkeys = new bytes[](1);
        pubkeys[0] = VALID_PUBKEY_48;

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSignature("OnlyConsolidator()"));
        river.selfConsolidation(pubkeys, 1 gwei);
    }

    function testRiverSelfConsolidationKeeperRevertsWhenNotConsolidator() public {
        bytes[] memory pubkeys = new bytes[](1);
        pubkeys[0] = VALID_PUBKEY_48;

        vm.prank(keeper);
        vm.expectRevert(abi.encodeWithSignature("OnlyConsolidator()"));
        river.selfConsolidation(pubkeys, 1 gwei);
    }

    function testRiverConsolidateMultipleSrcPubkeysForwardsAll() public {
        bytes[] memory srcPubkeys = new bytes[](3);
        srcPubkeys[0] = VALID_PUBKEY_48;
        srcPubkeys[1] = VALID_PUBKEY_48;
        srcPubkeys[2] = VALID_PUBKEY_48;
        IWithdrawV1.ConsolidationRequest[] memory requests = new IWithdrawV1.ConsolidationRequest[](1);
        requests[0] = IWithdrawV1.ConsolidationRequest({srcPubkeys: srcPubkeys, targetPubkey: VALID_PUBKEY_48});

        uint256 feePerOp = 1 gwei;
        uint256 valueSent = feePerOp * 3; // 3 src pubkeys
        vm.deal(consolidator, valueSent);

        vm.prank(consolidator);
        river.consolidate{value: valueSent}(requests, feePerOp);

        assertEq(address(mockConsolidation).balance, valueSent, "all 3 fees should be forwarded");
        assertEq(consolidator.balance, 0, "no excess since exact fee sent");
    }

    function testRiverConsolidateExcessFeeRefundedToConsolidator() public {
        bytes[] memory srcPubkeys = new bytes[](1);
        srcPubkeys[0] = VALID_PUBKEY_48;
        IWithdrawV1.ConsolidationRequest[] memory requests = new IWithdrawV1.ConsolidationRequest[](1);
        requests[0] = IWithdrawV1.ConsolidationRequest({srcPubkeys: srcPubkeys, targetPubkey: VALID_PUBKEY_48});

        uint256 maxFee = 5 gwei;
        uint256 actualFee = 1 gwei;
        mockConsolidation.setFee(actualFee);
        vm.deal(consolidator, maxFee);

        vm.prank(consolidator);
        river.consolidate{value: maxFee}(requests, maxFee);

        assertEq(address(mockConsolidation).balance, actualFee, "only actual fee paid");
        assertEq(consolidator.balance, maxFee - actualFee, "excess refunded to consolidator");
    }

    function testRiverConsolidateAllowsPrePectraSourceAndValidatorTarget() public {
        bytes memory sourcePubkey = _consolidationPubkey(50);
        _seedPrePectraPubkey(sourcePubkey);

        bytes[] memory srcPubkeys = new bytes[](1);
        srcPubkeys[0] = sourcePubkey;
        IWithdrawV1.ConsolidationRequest[] memory requests = new IWithdrawV1.ConsolidationRequest[](1);
        requests[0] = IWithdrawV1.ConsolidationRequest({srcPubkeys: srcPubkeys, targetPubkey: VALID_PUBKEY_48});

        uint256 fee = 1 gwei;
        vm.deal(consolidator, fee);

        vm.expectCall(address(mockConsolidation), fee, bytes.concat(sourcePubkey, VALID_PUBKEY_48));
        vm.prank(consolidator);
        river.consolidate{value: fee}(requests, fee);

        assertEq(address(mockConsolidation).balance, fee);
    }

    function testRiverConsolidateFeeTooHighReverts() public {
        bytes[] memory srcPubkeys = new bytes[](1);
        srcPubkeys[0] = VALID_PUBKEY_48;
        IWithdrawV1.ConsolidationRequest[] memory requests = new IWithdrawV1.ConsolidationRequest[](1);
        requests[0] = IWithdrawV1.ConsolidationRequest({srcPubkeys: srcPubkeys, targetPubkey: VALID_PUBKEY_48});

        uint256 maxFee = 1 gwei;
        uint256 actualFee = 2 gwei;
        mockConsolidation.setFee(actualFee);
        vm.deal(consolidator, actualFee);

        vm.prank(consolidator);
        vm.expectRevert(abi.encodeWithSelector(IWithdrawV1.FeeTooHigh.selector, actualFee, maxFee));
        river.consolidate{value: actualFee}(requests, maxFee);
    }
}

contract RiverV1ConsolidationMintTests is RiverV1TestBase {
    RedeemManagerV1WithLegacyInit redeemManager;

    function setUp() public override {
        super.setUp();
        bytes32 withdrawalCredentials = withdraw.getCredentials();
        redeemManager = new RedeemManagerV1WithLegacyInit();
        LibImplementationUnbricker.unbrick(vm, address(redeemManager));
        redeemManager.initializeRedeemManagerV1(address(river));
        vm.expectEmit(true, true, true, true);
        emit SetOperatorsRegistry(address(operatorsRegistry));
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
        river.initRiverV1_1(
            address(redeemManager),
            epochsPerFrame,
            slotsPerEpoch,
            secondsPerSlot,
            0,
            epochsUntilFinal,
            1000,
            500,
            maxDailyNetCommittableAmount,
            maxDailyRelativeCommittableAmount
        );
        river.initRiverV1_2();
        address[] memory _initRootAttesters = new address[](3);
        _initRootAttesters[0] = rootAttester1;
        _initRootAttesters[1] = rootAttester2;
        _initRootAttesters[2] = rootAttester3;
        address[] memory _initConsolidationCommitteeAttesters = new address[](2);
        _initConsolidationCommitteeAttesters[0] = consolidationCommitteeAttester1;
        _initConsolidationCommitteeAttesters[1] = consolidationCommitteeAttester2;
        attestationVerifier = new AttestationVerifierV1();
        LibImplementationUnbricker.unbrick(vm, address(attestationVerifier));
        attestationVerifier.initAttestationVerifierV1(
            address(river),
            address(depositBuffer),
            _initRootAttesters,
            2,
            bytes4(0),
            _initConsolidationCommitteeAttesters,
            2
        );
        vm.prank(admin);
        river.initRiverV1_3(
            withdrawalCredentials,
            address(consolidationCoverageFund),
            address(attestationVerifier),
            address(externalConsolidationRecipientMapping),
            consolidator
        );
        withdraw.initializeWithdrawV1(address(river));
        oracle.initOracleV1(address(river), admin, 225, 32, 12, 0, 1000, 500);

        vm.startPrank(admin);
        oracle.addMember(oracleMember, 1);
        river.setCoverageFund(address(coverageFund));
        river.setKeeper(keeper);
        vm.stopPrank();
    }

    function _buildConsolidationWithPubkeys(
        address withdrawalAddress,
        bytes[] memory sources,
        bytes[] memory targets,
        uint256 totalAmount
    ) internal view returns (IAttestationVerifierV1.ConsolidationObject memory consolidation) {
        bytes32 digest = _consolidationDigest(withdrawalAddress, sources, targets, totalAmount);

        bytes[] memory sigs = new bytes[](2);
        sigs[0] = _signConsolidation(consolidationCommitteeAttesterPk1, digest);
        sigs[1] = _signConsolidation(consolidationCommitteeAttesterPk2, digest);

        consolidation = IAttestationVerifierV1.ConsolidationObject({
            withdrawalAddress: withdrawalAddress,
            sourcePubkeys: sources,
            targetPubkeys: targets,
            totalAmount: totalAmount,
            signatures: sigs
        });
    }

    function _consolidationStructHash(IAttestationVerifierV1.ConsolidationObject memory consolidation)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                ATTEST_CONSOLIDATION_TYPEHASH,
                consolidation.withdrawalAddress,
                _hashBytesArray(consolidation.sourcePubkeys),
                _hashBytesArray(consolidation.targetPubkeys),
                consolidation.totalAmount
            )
        );
    }

    function testOnlyConsolidatorCanMintForConsolidation() public {
        address notConsolidator = makeAddr("notConsolidator");
        IAttestationVerifierV1.ConsolidationObject memory consolidation = _buildConsolidation(bob, 1 ether, 1);
        vm.prank(notConsolidator);
        vm.expectRevert(abi.encodeWithSignature("OnlyConsolidator()"));
        river.mintLsETHForConsolidation(consolidation);
    }

    function testMintLsETHForConsolidationKeeperIsNotConsolidator() public {
        IAttestationVerifierV1.ConsolidationObject memory consolidation = _buildConsolidation(bob, 1 ether, 2);
        vm.prank(keeper);
        vm.expectRevert(abi.encodeWithSignature("OnlyConsolidator()"));
        river.mintLsETHForConsolidation(consolidation);
    }

    function testMintLsETHForConsolidationZeroAmountReverts() public {
        _allowConsolidation(bob);
        IAttestationVerifierV1.ConsolidationObject memory consolidation = _buildConsolidation(bob, 0, 3);
        vm.prank(consolidator);
        vm.expectRevert(abi.encodeWithSelector(IAttestationVerifierV1.ZeroConsolidationTotalAmount.selector));
        river.mintLsETHForConsolidation(consolidation);
    }

    function testMintLsETHForConsolidationUnallowedUserRevertsAtAllowlist() public {
        IAttestationVerifierV1.ConsolidationObject memory consolidation = _buildConsolidation(bob, 1 ether, 4);
        vm.prank(consolidator);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", bob));
        river.mintLsETHForConsolidation(consolidation);
    }

    function testMintLsETHForConsolidationZeroRecipientReverts() public {
        IAttestationVerifierV1.ConsolidationObject memory consolidation = _buildConsolidation(address(0), 1 ether, 4);
        vm.prank(consolidator);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", address(0)));
        river.mintLsETHForConsolidation(consolidation);
    }

    function testMintLsETHForConsolidationHappyPath() public {
        uint256 amount = 10 ether;
        _allowConsolidation(bob);
        IAttestationVerifierV1.ConsolidationObject memory consolidation = _buildConsolidation(bob, amount, 6);
        assertEq(river.getBalanceToConsolidate(), 0);
        assertEq(river.balanceOf(bob), 0);

        vm.expectEmit(true, true, true, true);
        emit IRiverV1.LsETHMintedForConsolidation(bob, amount, amount);
        vm.prank(consolidator);
        river.mintLsETHForConsolidation(consolidation);

        assertEq(river.getBalanceToConsolidate(), amount);
        assertEq(river.balanceOf(bob), amount);
    }

    function testMintLsETHForConsolidationUsesMappedRecipient() public {
        uint256 amount = 7 ether;
        _allowConsolidation(bob);
        vm.prank(bob);
        externalConsolidationRecipientMapping.setRecipient(joe);
        IAttestationVerifierV1.ConsolidationObject memory consolidation = _buildConsolidation(bob, amount, 7);
        uint256 totalSupplyBefore = river.totalSupply();

        vm.expectEmit(true, true, true, true);
        emit IRiverV1.LsETHMintedForConsolidation(joe, amount, amount);
        vm.prank(consolidator);
        river.mintLsETHForConsolidation(consolidation);

        assertEq(river.getBalanceToConsolidate(), amount);
        assertEq(river.balanceOf(bob), 0);
        assertEq(river.balanceOf(joe), amount);
        assertEq(river.totalSupply(), totalSupplyBefore + amount);
    }

    function testMintLsETHForConsolidationMappedDeniedRecipientReverts() public {
        _allowConsolidation(bob);
        vm.prank(bob);
        externalConsolidationRecipientMapping.setRecipient(joe);
        _denyAccount(joe);
        IAttestationVerifierV1.ConsolidationObject memory consolidation = _buildConsolidation(bob, 4 ether, 8);

        vm.prank(consolidator);
        vm.expectRevert(abi.encodeWithSignature("Denied(address)", joe));
        river.mintLsETHForConsolidation(consolidation);
    }

    function testMintLsETHForConsolidationAtNonUnityPrice() public {
        address depositor = makeAddr("depositor");
        address[] memory allowees = new address[](1);
        allowees[0] = depositor;
        uint256[] memory permissions = new uint256[](1);
        permissions[0] = LibAllowlistMasks.DEPOSIT_MASK;
        vm.prank(allower);
        allowlist.setAllowPermissions(allowees, permissions);

        vm.deal(depositor, 10 ether);
        vm.prank(depositor);
        river.deposit{value: 10 ether}();
        river.sudoSetValidatorsBalance(10 ether);

        uint256 supplyBefore = river.totalSupply();
        uint256 underlyingBefore = river.totalUnderlyingSupply();
        assertEq(supplyBefore, 10 ether, "supply should equal deposited shares");
        assertEq(underlyingBefore, 20 ether, "underlying should include validator balance");

        uint256 amount = 3 ether;
        uint256 expectedShares = (amount * supplyBefore) / underlyingBefore;
        uint256 pricePerShareBefore = river.underlyingBalanceFromShares(1 ether);
        assertLt(expectedShares, amount, "share price should exceed one");

        _allowConsolidation(bob);
        IAttestationVerifierV1.ConsolidationObject memory consolidation = _buildConsolidation(bob, amount, 11);

        vm.expectEmit(true, true, true, true);
        emit IRiverV1.LsETHMintedForConsolidation(bob, amount, expectedShares);
        vm.prank(consolidator);
        river.mintLsETHForConsolidation(consolidation);

        assertEq(river.balanceOf(bob), expectedShares, "minted shares should follow share price");
        assertEq(river.totalSupply(), supplyBefore + expectedShares, "total supply should grow by converted shares");
        assertEq(river.totalUnderlyingSupply(), underlyingBefore + amount, "underlying should grow by totalAmount");
        assertApproxEqAbs(
            river.underlyingBalanceFromShares(1 ether),
            pricePerShareBefore,
            1,
            "share price should be neutral within 1 wei"
        );
    }

    function testMintLsETHForConsolidationCumulativeBalanceAndShares() public {
        _allowConsolidation(bob);
        _allowConsolidation(joe);
        IAttestationVerifierV1.ConsolidationObject memory bobConsolidation = _buildConsolidation(bob, 5 ether, 9);
        IAttestationVerifierV1.ConsolidationObject memory joeConsolidation = _buildConsolidation(joe, 3 ether, 10);

        vm.prank(consolidator);
        river.mintLsETHForConsolidation(bobConsolidation);
        assertEq(river.getBalanceToConsolidate(), 5 ether);
        assertEq(river.balanceOf(bob), 5 ether);

        vm.prank(consolidator);
        river.mintLsETHForConsolidation(joeConsolidation);
        assertEq(river.getBalanceToConsolidate(), 8 ether);
        assertEq(river.balanceOf(bob), 5 ether);
        assertEq(river.balanceOf(joe), 3 ether);
    }

    function testRevert_mintLsETHForConsolidationAlreadyProcessedDoesNotMintOrIncrementBuffer() public {
        uint256 amount = 13 ether;
        _allowConsolidation(bob);
        IAttestationVerifierV1.ConsolidationObject memory consolidation = _buildConsolidation(bob, amount, 17);

        vm.prank(consolidator);
        river.mintLsETHForConsolidation(consolidation);

        uint256 bufferBeforeReplay = river.getBalanceToConsolidate();
        uint256 bobSharesBeforeReplay = river.balanceOf(bob);
        uint256 totalSupplyBeforeReplay = river.totalSupply();
        bytes32 structHash = _consolidationStructHash(consolidation);

        vm.prank(consolidator);
        vm.expectRevert(
            abi.encodeWithSelector(IAttestationVerifierV1.ConsolidationAlreadyProcessed.selector, structHash)
        );
        river.mintLsETHForConsolidation(consolidation);

        assertEq(river.getBalanceToConsolidate(), bufferBeforeReplay);
        assertEq(river.balanceOf(bob), bobSharesBeforeReplay);
        assertEq(river.totalSupply(), totalSupplyBeforeReplay);
    }

    function testRevert_mintLsETHForConsolidationReplayWithDifferentValidSignaturesDoesNotMint() public {
        uint256 amount = 14 ether;
        uint256 alternateCommitteeAttesterPk = 0xC3;
        _allowConsolidation(bob);
        vm.prank(admin);
        attestationVerifier.setConsolidationCommitteeAttester(vm.addr(alternateCommitteeAttesterPk), true);

        IAttestationVerifierV1.ConsolidationObject memory consolidation = _buildConsolidation(bob, amount, 18);
        vm.prank(consolidator);
        river.mintLsETHForConsolidation(consolidation);

        bytes32 digest = _consolidationDigest(
            consolidation.withdrawalAddress,
            consolidation.sourcePubkeys,
            consolidation.targetPubkeys,
            consolidation.totalAmount
        );
        bytes[] memory alternateSigs = new bytes[](2);
        alternateSigs[0] = _signConsolidation(consolidationCommitteeAttesterPk1, digest);
        alternateSigs[1] = _signConsolidation(alternateCommitteeAttesterPk, digest);
        consolidation.signatures = alternateSigs;

        uint256 bufferBeforeReplay = river.getBalanceToConsolidate();
        uint256 bobSharesBeforeReplay = river.balanceOf(bob);
        uint256 totalSupplyBeforeReplay = river.totalSupply();
        bytes32 structHash = _consolidationStructHash(consolidation);

        vm.prank(consolidator);
        vm.expectRevert(
            abi.encodeWithSelector(IAttestationVerifierV1.ConsolidationAlreadyProcessed.selector, structHash)
        );
        river.mintLsETHForConsolidation(consolidation);

        assertEq(river.getBalanceToConsolidate(), bufferBeforeReplay);
        assertEq(river.balanceOf(bob), bobSharesBeforeReplay);
        assertEq(river.totalSupply(), totalSupplyBeforeReplay);
    }

    function testRevert_mintLsETHForConsolidationOverlappingSourceDistinctRequestsDoesNotMint() public {
        _allowConsolidation(bob);
        bytes memory sourceA = _fakePubkey(2000);
        bytes memory sourceB = _fakePubkey(2001);

        bytes[] memory firstSources = new bytes[](1);
        firstSources[0] = sourceA;
        bytes[] memory firstTargets = new bytes[](1);
        firstTargets[0] = _fakePubkey(2100);
        IAttestationVerifierV1.ConsolidationObject memory firstConsolidation =
            _buildConsolidationWithPubkeys(bob, firstSources, firstTargets, 32 ether);

        bytes[] memory secondSources = new bytes[](2);
        secondSources[0] = sourceA;
        secondSources[1] = sourceB;
        bytes[] memory secondTargets = new bytes[](2);
        secondTargets[0] = _fakePubkey(2200);
        secondTargets[1] = _fakePubkey(2201);
        IAttestationVerifierV1.ConsolidationObject memory secondConsolidation =
            _buildConsolidationWithPubkeys(bob, secondSources, secondTargets, 64 ether);

        assertTrue(
            _consolidationStructHash(firstConsolidation) != _consolidationStructHash(secondConsolidation),
            "overlap must not collapse distinct requests into replay"
        );

        vm.prank(consolidator);
        river.mintLsETHForConsolidation(firstConsolidation);
        assertEq(river.getBalanceToConsolidate(), 32 ether);
        assertEq(river.balanceOf(bob), 32 ether);

        uint256 bufferBeforeReplay = river.getBalanceToConsolidate();
        uint256 bobSharesBeforeReplay = river.balanceOf(bob);
        uint256 totalSupplyBeforeReplay = river.totalSupply();

        vm.prank(consolidator);
        vm.expectRevert(
            abi.encodeWithSelector(IAttestationVerifierV1.ConsolidationSourceAlreadyProcessed.selector, sourceA)
        );
        river.mintLsETHForConsolidation(secondConsolidation);
        assertEq(river.getBalanceToConsolidate(), bufferBeforeReplay);
        assertEq(river.balanceOf(bob), bobSharesBeforeReplay);
        assertEq(river.totalSupply(), totalSupplyBeforeReplay);
    }

    function testRevert_mintLsETHForConsolidationDuplicateSourceWithinRequestDoesNotMint() public {
        _allowConsolidation(bob);
        bytes memory sourceA = _fakePubkey(2300);

        bytes[] memory sources = new bytes[](2);
        sources[0] = sourceA;
        sources[1] = sourceA;
        bytes[] memory targets = new bytes[](2);
        targets[0] = _fakePubkey(2400);
        targets[1] = _fakePubkey(2401);
        uint256 totalAmount = 64 ether;
        IAttestationVerifierV1.ConsolidationObject memory consolidation =
            _buildConsolidationWithPubkeys(bob, sources, targets, totalAmount);

        uint256 bufferBefore = river.getBalanceToConsolidate();
        uint256 bobSharesBefore = river.balanceOf(bob);
        uint256 totalSupplyBefore = river.totalSupply();

        vm.prank(consolidator);
        vm.expectRevert(
            abi.encodeWithSelector(IAttestationVerifierV1.ConsolidationSourceAlreadyProcessed.selector, sourceA)
        );
        river.mintLsETHForConsolidation(consolidation);

        assertEq(river.getBalanceToConsolidate(), bufferBefore);
        assertEq(river.balanceOf(bob), bobSharesBefore);
        assertEq(river.totalSupply(), totalSupplyBefore);
    }
}
