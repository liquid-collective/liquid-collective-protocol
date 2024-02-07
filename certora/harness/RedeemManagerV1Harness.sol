// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import { RedeemManagerV1, WithdrawalStack, RedeemQueue } from "contracts/src/RedeemManager.1.sol";

contract RedeemManagerV1Harness is RedeemManagerV1 {

    function isMatchByID(uint32 requestID, uint32 eventID) external view returns (bool) {
        if (eventID >= WithdrawalStack.get().length) return false;
        if (requestID >= RedeemQueue.get().length) return false;
        return _isMatch(RedeemQueue.get()[requestID], WithdrawalStack.get()[eventID]);
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
        if (id >= RedeemQueue.get().length) return 0;
        RedeemQueue.RedeemRequest storage _request = RedeemQueue.get()[id];
        return _request.height;
    }

    function getRedeemRequestAmount(uint32 id) external view returns (uint256) {    
        if (id >= RedeemQueue.get().length) return 0;
        RedeemQueue.RedeemRequest storage _request = RedeemQueue.get()[id];
        return _request.amount;
    }
}