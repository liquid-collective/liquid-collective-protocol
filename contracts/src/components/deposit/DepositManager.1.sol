//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "./interfaces/IDepositContract.sol";
import "./state/DepositContractAddress.sol";

contract DepositManagerV1 {
    function depositManagerInitializeV1(address _depositContractAddress)
        internal
    {
        DepositContractAddress.Slot
            storage depositContractAddress = DepositContractAddress.get();
        depositContractAddress.value = IDepositContract(
            _depositContractAddress
        );
    }

    function depositToETH2() internal view {
        this;
    }
}
