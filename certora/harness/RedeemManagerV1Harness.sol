// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import { RedeemManagerV1, WithdrawalStack } from "contracts/src/RedeemManager.1.sol";
import "contracts/src/state/redeemManager/RedeemQueue.2.sol";

contract RedeemManagerV1Harness is RedeemManagerV1 {

    function isMatchByID(uint32 requestID, uint32 eventID) external view returns (bool) {
        if (eventID >= WithdrawalStack.get().length) return false;
        if (requestID >= RedeemQueueV2.get().length) return false;
        return _isMatch(RedeemQueueV2.get()[requestID], WithdrawalStack.get()[eventID]);
    }

    function getWithdrawalEventHeight(uint32 id) external view returns (uint256) {
        if (id >= WithdrawalStack.get().length) return 0;
        WithdrawalStack.WithdrawalEvent storage _event = WithdrawalStack.get()[id];
        return _event.height;
    }

    function getWithdrawalEventAmount(uint32 id) external view returns (uint256) {    
        if (id >= WithdrawalStack.get().length) return 0;
        WithdrawalStack.WithdrawalEvent storage _event = WithdrawalStack.get()[id];
        return _event.amount;
    }

    function getRedeemRequestHeight(uint32 id) external view returns (uint256) {    
        if (id >= RedeemQueueV2.get().length) return 0;
        RedeemQueueV2.RedeemRequest storage _request = RedeemQueueV2.get()[id];
        return _request.height;
    }

    function getRedeemRequestAmount(uint32 id) external view returns (uint256) {    
        if (id >= RedeemQueueV2.get().length) return 0;
        RedeemQueueV2.RedeemRequest storage _request = RedeemQueueV2.get()[id];
        return _request.amount;
    }

    function get_CLAIM_FULLY_CLAIMED() external view returns (uint8)
    {
        return CLAIM_FULLY_CLAIMED;
    }

    function get_CLAIM_PARTIALLY_CLAIMED() external view returns (uint8)
    {
        return CLAIM_PARTIALLY_CLAIMED;
    }

    function get_CLAIM_SKIPPED() external view returns (uint8)
    {
        return CLAIM_SKIPPED;
    }
}