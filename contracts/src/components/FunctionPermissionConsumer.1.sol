pragma solidity 0.8.10;

import "../FunctionPermissions.1.sol";
import "../state/shared/FunctionPermissionsContractAddress.sol";

abstract contract FunctionPermissionConsumer {
    FunctionPermissionsV1 internal functionPermissions;
    function setFunctionPermissionsContract() internal {
        functionPermissions = FunctionPermissionsV1(FunctionPermissionsContractAddress.get());
    }
}
