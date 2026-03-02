//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

interface IConsensusLayerDepositManagerV1 {
    /// @notice A single validator deposit with keeper-provided key, signature, and amount
    struct ValidatorDeposit {
        bytes pubkey;
        bytes signature;
        uint256 depositAmount;
        uint256 operatorIndex;
    }

    event SetDepositContractAddress(address indexed depositContract);
    event SetWithdrawalCredentials(bytes32 withdrawalCredentials);
    event SetDepositedBalance(uint256 oldDepositedBalance, uint256 newDepositedBalance);

    error NotEnoughFunds();
    error InconsistentPublicKeys();
    error InconsistentSignatures();
    error InvalidWithdrawalCredentials();
    error ErrorOnDeposit();
    error InvalidDepositRoot();
    error OnlyKeeper();
    error DepositAmountTooLow(uint256 amount, uint256 minimum);
    error DepositAmountTooHigh(uint256 amount, uint256 maximum);
    error DepositAmountNotGweiAligned(uint256 amount);
    error DepositsExceedCommittedBalance(uint256 totalAmount, uint256 committedBalance);
    error EmptyDepositsArray();

    function getBalanceToDeposit() external view returns (uint256);
    function getCommittedBalance() external view returns (uint256);
    function getWithdrawalCredentials() external view returns (bytes32);
    function getDepositedBalance() external view returns (uint256);
    function getActivatedDepositedBalance() external view returns (uint256);
    function getKeeper() external view returns (address);

    /// @notice Deposits ETH to the Consensus Layer with keeper-provided keys and signatures
    /// @param _deposits Array of validator deposits with pubkey, signature, amount, and operator index
    /// @param _depositRoot Expected deposit contract root for front-running protection
    function depositToConsensusLayer(
        ValidatorDeposit[] calldata _deposits,
        bytes32 _depositRoot
    ) external;
}
