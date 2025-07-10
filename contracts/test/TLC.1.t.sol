//SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.20;

import "../src/TLC.1.sol";
import "../src/TUPProxy.sol";
import "forge-std/Test.sol";

abstract contract TLCTestBase is Test {
    TLCV1 internal tlcImplem;
    TLCV1 internal tlc;

    address internal escrowImplem;
    address internal initAccount;
    address internal bob;
    address internal joe;
    address internal admin;

    bytes32 internal constant DELEGATION_TYPEHASH =
        keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)");

    uint256 internal constant PRIVATE_KEY = 0x7aca0a9d453404a0469898a3df5c3673cbcf5045e294ae50131d8fc6b9ec5152;
}

contract TLCInitializationTest is TLCTestBase {
    function setUp() public {
        initAccount = makeAddr("init");
        bob = makeAddr("bob");
        joe = makeAddr("joe");
        admin = makeAddr("admin");

        tlcImplem = new TLCV1();
    }

    function testInitialization() external {
        tlc = TLCV1(
            address(
                new TUPProxy(
                    address(tlcImplem), admin, abi.encodeWithSelector(tlcImplem.initTLCV1.selector, initAccount)
                )
            )
        );

        assertEq(1_000_000_000e18, tlc.totalSupply());
    }
}

contract TLCTests is TLCTestBase {
    function setUp() public {
        initAccount = makeAddr("init");
        bob = makeAddr("bob");
        joe = makeAddr("joe");
        admin = makeAddr("admin");

        tlcImplem = new TLCV1();
        tlc = TLCV1(
            address(
                new TUPProxy(
                    address(tlcImplem), admin, abi.encodeWithSelector(tlcImplem.initTLCV1.selector, initAccount)
                )
            )
        );
        tlc.migrateVestingSchedules();
    }

    function testImplementationInitialization() public {
        vm.expectRevert("Initializable: contract is already initialized");
        tlcImplem.initTLCV1(initAccount);
    }

    function testName() public view {
        assert(keccak256(bytes(tlc.name())) == keccak256("Liquid Collective"));
    }

    function testSymbol() public view {
        assert(keccak256(bytes(tlc.symbol())) == keccak256("TLC"));
    }

    function testInitialSupplyAndBalance() public view {
        assert(tlc.totalSupply() == 1_000_000_000e18);
        assert(tlc.balanceOf(initAccount) == tlc.totalSupply());
    }
}

contract TLCDelegationTest is TLCTests {
    function testDirectDelegateeNotAllowed() public {
        vm.expectRevert(abi.encodeWithSignature("DelegationNotAllowed()"));
        tlc.delegate(bob);
    }

    function testDirectDelegateeNotAllowedBySig() public {
        // Step 1: Retrieve domain separator
        bytes32 domainSeparator = tlc.DOMAIN_SEPARATOR();

        // Step 2: Set delegation parameters
        address signer = joe;
        address delegatee = bob;
        uint256 nonce = tlc.nonces(signer);
        uint256 expiry = block.timestamp + 3600; // 1 hour from now

        // Step 3: Create the struct hash and digest
        bytes32 structHash = keccak256(abi.encode(DELEGATION_TYPEHASH, delegatee, nonce, expiry));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));

        // Step 4: Generate a valid signature using the private key
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(PRIVATE_KEY, digest);

        // Step 5: Expect revert for direct delegation not allowed
        vm.prank(signer); // Simulate the signer
        vm.expectRevert(abi.encodeWithSignature("DelegationNotAllowed()"));
        tlc.delegateBySig(delegatee, nonce, expiry, v, r, s);
    }
}
