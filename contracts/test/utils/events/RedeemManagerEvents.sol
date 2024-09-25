pragma solidity 0.8.20;

/// @title Redeem Manager Events
/// @author Alluvial Finance Inc.
/// @notice Event definitions as emitted by the Redeem Manager for testing purposes
contract RedeemManagerEvents {
    event ReportedWithdrawal(uint256 height, uint256 amount, uint256 ethAmount, uint32 id);
}
