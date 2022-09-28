//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "./components/IConsensusLayerDepositManager.1.sol";
import "./components/IOracleManager.1.sol";
import "./components/ISharesManager.1.sol";
import "./components/IUserDepositManager.1.sol";

interface IRiverV1 is IConsensusLayerDepositManagerV1, IUserDepositManagerV1, ISharesManagerV1, IOracleManagerV1 {
    error ZeroMintedShares();
    error Denied(address _account);

    event PulledELFees(uint256 amount);
    event SetELFeeRecipient(address indexed elFeeRecipient);
    event SetCollector(address indexed collector);
    event SetAllowlist(address indexed allowlist);
    event SetGlobalFee(uint256 fee);
    event SetOperatorsRegistry(address indexed operatorRegistry);
    event RewardsEarnt(
        uint256 _oldTotalUnderylyingBalance,
        uint256 _oldTotalSupply,
        uint256 _newTotalUnderlyingBalance,
        uint256 _newTotalSupply
    );

    function initRiverV1(
        address _depositContractAddress,
        address _elFeeRecipientAddress,
        bytes32 _withdrawalCredentials,
        address _oracleAddress,
        address _systemAdministratorAddress,
        address _allowlistAddress,
        address _operatorRegistryAddress,
        address _collectorAddress,
        uint256 _globalFee
    ) external;

    function setGlobalFee(uint256 newFee) external;
    function getGlobalFee() external view returns (uint256);
    function setAllowlist(address _newAllowlist) external;
    function getAllowlist() external view returns (address);
    function setCollector(address _newCollector) external;
    function getCollector() external view returns (address);
    function setELFeeRecipient(address _newELFeeRecipient) external;
    function getELFeeRecipient() external view returns (address);
    function getOperatorsRegistry() external view returns (address);
    function sendELFees() external payable;
}
