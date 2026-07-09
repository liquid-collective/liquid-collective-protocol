// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "forge-std/Test.sol";

import "../../src/AttestationVerifier.1.sol";
import "../../src/interfaces/IAttestationVerifier.1.sol";
import "../../src/libraries/BLS12_381.sol";
import "../../src/libraries/LibErrors.sol";
import "../utils/LibImplementationUnbricker.sol";

contract SetDepositDomainFromForkVersionTest is Test {
    AttestationVerifierV1 internal verifier;

    address internal admin = makeAddr("admin");
    address internal river = makeAddr("river");

    // Beacon-chain GENESIS_FORK_VERSION constants. Mainnet is the value that ships;
    // hoodi is the supported staking testnet. Both confirmed against the beacon /eth/v1/beacon/genesis
    // endpoints. Sepolia is intentionally NOT supported here (app/EVM testnet, not used for staking).
    bytes4 internal constant MAINNET_FORK_VERSION = 0x00000000;
    bytes4 internal constant HOODI_FORK_VERSION = 0x10000910;

    function setUp() public {
        verifier = new AttestationVerifierV1();
        LibImplementationUnbricker.unbrick(vm, address(verifier));

        // onlyRiverAdmin resolves via IAdministrable(RiverAddress.get()).getAdmin()
        vm.mockCall(river, abi.encodeWithSignature("getAdmin()"), abi.encode(admin));

        address[] memory rootAttesters = new address[](1);
        rootAttesters[0] = makeAddr("rootAttester");
        address[] memory consolidationAttesters = new address[](1);
        consolidationAttesters[0] = makeAddr("consolidationAttester");

        // init with bytes4(0) — accepted here because the default Foundry chain (31337) is unknown,
        // so init is permissive; the strict admin setter below is what enforces correctness.
        verifier.initAttestationVerifierV1(
            river, makeAddr("buffer"), makeAddr("withdraw"), rootAttesters, 1, bytes4(0), consolidationAttesters, 1
        );
    }

    /// @dev Happy path on mainnet — the value that ships.
    function testSetDepositDomain_mainnet() public {
        vm.chainId(1);
        bytes32 expected = BLS12_381.computeDepositDomain(MAINNET_FORK_VERSION);

        vm.prank(admin);
        verifier.setDepositDomainFromForkVersion(MAINNET_FORK_VERSION);

        assertEq(verifier.DEPOSIT_DOMAIN(), expected, "domain not set to mainnet value");
    }

    /// @dev Hoodi is also accepted.
    function testSetDepositDomain_hoodi() public {
        vm.chainId(560048);
        bytes32 expected = BLS12_381.computeDepositDomain(HOODI_FORK_VERSION);

        vm.prank(admin);
        verifier.setDepositDomainFromForkVersion(HOODI_FORK_VERSION);

        assertEq(verifier.DEPOSIT_DOMAIN(), expected, "domain not set to hoodi value");
    }

    /// @dev Wrong value for the chain reverts. Note bytes4(0) is mainnet's *valid* value, so the
    ///      all-zero foot-gun is exercised on hoodi (where the expected value is non-zero); a
    ///      non-zero wrong value (hoodi's, incl. its reversed-byte cousins) is exercised on mainnet.
    function testRevert_wrongForkVersionForChain() public {
        // On mainnet, a non-zero wrong value reverts (bytes4(0) is mainnet's correct value).
        vm.chainId(1);
        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(IAttestationVerifierV1.InvalidGenesisForkVersion.selector, HOODI_FORK_VERSION)
        );
        verifier.setDepositDomainFromForkVersion(HOODI_FORK_VERSION); // hoodi's value, wrong on mainnet

        // On hoodi, the all-zero value reverts (hoodi's expected value is non-zero).
        vm.chainId(560048);
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(IAttestationVerifierV1.InvalidGenesisForkVersion.selector, bytes4(0)));
        verifier.setDepositDomainFromForkVersion(bytes4(0));
    }

    /// @dev On an unknown chain there is no canonical value to validate against, so any fork version
    ///      is accepted as-is (same pass-through behaviour as init).
    function testSetDepositDomain_unknownChainAccepts() public {
        vm.chainId(11155111); // sepolia — not in the known table
        bytes4 arbitrary = 0x12345678;
        bytes32 expected = BLS12_381.computeDepositDomain(arbitrary);

        vm.prank(admin);
        verifier.setDepositDomainFromForkVersion(arbitrary);

        assertEq(verifier.DEPOSIT_DOMAIN(), expected, "unknown chain should accept the supplied value");
    }

    /// @dev Only River's admin may call.
    function testRevert_notAdmin() public {
        vm.chainId(1);
        address stranger = makeAddr("stranger");
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.Unauthorized.selector, stranger));
        verifier.setDepositDomainFromForkVersion(MAINNET_FORK_VERSION);
    }

    // -----------------------------------------------------------------------
    // initAttestationVerifierV1 path — the deploy-time prevention. These exercise the same
    // shared validation reached through init (not just the recovery setter), so a future refactor
    // that stopped routing init through the check would fail here.
    // -----------------------------------------------------------------------

    /// @dev Deploy a fresh, uninitialized verifier (the setUp one is already init'd; init is one-shot).
    function _freshVerifier() internal returns (AttestationVerifierV1 fresh) {
        fresh = new AttestationVerifierV1();
        LibImplementationUnbricker.unbrick(vm, address(fresh));
    }

    function _init(AttestationVerifierV1 v, bytes4 forkVersion) internal {
        address[] memory rootAttesters = new address[](1);
        rootAttesters[0] = makeAddr("rootAttester");
        address[] memory consolidationAttesters = new address[](1);
        consolidationAttesters[0] = makeAddr("consolidationAttester");
        v.initAttestationVerifierV1(
            river, makeAddr("buffer"), makeAddr("withdraw"), rootAttesters, 1, forkVersion, consolidationAttesters, 1
        );
    }

    /// @dev init reverts at deploy on a known chain when the fork version is wrong.
    function testInit_revertsOnWrongForkVersion_knownChain() public {
        vm.chainId(1); // mainnet — canonical is 0x00000000
        AttestationVerifierV1 fresh = _freshVerifier();
        vm.expectRevert(
            abi.encodeWithSelector(IAttestationVerifierV1.InvalidGenesisForkVersion.selector, HOODI_FORK_VERSION)
        );
        _init(fresh, HOODI_FORK_VERSION); // non-zero wrong value on mainnet
    }

    /// @dev init reverts on hoodi for the all-zero foot-gun (hoodi's canonical value is non-zero).
    function testInit_revertsOnZeroForkVersion_hoodi() public {
        vm.chainId(560048); // hoodi — canonical is 0x10000910
        AttestationVerifierV1 fresh = _freshVerifier();
        vm.expectRevert(abi.encodeWithSelector(IAttestationVerifierV1.InvalidGenesisForkVersion.selector, bytes4(0)));
        _init(fresh, bytes4(0));
    }

    /// @dev init stores the correct domain when given the canonical value on a known chain.
    function testInit_acceptsCanonicalForkVersion_mainnet() public {
        vm.chainId(1);
        AttestationVerifierV1 fresh = _freshVerifier();
        _init(fresh, MAINNET_FORK_VERSION);
        assertEq(fresh.DEPOSIT_DOMAIN(), BLS12_381.computeDepositDomain(MAINNET_FORK_VERSION), "mainnet init domain");
    }

    /// @dev init passes through on an unknown chain: a fresh verifier on a not-mainnet/not-hoodi
    ///      chain accepts an arbitrary (non-canonical) fork version and stores its domain rather than
    ///      reverting. Self-contained — does not rely on setUp's chain/init state.
    function testInit_acceptsAnyForkVersion_unknownChain() public {
        vm.chainId(11155111); // sepolia — not in the known table
        bytes4 arbitrary = 0x12345678;
        AttestationVerifierV1 fresh = _freshVerifier();

        _init(fresh, arbitrary);

        assertEq(
            fresh.DEPOSIT_DOMAIN(),
            BLS12_381.computeDepositDomain(arbitrary),
            "unknown-chain init should store the supplied value"
        );
    }
}
