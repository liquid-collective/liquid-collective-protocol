//SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "./Vm.sol";
import "../src/components/shares/SharesManager.1.sol";

contract SharesManagerPublicDeal is SharesManagerV1 {
    function setValidatorBalance(uint256 _amount) external {
        ValidatorBalanceSum.set(_amount);
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
}

contract SharesManagerV1Tests {
    Vm internal vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    SharesManagerV1 internal sharesManager;

    function setUp() public {
        sharesManager = new SharesManagerPublicDeal();
    }

    function testBalanceOf(address _user) public {
        SharesManagerPublicDeal(address(sharesManager)).setValidatorBalance(
            3200 ether
        );
        assert(sharesManager.balanceOf(_user) == 0);

        uint256 shares = sharesManager.totalShares();
        uint256 supply = sharesManager.totalSupply();

        SharesManagerPublicDeal(address(sharesManager)).deal(_user, 10 ether);

        uint256 expectedBalance = (supply * 10 ether) / (shares + 10 ether);

        assert(sharesManager.balanceOf(_user) == expectedBalance);
    }

    function testSharesOf(address _user, address _anotherUser) public {
        _anotherUser = address(uint160(_user) + 1);
        SharesManagerPublicDeal(address(sharesManager)).setValidatorBalance(
            0 ether
        );

        assert(sharesManager.sharesOf(_user) == 0);

        SharesManagerPublicDeal(address(sharesManager)).setValidatorBalance(
            300 ether
        );
        SharesManagerPublicDeal(address(sharesManager)).mint(_user, 300 ether);

        assert(sharesManager.sharesOf(_user) == 300 ether);

        SharesManagerPublicDeal(address(sharesManager)).setValidatorBalance(
            440 ether
        );
        SharesManagerPublicDeal(address(sharesManager)).mint(
            _anotherUser,
            100 ether
        );

        assert(sharesManager.sharesOf(_user) == 300 ether);
        assert(sharesManager.sharesOf(_anotherUser) == 88235294117647058823);

        assert(sharesManager.balanceOf(_user) == 340 ether);
        assert(sharesManager.balanceOf(_anotherUser) == 99999999999999999999); // rounding issues with solidity, diff is negligible
    }
}
