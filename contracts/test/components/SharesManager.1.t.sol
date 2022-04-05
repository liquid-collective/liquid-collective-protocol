//SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "../Vm.sol";
import "../console.sol";
import "../../src/components/SharesManager.1.sol";

contract SharesManagerPublicDeal is SharesManagerV1 {
    uint256 public balanceSum;

    function setValidatorBalance(uint256 _amount) external {
        balanceSum = _amount;
    }

    function _assetBalance() internal view override returns (uint256) {
        return balanceSum + address(this).balance;
    }

    function _isAccountAllowed(address) internal pure override returns (bool) {
        return true;
    }

    function deal(address _owner, uint256 _amount) external {
        uint256 shares = SharesPerOwner.get(_owner);
        Shares.set(Shares.get() - shares);
        SharesPerOwner.set(_owner, SharesPerOwner.get(_owner) - shares);

        Shares.set(Shares.get() + _amount);
        SharesPerOwner.set(_owner, _amount);
    }

    function mint(address _owner, uint256 _amount) external {
        SharesManagerV1._mintShares(_owner, _amount);
    }

    fallback() external payable {}

    receive() external payable {}
}

contract SharesManagerV1Tests {
    Vm internal vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    SharesManagerV1 internal sharesManager;

    function setUp() public {
        sharesManager = new SharesManagerPublicDeal();
    }

    function testBalanceOf(address _user) public {
        SharesManagerPublicDeal(payable(address(sharesManager))).setValidatorBalance(3200 ether);
        assert(sharesManager.balanceOf(_user) == 0);

        uint256 shares = sharesManager.totalShares();
        uint256 supply = sharesManager.totalSupply();

        SharesManagerPublicDeal(payable(address(sharesManager))).deal(_user, 10 ether);

        uint256 expectedBalance = (supply * 10 ether) / (shares + 10 ether);

        assert(sharesManager.balanceOf(_user) == expectedBalance);
    }

    function testSharesOf(address _user, address _anotherUser) public {
        _anotherUser = address(uint160(_user) + 1);
        SharesManagerPublicDeal(payable(address(sharesManager))).setValidatorBalance(0 ether);

        assert(sharesManager.sharesOf(_user) == 0);

        SharesManagerPublicDeal(payable(address(sharesManager))).setValidatorBalance(300 ether);
        SharesManagerPublicDeal(payable(address(sharesManager))).mint(_user, 300 ether);

        assert(sharesManager.sharesOf(_user) == 300 ether);

        SharesManagerPublicDeal(payable(address(sharesManager))).setValidatorBalance(440 ether);
        SharesManagerPublicDeal(payable(address(sharesManager))).mint(_anotherUser, 100 ether);

        assert(sharesManager.sharesOf(_user) == 300 ether);
        assert(sharesManager.sharesOf(_anotherUser) == 88235294117647058823);

        assert(sharesManager.balanceOf(_user) == 340 ether);
        assert(sharesManager.balanceOf(_anotherUser) == 99999999999999999999); // rounding issues with solidity, diff is negligible
    }

    function testName() public view {
        assert(keccak256("River") == keccak256(bytes(sharesManager.name())));
    }

    function testSymbol() public view {
        assert(keccak256("rETH") == keccak256(bytes(sharesManager.symbol())));
    }

    function testDecimals() public view {
        assert(18 == sharesManager.decimals());
    }

    function testTotalSupply(
        address _user,
        uint128 validatorBalanceSum,
        uint128 depositSize
    ) public {
        vm.deal(_user, depositSize);
        vm.startPrank(_user);
        assert(sharesManager.totalSupply() == 0);
        SharesManagerPublicDeal(payable(address(sharesManager))).setValidatorBalance(validatorBalanceSum);
        (bool sent, ) = payable(address(sharesManager)).call{value: depositSize}("");
        assert(sent == true);
        assert(sharesManager.totalSupply() == uint256(validatorBalanceSum) + uint256(depositSize));
        vm.stopPrank();
    }

    function testApprove(
        address _userOne,
        address _userTwo,
        uint256 _allowance
    ) public {
        SharesManagerPublicDeal(payable(address(sharesManager))).deal(_userOne, _allowance);
        vm.startPrank(_userOne);
        assert(0 == sharesManager.allowance(_userOne, _userTwo));
        sharesManager.approve(_userTwo, _allowance);
        assert(_allowance == sharesManager.allowance(_userOne, _userTwo));
        vm.stopPrank();
    }

    function testApproveAndTransferPartial(address _userOne, uint128 _allowance) public {
        address _userTwo = address(uint160(_userOne) + 1);
        SharesManagerPublicDeal(payable(address(sharesManager))).deal(_userOne, _allowance);
        SharesManagerPublicDeal(payable(address(sharesManager))).setValidatorBalance(uint256(_allowance));
        vm.startPrank(_userOne);
        uint256 totalAllowance = sharesManager.balanceOf(_userOne);
        assert(0 == sharesManager.allowance(_userOne, _userTwo));
        sharesManager.approve(_userTwo, totalAllowance);
        assert(totalAllowance == sharesManager.allowance(_userOne, _userTwo));
        assert(totalAllowance == sharesManager.balanceOf(_userOne));
        assert(0 == sharesManager.balanceOf(_userTwo));
        uint256 transferValue = totalAllowance / 2;
        vm.stopPrank();
        if (transferValue > 0) {
            vm.startPrank(_userTwo);
            sharesManager.transferFrom(_userOne, _userTwo, transferValue);
            uint256 newBalanceUserOne = (sharesManager.sharesOf(_userOne) * sharesManager.totalSupply()) /
                sharesManager.totalShares();
            uint256 newBalanceUserTwo = (sharesManager.sharesOf(_userTwo) * sharesManager.totalSupply()) /
                sharesManager.totalShares();
            assert(totalAllowance - transferValue == sharesManager.allowance(_userOne, _userTwo));
            assert(newBalanceUserOne == sharesManager.balanceOf(_userOne));
            assert(newBalanceUserTwo == sharesManager.balanceOf(_userTwo));
            assert(newBalanceUserOne + newBalanceUserTwo == totalAllowance);
            vm.stopPrank();
        }
    }

    function testApproveAndTransferTotal(address _userOne, uint128 _allowance) public {
        address _userTwo = address(uint160(_userOne) + 1);
        SharesManagerPublicDeal(payable(address(sharesManager))).deal(_userOne, _allowance);
        SharesManagerPublicDeal(payable(address(sharesManager))).setValidatorBalance(uint256(_allowance));
        vm.startPrank(_userOne);
        uint256 totalAllowance = sharesManager.balanceOf(_userOne);
        assert(0 == sharesManager.allowance(_userOne, _userTwo));
        sharesManager.approve(_userTwo, totalAllowance);
        vm.stopPrank();
        assert(totalAllowance == sharesManager.allowance(_userOne, _userTwo));
        assert(totalAllowance == sharesManager.balanceOf(_userOne));
        assert(0 == sharesManager.balanceOf(_userTwo));
        uint256 transferValue = totalAllowance;
        if (transferValue > 0) {
            vm.startPrank(_userTwo);
            sharesManager.transferFrom(_userOne, _userTwo, transferValue);
            uint256 newBalanceUserOne = 0;
            uint256 newBalanceUserTwo = sharesManager.totalSupply();
            assert(0 == sharesManager.allowance(_userOne, _userTwo));
            assert(newBalanceUserOne == sharesManager.balanceOf(_userOne));
            assert(newBalanceUserTwo == sharesManager.balanceOf(_userTwo));
            assert(newBalanceUserOne + newBalanceUserTwo == totalAllowance);
            vm.stopPrank();
        }
    }

    function testApproveAndTransferZero(address _userOne, uint128 _allowance) public {
        address _userTwo = address(uint160(_userOne) + 1);
        SharesManagerPublicDeal(payable(address(sharesManager))).deal(_userOne, _allowance);
        SharesManagerPublicDeal(payable(address(sharesManager))).setValidatorBalance(uint256(_allowance));
        vm.startPrank(_userOne);
        uint256 totalAllowance = sharesManager.balanceOf(_userOne);
        sharesManager.approve(_userTwo, totalAllowance);
        vm.stopPrank();
        vm.startPrank(_userTwo);
        vm.expectRevert(abi.encodeWithSignature("NullTransfer()"));
        sharesManager.transferFrom(_userOne, _userTwo, 0);
        vm.stopPrank();
    }

    function testApproveAndTransferAboveAllowance(address _userOne, uint128 _allowance) public {
        address _userTwo = address(uint160(_userOne) + 1);
        SharesManagerPublicDeal(payable(address(sharesManager))).deal(_userOne, _allowance);
        SharesManagerPublicDeal(payable(address(sharesManager))).setValidatorBalance(uint256(_allowance));
        vm.startPrank(_userOne);
        uint256 totalAllowance = sharesManager.balanceOf(_userOne);
        sharesManager.approve(_userTwo, totalAllowance / 2);
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
            sharesManager.transferFrom(_userOne, _userTwo, totalAllowance);
            vm.stopPrank();
        }
    }

    function testApproveAndTransferAboveBalance(address _userOne, uint128 _allowance) public {
        address _userTwo = address(uint160(_userOne) + 1);
        SharesManagerPublicDeal(payable(address(sharesManager))).deal(_userOne, _allowance / 2);
        SharesManagerPublicDeal(payable(address(sharesManager))).setValidatorBalance(_allowance / 2);
        vm.startPrank(_userOne);
        sharesManager.approve(_userTwo, _allowance);
        vm.stopPrank();
        if (_allowance > 0) {
            vm.startPrank(_userTwo);
            vm.expectRevert(abi.encodeWithSignature("BalanceTooLow()"));
            sharesManager.transferFrom(_userOne, _userTwo, _allowance);
            vm.stopPrank();
        }
    }

    function testApproveAndTransferUnauthorized(address _userOne, uint128 _allowance) public {
        address _userTwo = address(uint160(_userOne) + 1);
        SharesManagerPublicDeal(payable(address(sharesManager))).deal(_userOne, _allowance);
        SharesManagerPublicDeal(payable(address(sharesManager))).setValidatorBalance(uint256(_allowance));
        if (_allowance > 0) {
            vm.startPrank(_userTwo);
            vm.expectRevert(
                abi.encodeWithSignature(
                    "AllowanceTooLow(address,address,uint256,uint256)",
                    _userOne,
                    _userTwo,
                    0,
                    _allowance
                )
            );
            sharesManager.transferFrom(_userOne, _userTwo, _allowance);
            vm.stopPrank();
        }
    }

    function testTransferPartial(address _userOne, uint128 _allowance) public {
        address _userTwo = address(uint160(_userOne) + 1);
        SharesManagerPublicDeal(payable(address(sharesManager))).deal(_userOne, _allowance);
        SharesManagerPublicDeal(payable(address(sharesManager))).setValidatorBalance(uint256(_allowance));
        vm.startPrank(_userOne);
        uint256 totalAllowance = sharesManager.balanceOf(_userOne);
        assert(0 == sharesManager.balanceOf(_userTwo));
        uint256 transferValue = totalAllowance / 2;
        if (transferValue > 0) {
            sharesManager.transfer(_userTwo, transferValue);
            uint256 newBalanceUserOne = (sharesManager.sharesOf(_userOne) * sharesManager.totalSupply()) /
                sharesManager.totalShares();
            uint256 newBalanceUserTwo = (sharesManager.sharesOf(_userTwo) * sharesManager.totalSupply()) /
                sharesManager.totalShares();
            assert(newBalanceUserOne == sharesManager.balanceOf(_userOne));
            assert(newBalanceUserTwo == sharesManager.balanceOf(_userTwo));
            assert(newBalanceUserOne + newBalanceUserTwo == totalAllowance);
        }
        vm.stopPrank();
    }

    function testTransferTotal(address _userOne, uint128 _allowance) public {
        address _userTwo = address(uint160(_userOne) + 1);
        SharesManagerPublicDeal(payable(address(sharesManager))).deal(_userOne, _allowance);
        SharesManagerPublicDeal(payable(address(sharesManager))).setValidatorBalance(uint256(_allowance));
        vm.startPrank(_userOne);
        uint256 totalAllowance = sharesManager.balanceOf(_userOne);
        assert(0 == sharesManager.balanceOf(_userTwo));
        uint256 transferValue = totalAllowance;
        if (transferValue > 0) {
            sharesManager.transfer(_userTwo, transferValue);
            uint256 newBalanceUserOne = 0;
            uint256 newBalanceUserTwo = _allowance;
            assert(newBalanceUserOne == sharesManager.balanceOf(_userOne));
            assert(newBalanceUserTwo == sharesManager.balanceOf(_userTwo));
            assert(newBalanceUserOne + newBalanceUserTwo == totalAllowance);
        }
        vm.stopPrank();
    }

    function testTransferTransferZero(address _userOne, uint128 _allowance) public {
        address _userTwo = address(uint160(_userOne) + 1);
        SharesManagerPublicDeal(payable(address(sharesManager))).deal(_userOne, _allowance);
        SharesManagerPublicDeal(payable(address(sharesManager))).setValidatorBalance(uint256(_allowance));
        vm.startPrank(_userOne);
        assert(0 == sharesManager.balanceOf(_userTwo));
        vm.expectRevert(abi.encodeWithSignature("NullTransfer()"));
        sharesManager.transfer(_userTwo, 0);
        vm.stopPrank();
    }

    function testTransferTransferBalanceTooLow(address _userOne) public {
        address _userTwo = address(uint160(_userOne) + 1);
        vm.startPrank(_userOne);
        assert(0 == sharesManager.balanceOf(_userTwo));
        vm.expectRevert(abi.encodeWithSignature("BalanceTooLow()"));
        sharesManager.transfer(_userTwo, 1);
        vm.stopPrank();
    }
}
