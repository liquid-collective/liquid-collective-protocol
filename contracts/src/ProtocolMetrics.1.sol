//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import {ISharesManagerV1} from "./interfaces/components/ISharesManager.1.sol";
import {Initializable} from "./Initializable.sol";
import {RiverAddress} from "./state/shared/RiverAddress.sol";

/// @dev REMOVED INITIALIZERS. The deployed proxy is at `Version == 1`, so the `init(N)` guard on
///      this can never pass again; it was deleted to reclaim bytecode. Recorded here so the version
///      counter's history stays readable, and so nobody reuses this slot:
///        init(0)  initProtocolMetricsV1(address)        -- river
///      Body preserved verbatim in contracts/test/utils/LegacyInit.sol
///      (ProtocolMetricsV1WithLegacyInit). NOTE: `RiverAddress` has no other setter, so this
///      implementation can no longer bootstrap a fresh proxy (e.g. a rate provider on a new chain).
contract ProtocolMetricsV1 is Initializable {
    // @dev Returns an 18 decimal fixed point number that is the exchange rate of the token to some other underlying
    //      token. The meaning of this rate depends on the context.
    function getRate() external view returns (uint256) {
        return ISharesManagerV1(RiverAddress.get()).underlyingBalanceFromShares(1e18);
    }
}
