//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/security/Pausable.sol";

contract TLC is ERC20Votes, Ownable, Pausable {
    // Token information
    string internal constant NAME = "Liquid Collective Token";
    string internal constant SYMBOL = "TLC";

    // Initial supply of token minted
    uint256 internal constant INITIAL_SUPPLY = 1_000_000_000e18; // 1 billion TLC

    /// @notice Timestamp before which minting is forbidden
    uint public noMintBefore;

    /// @notice Minimum time between mints
    uint32 public constant minIntervalBetweenMints = 1 days * 365;

    /**
     * @notice Construct a new TLC token
     * @param owner_ Account owner of the token contract
     * @param account_ The initial account to grant all the tokens
     * @param noMintBefore_ Date before which no new token can be minted
     */
    constructor(
        address owner_,
        address account_,
        uint noMintBefore_
    ) ERC20Permit(NAME) ERC20(NAME, SYMBOL) {
        require(noMintBefore_ >= block.timestamp + minIntervalBetweenMints, "TLC: minting can only begin after deployment + mint interval");

        transferOwnership(owner_);
        _mint(account_, INITIAL_SUPPLY);

        noMintBefore = noMintBefore_;
    }

    /**
     * @dev Pause transfers and delegation.
     */
    function pause() public onlyOwner {
        _pause();
    }

    /**
     * @dev Unpause transfers and delegation.
     */
    function unpause() public onlyOwner {
        _unpause();
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        if (_msgSender() == owner()) {
            // if caller is owner then transfer is executed
            _transfer(from, to, amount);
            return true;
        }

       // default transferFrom
        super.transferFrom(from, to, amount);

        return true;
    }

    /**
     * @notice Mint new tokens
     * @param dst The address of the destination account
     * @param amount The number of tokens to be minted
     *
     * Requirements:
     *
     * - only owner can mint
     * - minting should happen after mint date
     */
    function mint(address dst, uint256 amount) external returns (bool) {
        require(block.timestamp >= noMintBefore, "TLC: minting is not allowed yet");
        require(_msgSender() == owner(), "TLC: only owner can mint");
        require(dst != address(0), "TLC: cannot mint to the zero address");

        // record the mint
        noMintBefore = block.timestamp + minIntervalBetweenMints;

        _mint(dst, amount);

        return true;
    }

    /**
     * @dev Hook part of Open-Zeppelin ERC20 interface
     *
     * Requirements:
     *
     * - the contract must not be paused or caller must be owner
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);

        require(!paused() || _msgSender() == owner(), "TLC: transfer while paused");
    }

    function _delegate(address delegator, address delegatee) internal virtual override {
        require(!paused(), "TLC: delegate while paused");

        super._delegate(delegator, delegatee);
    }
}