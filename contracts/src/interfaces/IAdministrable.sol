//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

interface IAdministrable {
    function proposeAdmin(address _newOwner) external;
    function acceptAdmin() external;
    function getAdministrator() external view returns (address);
    function getPendingAdministrator() external view returns (address);
}
