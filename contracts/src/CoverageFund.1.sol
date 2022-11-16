//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "./interfaces/IRiver.1.sol";
import "./interfaces/IAllowlist.1.sol";
import "./interfaces/ICoverageFund.1.sol";

import "./libraries/LibUint256.sol";
import "./libraries/LibAllowlistMasks.sol";

import "./Initializable.sol";

import "./state/shared/RiverAddress.sol";
import "./state/slashingCoverage/BalanceForCoverage.sol";

/// @title Coverage Fund (v1)
/// @author Kiln
/// @notice This contract receive donations for the slashing coverage fund and pull the funds into river
contract CoverageFundV1 is Initializable, ICoverageFundV1 {
    /// @inheritdoc ICoverageFundV1
    function initCoverageFundV1(address _riverAddress) external init(0) {
        RiverAddress.set(_riverAddress);
        emit SetRiver(_riverAddress);
    }

    /// @inheritdoc ICoverageFundV1
    function pullCoverageFunds(uint256 _maxAmount) external {
        address river = RiverAddress.get();
        if (msg.sender != river) {
            revert LibErrors.Unauthorized(msg.sender);
        }
        uint256 amount = LibUint256.min(_maxAmount, BalanceForCoverage.get());

        if (amount > 0) {
            BalanceForCoverage.set(BalanceForCoverage.get() - amount);
            IRiverV1(payable(river)).sendCoverageFunds{value: amount}();
        }
    }

    /// @inheritdoc ICoverageFundV1
    function donate() external payable {
        if (msg.value == 0) {
            revert EmptyDonation();
        }
        BalanceForCoverage.set(BalanceForCoverage.get() + msg.value);

        IAllowlistV1 allowlist = IAllowlistV1(IRiverV1(payable(RiverAddress.get())).getAllowlist());
        allowlist.onlyAllowed(msg.sender, LibAllowlistMasks.DONATE_MASK);

        emit Donate(msg.sender, msg.value);
    }

    /// @inheritdoc ICoverageFundV1
    receive() external payable {
        revert InvalidCall();
    }

    /// @inheritdoc ICoverageFundV1
    fallback() external payable {
        revert InvalidCall();
    }
}
