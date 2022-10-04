//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/extensions/ERC20VotesUpgradeable.sol";


interface IVesterFactory {
    function deployVester() external returns (address)
}

interface IVester {
    function create(
        address _beneficiary,
        uint32 _cliffLength,
        uint112 _cliffGrant,
        uint32 _startTime,
        uint112 _vestingAllocation,
        uint32 _vestingPeriodLength,
        uint32 _numberOfVestingPeriods,
        bool _cancellable
    ) external returns (bool);

    function deposit(uint256 _amount) external returns (uint256);
}


contract TLC is ERC20VotesUpgradeable {
    // Token information
    string internal constant NAME = "Liquid Collective";
    string internal constant SYMBOL = "TLC";

    // Initial supply of token minted
    uint256 internal constant INITIAL_SUPPLY = 1_000_000_000e18; // 1 billion TLC

    IVesterFactory internal vesterFactory;

    /// @notice Initializes the TLC Token
    /// * @param account_ The initial account to grant all the minted tokens
    function initTLCV1(address account_) external initializer {
        __ERC20Permit_init(NAME);
        __ERC20_init(NAME, SYMBOL);
        _mint(account_, INITIAL_SUPPLY);
    }

    function createVesting(
        address _beneficiary,
        uint32 _cliffLength,
        uint112 _cliffGrant,
        uint32 _startTime,
        uint112 _vestingAllocation,
        uint32 _vestingPeriodLength,
        uint32 _numberOfVestingPeriods,
        bool _cancellable
    ) external returns (bool) {
        IVester vester = IVester(payable(vesterFactory.deployVester()));
        
    }
}
