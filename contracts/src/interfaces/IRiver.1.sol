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
    event RewardsEarned(
        address indexed _collector,
        uint256 _oldTotalUnderlyingBalance,
        uint256 _oldTotalSupply,
        uint256 _newTotalUnderlyingBalance,
        uint256 _newTotalSupply
    );

    /// @notice Initializes the River system
    /// @param _depositContractAddress Address to make Consensus Layer deposits
    /// @param _elFeeRecipientAddress Address that receives the execution layer fees
    /// @param _withdrawalCredentials Credentials to use for every validator deposit
    /// @param _systemAdministratorAddress Administrator address
    /// @param _allowlistAddress Address of the allowlist contract
    /// @param _operatorRegistryAddress Address of the operator registry
    /// @param _collectorAddress Address receiving the fee minus the operator share
    /// @param _globalFee Amount retained when the eth balance increases, splitted between the collector and the operators
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

    /// @notice Get the current global fee
    /// @return The global fee
    function getGlobalFee() external view returns (uint256);

    /// @notice Retrieve the allowlist address
    /// @return The allowlist address
    function getAllowlist() external view returns (address);

    /// @notice Retrieve the collector address
    /// @return The collector address
    function getCollector() external view returns (address);

    /// @notice Retrieve the execution layer fee recipient
    /// @return The execution layer fee recipient address
    function getELFeeRecipient() external view returns (address);

    /// @notice Retrieve the operators registry
    /// @return The operators registry address
    function getOperatorsRegistry() external view returns (address);

    /// @notice Changes the global fee parameter
    /// @param newFee New fee value
    function setGlobalFee(uint256 newFee) external;

    /// @notice Changes the allowlist address
    /// @param _newAllowlist New address for the allowlist
    function setAllowlist(address _newAllowlist) external;

    /// @notice Changes the collector address
    /// @param _newCollector New address for the collector
    function setCollector(address _newCollector) external;

    /// @notice Changes the execution layer fee recipient
    /// @param _newELFeeRecipient New address for the recipient
    function setELFeeRecipient(address _newELFeeRecipient) external;

    /// @notice Input for execution layer fee earnings
    function sendELFees() external payable;
}
