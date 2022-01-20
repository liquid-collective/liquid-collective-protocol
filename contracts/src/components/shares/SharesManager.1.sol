//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "./interfaces/IERC20.sol";
import "./state/Shares.sol";
import "./state/SharesPerOwner.sol";
import "./state/ApprovalsPerOwner.sol";
import "./state/ValidatorBalanceSum.sol";

contract SharesManagerV1 is IERC20 {
    error BalanceTooLow();
    error UnauthorizedOperation();

    function name() external pure returns (string memory) {
        return "River";
    }

    function symbol() external pure returns (string memory) {
        return "RIV";
    }

    function decimals() external pure returns (uint8) {
        return 18;
    }

    function totalSupply() external view returns (uint256) {
        return _assetBalance();
    }

    function balanceOf(address _owner) external view returns (uint256 balance) {
        return _balanceOf(_owner);
    }

    function allowance(address _owner, address _spender)
        external
        view
        returns (uint256 remaining)
    {
        return ApprovalsPerOwner.get(_owner, _spender);
    }

    function sharesOf(address _owner) external view returns (uint256 shares) {
        return SharesPerOwner.get(_owner);
    }

    function transfer(address _to, uint256 _value)
        external
        returns (bool success)
    {
        if (_balanceOf(msg.sender) >= _value) {
            revert BalanceTooLow();
        }

        uint256 shares = _sharesFromBalance(_value);

        SharesPerOwner.set(msg.sender, SharesPerOwner.get(msg.sender) - shares);
        SharesPerOwner.set(_to, SharesPerOwner.get(_to) + shares);

        return true;
    }

    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) external returns (bool success) {
        if (
            _from != msg.sender &&
            ApprovalsPerOwner.get(msg.sender, _from) < _value
        ) {
            revert UnauthorizedOperation();
        }

        if (_balanceOf(_from) >= _value) {
            revert BalanceTooLow();
        }

        uint256 shares = _sharesFromBalance(_value);

        SharesPerOwner.set(msg.sender, SharesPerOwner.get(msg.sender) - shares);
        SharesPerOwner.set(_to, SharesPerOwner.get(_to) + shares);

        return true;
    }

    function approve(address _spender, uint256 _value)
        external
        returns (bool success)
    {
        ApprovalsPerOwner.set(msg.sender, _spender, _value);
        return true;
    }

    function _assetBalance() internal view returns (uint256) {
        return ValidatorBalanceSum.get() + address(this).balance;
    }

    function _balanceFromShares(uint256 shares)
        internal
        view
        returns (uint256)
    {
        uint256 _totalSharesValue = Shares.get();

        if (_totalSharesValue == 0) {
            return 0;
        }

        return ((shares * _assetBalance())) / _totalSharesValue;
    }

    function _sharesFromBalance(uint256 balance)
        internal
        view
        returns (uint256)
    {
        uint256 assetBalance = _assetBalance();

        if (assetBalance == 0) {
            return 0;
        }

        return (balance * Shares.get()) / assetBalance;
    }

    // assuming funds are received, _assetBalance should have taken _value into account
    function _mintShares(address _owner, uint256 _value) internal {
        uint256 assetBalance = _assetBalance();
        uint256 oldTotalAssetBalance = _assetBalance() - _value;

        if (oldTotalAssetBalance == 0) {
            Shares.set(Shares.get() + assetBalance);
            SharesPerOwner.set(_owner, assetBalance);
        } else {
            uint256 sharesToMint = (_value * _totalShares()) /
                oldTotalAssetBalance;
            // uint256 sharesToMint = (((assetBalance * 1 ether) /
            //     oldTotalAssetBalance) * _totalShares()) /
            //     1 ether -
            //     _totalShares();

            Shares.set(Shares.get() + sharesToMint);
            SharesPerOwner.set(
                _owner,
                SharesPerOwner.get(_owner) + sharesToMint
            );
        }
    }

    function _balanceOf(address _owner)
        internal
        view
        returns (uint256 balance)
    {
        return _balanceFromShares(SharesPerOwner.get(_owner));
    }

    function _totalShares() internal view returns (uint256) {
        return Shares.get();
    }

    function totalShares() external view returns (uint256) {
        return _totalShares();
    }
}
