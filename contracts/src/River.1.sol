//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "./components/DepositManager.1.sol";
import "./components/TransferManager.1.sol";
import "./components/SharesManager.1.sol";
import "./components/OracleManager.1.sol";
import "./components/OperatorsManager.1.sol";
import "./Initializable.sol";
import "./libraries/LibOwnable.sol";

import "./state/shared/AdministratorAddress.sol";
import "./state/river/AllowlistAddress.sol";
import "./state/river/TreasuryAddress.sol";
import "./state/river/OperatorRewardsShare.sol";
import "./state/river/GlobalFee.sol";

/// @title River (v1)
/// @author Kiln
/// @notice This contract merges all the manager contracts and implements all the virtual methods stitching all components together
contract RiverV1 is
    DepositManagerV1,
    TransferManagerV1,
    SharesManagerV1,
    OracleManagerV1,
    OperatorsManagerV1,
    Initializable
{
    uint256 public constant BASE = 100000;
    uint256 internal constant DEPOSIT_MASK = 0x1;
    uint256 internal constant TRANSFER_MASK = 0;

    /// @notice Prevents unauthorized calls
    modifier onlyAdmin() override(OperatorsManagerV1, OracleManagerV1) {
        if (msg.sender != LibOwnable._getAdmin()) {
            revert Errors.Unauthorized(msg.sender);
        }
        _;
    }

    /// @notice Initializes the River system
    /// @param _depositContractAddress Address to make Consensus Layer deposits
    /// @param _withdrawalCredentials Credentials to use for every validator deposit
    /// @param _systemAdministratorAddress Administrator address
    /// @param _allowlistAddress Address of the allowlist contract
    /// @param _treasuryAddress Address receiving the fee minus the operator share
    /// @param _globalFee Amount retained when the eth balance increases, splitted between the treasury and the operators
    /// @param _operatorRewardsShare Share of the global fee used to reward node operators
    function initRiverV1(
        address _depositContractAddress,
        bytes32 _withdrawalCredentials,
        address _oracleAddress,
        address _systemAdministratorAddress,
        address _allowlistAddress,
        address _treasuryAddress,
        uint256 _globalFee,
        uint256 _operatorRewardsShare
    ) external init(0) {
        if (_systemAdministratorAddress == address(0)) {
            // only check on initialization
            revert Errors.InvalidZeroAddress();
        }
        LibOwnable._setAdmin(_systemAdministratorAddress);
        TreasuryAddress.set(_treasuryAddress);
        GlobalFee.set(_globalFee);
        OperatorRewardsShare.set(_operatorRewardsShare);

        DepositManagerV1.initDepositManagerV1(_depositContractAddress, _withdrawalCredentials);
        OracleManagerV1.initOracleManagerV1(_oracleAddress);
        AllowlistAddress.set(_allowlistAddress);
    }

    /// @notice Changes the global fee parameter
    /// @param newFee New fee value
    function setGlobalFee(uint256 newFee) external onlyAdmin {
        if (newFee > BASE) {
            revert Errors.InvalidArgument();
        }

        GlobalFee.set(newFee);
    }

    /// @notice Changes the operator rewards share.
    /// @param newOperatorRewardsShare New share value
    function setOperatorRewardsShare(uint256 newOperatorRewardsShare) external onlyAdmin {
        if (newOperatorRewardsShare > BASE) {
            revert Errors.InvalidArgument();
        }

        OperatorRewardsShare.set(newOperatorRewardsShare);
    }

    /// @notice Changes the allowlist address
    /// @param _newAllowlist New address for the allowlist
    function setAllowlist(address _newAllowlist) external onlyAdmin {
        AllowlistAddress.set(_newAllowlist);
    }

    /// @notice Retrieve the allowlist address
    function getAllowlist() external view returns (address) {
        return address(AllowlistAddress.get());
    }

    /// @notice Changes the treasury address
    /// @param _newTreasury New address for the treasury
    function setTreasury(address _newTreasury) external onlyAdmin {
        TreasuryAddress.set(_newTreasury);
    }

    /// @notice Retrieve the treasury address
    function getTreasury() external view returns (address) {
        return TreasuryAddress.get();
    }

    /// @notice Changes the admin
    /// @param _newAdmin New address for the admin
    function setAdministrator(address _newAdmin) external onlyAdmin {
        LibOwnable._setAdmin(_newAdmin);
    }

    /// @notice Retrieve system administrator address
    function getAdministrator() external view returns (address) {
        return LibOwnable._getAdmin();
    }

    /// @notice Handler called whenever a token transfer is triggered
    /// @param _from Token sender
    /// @param _to Token receiver
    function _onTransfer(address _from, address _to) internal view override {
        (AllowlistAddress.get()).onlyAllowed(_from, TRANSFER_MASK); // this call reverts if unauthorized or denied
        (AllowlistAddress.get()).onlyAllowed(_to, TRANSFER_MASK); // this call reverts if unauthorized or denied
    }

    /// @notice Handler called whenever a user deposits ETH to the system. Mints the adequate amount of shares.
    /// @param _depositor User address that made the deposit
    /// @param _amount Amount of ETH deposited
    function _onDeposit(
        address _depositor,
        address _recipient,
        uint256 _amount
    ) internal override {
        SharesManagerV1._mintShares(_depositor, _amount);
        if (_depositor == _recipient) {
            (AllowlistAddress.get()).onlyAllowed(_depositor, DEPOSIT_MASK); // this call reverts if unauthorized or denied
        } else {
            (AllowlistAddress.get()).onlyAllowed(_depositor, DEPOSIT_MASK + TRANSFER_MASK); // this call reverts if unauthorized or denied
            (AllowlistAddress.get()).onlyAllowed(_recipient, TRANSFER_MASK);
            _transfer(_depositor, _recipient, _amount);
        }
    }

    /// @notice Handler called whenever a deposit to the consensus layer is made. Should retrieve _requestedAmount or lower keys
    /// @param _requestedAmount Amount of keys required. Contract is expected to send _requestedAmount or lower.
    function _getNextValidators(uint256 _requestedAmount)
        internal
        override
        returns (bytes[] memory publicKeys, bytes[] memory signatures)
    {
        return OperatorsManagerV1._getNextValidatorsFromActiveOperators(_requestedAmount);
    }

    /// @notice Internal utility managing reward distribution amongst node operators
    /// @param _reward Amount of shares to split between operators
    function _rewardOperators(uint256 _reward) internal returns (uint256) {
        Operators.Operator[] memory operators = Operators.getAllActive();
        uint256[] memory validatorCounts = new uint256[](operators.length);

        uint256 totalActiveValidators = 0;
        for (uint256 idx = 0; idx < operators.length; ++idx) {
            uint256 operatorActiveValidatorCount = operators[idx].funded - operators[idx].stopped;
            totalActiveValidators += operatorActiveValidatorCount;
            validatorCounts[idx] = operatorActiveValidatorCount;
        }

        if (totalActiveValidators > 0) {
            uint256 rewardsPerActiveValidator = _reward / totalActiveValidators;

            for (uint256 idx = 0; idx < validatorCounts.length; ++idx) {
                _mintRawShares(operators[idx].feeRecipient, validatorCounts[idx] * rewardsPerActiveValidator);
            }
        } else {
            _reward = 0;
        }

        return _reward;
    }

    /// @notice Handler called whenever a donation of ETH has been made to the system. It calls the same logic as when revenues are earned.
    /// @param _amount Additional eth donated
    function _onDonation(uint256 _amount) internal override {
        _onEarnings(_amount);
    }

    /// @notice Handler called whenever the balance of ETH handled by the system increases. Splits funds between operators and treasury.
    /// @param _amount Additional eth received
    function _onEarnings(uint256 _amount) internal override {
        uint256 globalFee = GlobalFee.get();
        uint256 sharesToMint = (_amount * _totalSupply() * globalFee) /
            ((_assetBalance() * BASE) - (_amount * globalFee));

        uint256 operatorRewards = (sharesToMint * OperatorRewardsShare.get()) / BASE;

        uint256 mintedRewards = _rewardOperators(operatorRewards);

        _mintRawShares(TreasuryAddress.get(), sharesToMint - mintedRewards);
    }

    /// @notice Handler called whenever the total balance of ETH is requested
    function _assetBalance() internal view override returns (uint256) {
        uint256 beaconValidatorCount = BeaconValidatorCount.get();
        uint256 depositedValidatorCount = DepositedValidatorCount.get();
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
}
