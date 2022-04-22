//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../interfaces/IERC20.sol";
import "../libraries/Errors.sol";

/// @title GovernanceToken (v1)
/// @author Figment
/// @notice This contract represents your voting power in the River governor DAO.
///         It uses timelocked token voting.
///         SUPER BASIC, ONLY FOR TESTING PURPOSES. Specifically, to keep things simple:
///         - No minting, fixed supply
///         - No delegation
///         - No optimisation - uint256s could be lowered to uint256 for example
/// TODO Is there some offline system in Uni that is calling _writeCheckpoint every block?
///      Or does the uni interface make it so that whenever you write a proposal there's also a checkpoint?
contract GovernanceTokenV1 is IERC20 {

    /// @notice A checkpoint for marking number of votes from a given block
    struct Checkpoint {
        uint256 fromBlock;
        uint256 votes;
    }

    /// @notice A record of votes checkpoints for each account, by index
    mapping (address => mapping (uint256 => Checkpoint)) public checkpoints;

    /// @notice The number of checkpoints for each account
    mapping (address => uint256) public numCheckpoints;

    function name() external pure returns (string memory) {
        return "GovernanceToken";
    }

    function symbol() external pure returns (string memory) {
        return "rGOV";
    }

    function decimals() external pure returns (uint8) {
        return 18;
    }

    uint public totalSupply = 1_000_000_000e18; // 1 billion rGOVs

    /// @notice Allowance amounts on behalf of others
    mapping (address => mapping (address => uint256)) internal allowances;

    /// @notice Official record of token balances for each account
    mapping (address => uint256) internal balances;

    function balanceOf(address _owner) external view returns (uint256 balance) {
        return balances[_owner];
    }

    function allowance(address _owner, address _spender) external view returns (uint256 remaining) {
        return allowances[_owner][_spender];
    }

    function transfer(address _to, uint256 _value) external returns (bool) {
        return _transfer(msg.sender, _to, _value);
    }

    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) external returns (bool) {
        if (_from != msg.sender) {
            uint256 currentAllowance = allowances[_from][msg.sender];
            if (currentAllowance < _value) {
                revert('Allowance too low');
            }
            allowances[_from][msg.sender] -= _value;
        }

        return _transfer(_from, _to, _value);
    }

    function approve(address _spender, uint256 _value) external returns (bool success) {
        allowances[msg.sender][_spender] = _value;
        return true;
    }

    function _transfer(
        address _from,
        address _to,
        uint256 _value
    ) internal returns (bool) {
        balances[_from] -= _value;
        balances[_to] += _value;
        _writeCheckpoint(_from);
        _writeCheckpoint(_to);
        return true;
    }

    /**
     * @notice Gets the current votes balance for `account`
     * @param account The address to get votes balance
     * @return The number of current votes for `account`
     */
    function getCurrentVotes(address account) external view returns (uint256) {
        uint256 nCheckpoints = numCheckpoints[account];
        return nCheckpoints > 0 ? checkpoints[account][nCheckpoints - 1].votes : 0;
    }

    /**
     * @notice Determine the prior number of votes for an account as of a block number
     * @dev Block number must be a finalized block or else this function will revert to prevent misinformation.
     * @param account The address of the account to check
     * @param blockNumber The block number to get the vote balance at
     * @return The number of votes the account had as of the given block
     */
    function getPriorVotes(address account, uint blockNumber) public view returns (uint256) {
        require(blockNumber < block.number, "Not yet determined");

        uint256 nCheckpoints = numCheckpoints[account];
        if (nCheckpoints == 0) {
            return 0;
        }

        // First check most recent balance
        if (checkpoints[account][nCheckpoints - 1].fromBlock <= blockNumber) {
            return checkpoints[account][nCheckpoints - 1].votes;
        }

        // Next check implicit zero balance
        if (checkpoints[account][0].fromBlock > blockNumber) {
            return 0;
        }

        uint256 lower = 0;
        uint256 upper = nCheckpoints - 1;
        while (upper > lower) {
            uint256 center = upper - (upper - lower) / 2; // ceil, avoiding overflow
            Checkpoint memory cp = checkpoints[account][center];
            if (cp.fromBlock == blockNumber) {
                return cp.votes;
            } else if (cp.fromBlock < blockNumber) {
                lower = center;
            } else {
                upper = center - 1;
            }
        }
        return checkpoints[account][lower].votes;
    }

    function _writeCheckpoint(address voter) internal {
      uint blockNumber = block.number;
      checkpoints[voter][numCheckpoints[voter]] = Checkpoint(blockNumber, balances[voter]);
      numCheckpoints[voter] += 1;
    }
}
