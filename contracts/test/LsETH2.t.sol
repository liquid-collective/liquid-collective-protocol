//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "./utils/LibImplementationUnbricker.sol";
import "./utils/UserFactory.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {LsETH} from "./../src/LsETH.2.sol";
import {TUPProxy} from "./../src/TUPProxy.sol";

contract Base is Test {
    UserFactory internal uf = new UserFactory();
    LsETH lsETH2;
    MockERC20 opWETH;
    MockERC20 remoteToken;

    address bridge;
    address admin;

    address opWETHWhale;
    address remoteTokenWhale;

    function setUp() public {
        // Setup test environment
        lsETH2 = new LsETH();
        LibImplementationUnbricker.unbrick(vm, address(lsETH2));
        opWETH = new MockERC20("Optimism WETH", "OPWETH", 18);
        remoteToken = new MockERC20("Remote Token", "RT", 18);

        bridge = makeAddr("bridge");
        admin = makeAddr("admin");
        opWETHWhale = makeAddr("opWETHWhale");
        remoteTokenWhale = makeAddr("remoteTokenWhale");

        lsETH2.initialize(bridge, address(remoteToken), address(opWETH), admin);

        // Mint some OPWETH and remote token for whales
        vm.startPrank(opWETHWhale);
        opWETH.mint(opWETHWhale, 1000 ether);
        vm.stopPrank();

        vm.startPrank(remoteTokenWhale);
        remoteToken.mint(remoteTokenWhale, 1000 ether);
        vm.stopPrank();
    }

    function _mintAmount(address _to, uint256 _amount) internal {
        vm.startPrank(bridge);
        lsETH2.mint(_to, _amount);
        assertEq(lsETH2.balanceOf(_to), _amount);
        vm.stopPrank();
    }
}

contract TestTokenDetails is Base {
    function testName() public view {
        assert(keccak256("Liquid Staked ETH") == keccak256(bytes(lsETH2.name())));
    }

    function testSymbol() public view {
        assert(keccak256("LsETH") == keccak256(bytes(lsETH2.symbol())));
    }

    function testDecimals() public view {
        assert(18 == lsETH2.decimals());
    }
}

contract TestMintingAndBurning is Base {
    // Test minting
    function testMint() public {
        vm.startPrank(bridge);
        lsETH2.mint(opWETHWhale, 100 ether);
        assertEq(lsETH2.balanceOf(opWETHWhale), 100 ether);
        vm.stopPrank();
    }

    function testNoOneCanMintExceptBridge(uint256 salt) public {
        address temp = uf._new(salt);
        vm.startPrank(temp);
        vm.expectRevert(abi.encodeWithSignature("OnlyBridge()"));
        lsETH2.mint(opWETHWhale, 100 ether);
        vm.stopPrank();
    }

    // Test withdraw
    function testBridgeCanWithdraw(uint256 _value) public {
        vm.startPrank(bridge);
        lsETH2.mint(bridge, _value);
        assertEq(lsETH2.balanceOf(bridge), _value);

        lsETH2.burn(bridge, _value);
        assertEq(lsETH2.balanceOf(bridge), 0);
        vm.stopPrank();
    }

    function testNonBridgeCantWithdraw(uint256 _value) public {
        vm.startPrank(bridge);
        lsETH2.mint(opWETHWhale, _value);
        assertEq(lsETH2.balanceOf(opWETHWhale), _value);
        vm.stopPrank();

        vm.startPrank(opWETHWhale);
        vm.expectRevert(abi.encodeWithSignature("OnlyBridge()"));
        lsETH2.burn(opWETHWhale, _value);
        vm.stopPrank();
    }
}

contract TestDepositAndRedeem is Base {
    // Test User Deposits
    function testUserCanDeposit(uint256 _depositAmount) public {}

    function testUserCanDepositForAnotherUser(uint256 _depositAmount, address _recipient) public {}

    // Test User Redemption
    function testUserCanRedeem(uint256 _depositAmount) public {}

    function testUserCanRedeemAndTransfer(uint256 _depositAmount, address _recipient) public {}
}

contract TestTransferApprovalAllowance is Base {
    function testApprove(uint256 _userOneSalt, uint256 _userTwoSalt, uint256 _allowance) public {
        address _userOne = uf._new(_userOneSalt);
        address _userTwo = uf._new(_userTwoSalt);
        _mintAmount(_userOne, _allowance);
        vm.startPrank(_userOne);
        assert(0 == lsETH2.allowance(_userOne, _userTwo));
        lsETH2.approve(_userTwo, _allowance);
        assert(_allowance == lsETH2.allowance(_userOne, _userTwo));
        vm.stopPrank();
    }

    function testApproveZeroAddress(uint256 _userOneSalt, uint256 _allowance) public {
        address _userOne = uf._new(_userOneSalt);
        _mintAmount(_userOne, _allowance);
        vm.startPrank(_userOne);
        vm.expectRevert(abi.encodeWithSignature("InvalidZeroAddress()"));
        lsETH2.approve(address(0), _allowance);
        vm.stopPrank();
    }

    function testApproveAndTransferPartial(uint256 _userOneSalt, uint256 _userTwoSalt, uint128 _allowance) public {
        address _userOne = uf._new(_userOneSalt);
        address _userTwo = uf._new(_userTwoSalt);
        _mintAmount(_userOne, _allowance);

        vm.startPrank(_userOne);
        uint256 totalAllowance = lsETH2.balanceOf(_userOne);
        assert(0 == lsETH2.allowance(_userOne, _userTwo));
        lsETH2.approve(_userTwo, totalAllowance);
        assert(totalAllowance == lsETH2.allowance(_userOne, _userTwo));
        assert(totalAllowance == lsETH2.balanceOf(_userOne));
        assert(0 == lsETH2.balanceOf(_userTwo));
        uint256 transferValue = totalAllowance / 2;
        vm.stopPrank();
        if (transferValue > 0) {
            vm.startPrank(_userTwo);
            lsETH2.transferFrom(_userOne, _userTwo, transferValue);
            uint256 newBalanceUserOne = lsETH2.balanceOf(_userOne);
            uint256 newBalanceUserTwo = lsETH2.balanceOf(_userTwo);
            assert(totalAllowance - transferValue == lsETH2.allowance(_userOne, _userTwo));
            assert(newBalanceUserOne == lsETH2.balanceOf(_userOne));
            assert(newBalanceUserTwo == lsETH2.balanceOf(_userTwo));
            assert(newBalanceUserOne + newBalanceUserTwo == totalAllowance);
            vm.stopPrank();
        }
    }

    function testApproveAndTransferTotal(uint256 _userOneSalt, uint256 _userTwoSalt, uint128 _allowance) public {
        address _userOne = uf._new(_userOneSalt);
        address _userTwo = uf._new(_userTwoSalt);
        _mintAmount(_userOne, _allowance);

        vm.startPrank(_userOne);
        uint256 totalAllowance = lsETH2.balanceOf(_userOne);
        assert(0 == lsETH2.allowance(_userOne, _userTwo));
        lsETH2.approve(_userTwo, totalAllowance);
        vm.stopPrank();
        assert(totalAllowance == lsETH2.allowance(_userOne, _userTwo));
        assert(totalAllowance == lsETH2.balanceOf(_userOne));
        assert(0 == lsETH2.balanceOf(_userTwo));
        uint256 transferValue = totalAllowance;
        if (transferValue > 0) {
            vm.startPrank(_userTwo);
            lsETH2.transferFrom(_userOne, _userTwo, transferValue);
            uint256 newBalanceUserOne = 0;
            uint256 newBalanceUserTwo = lsETH2.balanceOf(_userTwo);
            assert(0 == lsETH2.allowance(_userOne, _userTwo));
            assert(newBalanceUserOne == lsETH2.balanceOf(_userOne));
            assert(newBalanceUserTwo == lsETH2.balanceOf(_userTwo));
            assert(newBalanceUserOne + newBalanceUserTwo == totalAllowance);
            vm.stopPrank();
        }
    }

    function testApproveAndTransferZero(uint256 _userOneSalt, uint256 _userTwoSalt, uint128 _allowance) public {
        address _userOne = uf._new(_userOneSalt);
        address _userTwo = uf._new(_userTwoSalt);
        _mintAmount(_userOne, _allowance);
        vm.startPrank(_userOne);
        uint256 totalAllowance = lsETH2.balanceOf(_userOne);
        lsETH2.approve(_userTwo, totalAllowance);
        vm.stopPrank();
        vm.startPrank(_userTwo);
        vm.expectRevert(abi.encodeWithSignature("NullTransfer()"));
        lsETH2.transferFrom(_userOne, _userTwo, 0);
        vm.stopPrank();
    }

    function testApproveAndTransferAboveAllowance(uint256 _userOneSalt, uint256 _userTwoSalt, uint128 _allowance)
        public
    {
        address _userOne = uf._new(_userOneSalt);
        address _userTwo = uf._new(_userTwoSalt);
        _mintAmount(_userOne, _allowance);
        vm.startPrank(_userOne);
        uint256 totalAllowance = lsETH2.balanceOf(_userOne);
        lsETH2.approve(_userTwo, totalAllowance / 2);
        vm.stopPrank();
        if (totalAllowance > 0) {
            vm.startPrank(_userTwo);
            vm.expectRevert(
                abi.encodeWithSignature(
                    "AllowanceTooLow(address,address,uint256,uint256)",
                    _userOne,
                    _userTwo,
                    totalAllowance / 2,
                    totalAllowance
                )
            );
            lsETH2.transferFrom(_userOne, _userTwo, totalAllowance);
            vm.stopPrank();
        }
    }

    function testApproveAndTransferAboveBalance(uint256 _userOneSalt, uint256 _userTwoSalt, uint128 _allowance)
        public
    {
        address _userOne = uf._new(_userOneSalt);
        address _userTwo = uf._new(_userTwoSalt);
        _mintAmount(_userOne, _allowance / 2);
        vm.startPrank(_userOne);
        lsETH2.approve(_userTwo, _allowance);
        vm.stopPrank();
        if (_allowance > 0) {
            vm.startPrank(_userTwo);
            vm.expectRevert(abi.encodeWithSignature("BalanceTooLow()"));
            lsETH2.transferFrom(_userOne, _userTwo, _allowance);
            vm.stopPrank();
        }
    }

    function testApproveAndTransferUnauthorized(uint256 _userOneSalt, uint256 _userTwoSalt, uint128 _allowance)
        public
    {
        address _userOne = uf._new(_userOneSalt);
        address _userTwo = uf._new(_userTwoSalt);
        _mintAmount(_userOne, _allowance);
        if (_allowance > 0) {
            vm.startPrank(_userTwo);
            vm.expectRevert(
                abi.encodeWithSignature(
                    "AllowanceTooLow(address,address,uint256,uint256)", _userOne, _userTwo, 0, _allowance
                )
            );
            lsETH2.transferFrom(_userOne, _userTwo, _allowance);
            vm.stopPrank();
        }
    }

    function testTransferPartial(uint256 _userOneSalt, uint256 _userTwoSalt, uint128 _allowance) public {
        address _userOne = uf._new(_userOneSalt);
        address _userTwo = uf._new(_userTwoSalt);
        _mintAmount(_userOne, _allowance);
        vm.startPrank(_userOne);
        uint256 totalAllowance = lsETH2.balanceOf(_userOne);
        assert(0 == lsETH2.balanceOf(_userTwo));
        uint256 transferValue = totalAllowance / 2;
        if (transferValue > 0) {
            lsETH2.transfer(_userTwo, transferValue);
            uint256 newBalanceUserOne = lsETH2.balanceOf(_userOne);
            uint256 newBalanceUserTwo = lsETH2.balanceOf(_userTwo);
            assert(newBalanceUserOne == lsETH2.balanceOf(_userOne));
            assert(newBalanceUserTwo == lsETH2.balanceOf(_userTwo));
            assert(newBalanceUserOne + newBalanceUserTwo == totalAllowance);
        }
        vm.stopPrank();
    }

    function testTransferZeroAddress(uint256 _userOneSalt, uint256 _userTwoSalt, uint128 _allowance) public {
        address _userOne = uf._new(_userOneSalt);
        address _userTwo = uf._new(_userTwoSalt);
        _mintAmount(_userOne, _allowance);
        vm.startPrank(_userOne);
        uint256 totalAllowance = lsETH2.balanceOf(_userOne);
        assert(0 == lsETH2.balanceOf(_userTwo));
        uint256 transferValue = totalAllowance / 2;
        if (transferValue > 0) {
            vm.expectRevert(abi.encodeWithSignature("UnauthorizedTransfer(address,address)", _userOne, address(0)));
            lsETH2.transfer(address(0), transferValue);
        }
        vm.stopPrank();
    }

    function testTransferTotal(uint256 _userOneSalt, uint256 _userTwoSalt, uint128 _allowance) public {
        address _userOne = uf._new(_userOneSalt);
        address _userTwo = uf._new(_userTwoSalt);
        _mintAmount(_userOne, _allowance);
        vm.startPrank(_userOne);
        uint256 totalAllowance = lsETH2.balanceOf(_userOne);
        assert(0 == lsETH2.balanceOf(_userTwo));
        uint256 transferValue = totalAllowance;
        if (transferValue > 0) {
            lsETH2.transfer(_userTwo, transferValue);
            uint256 newBalanceUserOne = 0;
            uint256 newBalanceUserTwo = _allowance;
            assert(newBalanceUserOne == lsETH2.balanceOf(_userOne));
            assert(newBalanceUserTwo == lsETH2.balanceOf(_userTwo));
            assert(newBalanceUserOne + newBalanceUserTwo == totalAllowance);
        }
        vm.stopPrank();
    }

    function testApproveAndTransferMsgSender(uint256 _userOneSalt, uint256 _userTwoSalt, uint128 _allowance) public {
        address _userOne = uf._new(_userOneSalt);
        address _userTwo = uf._new(_userTwoSalt);
        _mintAmount(_userOne, _allowance);
        if (_allowance > 0) {
            vm.startPrank(_userOne);
            vm.expectRevert(
                abi.encodeWithSignature(
                    "AllowanceTooLow(address,address,uint256,uint256)", _userOne, _userOne, 0, _allowance
                )
            );
            lsETH2.transferFrom(_userOne, _userTwo, _allowance);
            vm.stopPrank();
        }
    }

    function testApproveAndTransferZeroAddress(uint256 _userOneSalt, uint256 _userTwoSalt, uint128 _allowance) public {
        address _userOne = uf._new(_userOneSalt);
        address _userTwo = uf._new(_userTwoSalt);
        _mintAmount(_userOne, _allowance);
        if (_allowance > 0) {
            vm.prank(_userOne);
            lsETH2.approve(_userTwo, _allowance);
            vm.prank(_userTwo);
            vm.expectRevert(abi.encodeWithSignature("UnauthorizedTransfer(address,address)", _userOne, address(0)));
            lsETH2.transferFrom(_userOne, address(0), _allowance);
        }
    }

    function testIncreaseAllowanceAndTransferFrom(uint256 _userOneSalt, uint256 _userTwoSalt, uint128 _allowance)
        public
    {
        address _userOne = uf._new(_userOneSalt);
        address _userTwo = uf._new(_userTwoSalt);
        _mintAmount(_userOne, _allowance);
        vm.prank(_userOne);
        lsETH2.increaseAllowance(_userTwo, _allowance);
        if (_allowance > 0) {
            vm.startPrank(_userTwo);
            lsETH2.transferFrom(_userOne, _userTwo, _allowance);
            vm.stopPrank();
            assert(lsETH2.balanceOf(_userTwo) == _allowance);
        }
    }

    function testIncreaseDecreaseAllowanceAndTransferFrom(
        uint256 _userOneSalt,
        uint256 _userTwoSalt,
        uint128 _allowance
    ) public {
        address _userOne = uf._new(_userOneSalt);
        address _userTwo = uf._new(_userTwoSalt);
        _mintAmount(_userOne, _allowance);
        vm.prank(_userOne);
        lsETH2.increaseAllowance(_userTwo, uint256(_allowance) * 2);
        vm.prank(_userOne);
        lsETH2.decreaseAllowance(_userTwo, _allowance);
        if (_allowance > 0) {
            vm.startPrank(_userTwo);
            lsETH2.transferFrom(_userOne, _userTwo, _allowance);
            vm.stopPrank();
            assert(lsETH2.balanceOf(_userTwo) == _allowance);
        }
    }

    function testTransferTransferZero(uint256 _userOneSalt, uint256 _userTwoSalt, uint128 _allowance) public {
        address _userOne = uf._new(_userOneSalt);
        address _userTwo = uf._new(_userTwoSalt);
        _mintAmount(_userOne, _allowance);
        vm.startPrank(_userOne);
        assert(0 == lsETH2.balanceOf(_userTwo));
        vm.expectRevert(abi.encodeWithSignature("NullTransfer()"));
        lsETH2.transfer(_userTwo, 0);
        vm.stopPrank();
    }

    function testTransferTransferBalanceTooLow(uint256 _userOneSalt, uint256 _userTwoSalt) public {
        address _userOne = uf._new(_userOneSalt);
        address _userTwo = uf._new(_userTwoSalt);
        vm.startPrank(_userOne);
        assert(0 == lsETH2.balanceOf(_userTwo));
        vm.expectRevert(abi.encodeWithSignature("BalanceTooLow()"));
        lsETH2.transfer(_userTwo, 1);
        vm.stopPrank();
    }
}

contract TestFloatFunctions is Base {
    /// Test DepositETH
    function testAdminCanDepositOpWeth() public {}
    /// Test WithdrawETH
    function testAdminCanWithdrawOpWeth() public {}
    /// Test withdraw LsETH & bridge to L1
}
