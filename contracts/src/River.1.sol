//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "./components/DepositManager.1.sol";
import "./components/TransferManager.1.sol";
import "./components/SharesManager.1.sol";
import "./components/OracleManager.1.sol";
import "./components/OperatorsManager.1.sol";
import "./components/WhitelistManager.1.sol";

import "./state/AdministratorAddress.sol";

contract RiverV1 is
    DepositManagerV1,
    TransferManagerV1,
    SharesManagerV1,
    OracleManagerV1,
    OperatorsManagerV1,
    WhitelistManagerV1
{
    function _onDeposit() internal view override {
        this;
    }

    function _isAllowed(address _account)
        internal
        view
        override
        returns (bool)
    {
        return WhitelistManagerV1._isWhitelisted(_account);
    }

    function _onValidatorKeyRequest(uint256)
        internal
        override
        returns (bytes memory publicKeys, bytes memory signatures)
    {
        return ("", "");
    }

    function _onEarnings(uint256) internal override {
        this;
    }

    function _assetBalance() internal view override returns (uint256) {
        uint256 beaconValidatorCount = BeaconValidatorCount.get();
        uint256 depositedValidatorCount = BeaconValidatorCount.get();
        if (beaconValidatorCount < depositedValidatorCount) {
            return
                BeaconValidatorBalanceSum.get() +
                address(this).balance +
                (depositedValidatorCount - beaconValidatorCount) *
                DepositManagerV1.DEPOSIT_SIZE;
        } else {
            return BeaconValidatorBalanceSum.get() + address(this).balance;
        }
    }

    function riverInitializeV1(
        address _depositContractAddress,
        bytes32 _withdrawalCredentials,
        address _oracleAddress,
        address _systemAdministratorAddress
    ) public {
        AdministratorAddress.set(_systemAdministratorAddress);
        DepositManagerV1.depositManagerInitializeV1(
            _depositContractAddress,
            _withdrawalCredentials
        );
        OracleManagerV1.oracleManagerInitializeV1(_oracleAddress);
    }
}
