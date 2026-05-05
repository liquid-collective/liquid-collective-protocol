//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "./interfaces/IRiver.1.sol";
import "./interfaces/IAllowlist.1.sol";
import "./interfaces/IConsolidationCoverageFund.1.sol";
import "./interfaces/IProtocolVersion.sol";

import "./libraries/LibUint256.sol";
import "./libraries/LibAllowlistMasks.sol";

import "./Initializable.sol";

import "./state/shared/RiverAddress.sol";
import "./state/consolidationCoverage/BalanceForConsolidationCoverage.sol";

/// @title Consolidation Coverage Fund (v1)
/// @author Alluvial Finance Inc.
/// @notice This contract receives donations for the consolidation coverage fund and pulls the funds into river
/// @notice This contract acts as a temporary buffer for funds that should be pulled in case of a loss of money on the consensus layer due to consolidation-related events.
/// @notice There is no fee taken on these funds, they are entirely distributed to the LsETH holders, and no shares will get minted.
/// @notice The fund will be called on every report and if the coverage buffer is greater than 0, River will attempt to pull an amount of ETH equal to the coverage buffer.
/// @notice The value provided to this contract is computed off-chain and provided manually
/// @notice The entities allowed to donate are selected by the team. It will mainly be entities using the consolidation feature or insurance protocols.
contract ConsolidationCoverageFundV1 is Initializable, IConsolidationCoverageFundV1, IProtocolVersion {
    /// @inheritdoc IConsolidationCoverageFundV1
    function initConsolidationCoverageFundV1(address _riverAddress) external init(0) {
        RiverAddress.set(_riverAddress);
        emit SetRiver(_riverAddress);
    }

    /// @inheritdoc IConsolidationCoverageFundV1
    function pullCoverageFunds(uint256 _maxAmount) external {
        address river = RiverAddress.get();
        if (msg.sender != river) {
            revert LibErrors.Unauthorized(msg.sender);
        }
        uint256 amount = LibUint256.min(_maxAmount, BalanceForConsolidationCoverage.get());

        if (amount > 0) {
            BalanceForConsolidationCoverage.set(BalanceForConsolidationCoverage.get() - amount);
            IRiverV1(payable(river)).sendConsolidationCoverageFunds{value: amount}();
        }
    }

    /// @inheritdoc IConsolidationCoverageFundV1
    function donate() external payable {
        if (msg.value == 0) {
            revert EmptyDonation();
        }
        BalanceForConsolidationCoverage.set(BalanceForConsolidationCoverage.get() + msg.value);

        IAllowlistV1 allowlist = IAllowlistV1(IRiverV1(payable(RiverAddress.get())).getAllowlist());
        allowlist.onlyAllowed(msg.sender, LibAllowlistMasks.DONATE_CONSOLIDATION_MASK);

        emit Donate(msg.sender, msg.value);
    }

    /// @inheritdoc IConsolidationCoverageFundV1
    receive() external payable {
        revert InvalidCall();
    }

    /// @inheritdoc IConsolidationCoverageFundV1
    fallback() external payable {
        revert InvalidCall();
    }

    function version() external pure returns (string memory) {
        return "1.0.0";
    }
}
