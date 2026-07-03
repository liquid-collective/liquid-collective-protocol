//SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.34;

import "forge-std/Test.sol";

import "../../../src/TUPProxy.sol";
import "../../../src/River.1.sol";
import "../../../src/Withdraw.1.sol";
import "../../../src/OperatorsRegistry.1.sol";
import "../../../src/AttestationVerifier.1.sol";
import "../../utils/LibImplementationUnbricker.sol";
import {
    ITransparentUpgradeableProxy
} from "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

/// @notice Fork coverage for the atomicity requirement of the Pectra reinitializers.
///
///         The `init(N)` modifier only version-gates; it performs no caller authorization. The
///         reinitializers are therefore safe only when the implementation swap and the initializer
///         call happen in one transaction via `upgradeToAndCall`. These tests:
///           1. reproduce the production atomic `upgradeToAndCall` sequence and assert it succeeds
///              with the intended parameters (msg.sender inside the init is the proxy admin);
///           2. demonstrate that a non-atomic `upgradeTo` + separate initializer sequence leaves a
///              window in which any non-admin account can front-run the initializer through the
///              transparent proxy and set attacker-chosen parameters — the exact risk the runbook's
///              atomic-upgrade rule closes;
///           3. assert each reinitializer cannot be re-run once its version is consumed.
///
///         Requires a mainnet archive RPC in `MAINNET_FORK_RPC_URL`; otherwise the whole suite
///         is skipped (same convention as the other fork tests in this directory).
contract PectraReinitializerAtomicUpgrade is Test {
    bool internal _skip = false;

    // Mainnet proxies to be initialized by the Pectra upgrade.
    address internal constant RIVER_MAINNET_ADDRESS = 0x8c1BEd5b9a0928467c9B1341Da1D7BD5e10b6549;
    address internal constant WITHDRAW_MAINNET_ADDRESS = 0x0AFd81862eEA47322Cf85Db39D3D07e8A3c25154;
    address internal constant OPERATORS_REGISTRY_MAINNET_ADDRESS = 0x1235f1b60df026B2620e48E735C422425E06b725;

    // EIP-1967 admin slot: the proxy admin (ProxyFirewall) is the only account that may call
    // `upgradeToAndCall`. Read dynamically to avoid hardcoding per-proxy firewall addresses.
    bytes32 internal constant ERC1967_ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    // Initializable version counter slot (see contracts/src/state/shared/Version.sol).
    bytes32 internal constant VERSION_SLOT = bytes32(uint256(keccak256("river.state.version")) - 1);

    // 0x02 withdrawal-credentials prefix used by post-Pectra LC validators.
    bytes32 internal constant WC_0X02_PREFIX = 0x0200000000000000000000000000000000000000000000000000000000000000;

    address internal constant ATTACKER = address(0xBAD);

    function setUp() external {
        try vm.envString("MAINNET_FORK_RPC_URL") returns (string memory rpcUrl) {
            vm.createSelectFork(rpcUrl, 21_700_000);
            console.log("5.pectraReinitializerAtomicUpgrade.t.sol is active");
        } catch {
            _skip = true;
        }
    }

    modifier shouldSkip() {
        if (!_skip) {
            _;
        }
    }

    // ─────────────────────────────── Withdraw.initWithdrawV1_1 ───────────────────────────────

    function test_withdraw_atomicUpgrade_ok() external shouldSkip {
        _assertVersion(WITHDRAW_MAINNET_ADDRESS, 1, "withdraw pre-upgrade version");

        WithdrawV1 newImpl = new WithdrawV1();
        (address pectraWithdrawal, address pectraConsolidation, address registry, address verifier) =
            (address(0xA11), address(0xA12), address(0xA13), address(0xA14));

        vm.prank(_proxyAdmin(WITHDRAW_MAINNET_ADDRESS));
        ITransparentUpgradeableProxy(WITHDRAW_MAINNET_ADDRESS)
            .upgradeToAndCall(
                address(newImpl),
                abi.encodeCall(WithdrawV1.initWithdrawV1_1, (pectraWithdrawal, pectraConsolidation, registry, verifier))
            );

        _assertVersion(WITHDRAW_MAINNET_ADDRESS, 2, "withdraw post-upgrade version");
        _assertAddressSlot(
            WITHDRAW_MAINNET_ADDRESS,
            "withdraw.state.pectraWithdrawalContractAddress",
            pectraWithdrawal,
            "pectraWithdrawal"
        );
        _assertAddressSlot(
            WITHDRAW_MAINNET_ADDRESS,
            "withdraw.state.pectraConsolidationContractAddress",
            pectraConsolidation,
            "pectraConsolidation"
        );
        _assertAddressSlot(WITHDRAW_MAINNET_ADDRESS, "river.state.operatorsRegistryAddress", registry, "registry");
        _assertAddressSlot(WITHDRAW_MAINNET_ADDRESS, "river.state.attestationVerifierAddress", verifier, "verifier");
    }

    /// @notice A non-atomic `upgradeTo` + separate init leaves the initializer front-runnable by a
    ///         non-admin account. This asserts the front-run SUCCEEDS today, documenting why the
    ///         upgrade must be atomic. If a local caller guard is ever added, this expectation must
    ///         flip to a revert — a deliberate signal of the behavior change.
    function test_withdraw_frontRun_whenNonAtomic() external shouldSkip {
        WithdrawV1 newImpl = new WithdrawV1();

        vm.prank(_proxyAdmin(WITHDRAW_MAINNET_ADDRESS));
        ITransparentUpgradeableProxy(WITHDRAW_MAINNET_ADDRESS).upgradeTo(address(newImpl));

        // Version is still 1; the initializer has not run. An attacker front-runs it.
        vm.prank(ATTACKER);
        WithdrawV1(WITHDRAW_MAINNET_ADDRESS)
            .initWithdrawV1_1(address(0xBAD1), address(0xBAD2), address(0xBAD3), address(0xBAD4));

        _assertVersion(WITHDRAW_MAINNET_ADDRESS, 2, "withdraw version after front-run");
        _assertAddressSlot(
            WITHDRAW_MAINNET_ADDRESS,
            "withdraw.state.pectraWithdrawalContractAddress",
            address(0xBAD1),
            "attacker pectraWithdrawal"
        );
    }

    function test_withdraw_cannotRerun() external shouldSkip {
        WithdrawV1 newImpl = new WithdrawV1();

        vm.startPrank(_proxyAdmin(WITHDRAW_MAINNET_ADDRESS));
        ITransparentUpgradeableProxy(WITHDRAW_MAINNET_ADDRESS)
            .upgradeToAndCall(
                address(newImpl),
                abi.encodeCall(
                    WithdrawV1.initWithdrawV1_1, (address(0xA11), address(0xA12), address(0xA13), address(0xA14))
                )
            );

        vm.expectRevert();
        ITransparentUpgradeableProxy(WITHDRAW_MAINNET_ADDRESS)
            .upgradeToAndCall(
                address(newImpl),
                abi.encodeCall(
                    WithdrawV1.initWithdrawV1_1, (address(0xA11), address(0xA12), address(0xA13), address(0xA14))
                )
            );
        vm.stopPrank();
    }

    // ───────────────────────── OperatorsRegistry.initOperatorsRegistryV1_2 ─────────────────────

    function test_operatorsRegistry_atomicUpgrade_ok() external shouldSkip {
        _assertVersion(OPERATORS_REGISTRY_MAINNET_ADDRESS, 2, "operatorsRegistry pre-upgrade version");

        OperatorsRegistryV1 newImpl = new OperatorsRegistryV1();
        address withdrawAddr = address(0xB11);

        vm.prank(_proxyAdmin(OPERATORS_REGISTRY_MAINNET_ADDRESS));
        ITransparentUpgradeableProxy(OPERATORS_REGISTRY_MAINNET_ADDRESS)
            .upgradeToAndCall(
                address(newImpl), abi.encodeCall(OperatorsRegistryV1.initOperatorsRegistryV1_2, withdrawAddr)
            );

        _assertVersion(OPERATORS_REGISTRY_MAINNET_ADDRESS, 3, "operatorsRegistry post-upgrade version");
        _assertAddressSlot(
            OPERATORS_REGISTRY_MAINNET_ADDRESS, "river.state.withdrawAddress", withdrawAddr, "withdrawAddress"
        );
    }

    function test_operatorsRegistry_frontRun_whenNonAtomic() external shouldSkip {
        OperatorsRegistryV1 newImpl = new OperatorsRegistryV1();

        vm.prank(_proxyAdmin(OPERATORS_REGISTRY_MAINNET_ADDRESS));
        ITransparentUpgradeableProxy(OPERATORS_REGISTRY_MAINNET_ADDRESS).upgradeTo(address(newImpl));

        vm.prank(ATTACKER);
        OperatorsRegistryV1(OPERATORS_REGISTRY_MAINNET_ADDRESS).initOperatorsRegistryV1_2(ATTACKER);

        _assertVersion(OPERATORS_REGISTRY_MAINNET_ADDRESS, 3, "operatorsRegistry version after front-run");
        _assertAddressSlot(
            OPERATORS_REGISTRY_MAINNET_ADDRESS, "river.state.withdrawAddress", ATTACKER, "attacker withdrawAddress"
        );
    }

    function test_operatorsRegistry_cannotRerun() external shouldSkip {
        OperatorsRegistryV1 newImpl = new OperatorsRegistryV1();

        vm.startPrank(_proxyAdmin(OPERATORS_REGISTRY_MAINNET_ADDRESS));
        ITransparentUpgradeableProxy(OPERATORS_REGISTRY_MAINNET_ADDRESS)
            .upgradeToAndCall(
                address(newImpl), abi.encodeCall(OperatorsRegistryV1.initOperatorsRegistryV1_2, address(0xB11))
            );

        vm.expectRevert();
        ITransparentUpgradeableProxy(OPERATORS_REGISTRY_MAINNET_ADDRESS)
            .upgradeToAndCall(
                address(newImpl), abi.encodeCall(OperatorsRegistryV1.initOperatorsRegistryV1_2, address(0xB11))
            );
        vm.stopPrank();
    }

    // ─────────────────────────────────── River.initRiverV1_3 ───────────────────────────────────

    function test_river_atomicUpgrade_ok() external shouldSkip {
        _assertVersion(RIVER_MAINNET_ADDRESS, 3, "river pre-upgrade version");

        RiverV1 newImpl = new RiverV1();
        address verifier = _deployVerifierWiredTo(RIVER_MAINNET_ADDRESS);
        address coverageFund = address(0xC11);
        address recipientMapping = address(0xC12);
        address consolidator = address(0xC13);

        vm.prank(_proxyAdmin(RIVER_MAINNET_ADDRESS));
        ITransparentUpgradeableProxy(RIVER_MAINNET_ADDRESS)
            .upgradeToAndCall(
                address(newImpl),
                abi.encodeCall(
                    RiverV1.initRiverV1_3,
                    (_withdrawCredentials(), coverageFund, verifier, recipientMapping, consolidator)
                )
            );

        _assertVersion(RIVER_MAINNET_ADDRESS, 4, "river post-upgrade version");
        assertEq(RiverV1(payable(RIVER_MAINNET_ADDRESS)).getConsolidator(), consolidator, "consolidator mismatch");
        assertEq(
            RiverV1(payable(RIVER_MAINNET_ADDRESS)).getConsolidationCoverageFund(),
            coverageFund,
            "coverageFund mismatch"
        );
    }

    function test_river_frontRun_whenNonAtomic() external shouldSkip {
        RiverV1 newImpl = new RiverV1();

        vm.prank(_proxyAdmin(RIVER_MAINNET_ADDRESS));
        ITransparentUpgradeableProxy(RIVER_MAINNET_ADDRESS).upgradeTo(address(newImpl));

        // The attestation-verifier validation (getRiver() == River) is satisfiable by anyone: the
        // attacker simply deploys a verifier wired to River, so the front-run still lets them pin
        // attacker-chosen consolidator / coverage-fund / recipient-mapping addresses.
        address attackerVerifier = _deployVerifierWiredTo(RIVER_MAINNET_ADDRESS);

        vm.prank(ATTACKER);
        RiverV1(payable(RIVER_MAINNET_ADDRESS))
            .initRiverV1_3(_withdrawCredentials(), ATTACKER, attackerVerifier, ATTACKER, ATTACKER);

        _assertVersion(RIVER_MAINNET_ADDRESS, 4, "river version after front-run");
        assertEq(
            RiverV1(payable(RIVER_MAINNET_ADDRESS)).getConsolidator(), ATTACKER, "attacker set themselves consolidator"
        );
    }

    function test_river_cannotRerun() external shouldSkip {
        RiverV1 newImpl = new RiverV1();
        address verifier = _deployVerifierWiredTo(RIVER_MAINNET_ADDRESS);

        vm.startPrank(_proxyAdmin(RIVER_MAINNET_ADDRESS));
        ITransparentUpgradeableProxy(RIVER_MAINNET_ADDRESS)
            .upgradeToAndCall(
                address(newImpl),
                abi.encodeCall(
                    RiverV1.initRiverV1_3,
                    (_withdrawCredentials(), address(0xC11), verifier, address(0xC12), address(0xC13))
                )
            );

        vm.expectRevert();
        ITransparentUpgradeableProxy(RIVER_MAINNET_ADDRESS)
            .upgradeToAndCall(
                address(newImpl),
                abi.encodeCall(
                    RiverV1.initRiverV1_3,
                    (_withdrawCredentials(), address(0xC11), verifier, address(0xC12), address(0xC13))
                )
            );
        vm.stopPrank();
    }

    // ──────────────────────────────────────── helpers ────────────────────────────────────────

    /// @notice Deploy a standalone AttestationVerifier implementation wired to `river` so it passes
    ///         `initRiverV1_3`'s `getRiver() == address(this)` validation. Mirrors the wiring in
    ///         AccountingHarnessBase (impl unbricked, then initialized directly).
    function _deployVerifierWiredTo(address river) internal returns (address) {
        AttestationVerifierV1 verifier = new AttestationVerifierV1();
        LibImplementationUnbricker.unbrick(vm, address(verifier));

        address[] memory rootAttesters = new address[](1);
        rootAttesters[0] = makeAddr("rootAttester");
        address[] memory consolidationAttesters = new address[](1);
        consolidationAttesters[0] = makeAddr("consolidationAttester");

        verifier.initAttestationVerifierV1(
            river, makeAddr("depositDataBuffer"), rootAttesters, 1, bytes4(0), consolidationAttesters, 1
        );
        return address(verifier);
    }

    /// @notice The 0x02 withdrawal credentials for the mainnet Withdraw contract.
    function _withdrawCredentials() internal pure returns (bytes32) {
        return bytes32(uint256(uint160(WITHDRAW_MAINNET_ADDRESS)) + uint256(WC_0X02_PREFIX));
    }

    function _proxyAdmin(address proxy) internal view returns (address) {
        return address(uint160(uint256(vm.load(proxy, ERC1967_ADMIN_SLOT))));
    }

    function _assertVersion(address proxy, uint256 expected, string memory label) internal {
        assertEq(uint256(vm.load(proxy, VERSION_SLOT)), expected, label);
    }

    function _assertAddressSlot(address proxy, string memory slotName, address expected, string memory label) internal {
        bytes32 slot = bytes32(uint256(keccak256(bytes(slotName))) - 1);
        assertEq(address(uint160(uint256(vm.load(proxy, slot)))), expected, label);
    }
}
