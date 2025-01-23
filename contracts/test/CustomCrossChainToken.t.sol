// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";

import {IBurnMintERC20} from "../src/l2-token/IBurnMintERC20.sol";
import {IERC165} from "openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {CustomCrossChainToken} from "contracts/src/l2-token/CustomCrossChainToken.sol";
import "./utils/LibImplementationUnbricker.sol";

contract BaseTest is Test {
    bool private s_baseTestInitialized;
    address internal constant OWNER = 0x72da681452Ab957d1020c25fFaCA47B43980b7C3;
    address internal constant STRANGER = 0x02e7d5DD1F4dDbC9f512FfA01d30aa190Ae3edBb;

    // Fri May 26 2023 13:49:53 GMT+0000
    uint256 internal constant BLOCK_TIME = 1685108993;

    function setUp() public virtual {
        // BaseTest.setUp is often called multiple times from tests' setUp due to inheritance.
        if (s_baseTestInitialized) return;
        s_baseTestInitialized = true;

        vm.label(OWNER, "Owner");
        vm.label(STRANGER, "Stranger");

        // Set the sender to OWNER permanently
        vm.startPrank(OWNER);
        deal(OWNER, 1e20);

        // Set the block time to a constant known value
        vm.warp(BLOCK_TIME);
    }
}

contract CustomCrossChainTokenSetup is BaseTest {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event MintAccessGranted(address indexed minter);
    event BurnAccessGranted(address indexed burner);
    event MintAccessRevoked(address indexed minter);
    event BurnAccessRevoked(address indexed burner);

    CustomCrossChainToken internal s_customCrossChainToken;

    address internal s_mockPool = address(6243783892);
    uint256 internal s_amount = 1e18;

    function setUp() public virtual override {
        BaseTest.setUp();
        s_customCrossChainToken = new CustomCrossChainToken();
        LibImplementationUnbricker.unbrick(vm, address(s_customCrossChainToken));
        s_customCrossChainToken.initialize("Chainlink Token", "LINK");
        // Set s_mockPool to be a burner and minter
        s_customCrossChainToken.grantRole(s_customCrossChainToken.BURNER_ROLE(), s_mockPool);
        s_customCrossChainToken.grantRole(s_customCrossChainToken.MINTER_ROLE(), s_mockPool);
        deal(address(s_customCrossChainToken), OWNER, s_amount);
    }
}

contract CustomCrossChainToken_constructor is CustomCrossChainTokenSetup {
    function testConstructorSuccess() public {
        string memory name = "Chainlink token v2";
        string memory symbol = "LINK2";
        uint8 decimals = 18;
        s_customCrossChainToken = new CustomCrossChainToken();
        LibImplementationUnbricker.unbrick(vm, address(s_customCrossChainToken));
        s_customCrossChainToken.initialize(name, symbol);
        assertEq(name, s_customCrossChainToken.name());
        assertEq(symbol, s_customCrossChainToken.symbol());
        assertEq(decimals, s_customCrossChainToken.decimals());
    }
}

contract CustomCrossChainToken_approve is CustomCrossChainTokenSetup {
    function testApproveSuccess() public {
        uint256 balancePre = s_customCrossChainToken.balanceOf(STRANGER);
        uint256 sendingAmount = s_amount / 2;

        s_customCrossChainToken.approve(STRANGER, sendingAmount);

        changePrank(STRANGER);

        s_customCrossChainToken.transferFrom(OWNER, STRANGER, sendingAmount);

        assertEq(sendingAmount + balancePre, s_customCrossChainToken.balanceOf(STRANGER));
    }
}

contract CustomCrossChainToken_transfer is CustomCrossChainTokenSetup {
    function testTransferSuccess() public {
        uint256 balancePre = s_customCrossChainToken.balanceOf(STRANGER);
        uint256 sendingAmount = s_amount / 2;

        s_customCrossChainToken.transfer(STRANGER, sendingAmount);

        assertEq(sendingAmount + balancePre, s_customCrossChainToken.balanceOf(STRANGER));
    }
}

contract CustomCrossChainToken_mint is CustomCrossChainTokenSetup {
    function testBasicMintSuccess() public {
        uint256 balancePre = s_customCrossChainToken.balanceOf(OWNER);

        s_customCrossChainToken.grantRole(s_customCrossChainToken.BURNER_ROLE(), OWNER);
        s_customCrossChainToken.grantRole(s_customCrossChainToken.MINTER_ROLE(), OWNER);

        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0), OWNER, s_amount);

        s_customCrossChainToken.mint(OWNER, s_amount);

        assertEq(balancePre + s_amount, s_customCrossChainToken.balanceOf(OWNER));
    }
}

contract CustomCrossChainToken_burn is CustomCrossChainTokenSetup {
    function testBasicBurnSuccess() public {
        s_customCrossChainToken.grantRole(s_customCrossChainToken.BURNER_ROLE(), OWNER);

        deal(address(s_customCrossChainToken), OWNER, s_amount);

        vm.expectEmit(true, true, true, true);
        emit Transfer(OWNER, address(0), s_amount);

        s_customCrossChainToken.burn(s_amount);

        assertEq(0, s_customCrossChainToken.balanceOf(OWNER));
    }

    // Revert

    function testSenderNotBurnerReverts() public {
        vm.expectRevert();
        s_customCrossChainToken.burnFrom(STRANGER, s_amount);
    }

    function testExceedsBalanceReverts() public {
        changePrank(s_mockPool);

        vm.expectRevert("ERC20: burn amount exceeds balance");

        s_customCrossChainToken.burn(s_amount * 2);
    }

    function testBurnFromZeroAddressReverts() public {
        s_customCrossChainToken.grantRole(s_customCrossChainToken.BURNER_ROLE(), address(0));

        changePrank(address(0));

        vm.expectRevert("ERC20: burn from the zero address");

        s_customCrossChainToken.burn(0);
    }
}

contract CustomCrossChainToken_burnFromAlias is CustomCrossChainTokenSetup {
    function setUp() public virtual override {
        CustomCrossChainTokenSetup.setUp();
    }

    function testBurnFromSuccess() public {
        s_customCrossChainToken.approve(s_mockPool, s_amount);

        changePrank(s_mockPool);

        s_customCrossChainToken.burn(OWNER, s_amount);

        assertEq(0, s_customCrossChainToken.balanceOf(OWNER));
    }

    // Reverts

    function testSenderNotBurnerReverts() public {
        vm.expectRevert();
        s_customCrossChainToken.burn(OWNER, s_amount);
    }

    function testInsufficientAllowanceReverts() public {
        changePrank(s_mockPool);

        vm.expectRevert("ERC20: insufficient allowance");

        s_customCrossChainToken.burn(OWNER, s_amount);
    }

    function testExceedsBalanceReverts() public {
        s_customCrossChainToken.approve(s_mockPool, s_amount * 2);

        changePrank(s_mockPool);

        vm.expectRevert("ERC20: burn amount exceeds balance");

        s_customCrossChainToken.burn(OWNER, s_amount * 2);
    }
}

contract CustomCrossChainToken_burnFrom is CustomCrossChainTokenSetup {
    function setUp() public virtual override {
        CustomCrossChainTokenSetup.setUp();
    }

    function testBurnFromSuccess() public {
        s_customCrossChainToken.approve(s_mockPool, s_amount);

        changePrank(s_mockPool);

        s_customCrossChainToken.burnFrom(OWNER, s_amount);

        assertEq(0, s_customCrossChainToken.balanceOf(OWNER));
    }

    // Reverts
    function testSenderNotBurnerReverts() public {
        vm.expectRevert();
        s_customCrossChainToken.burnFrom(OWNER, s_amount);
    }

    function testInsufficientAllowanceReverts() public {
        changePrank(s_mockPool);

        vm.expectRevert("ERC20: insufficient allowance");

        s_customCrossChainToken.burnFrom(OWNER, s_amount);
    }

    function testExceedsBalanceReverts() public {
        s_customCrossChainToken.approve(s_mockPool, s_amount * 2);

        changePrank(s_mockPool);

        vm.expectRevert("ERC20: burn amount exceeds balance");

        s_customCrossChainToken.burnFrom(OWNER, s_amount * 2);
    }
}

contract CustomCrossChainToken_grantRole is CustomCrossChainTokenSetup {
    function testGrantMintAccessSuccess() public {
        assertFalse(s_customCrossChainToken.hasRole(s_customCrossChainToken.BURNER_ROLE(), STRANGER));

        s_customCrossChainToken.grantRole(s_customCrossChainToken.MINTER_ROLE(), STRANGER);
        s_customCrossChainToken.grantRole(s_customCrossChainToken.BURNER_ROLE(), STRANGER);

        assertTrue(s_customCrossChainToken.hasRole(s_customCrossChainToken.BURNER_ROLE(), STRANGER));

        s_customCrossChainToken.revokeRole(s_customCrossChainToken.BURNER_ROLE(), STRANGER);

        assertFalse(s_customCrossChainToken.hasRole(s_customCrossChainToken.BURNER_ROLE(), STRANGER));
    }

    function testGrantBurnAccessSuccess() public {
        assertFalse(s_customCrossChainToken.hasRole(s_customCrossChainToken.MINTER_ROLE(), STRANGER));

        s_customCrossChainToken.grantRole(s_customCrossChainToken.MINTER_ROLE(), STRANGER);

        assertTrue(s_customCrossChainToken.hasRole(s_customCrossChainToken.MINTER_ROLE(), STRANGER));

        s_customCrossChainToken.revokeRole(s_customCrossChainToken.BURNER_ROLE(), STRANGER);

        assertFalse(s_customCrossChainToken.hasRole(s_customCrossChainToken.BURNER_ROLE(), STRANGER));
    }

    function testGrantManySuccess() public {
        uint256 numberOfPools = 10;
        address[] memory permissionedAddresses = new address[](numberOfPools + 1);
        permissionedAddresses[0] = s_mockPool;

        for (uint160 i = 0; i < numberOfPools; ++i) {
            permissionedAddresses[i + 1] = address(i);
            s_customCrossChainToken.grantRole(s_customCrossChainToken.BURNER_ROLE(), address(i));
            s_customCrossChainToken.grantRole(s_customCrossChainToken.MINTER_ROLE(), address(i));
        }
        for (uint160 i = 0; i < numberOfPools; ++i) {
            assert(s_customCrossChainToken.hasRole(s_customCrossChainToken.BURNER_ROLE(), permissionedAddresses[i]));
            assert(s_customCrossChainToken.hasRole(s_customCrossChainToken.MINTER_ROLE(), permissionedAddresses[i]));
        }
    }
}

contract CustomCrossChainToken_grantMintAndBurnRoles is CustomCrossChainTokenSetup {
    function testGrantMintAndBurnRolesSuccess() public {
        assertFalse(s_customCrossChainToken.hasRole(s_customCrossChainToken.BURNER_ROLE(), STRANGER));
        assertFalse(s_customCrossChainToken.hasRole(s_customCrossChainToken.MINTER_ROLE(), STRANGER));

        s_customCrossChainToken.grantRole(s_customCrossChainToken.BURNER_ROLE(), STRANGER);
        s_customCrossChainToken.grantRole(s_customCrossChainToken.MINTER_ROLE(), STRANGER);

        assertTrue(s_customCrossChainToken.hasRole(s_customCrossChainToken.BURNER_ROLE(), STRANGER));
        assertTrue(s_customCrossChainToken.hasRole(s_customCrossChainToken.MINTER_ROLE(), STRANGER));
    }
}

contract CustomCrossChainToken_decreaseApproval is CustomCrossChainTokenSetup {
    function testDecreaseApprovalSuccess() public {
        s_customCrossChainToken.approve(s_mockPool, s_amount);
        uint256 allowance = s_customCrossChainToken.allowance(OWNER, s_mockPool);
        assertEq(allowance, s_amount);
        s_customCrossChainToken.decreaseAllowance(s_mockPool, s_amount);
        assertEq(s_customCrossChainToken.allowance(OWNER, s_mockPool), allowance - s_amount);
    }
}

contract CustomCrossChainToken_increaseApproval is CustomCrossChainTokenSetup {
    function testIncreaseApprovalSuccess() public {
        s_customCrossChainToken.approve(s_mockPool, s_amount);
        uint256 allowance = s_customCrossChainToken.allowance(OWNER, s_mockPool);
        assertEq(allowance, s_amount);
        s_customCrossChainToken.increaseAllowance(s_mockPool, s_amount);
        assertEq(s_customCrossChainToken.allowance(OWNER, s_mockPool), allowance + s_amount);
    }
}

contract CustomCrossChainToken_supportsInterface is CustomCrossChainTokenSetup {
    function testConstructorSuccess() public {
        assertTrue(s_customCrossChainToken.supportsInterface(type(IERC165).interfaceId));
    }
}
