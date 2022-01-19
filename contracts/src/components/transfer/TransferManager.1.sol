//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

abstract contract TransferManagerV1 {
    error InvalidCall();

    event UserDeposit(
        address indexed user,
        address indexed referral,
        uint256 amount
    );

    function _onDeposit() internal virtual;

    function _deposit(address referral) internal {
        _onDeposit();

        emit UserDeposit(msg.sender, referral, msg.value);
    }

    function deposit(address referral) external payable {
        _deposit(referral);
    }

    receive() external payable {
        _deposit(address(0));
    }

    fallback() external payable {
        revert InvalidCall();
    }
}
