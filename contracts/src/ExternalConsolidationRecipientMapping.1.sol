//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "./interfaces/IAllowlist.1.sol";
import "./interfaces/IExternalConsolidationRecipientMapping.1.sol";
import "./interfaces/IProtocolVersion.sol";
import "./interfaces/IRiver.1.sol";

import "./libraries/LibAllowlistMasks.sol";

import "./Initializable.sol";

import "./state/shared/RiverAddress.sol";
import "./state/externalConsolidationRecipientMapping/ExternalConsolidationRecipientMapping.sol";

/// @title External Consolidation Recipient Mapping (v1)
/// @author Alluvial Finance Inc.
/// @notice Maps caller's withdrawal credentials to recipient addresses for external consolidation minting
contract ExternalConsolidationRecipientMappingV1 is
    Initializable,
    IExternalConsolidationRecipientMappingV1,
    IProtocolVersion
{
    /// @inheritdoc IExternalConsolidationRecipientMappingV1
    function initExternalConsolidationRecipientMappingV1(address _riverAddress) external init(0) {
        RiverAddress.set(_riverAddress);
        emit SetRiver(_riverAddress);
    }

    /// @inheritdoc IExternalConsolidationRecipientMappingV1
    function setRecipient(address _recipient) external {
        IAllowlistV1 allowlist = IAllowlistV1(IRiverV1(payable(RiverAddress.get())).getAllowlist());
        allowlist.onlyAllowed(msg.sender, LibAllowlistMasks.CONSOLIDATE_MASK);
        if (allowlist.isDenied(_recipient)) {
            revert RecipientIsDenied();
        }

        ExternalConsolidationRecipientMapping.set(msg.sender, _recipient);
        emit SetRecipient(msg.sender, _recipient);
    }

    /// @inheritdoc IExternalConsolidationRecipientMappingV1
    function getRecipient(address _withdrawalCredentialAddress) external view returns (address) {
        return ExternalConsolidationRecipientMapping.get(_withdrawalCredentialAddress);
    }

    /// @inheritdoc IExternalConsolidationRecipientMappingV1
    function resolveRecipient(address _withdrawalCredentialAddress) external view returns (address) {
        address recipient = ExternalConsolidationRecipientMapping.get(_withdrawalCredentialAddress);
        return recipient == address(0) ? _withdrawalCredentialAddress : recipient;
    }

    function version() external pure returns (string memory) {
        return "1.3.0";
    }
}
