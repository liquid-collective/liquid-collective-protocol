// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    bool transferFromFail;

    constructor(string memory name, string memory symbol, uint8 decimals) ERC20(name, symbol) {}

    function setTransferFromFail(bool _fail) external {
        transferFromFail = _fail;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        if (transferFromFail) {
            return false;
        }
        return super.transferFrom(sender, recipient, amount);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
