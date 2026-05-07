// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "forge-std/Test.sol";

import "../utils/BytesGenerator.sol";
import "../utils/LibImplementationUnbricker.sol";
import "../mocks/DepositContractMock.sol";

import "../../src/River.1.sol";
import "../../src/AttestationValidator.1.sol";
import "../../src/Oracle.1.sol";
import "../../src/OperatorsRegistry.1.sol";
import "../../src/Allowlist.1.sol";
import "../../src/ELFeeRecipient.1.sol";
import "../../src/CoverageFund.1.sol";
import "../../src/RedeemManager.1.sol";
import "../../src/Withdraw.1.sol";

import "../../src/interfaces/IOperatorRegistry.1.sol";
import "../../src/interfaces/IDepositDataBuffer.sol";
import "../../src/interfaces/components/IOracleManager.1.sol";
import "../../src/libraries/BLS12_381.sol";
import "../../src/libraries/LibAllowlistMasks.sol";
import "../../src/state/river/InFlightDeposit.sol";
import "../../src/state/river/CommittedBalance.sol";
import "../../src/state/river/BalanceToDeposit.sol";
import "../../src/state/attestationValidator/DepositDomainValue.sol";
import "../../src/state/operatorsRegistry/Operators.3.sol";

// -----------------------------------------------------------------------
// Mock DepositDataBuffer — stores batches by ID for accounting harness deposits
// -----------------------------------------------------------------------

contract AccountingMockDepositDataBuffer is IDepositDataBuffer {
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

/// @dev Test-only OperatorsRegistry subclass exposing raw exited ETH initialization.
contract AccountingTestOperatorsRegistry is OperatorsRegistryV1 {
    function sudoSetRawExitedETH(uint256[] memory value) external {
        OperatorsV3.setRawExitedETH(value);
    }
}

/// @dev Test-only River subclass exposing InFlightDeposit and debug helpers.
contract AccountingRiverV1 is RiverV1 {
    function getInFlightDeposit() external view returns (uint256) {
        return InFlightDeposit.get();
    }

    function debug_moveDepositToCommitted() external {
        _setCommittedBalance(CommittedBalance.get() + BalanceToDeposit.get());
        _setBalanceToDeposit(0);
    }
}

abstract contract AccountingHarnessBase is Test, BytesGenerator {
    // ─── protocol constants ───────────────────────────────────────────────────
    uint64 internal constant EPOCHS_PER_FRAME = 225;
    uint64 internal constant SLOTS_PER_EPOCH = 32;
    uint64 internal constant SECONDS_PER_SLOT = 12;
    uint64 internal constant EPOCHS_UNTIL_FINAL = 4;
    uint256 internal constant DEPOSIT_SIZE = 32 ether;
    uint128 internal constant MAX_DAILY_NET = 3200 ether;
    uint128 internal constant MAX_DAILY_REL = 2000;

    // ─── contracts ────────────────────────────────────────────────────────────
    AccountingRiverV1 internal river;
    OracleV1 internal oracle;
    AccountingTestOperatorsRegistry internal operatorsRegistry;
    AllowlistV1 internal allowlist;
    ELFeeRecipientV1 internal elFeeRecipient;
    CoverageFundV1 internal coverageFund;
    RedeemManagerV1 internal redeemManager;
    WithdrawV1 internal withdraw;
    IDepositContract internal depositContract;
    AccountingMockDepositDataBuffer internal depositBuffer;
    AttestationValidatorV1 internal attestationValidator;

    // ─── attestation ──────────────────────────────────────────────────────────
    uint256 internal constant ATTESTER_PK_1 = 0xA1;
    uint256 internal constant ATTESTER_PK_2 = 0xA2;
    uint256 internal constant ATTESTER_PK_3 = 0xA3;
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

    // ─── actors ───────────────────────────────────────────────────────────────
    address internal admin;
    address internal allower;
    address internal keeper;
    address internal oracleMember;
    address internal operatorOneAddr;
    address internal operatorTwoAddr;

    uint256 internal operatorOneIndex;
    uint256 internal operatorTwoIndex;

    // ─── test helpers ─────────────────────────────────────────────────────────
    uint256 private _fundUserCounter;
    /// @dev Tracks total ETH deposited by users into the river (independent of contract storage).
    uint256 internal _simTotalUserDeposited;

    // ─── setUp ────────────────────────────────────────────────────────────────
    function setUp() public virtual {
        admin = makeAddr("admin");
        allower = makeAddr("allower");
        keeper = makeAddr("keeper");
        oracleMember = makeAddr("oracleMember");
        operatorOneAddr = makeAddr("operatorOne");
        operatorTwoAddr = makeAddr("operatorTwo");

        attester1 = vm.addr(ATTESTER_PK_1);
        attester2 = vm.addr(ATTESTER_PK_2);
        attester3 = vm.addr(ATTESTER_PK_3);

        vm.warp(1_000_000);

        depositContract = new DepositContractMock();
        depositBuffer = new AccountingMockDepositDataBuffer();
        withdraw = new WithdrawV1();
        oracle = new OracleV1();
        allowlist = new AllowlistV1();
        redeemManager = new RedeemManagerV1();
        elFeeRecipient = new ELFeeRecipientV1();
        coverageFund = new CoverageFundV1();
        river = new AccountingRiverV1();
        operatorsRegistry = new AccountingTestOperatorsRegistry();

        LibImplementationUnbricker.unbrick(vm, address(withdraw));
        LibImplementationUnbricker.unbrick(vm, address(oracle));
        LibImplementationUnbricker.unbrick(vm, address(allowlist));
        LibImplementationUnbricker.unbrick(vm, address(redeemManager));
        LibImplementationUnbricker.unbrick(vm, address(elFeeRecipient));
        LibImplementationUnbricker.unbrick(vm, address(coverageFund));
        LibImplementationUnbricker.unbrick(vm, address(river));
        LibImplementationUnbricker.unbrick(vm, address(operatorsRegistry));

        allowlist.initAllowlistV1(admin, allower);
        allowlist.initAllowlistV1_1(makeAddr("denier"));

        operatorsRegistry.initOperatorsRegistryV1(admin, address(river));

        redeemManager.initializeRedeemManagerV1(address(river));

        river.initRiverV1(
            address(depositContract),
            address(elFeeRecipient),
            withdraw.getCredentials(),
            address(oracle),
            admin,
            address(allowlist),
            address(operatorsRegistry),
            makeAddr("collector"),
            500
        );
        river.initRiverV1_1(
            address(redeemManager),
            EPOCHS_PER_FRAME,
            SLOTS_PER_EPOCH,
            SECONDS_PER_SLOT,
            0,
            EPOCHS_UNTIL_FINAL,
            1000,
            500,
            MAX_DAILY_NET,
            MAX_DAILY_REL
        );
        river.initRiverV1_2();
        // 3 attesters with quorum=2 (quorum must be ≤ attester count and ≤ MAX_SIGNATURES)
        address[] memory _initAttesters = new address[](3);
        _initAttesters[0] = attester1;
        _initAttesters[1] = attester2;
        _initAttesters[2] = attester3;

        // Deploy and initialize the AttestationValidator sibling contract that River
        // delegates attestation+BLS verification to. EIP-712 verifyingContract is
        // pinned to River's address inside the validator's domain separator.
        attestationValidator = new AttestationValidatorV1();
        LibImplementationUnbricker.unbrick(vm, address(attestationValidator));
        attestationValidator.initAttestationValidatorV1(
            address(river), address(depositContract), address(depositBuffer), _initAttesters, 2, bytes4(0)
        );

        bytes32 _initWc = withdraw.getCredentials();
        vm.prank(admin);
        river.initRiverV1_3(_initWc, address(attestationValidator));
        // Mock BLS verification on the validator: EIP-2537 precompiles are unavailable
        // in Foundry's default EVM.
        vm.mockCall(
            address(attestationValidator),
            abi.encodeWithSelector(attestationValidator.verifyBLSDeposit.selector),
            bytes("")
        );

        withdraw.initializeWithdrawV1(address(river));
        elFeeRecipient.initELFeeRecipientV1(address(river));
        coverageFund.initCoverageFundV1(address(river));

        oracle.initOracleV1(address(river), admin, EPOCHS_PER_FRAME, SLOTS_PER_EPOCH, SECONDS_PER_SLOT, 0, 1000, 500);

        vm.startPrank(admin);
        river.setCoverageFund(address(coverageFund));
        river.setKeeper(keeper);
        oracle.addMember(oracleMember, 1);
        operatorOneIndex = operatorsRegistry.addOperator("OperatorOne", operatorOneAddr);
        operatorTwoIndex = operatorsRegistry.addOperator("OperatorTwo", operatorTwoAddr);
        vm.stopPrank();

        // Initialize the exited ETH array to zeros (opCount + 1 elements: [total, op0, op1, ...]).
        // Required because _setExitedETH accesses currentExitedETH[idx] without a bounds check,
        // so the array must be pre-populated before the first oracle report.
        uint256 opCount = operatorsRegistry.getOperatorCount();
        operatorsRegistry.sudoSetRawExitedETH(new uint256[](opCount + 1));
    }

    // ─── helpers ──────────────────────────────────────────────────────────────

    function _fundRiver(uint256 ethAmount) internal {
        require(ethAmount > 0, "fundRiver: zero amount");
        _simTotalUserDeposited += ethAmount;
        address user = makeAddr(string(abi.encode("fundUser", _fundUserCounter++)));
        _allowUser(user);
        vm.deal(user, ethAmount);
        vm.prank(user);
        river.deposit{value: ethAmount}();
        river.debug_moveDepositToCommitted();
    }

    function _allowUser(address user) internal {
        address[] memory addrs = new address[](1);
        addrs[0] = user;
        uint256[] memory masks = new uint256[](1);
        masks[0] = LibAllowlistMasks.DEPOSIT_MASK | LibAllowlistMasks.REDEEM_MASK;
        vm.prank(allower);
        allowlist.setAllowPermissions(addrs, masks);
    }

    function _makeDeposits(uint256 opIdx, uint256[] memory amounts)
        internal
        returns (IOperatorsRegistryV1.ValidatorDeposit[] memory allocs)
    {
        allocs = new IOperatorsRegistryV1.ValidatorDeposit[](amounts.length);
        for (uint256 i = 0; i < amounts.length; i++) {
            allocs[i] = IOperatorsRegistryV1.ValidatorDeposit({
                operatorIndex: opIdx, pubkey: genBytes(48), signature: genBytes(96), depositAmount: amounts[i]
            });
        }
        return allocs;
    }

    /// @dev Convenience overload — builds `n` allocations of `DEPOSIT_SIZE` each for `opIdx`.
    function _makeDeposits(uint256 opIdx, uint256 n) internal returns (IOperatorsRegistryV1.ValidatorDeposit[] memory) {
        return _makeDeposits(opIdx, _amounts(n, DEPOSIT_SIZE));
    }

    // ─── attestation helpers ───────────────────────────────────────────────────

    /// @dev Encode "operator:N" as left-aligned bytes32 metadata.
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

    function _emptyDepositY() internal pure returns (BLS12_381.DepositY memory) {
        return BLS12_381.DepositY({
            pubkeyY: BLS12_381.Fp({a: bytes32(0), b: bytes32(0)}),
            signatureY: BLS12_381.Fp2({c0_a: bytes32(0), c0_b: bytes32(0), c1_a: bytes32(0), c1_b: bytes32(0)})
        });
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

    /// @dev Build deposit objects from a set of (operatorIndex, amount) tuples.
    ///      Each deposit uses a deterministic pubkey/signature seeded by position.
    function _makeDepositObjects(uint256[] memory opIndices, uint256[] memory amounts)
        internal
        view
        returns (IDepositDataBuffer.DepositObject[] memory deposits)
    {
        require(opIndices.length == amounts.length, "length mismatch");
        bytes32 wc = river.getWithdrawalCredentials();
        deposits = new IDepositDataBuffer.DepositObject[](opIndices.length);
        for (uint256 i = 0; i < opIndices.length; i++) {
            deposits[i] = IDepositDataBuffer.DepositObject({
                pubkey: abi.encodePacked(sha256(abi.encode("pubkey", i, opIndices[i], block.number)), bytes16(0)),
                signature: abi.encodePacked(
                    sha256(abi.encode("sig-a", i, opIndices[i], block.number)),
                    sha256(abi.encode("sig-b", i, opIndices[i], block.number)),
                    bytes32(0)
                ),
                amount: amounts[i],
                withdrawalCredentials: abi.encode(wc),
                depositDataRoot: bytes32(0),
                metadata: _operatorMeta(opIndices[i])
            });
        }
    }

    /// @dev Returns the elapsed time (seconds) of a single reporting frame under the current
    ///      harness constants. Used in boundary tests that must compare against the src's
    ///      APR/lower-bound arithmetic without hardcoding the frame cadence.
    function _frameDuration() internal pure returns (uint256) {
        return uint256(EPOCHS_PER_FRAME) * uint256(SLOTS_PER_EPOCH) * uint256(SECONDS_PER_SLOT);
    }

    /// @dev Convenience: create an array of `n` identical deposit amounts.
    function _amounts(uint256 n, uint256 amountEach) internal pure returns (uint256[] memory amounts) {
        amounts = new uint256[](n);
        for (uint256 i = 0; i < n; i++) {
            amounts[i] = amountEach;
        }
    }

    /// @dev Pranks `user` and invokes `river.requestRedeem(lsEthAmount, user)`.
    function sim_requestRedeem(address user, uint256 lsEthAmount) internal {
        vm.prank(user);
        river.requestRedeem(lsEthAmount, user);
    }
}
