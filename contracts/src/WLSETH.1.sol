//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "./Initializable.sol";
import "./interfaces/IRiver.1.sol";
import "./interfaces/IWLSETH.1.sol";

import "./state/shared/RiverAddress.sol";
import "./state/shared/ApprovalsPerOwner.sol";
import "./state/wlseth/BalanceOf.sol";

import "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";

/// @title Wrapped lsETH v1
/// @author Kiln
/// @notice This contract wraps the lsETH token into a rebase token, more suitable for some DeFi use-cases
///         like stable swaps.
contract WLSETHV1 is IWLSETHV1, Initializable, ReentrancyGuard {
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

    /// @notice Initializes the wrapped token contract
    /// @param _river Address of the River contract
    function initWLSETHV1(address _river) external init(0) {
        RiverAddress.set(_river);
    }

    /// @notice Retrieves the token full name
    function name() external pure returns (string memory) {
        return "Wrapped Liquid Staked ETH";
    }

    /// @notice Retrieves the token ticker
    function symbol() external pure returns (string memory) {
        return "wLsETH";
    }

    /// @notice Retrieves the token decimal count
    function decimals() external pure returns (uint8) {
        return 18;
    }

    /// @notice Retrieves the token total supply
    function totalSupply() external view returns (uint256) {
        return IRiverV1(payable(RiverAddress.get())).balanceOfUnderlying(address(this));
    }

    /// @notice Retrieves the token balance of the specified user
    /// @param _owner Owner to check the balance
    function balanceOf(address _owner) external view returns (uint256 balance) {
        return _balanceOf(_owner);
    }

    /// @notice Retrieves the raw shares count of the user
    /// @param _owner Owner to check the shares balance
    function sharesOf(address _owner) external view returns (uint256 shares) {
        return BalanceOf.get(_owner);
    }

    /// @notice Retrieves the token allowance given from one address to another
    /// @param _owner Owner that gave the allowance
    /// @param _spender Spender that received the allowance
    function allowance(address _owner, address _spender) external view returns (uint256 remaining) {
        return ApprovalsPerOwner.get(_owner, _spender);
    }

    /// @notice Transfers tokens between the message sender and a recipient
    /// @param _to Recipient of the transfer
    /// @param _value Amount to transfer
    function transfer(address _to, uint256 _value)
        external
        isNotNull(_value)
        hasFunds(msg.sender, _value)
        returns (bool)
    {
        if (_to == address(0)) {
            revert UnauthorizedTransfer(msg.sender, address(0));
        }
        return _transfer(msg.sender, _to, _value);
    }

    /// @notice Transfers tokens between two accounts
    /// @dev If _from is not the message sender, then it is expected that _from has given at leave _value allowance to msg.sender
    /// @param _from Sender account
    /// @param _to Recipient of the transfer
    /// @param _value Amount to transfer
    function transferFrom(address _from, address _to, uint256 _value)
        external
        isNotNull(_value)
        hasFunds(_from, _value)
        returns (bool)
    {
        if (_to == address(0)) {
            revert UnauthorizedTransfer(_from, address(0));
        }
        _spendAllowance(_from, _value);
        return _transfer(_from, _to, _value);
    }

    /// @notice Approves another account to transfer tokens
    /// @param _spender Spender that receives the allowance
    /// @param _value Amount to allow
    function approve(address _spender, uint256 _value) external returns (bool success) {
        ApprovalsPerOwner.set(msg.sender, _spender, _value);
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    /// @notice Increase allowance to another account
    /// @param _spender Spender that receives the allowance
    /// @param _additionalValue Amount to add
    function increaseAllowance(address _spender, uint256 _additionalValue) external returns (bool success) {
        uint256 newApprovalValue = ApprovalsPerOwner.get(msg.sender, _spender) + _additionalValue;
        ApprovalsPerOwner.set(msg.sender, _spender, newApprovalValue);
        emit Approval(msg.sender, _spender, newApprovalValue);
        return true;
    }

    /// @notice Decrease allowance to another account
    /// @param _spender Spender that receives the allowance
    /// @param _subtractableValue Amount to add
    function decreaseAllowance(address _spender, uint256 _subtractableValue) external returns (bool success) {
        uint256 newApprovalValue = ApprovalsPerOwner.get(msg.sender, _spender) - _subtractableValue;
        ApprovalsPerOwner.set(msg.sender, _spender, newApprovalValue);
        emit Approval(msg.sender, _spender, newApprovalValue);
        return true;
    }

    /// @notice Mint tokens by providing River tokens
    /// @dev Minted tokens are sent to recipient but are minted from the message sender balance
    /// @dev It is expected that the message sender approves _value amount of River token to
    /// @dev this contract before calling
    /// @param _recipient Spender that receives the allowance
    /// @param _value Amount of river token to give to the mint
    function mint(address _recipient, uint256 _value) external nonReentrant {
        BalanceOf.set(_recipient, BalanceOf.get(_recipient) + _value);
        if (!IRiverV1(payable(RiverAddress.get())).transferFrom(msg.sender, address(this), _value)) {
            revert TokenTransferError();
        }
    }

    /// @notice Burn tokens and retrieve underlying River tokens
    /// @dev Burned tokens are sent to recipient but are minted from the message sender balance
    /// @dev No approval required from the message sender
    /// @param _recipient Spender that receives the allowance
    /// @param _shares Amount of shares to burn
    function burn(address _recipient, uint256 _shares) external nonReentrant {
        uint256 shares = BalanceOf.get(msg.sender);
        if (_shares > shares) {
            revert BalanceTooLow();
        }
        BalanceOf.set(msg.sender, shares - _shares);
        if (!IRiverV1(payable(RiverAddress.get())).transfer(_recipient, _shares)) {
            revert TokenTransferError();
        }
    }

    function _spendAllowance(address _from, uint256 _value) internal {
        uint256 currentAllowance = ApprovalsPerOwner.get(_from, msg.sender);
        if (currentAllowance < _value) {
            revert AllowanceTooLow(_from, msg.sender, currentAllowance, _value);
        }
        if (currentAllowance != type(uint256).max) {
            ApprovalsPerOwner.set(_from, msg.sender, currentAllowance - _value);
        }
    }

    function _balanceOf(address _owner) internal view returns (uint256 balance) {
        return IRiverV1(payable(RiverAddress.get())).underlyingBalanceFromShares(BalanceOf.get(_owner));
    }

    function _transfer(address _from, address _to, uint256 _value) internal returns (bool) {
        uint256 valueToShares = IRiverV1(payable(RiverAddress.get())).sharesFromUnderlyingBalance(_value);
        BalanceOf.set(_from, BalanceOf.get(_from) - valueToShares);
        BalanceOf.set(_to, BalanceOf.get(_to) + valueToShares);

        emit Transfer(_from, _to, _value);

        return true;
    }
}
