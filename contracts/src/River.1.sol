//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "./components/DepositManager.1.sol";
import "./components/TransferManager.1.sol";
import "./components/SharesManager.1.sol";
import "./components/OracleManager.1.sol";
import "./components/OperatorsManager.1.sol";
import "./components/AllowlistManager.1.sol";
import "./Initializable.sol";
import "./libraries/LibOwnable.sol";

import "./state/shared/AdministratorAddress.sol";
import "./state/river/TreasuryAddress.sol";
import "./state/river/OperatorRewardsShare.sol";
import "./state/river/GlobalFee.sol";

/// @title River (v1)
/// @author SkillZ
/// @notice This contract merges all the manager contracts and implements all the virtual methods stitching all components together
contract RiverV1 is
    DepositManagerV1,
    TransferManagerV1,
    SharesManagerV1,
    OracleManagerV1,
    OperatorsManagerV1,
    AllowlistManagerV1,
    Initializable
{
    uint256 public constant BASE = 100000;

    /// @notice Prevents unauthorized calls
    modifier onlyAdmin() override(OperatorsManagerV1, OracleManagerV1, AllowlistManagerV1) {
        if (msg.sender != LibOwnable._getAdmin()) {
            revert Errors.Unauthorized(msg.sender);
        }
        _;
    }

    /// @notice Initializes the River system
    /// @param _depositContractAddress Address to make Consensus Layer deposits
    /// @param _withdrawalCredentials Credentials to use for every validator deposit
    /// @param _systemAdministratorAddress Administrator address
    /// @param _allowerAddress Address able to manage the allowlist
    /// @param _treasuryAddress Address receiving the fee minus the operator share
    /// @param _globalFee Amount retained when the eth balance increases, splitted between the treasury and the operators
    /// @param _operatorRewardsShare Share of the global fee used to reward node operators
    function initRiverV1(
        address _depositContractAddress,
        bytes32 _withdrawalCredentials,
        address _systemAdministratorAddress,
        address _allowerAddress,
        address _treasuryAddress,
        uint256 _globalFee,
        uint256 _operatorRewardsShare
    ) external init(0) {
        LibOwnable._setAdmin(_systemAdministratorAddress);
        TreasuryAddress.set(_treasuryAddress);
        GlobalFee.set(_globalFee);
        OperatorRewardsShare.set(_operatorRewardsShare);

        DepositManagerV1.initDepositManagerV1(_depositContractAddress, _withdrawalCredentials);
        AllowlistManagerV1.initAllowlistManagerV1(_allowerAddress);
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

    /// @notice Retrieve system administrator address
    function getAdministrator() external view returns (address) {
        return LibOwnable._getAdmin();
    }

    uint256 internal constant DEPOSIT_MASK = 0x1;
    uint256 internal constant TRANSFER_MASK = 0x1 << 1;

    /// @notice Handler called whenever a user deposits ETH to the system. Mints the adequate amount of shares.
    /// @param _depositor User address that made the deposit
    /// @param _amount Amount of ETH deposited
    function _onDeposit(address _depositor, uint256 _amount) internal override {
        if (AllowlistManagerV1._isAllowed(_depositor, DEPOSIT_MASK) == false) {
            revert Errors.Unauthorized(_depositor);
        }
        SharesManagerV1._mintShares(_depositor, _amount);
    }

    /// @notice Handler called whenever an allowlist check is made for an address. Asks the Allowlist Manager component.
    /// @param _account Address to verify
    function _isAccountAllowed(address _account) internal view override returns (bool) {
        return AllowlistManagerV1._isAllowed(_account, TRANSFER_MASK);
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

    /// @notice Handler called whenever the balance of ETH handled by the system increases. Splits funds between operators and treasury.
    /// @param _amount Additional eth received
    function _onEarnings(uint256 _amount) internal override {
        uint256 globalFee = GlobalFee.get();
        uint256 sharesToMint = (_amount * _totalShares() * globalFee) /
            ((_assetBalance() * BASE) - (_amount * globalFee));

        uint256 operatorRewards = (sharesToMint * OperatorRewardsShare.get()) / BASE;

        Operators.Operator[] memory operators = Operators.getAllActive();
        uint256[] memory validatorCounts = new uint256[](operators.length);

        uint256 totalActiveValidators = 0;
        for (uint256 idx = 0; idx < operators.length; ++idx) {
            uint256 operatorActiveValidatorCount = operators[idx].funded - operators[idx].stopped;
            totalActiveValidators += operatorActiveValidatorCount;
            validatorCounts[idx] = operatorActiveValidatorCount;
        }

        if (totalActiveValidators > 0) {
            uint256 rewardsPerActiveValidator = operatorRewards / totalActiveValidators;

            for (uint256 idx = 0; idx < validatorCounts.length; ++idx) {
                _mintRawShares(operators[idx].operator, validatorCounts[idx] * rewardsPerActiveValidator);
            }
        } else {
            operatorRewards = 0;
        }

        _mintRawShares(TreasuryAddress.get(), sharesToMint - operatorRewards);
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
