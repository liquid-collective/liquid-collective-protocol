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
import "../src/interfaces/IDepositDataBuffer.sol";
import "../src/Withdraw.1.sol";
import "../src/Oracle.1.sol";
import "../src/ELFeeRecipient.1.sol";
import "../src/OperatorsRegistry.1.sol";
import "../src/CoverageFund.1.sol";
import "../src/RedeemManager.1.sol";

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

contract OperatorsRegistryWithOverridesV1 is OperatorsRegistryV1 {
    function sudoReportExitedETH(uint256[] calldata exitedETH, uint256 totalDepositedETH) external {
        _setExitedETH(exitedETH, totalDepositedETH);
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
}

abstract contract RiverV1TestBase is OperatorAllocationTestBase, BytesGenerator {
    UserFactory internal uf = new UserFactory();

    RiverV1ForceCommittable internal river;
    IDepositContract internal deposit;
    WithdrawV1 internal withdraw;
    OracleV1 internal oracle;
    ELFeeRecipientV1 internal elFeeRecipient;
    CoverageFundV1 internal coverageFund;
    AllowlistV1 internal allowlist;
    OperatorsRegistryWithOverridesV1 internal operatorsRegistry;

    MockDepositDataBuffer internal depositBuffer;
    AttestationVerifierV1 internal attestationVerifier;

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

    event PulledELFees(uint256 amount);
    event SetELFeeRecipient(address indexed elFeeRecipient);
    event SetCollector(address indexed collector);
    event SetCoverageFund(address indexed coverageFund);
    event SetAllowlist(address indexed allowlist);
    event SetGlobalFee(uint256 fee);
    event SetOperatorsRegistry(address indexed operatorsRegistry);
    event SetKeeper(address indexed keeper);

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

        attester1 = vm.addr(attesterPk1);
        attester2 = vm.addr(attesterPk2);
        attester3 = vm.addr(attesterPk3);

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
        depositBuffer = new MockDepositDataBuffer();

        allowlist.initAllowlistV1(admin, allower);
        allowlist.initAllowlistV1_1(denier);
        operatorsRegistry.initOperatorsRegistryV1(admin, address(river));
        elFeeRecipient.initELFeeRecipientV1(address(river));
        coverageFund.initCoverageFundV1(address(river));
    }

    // -----------------------------------------------------------------------
    // Attestation-based deposit helpers
    // -----------------------------------------------------------------------

    /// @dev Encode "operator:N" as left-aligned bytes32.
    function _operatorMeta(uint256 opIdx) internal pure returns (bytes32) {
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

    /// @dev Replacement for the old depositToConsensusLayerWithDepositRoot.
    ///      Builds deposit objects, submits to buffer, signs, and calls new function.
    function _depositToConsensusLayer(uint256[] memory opIndices, uint32[] memory counts) internal {
        bytes32 wc = river.getWithdrawalCredentials();

        // Count total deposits
        uint256 total = 0;
        for (uint256 i = 0; i < counts.length; i++) {
            total += counts[i];
        }

        // Build deposit objects
        IDepositDataBuffer.DepositObject[] memory deposits = new IDepositDataBuffer.DepositObject[](total);
        uint256 idx = 0;
        for (uint256 i = 0; i < opIndices.length; i++) {
            for (uint256 j = 0; j < counts[i]; j++) {
                deposits[idx] = IDepositDataBuffer.DepositObject({
                    pubkey: _fakePubkey(idx),
                    signature: _fakeSignature(idx),
                    amount: 32 ether,
                    depositDataRoot: bytes32(0),
                    metadata: _operatorMeta(opIndices[i])
                });
                idx++;
            }
        }

        bytes32 bufferId = keccak256(abi.encode(deposits));
        depositBuffer.submitDepositData(bufferId, deposits);

        bytes32 rootHash = deposit.get_deposit_root();

        bytes[] memory sigs = new bytes[](2);
        sigs[0] = _signAttestation(attesterPk1, bufferId, rootHash);
        sigs[1] = _signAttestation(attesterPk2, bufferId, rootHash);

        BLS12_381.DepositY[] memory ys = new BLS12_381.DepositY[](total);
        for (uint256 i = 0; i < total; i++) {
            ys[i] = _emptyDepositY();
        }

        // The new function requires keeper, not admin
        address currentKeeper = river.getKeeper();
        vm.prank(currentKeeper);
        river.depositToConsensusLayerWithAttestation(bufferId, rootHash, sigs, ys);
    }

    /// @dev Single-operator convenience overload.
    function _depositToConsensusLayer(uint256 opIndex, uint32 count) internal {
        uint256[] memory idx = new uint256[](1);
        idx[0] = opIndex;
        uint32[] memory cnt = new uint32[](1);
        cnt[0] = count;
        _depositToConsensusLayer(idx, cnt);
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
        river.setKeeper(admin);
        oracle.addMember(oracleMember, 1);
        // ===================

        operatorOneIndex = operatorsRegistry.addOperator(operatorOneName, operatorOne);
        operatorTwoIndex = operatorsRegistry.addOperator(operatorTwoName, operatorTwo);

        vm.stopPrank();

        // Deploy + initialize the AttestationVerifier sibling. The validator's EIP-712
        // domain separator binds verifyingContract to River's address.
        address[] memory _initAttesters = new address[](3);
        _initAttesters[0] = attester1;
        _initAttesters[1] = attester2;
        _initAttesters[2] = attester3;
        attestationVerifier = new AttestationVerifierV1();
        LibImplementationUnbricker.unbrick(vm, address(attestationVerifier));
        attestationVerifier.initAttestationVerifierV1(
            address(river), address(deposit), address(depositBuffer), _initAttesters, 2, bytes4(0)
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
        address keeper = makeAddr("keeper");
        assert(river.getKeeper() == admin);
        vm.prank(admin);
        vm.expectEmit(true, true, true, true);
        emit SetKeeper(keeper);
        river.setKeeper(keeper);
        assert(river.getKeeper() == keeper);

        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", address(this)));
        river.setKeeper(address(0));
    }

    function testSetKeeperViaInterface() public {
        address keeper = makeAddr("keeper");
        vm.prank(admin);
        IRiverV1(payable(address(river))).setKeeper(keeper);
        assert(river.getKeeper() == keeper);
    }

    function testInitWithZeroAddressValue() public {
        withdraw = new WithdrawV1();
        bytes32 withdrawalCredentials = withdraw.getCredentials();
        river = new RiverV1ForceCommittable();
        LibImplementationUnbricker.unbrick(vm, address(river));
        vm.expectRevert(abi.encodeWithSignature("InvalidZeroAddress()"));
        river.initRiverV1(
            address(0),
            address(0),
            withdrawalCredentials,
            address(0),
            address(0),
            address(0),
            address(0),
            address(0),
            5000
        );
    }

    function testAdditionalInit() public {
        bytes32 withdrawalCredentials = withdraw.getCredentials();
        vm.startPrank(admin);
        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization(uint256,uint256)", 0, 1));
        river.initRiverV1(
            address(deposit),
            address(elFeeRecipient),
            withdrawalCredentials,
            address(oracle),
            admin,
            allower,
            address(operatorsRegistry),
            collector,
            5000
        );
        vm.stopPrank();
    }

    function testInit2(uint128 depositTotal, uint96 committedBalance) public {
        vm.assume(depositTotal > committedBalance && committedBalance > 0);
        RedeemManagerV1 redeemManager;
        redeemManager = new RedeemManagerV1();
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

    function testRequestRedeemAllowedWhenSlashingModeOff() public {
        RedeemManagerV1 redeemManager = new RedeemManagerV1();
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
        RedeemManagerV1 redeemManager = new RedeemManagerV1();
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
        RedeemManagerV1 redeemManager = new RedeemManagerV1();
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
}

contract RiverV1TestsReport_HEAVY_FUZZING is RiverV1TestBase {
    RedeemManagerV1 redeemManager;

    function setUp() public override {
        super.setUp();
        bytes32 withdrawalCredentials = withdraw.getCredentials();
        redeemManager = new RedeemManagerV1();
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
        river.setKeeper(admin);

        vm.stopPrank();

        // Deploy + initialize the AttestationVerifier sibling.
        address[] memory _initAttesters2 = new address[](3);
        _initAttesters2[0] = attester1;
        _initAttesters2[1] = attester2;
        _initAttesters2[2] = attester3;
        attestationVerifier = new AttestationVerifierV1();
        LibImplementationUnbricker.unbrick(vm, address(attestationVerifier));
        attestationVerifier.initAttestationVerifierV1(
            address(river), address(deposit), address(depositBuffer), _initAttesters2, 2, bytes4(0)
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
        // Populate activeCLETH with the deposit distribution so ExitedETHExceedsPriorCLETH passes
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

    // DISABLED: InvalidValidatorCountReport error no longer exists; DepositedValidatorCount
    // is no longer tracked. This validation has been removed in the new attestation-based flow.
    // function testReportingError_InvalidValidatorCountReport(uint256 _salt) external { ... }

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

    // DISABLED: InvalidValidatorCountReport error no longer exists; DepositedValidatorCount
    // is no longer tracked. These validations have been removed in the new attestation-based flow.
    // function testReportingError_ValidatorCountDecreasing(uint256 _salt) external { ... }
    // function testReportingError_ValidatorCountHigherThanDeposits(uint256 _salt) external { ... }

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
        // and set activeCLETH so the ExitedETHExceedsPriorCLETH check passes (deltaExited = 2*32 ether).
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
        maxCommittedBalanceIncrease = maxCommittedBalanceIncrease / 32 ether * 32 ether;

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

        assertEq(river.getCommittedBalance() % 32 ether, 0);
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

        assertEq(river.getCommittedBalance() % 32 ether, 0);
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

        assertEq(river.getCommittedBalance() % 32 ether, 0);
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

        assertEq(river.getCommittedBalance() % 32 ether, 0);
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
    RedeemManagerV1 internal redeemManager;

    bytes32 constant DEPOSITED_VALIDATOR_COUNT_SLOT =
        bytes32(uint256(keccak256("river.state.depositedValidatorCount")) - 1);
    bytes32 constant LAST_CLR_BASE_SLOT = bytes32(uint256(keccak256("river.state.lastConsensusLayerReport")) - 1);
    bytes32 constant IN_FLIGHT_DEPOSIT_SLOT = bytes32(uint256(keccak256("river.state.inFlightDeposit")) - 1);
    bytes32 constant BUFFERED_EXCEEDING_ETH_SLOT = bytes32(uint256(keccak256("river.state.bufferedExceedingEth")) - 1);

    /// @dev Helper: deploy and init an AttestationVerifier pointed at this test's River.
    function _deployValidatorFor(address _river) internal returns (AttestationVerifierV1 v) {
        address[] memory _attesters_ = new address[](2);
        _attesters_[0] = makeAddr("attester1");
        _attesters_[1] = makeAddr("attester2");
        v = new AttestationVerifierV1();
        LibImplementationUnbricker.unbrick(vm, address(v));
        v.initAttestationVerifierV1(_river, address(deposit), makeAddr("depositBuffer"), _attesters_, 1, bytes4(0));
    }

    /// Asserts that initRiverV1_3 sets in-flight deposit when reported validator count is less than deposited count.
    function testInitRiverV1_3WithInFlightValidators() public {
        _initRiverAndV1_2();
        // 10 deposited validators, 7 reported -> 3 in flight.
        vm.store(address(river), DEPOSITED_VALIDATOR_COUNT_SLOT, bytes32(uint256(10)));
        vm.store(address(river), bytes32(uint256(LAST_CLR_BASE_SLOT) + 5), bytes32(uint256(7)));
        AttestationVerifierV1 v = _deployValidatorFor(address(river));
        bytes32 wc = withdraw.getCredentials();
        vm.prank(admin);
        river.initRiverV1_3(wc, address(v));
        assertEq(river.getTotalDepositedETH(), 10 * 32 ether);
        assertEq(uint256(vm.load(address(river), IN_FLIGHT_DEPOSIT_SLOT)), 3 * 32 ether);
    }

    /// Asserts that initRiverV1_3 leaves in-flight deposit zero when reported count equals deposited count.
    function testInitRiverV1_3NoInFlight() public {
        _initRiverAndV1_2();
        vm.store(address(river), DEPOSITED_VALIDATOR_COUNT_SLOT, bytes32(uint256(5)));
        vm.store(address(river), bytes32(uint256(LAST_CLR_BASE_SLOT) + 5), bytes32(uint256(5)));
        AttestationVerifierV1 v = _deployValidatorFor(address(river));
        bytes32 wc = withdraw.getCredentials();
        vm.prank(admin);
        river.initRiverV1_3(wc, address(v));
        assertEq(river.getTotalDepositedETH(), 5 * 32 ether);
        assertEq(uint256(vm.load(address(river), IN_FLIGHT_DEPOSIT_SLOT)), 0);
    }

    /// Asserts that AttestationVerifier init reverts on an empty attester array.
    function testInitAttestationVerifierRevertsOnEmptyAttesters() public {
        _initRiverAndV1_2();
        address[] memory _attesters_ = new address[](0);
        AttestationVerifierV1 v = new AttestationVerifierV1();
        LibImplementationUnbricker.unbrick(vm, address(v));
        vm.expectRevert(abi.encodeWithSignature("InvalidArgument()"));
        v.initAttestationVerifierV1(
            address(river), address(deposit), makeAddr("depositBuffer"), _attesters_, 1, bytes4(0)
        );
    }

    /// Asserts that AttestationVerifier init reverts when the attesters array exceeds MAX_ATTESTERS.
    function testInitAttestationVerifierRevertsOnTooManyAttesters() public {
        _initRiverAndV1_2();
        AttestationVerifierV1 v = new AttestationVerifierV1();
        LibImplementationUnbricker.unbrick(vm, address(v));
        uint256 tooMany = v.MAX_ATTESTERS() + 1;
        address[] memory _attesters_ = new address[](tooMany);
        for (uint256 i = 0; i < tooMany; i++) {
            _attesters_[i] = address(uint160(i + 1));
        }
        vm.expectRevert(abi.encodeWithSignature("InvalidArgument()"));
        v.initAttestationVerifierV1(
            address(river), address(deposit), makeAddr("depositBuffer"), _attesters_, 1, bytes4(0)
        );
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
        vm.store(address(river), bytes32(uint256(LAST_CLR_BASE_SLOT) + 1), bytes32(uint256(32 ether)));
        uint256 epoch = epochsPerFrame;
        vm.warp((epoch + epochsUntilFinal) * slotsPerEpoch * secondsPerSlot);
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
        vm.warp((epoch + epochsUntilFinal) * slotsPerEpoch * secondsPerSlot);
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
        vm.warp((epoch + epochsUntilFinal) * slotsPerEpoch * secondsPerSlot);
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

    function _initRiverAndV1_2() internal {
        super.setUp();
        redeemManager = new RedeemManagerV1();
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
        river.setKeeper(admin);
        redeemManager.initializeRedeemManagerV1(address(river));
    }

    function _initRiverMinimalForReporting() internal {
        super.setUp();
        redeemManager = new RedeemManagerV1();
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
        river.setKeeper(admin);
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
