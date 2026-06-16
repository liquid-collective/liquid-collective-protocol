//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "./Initializable.sol";

import "./interfaces/IAdministrable.sol";
import "./interfaces/IAllowlist.1.sol";
import "./interfaces/IAttestationVerifier.1.sol";
import "./interfaces/IAttestationVerifierPectraMigration.1.sol";
import "./interfaces/IConsolidationManager.1.sol";
import "./interfaces/IExternalConsolidationRecipientMapping.1.sol";
import "./interfaces/IProtocolVersion.sol";
import "./interfaces/IRiver.1.sol";
import "./interfaces/IWithdraw.1.sol";

import "./libraries/LibAllowlistMasks.sol";
import "./libraries/LibErrors.sol";

import "./state/river/ConsolidatorAddress.sol";
import "./state/river/ExternalConsolidationRecipientMappingAddress.sol";
import "./state/shared/RiverAddress.sol";

/// @title Consolidation Manager (v1)
/// @author Alluvial Finance Inc.
/// @notice Coordinates new Pectra consolidation flows outside River's bytecode.
contract ConsolidationManagerV1 is Initializable, IConsolidationManagerV1, IProtocolVersion {
    modifier onlyConsolidator() {
        if (msg.sender != ConsolidatorAddress.get()) {
            revert OnlyConsolidator();
        }
        _;
    }

    modifier onlyRiverAdmin() {
        if (msg.sender != IAdministrable(RiverAddress.get()).getAdmin()) {
            revert LibErrors.Unauthorized(msg.sender);
        }
        _;
    }

    /// @inheritdoc IConsolidationManagerV1
    function initConsolidationManagerV1(
        address _riverAddress,
        address _externalConsolidationRecipientMapping,
        address _consolidator
    ) external init(0) {
        RiverAddress.set(_riverAddress);
        emit SetRiver(_riverAddress);

        ExternalConsolidationRecipientMappingAddress.set(_externalConsolidationRecipientMapping);
        emit SetExternalConsolidationRecipientMapping(_externalConsolidationRecipientMapping);

        _setConsolidator(_consolidator);
    }

    /// @inheritdoc IConsolidationManagerV1
    function getConsolidator() external view returns (address) {
        return ConsolidatorAddress.get();
    }

    /// @inheritdoc IConsolidationManagerV1
    function getExternalConsolidationRecipientMapping() external view returns (address) {
        return ExternalConsolidationRecipientMappingAddress.get();
    }

    /// @inheritdoc IConsolidationManagerV1
    function setConsolidator(address _newConsolidator) external onlyRiverAdmin {
        _setConsolidator(_newConsolidator);
    }

    /// @inheritdoc IConsolidationManagerV1
    function mintLsETHForConsolidation(IAttestationVerifierV1.ConsolidationObject calldata consolidation)
        external
        onlyConsolidator
    {
        IRiverV1 river = IRiverV1(payable(RiverAddress.get()));
        IAllowlistV1 allowlist = IAllowlistV1(river.getAllowlist());
        allowlist.onlyAllowed(consolidation.withdrawalAddress, LibAllowlistMasks.CONSOLIDATE_MASK);

        address recipient = IExternalConsolidationRecipientMappingV1(ExternalConsolidationRecipientMappingAddress.get())
            .getRecipient(consolidation.withdrawalAddress);

        if (recipient == address(0)) {
            recipient = consolidation.withdrawalAddress;
        } else if (allowlist.isDenied(recipient)) {
            revert IRiverV1.Denied(recipient);
        }

        IAttestationVerifierV1(river.getAttestationVerifier()).validateConsolidation(consolidation);

        uint256 sharesMinted = river.mintLsETHForConsolidation(recipient, consolidation.totalAmount);
        emit LsETHMintedForConsolidation(recipient, consolidation.totalAmount, sharesMinted);
    }

    /// @inheritdoc IConsolidationManagerV1
    function selfConsolidation(bytes[] calldata pubkeys, uint256 maxFeePerConsolidation)
        external
        payable
        onlyConsolidator
    {
        IRiverV1 river = IRiverV1(payable(RiverAddress.get()));
        IWithdrawV1.ConsolidationRequest[] memory requests =
            IAttestationVerifierPectraMigrationV1(river.getAttestationVerifier()).validateSelfConsolidation(pubkeys);
        _requestConsolidation(river, requests, maxFeePerConsolidation);
    }

    /// @inheritdoc IConsolidationManagerV1
    function consolidate(IWithdrawV1.ConsolidationRequest[] calldata requests, uint256 maxFeePerConsolidation)
        external
        payable
        onlyConsolidator
    {
        _requestConsolidation(IRiverV1(payable(RiverAddress.get())), requests, maxFeePerConsolidation);
    }

    function _requestConsolidation(
        IRiverV1 river,
        IWithdrawV1.ConsolidationRequest[] memory requests,
        uint256 maxFeePerConsolidation
    ) internal {
        address excessFeeRecipient = msg.sender;
        river.requestConsolidation{value: msg.value}(requests, maxFeePerConsolidation, excessFeeRecipient);
        emit PectraConsolidationRequested(requests, maxFeePerConsolidation, excessFeeRecipient, msg.value);
    }

    function _setConsolidator(address _newConsolidator) internal {
        ConsolidatorAddress.set(_newConsolidator);
        emit SetConsolidator(_newConsolidator);
    }

    function version() external pure returns (string memory) {
        return "1.3.0";
    }
}
