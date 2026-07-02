//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../interfaces/IRiver.1.sol";
import "../interfaces/IOperatorRegistry.1.sol";
import "../interfaces/IDepositDataBuffer.sol";

import "./LibAdministrable.sol";
import "./LibFundingDeltas.sol";

import "../state/river/CommittedBalance.sol";
import "../state/river/LastConsensusLayerReport.sol";
import "../state/shared/OperatorsRegistryAddress.sol";

/// @title Lib River Handlers
/// @author Alluvial Finance Inc.
/// @notice Single source of truth for the ConsensusLayerDepositManagerV1 abstract handler bodies that both
///         RiverV1 and RiverDepositManagerV1 must implement. RiverDepositManagerV1 runs in River's storage
///         context via delegatecall, so the two concrete contracts have to resolve these handlers identically;
///         centralising the bodies here means the deposit path and River's own paths cannot silently diverge.
/// @dev    All functions are internal, so they inline into each caller — this deduplicates the source without
///         adding an external call or changing deployed bytecode versus the previous inline handler bodies.
library LibRiverHandlers {
    /// @notice Returns the system admin address
    /// @return The address of the admin
    function getAdmin() internal view returns (address) {
        return LibAdministrable._getAdmin();
    }

    /// @notice Increments the funded ETH for the operators
    /// @param _deltas The per-operator funding deltas (sorted by operatorIndex)
    function incrementFundedETH(IOperatorsRegistryV1.OperatorFundingDelta[] memory _deltas) internal {
        IOperatorsRegistryV1(OperatorsRegistryAddress.get()).incrementFundedETH(_deltas);
    }

    /// @notice Updates operator funded ETH accounting for attestation-based deposits.
    ///         Delegates bucketing/aggregation to LibFundingDeltas so the production path and the
    ///         attestation test harness share the same code, then forwards to incrementFundedETH.
    /// @param deposits Initial deposits from the buffer
    /// @param topUps Top-ups from the buffer
    function updateFundedETHFromBuffer(
        IDepositDataBuffer.Deposit[] memory deposits,
        IDepositDataBuffer.TopUp[] memory topUps
    ) internal {
        if (deposits.length == 0 && topUps.length == 0) return;
        uint256 operatorCount = IOperatorsRegistryV1(OperatorsRegistryAddress.get()).getOperatorCount();
        incrementFundedETH(LibFundingDeltas.build(deposits, topUps, operatorCount));
    }

    /// @notice Sets the committed balance, ready to be deposited to the consensus layer
    /// @param _newCommittedBalance The new committed balance value
    function setCommittedBalance(uint256 _newCommittedBalance) internal {
        emit IRiverV1.SetBalanceCommittedToDeposit(CommittedBalance.get(), _newCommittedBalance);
        CommittedBalance.set(_newCommittedBalance);
    }

    /// @notice Returns whether slashing containment mode is currently active
    function getSlashingContainmentMode() internal view returns (bool) {
        return LastConsensusLayerReport.get().slashingContainmentMode;
    }
}
