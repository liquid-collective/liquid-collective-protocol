//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "./components/deposit/DepositManager.1.sol";
import "./components/transfer/TransferManager.1.sol";

contract RiverV1 is DepositManagerV1, TransferManagerV1 {
    function _onDeposit() internal view override {
        this;
    }

    function riverInitializeV1(
        address _depositContractAddress,
        address _validatorCredentialsProviderAddress,
        bytes32 _withdrawalCredentials
    ) public {
        DepositManagerV1.depositManagerInitializeV1(
            _depositContractAddress,
            _validatorCredentialsProviderAddress,
            _withdrawalCredentials
        );
    }
}
