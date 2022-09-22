//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

interface IAdministrable {
    event ProposedAdmin(address newPendingAdmin);
    event AcceptedAdmin(address newAdmin);

    function proposeAdmin(address _newAdmin) external;
    function acceptAdmin() external;
    function getAdmin() external view returns (address);
    function getPendingAdmin() external view returns (address);
}
