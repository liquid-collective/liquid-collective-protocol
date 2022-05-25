//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "./Initializable.sol";
import "./interfaces/IRiverToken.sol";

import "./state/shared/RiverAddress.sol";
import "./state/shared/ApprovalsPerOwner.sol";
import "./state/wlseth/BalanceOf.sol";

/// @title Oracle Manager (v1)
/// @author SkillZ
/// @notice This contract handles the inputs provided by the oracle
contract WLSETHV1 is Initializable {
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);

    error BalanceTooLow();
    error UnauthorizedOperation();
    error AllowanceTooLow(address _from, address _operator, uint256 _allowance, uint256 _value);
    error NullTransfer();

    function initWLSETHV1(address _river) external init(0) {
        RiverAddress.set(_river);
    }

    function name() external pure returns (string memory) {
        return "Wrapped River";
    }

    function symbol() external pure returns (string memory) {
        return "wlsETH";
    }

    function decimals() external pure returns (uint8) {
        return 18;
    }

    function totalSupply() external view returns (uint256) {
        return IRiverToken(RiverAddress.get()).balanceOfUnderlying(address(this));
    }

    function balanceOf(address _owner) external view returns (uint256 balance) {
        return _balanceOf(_owner);
    }

    function _balanceOf(address _owner) internal view returns (uint256 balance) {
        return IRiverToken(RiverAddress.get()).underlyingBalanceFromShares(BalanceOf.get(_owner));
    }

    function allowance(address _owner, address _spender) external view returns (uint256 remaining) {
        return ApprovalsPerOwner.get(_owner, _spender);
    }

    modifier isNotNull(uint256 _value) {
        if (_value == 0) {
            revert NullTransfer();
        }
        _;
    }

    modifier hasFunds(address _owner, uint256 _value) {
        if (_balanceOf(_owner) < _value) {
            revert BalanceTooLow();
        }
        _;
    }

    function transfer(address _to, uint256 _value)
        external
        isNotNull(_value)
        hasFunds(msg.sender, _value)
        returns (bool)
    {
        return _transfer(msg.sender, _to, _value);
    }

    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) external isNotNull(_value) hasFunds(_from, _value) returns (bool) {
        if (_from != msg.sender) {
            uint256 currentAllowance = ApprovalsPerOwner.get(_from, msg.sender);
            if (currentAllowance < _value) {
                revert AllowanceTooLow(_from, msg.sender, currentAllowance, _value);
            }
            ApprovalsPerOwner.set(_from, msg.sender, currentAllowance - _value);
        }
        return _transfer(_from, _to, _value);
    }

    function approve(address _spender, uint256 _value) external returns (bool success) {
        ApprovalsPerOwner.set(msg.sender, _spender, _value);
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function _transfer(
        address _from,
        address _to,
        uint256 _value
    ) internal returns (bool) {
        uint256 valueToShares = IRiverToken(RiverAddress.get()).sharesFromUnderlyingBalance(_value);
        BalanceOf.set(_from, BalanceOf.get(_from) - valueToShares);
        BalanceOf.set(_to, BalanceOf.get(_to) + valueToShares);

        emit Transfer(_from, _to, _value);

        return true;
    }

    function mint(address _recipient, uint256 _value) external {
        BalanceOf.set(_recipient, BalanceOf.get(_recipient) + _value);
        IRiverToken(RiverAddress.get()).transferFrom(msg.sender, address(this), _value);
    }

    function burn(address _recipient, uint256 _value) external {
        uint256 callerUnderlyingBalance = IRiverToken(RiverAddress.get()).underlyingBalanceFromShares(
            BalanceOf.get(msg.sender)
        );
        if (_value > callerUnderlyingBalance) {
            revert BalanceTooLow();
        }
        uint256 sharesAmount = IRiverToken(RiverAddress.get()).sharesFromUnderlyingBalance(_value);
        BalanceOf.set(msg.sender, BalanceOf.get(msg.sender) - sharesAmount);
        IRiverToken(RiverAddress.get()).transfer(_recipient, sharesAmount);
    }
}
