//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "./components/DepositManager.1.sol";
import "./components/TransferManager.1.sol";
import "./components/SharesManager.1.sol";
import "./components/OracleManager.1.sol";
import "./components/OperatorsManager.1.sol";
import "./components/WhitelistManager.1.sol";
import "./Initializable.sol";
import "./libraries/Utils.sol";

import "./state/shared/AdministratorAddress.sol";
import "./state/river/TreasuryAddress.sol";
import "./state/river/OperatorRewardsShare.sol";
import "./state/river/GlobalFee.sol";

/// @title River (v1)
/// @author Iulian Rotaru
/// @notice This contract merges all the manager contracts and implements all the virtual methods stitching all components together
contract RiverV1 is
    DepositManagerV1,
    TransferManagerV1,
    SharesManagerV1,
    OracleManagerV1,
    OperatorsManagerV1,
    WhitelistManagerV1,
    Initializable
{
    uint256 public constant BASE = 100000;

    /// @notice Initializes the River system
    /// @param _depositContractAddress Address to make Consensus Layer deposits
    /// @param _withdrawalCredentials Credentials to use for every validator deposit
    /// @param _systemAdministratorAddress Administrator address
    /// @param _treasuryAddress Address receiving the fee minus the operator share
    /// @param _globalFee Amount retained when the eth balance increases, splitted between the treasury and the operators
    /// @param _operatorRewardsShare Share of the global fee used to reward node operators
    // review(nmvalera): minor: rename starting with a verb (e.g. initRiverV1)
    function riverInitializeV1(
        address _depositContractAddress,
        bytes32 _withdrawalCredentials,
        address _systemAdministratorAddress,
        address _treasuryAddress,
        uint256 _globalFee,
        uint256 _operatorRewardsShare
    ) external init(0) {
        AdministratorAddress.set(_systemAdministratorAddress);
        TreasuryAddress.set(_treasuryAddress);
        GlobalFee.set(_globalFee);
        OperatorRewardsShare.set(_operatorRewardsShare);

        DepositManagerV1.depositManagerInitializeV1(_depositContractAddress, _withdrawalCredentials);
    }

    /// @notice Changes the global fee parameter
    /// @param newFee New fee value
    // review(nmvalera): should we move the fee logic into a RewardDispatcher contract that River inherits from?
    function setGlobalFee(uint256 newFee) external {
        UtilsLib.adminOnly();

        if (newFee > BASE) {
            revert Errors.InvalidArgument();
        }

        GlobalFee.set(newFee);
    }

    /// @notice Changes the operator rewards share.
    /// @param newOperatorRewardsShare New share value
    function setOperatorRewardsShare(uint256 newOperatorRewardsShare) external {
        UtilsLib.adminOnly();

        if (newOperatorRewardsShare > BASE) {
            revert Errors.InvalidArgument();
        }

        OperatorRewardsShare.set(newOperatorRewardsShare);
    }

    /// @notice Retrieve system administrator address
    // review(nmvalera): should we move the admin logic into an ACL contract that River inherits from?
    function getAdministrator() external view returns (address) {
        return AdministratorAddress.get();
    }

    /// @notice Handler called whenever a user deposits ETH to the system. Mints the adequate amount of shares.
    /// @param _depositor User address that made the deposit
    /// @param _amount Amount of ETH deposited
    function _onDeposit(address _depositor, uint256 _amount) internal override {
        SharesManagerV1._mintShares(_depositor, _amount);
    }

    /// @notice Handler called whenever a whitelist check is made for an address. Asks the Whitelist Manager component.
    /// @param _account Address to verify
    function _isAllowed(address _account) internal view override returns (bool) {
        return WhitelistManagerV1._isWhitelisted(_account);
    }

    /// @notice Internal utility to concatenate bytes arrays together
    function _concatenateByteArrays(bytes[] memory arr1, bytes[] memory arr2)
        internal
        pure
        returns (bytes[] memory res)
    {
        res = new bytes[](arr1.length + arr2.length);
        for (uint256 idx = 0; idx < arr1.length; ++idx) {
            res[idx] = arr1[idx];
        }
        for (uint256 idx = 0; idx < arr2.length; ++idx) {
            res[idx + arr1.length] = arr2[idx];
        }
    }

    /// @notice Handler called whenever a deposit to the consensus layer is made. Should retrieve _requestedAmount or lower keys
    /// @param _requestedAmount Amount of keys required. Contract is expected to send _requestedAmount or lower.
    function _onValidatorKeyRequest(uint256 _requestedAmount)
        internal
        override
        returns (bytes[] memory publicKeys, bytes[] memory signatures)
    {
        Operators.Operator[] memory operators = Operators.getAllFundable();

        if (operators.length == 0) {
            return (new bytes[](0), new bytes[](0));
        }

        uint256 selectedOperatorIndex = 0;
        for (uint256 idx = 1; idx < operators.length; ++idx) {
            if (operators[idx].funded < operators[selectedOperatorIndex].funded) {
                selectedOperatorIndex = idx;
            }
        }

        uint256 availableOperatorKeys = UintLib.min(
            operators[selectedOperatorIndex].keys,
            operators[selectedOperatorIndex].limit
        ) - operators[selectedOperatorIndex].funded;

        Operators.Operator storage operator = Operators.get(operators[selectedOperatorIndex].name);
        if (availableOperatorKeys >= _requestedAmount) {
            (publicKeys, signatures) = ValidatorKeys.getKeys(
                operators[selectedOperatorIndex].name,
                operators[selectedOperatorIndex].funded,
                _requestedAmount
            );
            operator.funded += _requestedAmount;
        } else {
            (publicKeys, signatures) = ValidatorKeys.getKeys(
                operators[selectedOperatorIndex].name,
                operators[selectedOperatorIndex].funded,
                availableOperatorKeys
            );
            operator.funded += availableOperatorKeys;
            (bytes[] memory additionalPublicKeys, bytes[] memory additionalSignatures) = _onValidatorKeyRequest(
                _requestedAmount - availableOperatorKeys
            );
            publicKeys = _concatenateByteArrays(publicKeys, additionalPublicKeys);
            signatures = _concatenateByteArrays(signatures, additionalSignatures);
        }
    }

    /// @notice Handler called whenever the balance of ETH handled by the system increases. Splits funds between operators and treasury.
    /// @param _amount Additional eth received
    function _onEarnings(uint256 _amount) internal override {
        uint256 collectedFees = (_amount * GlobalFee.get()) / BASE;

        uint256 operatorRewards = (collectedFees * OperatorRewardsShare.get()) / BASE;

        Operators.Operator[] memory operators = Operators.getAllActive();
        uint256[] memory validatorCounts = new uint256[](operators.length);

        uint256 totalActiveValidators = 0;
        for (uint256 idx = 0; idx < operators.length; ++idx) {
            uint256 operatorActiveValidatorCount = operators[idx].funded - operators[idx].stopped;
            totalActiveValidators += operatorActiveValidatorCount;
            validatorCounts[operatorActiveValidatorCount];
        }

        if (totalActiveValidators > 0) {
            uint256 rewardsPerActiveValidator = operatorRewards / totalActiveValidators;

            for (uint256 idx = 0; idx < validatorCounts.length; ++idx) {
                _mintShares(operators[idx].operator, validatorCounts[idx] * rewardsPerActiveValidator);
            }
        } else {
            operatorRewards = 0;
        }

        _mintShares(TreasuryAddress.get(), collectedFees - operatorRewards);
    }

    /// @notice Handler called whenever the total balance of ETH is requested
    function _assetBalance() internal view override returns (uint256) {
        uint256 beaconValidatorCount = BeaconValidatorCount.get();
        uint256 depositedValidatorCount = BeaconValidatorCount.get();
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
