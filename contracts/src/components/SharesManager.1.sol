//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../interfaces/IERC20.sol";
import "../libraries/Errors.sol";

import "../state/river/Shares.sol";
import "../state/river/SharesPerOwner.sol";
import "../state/river/ApprovalsPerOwner.sol";

/// @title Shares Manager (v1)
/// @author SkillZ
/// @notice This contract handles the shares of the depositor and the rebasing effect depending on the oracle data
abstract contract SharesManagerV1 is IERC20 {
    error BalanceTooLow();
    error UnauthorizedOperation();
    error AllowanceTooLow(address _from, address _operator, uint256 _allowance, uint256 _value);
    error NullTransfer();

    function _isAccountAllowed(address _account) internal view virtual returns (bool);

    modifier allowed(address _account) {
        if (!_isAccountAllowed(_account)) {
            revert Errors.Unauthorized(_account);
        }
        _;
    }

    function name() external pure returns (string memory) {
        return "River";
    }

    function symbol() external pure returns (string memory) {
        return "rETH";
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

    function balanceOfUnderlying(address _owner) public view returns (uint256 balance) {
        return _balanceFromShares(SharesPerOwner.get(_owner));
    }

    function allowance(address _owner, address _spender) external view returns (uint256 remaining) {
        return ApprovalsPerOwner.get(_owner, _spender);
    }

    function sharesOf(address _owner) external view returns (uint256 shares) {
        return SharesPerOwner.get(_owner);
    }

    function transfer(address _to, uint256 _value) external allowed(msg.sender) allowed(_to) returns (bool success) {
        if (_value == 0) {
            revert NullTransfer();
        }
        if (_balanceOf(msg.sender) < _value) {
            revert BalanceTooLow();
        }

        SharesPerOwner.set(msg.sender, SharesPerOwner.get(msg.sender) - _value);
        SharesPerOwner.set(_to, SharesPerOwner.get(_to) + _value);

        emit Transfer(msg.sender, _to, _value);

        return true;
    }

    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) external allowed(_from) allowed(_to) returns (bool success) {
        if (_value == 0) {
            revert NullTransfer();
        }
        if (_from != msg.sender) {
            uint256 currentAllowance = ApprovalsPerOwner.get(_from, msg.sender);
            if (currentAllowance < _value) {
                revert AllowanceTooLow(_from, msg.sender, currentAllowance, _value);
            }
            ApprovalsPerOwner.set(_from, msg.sender, currentAllowance - _value);
        }

        if (_balanceOf(_from) < _value) {
            revert BalanceTooLow();
        }

        uint256 shares = _sharesFromBalance(_value);

        SharesPerOwner.set(_from, SharesPerOwner.get(_from) - shares);
        SharesPerOwner.set(_to, SharesPerOwner.get(_to) + shares);

        emit Transfer(_from, _to, _value);

        return true;
    }

    function approve(address _spender, uint256 _value) external allowed(msg.sender) returns (bool success) {
        ApprovalsPerOwner.set(msg.sender, _spender, _value);
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function _assetBalance() internal view virtual returns (uint256);

    function _balanceFromShares(uint256 shares) internal view returns (uint256) {
        uint256 _totalSharesValue = Shares.get();

        if (_totalSharesValue == 0) {
            return 0;
        }

        return ((shares * _assetBalance())) / _totalSharesValue;
    }

    function _sharesFromBalance(uint256 balance) internal view returns (uint256) {
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
            _mintRawShares(_owner, assetBalance);
        } else {
            uint256 sharesToMint = (_value * _totalShares()) / oldTotalAssetBalance;
            _mintRawShares(_owner, sharesToMint);
        }
    }

    // assuming funds are received, _assetBalance should have taken _value into account
    function _mintRawShares(address _owner, uint256 _value) internal {
        Shares.set(Shares.get() + _value);
        SharesPerOwner.set(_owner, SharesPerOwner.get(_owner) + _value);
        emit Transfer(address(0), _owner, _value);
    }

    function _balanceOf(address _owner) internal view returns (uint256 balance) {
        return SharesPerOwner.get(_owner);
    }

    function _totalShares() internal view returns (uint256) {
        return Shares.get();
    }

    function totalShares() external view returns (uint256) {
        return _totalShares();
    }
}
