//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "./interfaces/IRiver.1.sol";
import "./interfaces/IOperatorRegistry.1.sol";
import "./interfaces/IDepositDataBuffer.sol";

import "./components/ConsensusLayerDepositManager.1.sol";

import "./libraries/LibAdministrable.sol";
import "./libraries/LibFundingDeltas.sol";

import "./state/river/CommittedBalance.sol";
import "./state/river/LastConsensusLayerReport.sol";
import "./state/shared/OperatorsRegistryAddress.sol";

/// @title River Deposit Manager (v1)
/// @author Alluvial Finance Inc.
/// @notice Holds the body of the attestation-gated consensus-layer deposit flow, extracted out of River
///         to keep River's deployed bytecode under EIP-170. River reaches it via DELEGATECALL, so the flow
///         runs in River's storage context: it reads/writes River's unstructured-storage slots through the
///         same state libraries, moves River's ETH to the deposit contract, and emits the same events
///         (qualified to their declaring interfaces so log topics are identical).
/// @dev    The deposit body itself is inherited verbatim from ConsensusLayerDepositManagerV1 — the single
///         source of truth shared with the component-level test harness. This contract only supplies the
///         concrete handler implementations that River previously provided (registry accounting, committed
///         balance, slashing-mode read, admin lookup).
/// @dev    The entry point is intentionally reachable only through River's delegatecall stub: a DIRECT call
///         to this standalone contract runs against its own zeroed storage — `KeeperAddress` reads as 0 so
///         the keeper check reverts, and even past that the `AttestationVerifierAddress` read is 0 and this
///         contract holds no ETH, so it cannot move funds.
contract RiverDepositManagerV1 is ConsensusLayerDepositManagerV1 {
    /// @notice Overridden handler to pass the system admin inside components
    /// @return The address of the admin
    function _getRiverAdmin() internal view override returns (address) {
        return LibAdministrable._getAdmin();
    }

    /// @notice Overridden handler to increment the funded ETH for the operators
    /// @param _deltas The per-operator funding deltas (sorted by operatorIndex)
    function _incrementFundedETH(IOperatorsRegistryV1.OperatorFundingDelta[] memory _deltas) internal override {
        IOperatorsRegistryV1(OperatorsRegistryAddress.get()).incrementFundedETH(_deltas);
    }

    /// @notice Overridden handler to update operator funded ETH accounting for attestation-based deposits.
    ///         Delegates bucketing/aggregation to LibFundingDeltas so the production path and the
    ///         attestation test harness share the same code, then forwards to _incrementFundedETH.
    /// @param deposits Initial deposits from the buffer
    /// @param topUps Top-ups from the buffer
    function _updateFundedETHFromBuffer(
        IDepositDataBuffer.Deposit[] memory deposits,
        IDepositDataBuffer.TopUp[] memory topUps
    ) internal override {
        if (deposits.length == 0 && topUps.length == 0) return;
        uint256 operatorCount = IOperatorsRegistryV1(OperatorsRegistryAddress.get()).getOperatorCount();
        _incrementFundedETH(LibFundingDeltas.build(deposits, topUps, operatorCount));
    }

    /// @notice Sets the committed balance, ready to be deposited to the consensus layer
    /// @param _newCommittedBalance The new committed balance value
    function _setCommittedBalance(uint256 _newCommittedBalance) internal override {
        emit IRiverV1.SetBalanceCommittedToDeposit(CommittedBalance.get(), _newCommittedBalance);
        CommittedBalance.set(_newCommittedBalance);
    }

    /// @notice Returns whether slashing containment mode is currently active
    function _getSlashingContainmentMode() internal view override returns (bool) {
        return LastConsensusLayerReport.get().slashingContainmentMode;
    }
}
