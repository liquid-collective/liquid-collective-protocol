//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import "./interfaces/components/ISharesManager.1.sol";

contract RateProvider {
    ISharesManagerV1 private sharesManager;

    constructor(address river) {
        sharesManager = ISharesManagerV1(river);
    }

    // @dev Returns an 18 decimal fixed point number that is the exchange rate of the token to some other underlying
    //      token. The meaning of this rate depends on the context.
    function getRate() external view returns (uint256) {
        return sharesManager.underlyingBalanceFromShares(1e18);
    }
}