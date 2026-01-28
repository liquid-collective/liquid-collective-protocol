// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {CCIPAdminAddress} from "contracts/src/l2-token/state/CCIPAdminAddress.sol";

import {IBurnMintERC20} from "./IBurnMintERC20.sol";
import {IGetCCIPAdmin} from "contracts/src/l2-token/IGetCCIPAdmin.sol";
import {IAccessControl} from "openzeppelin-contracts/contracts/access/IAccessControl.sol";
import {IERC165} from "openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {
    AccessControlUpgradeable
} from "openzeppelin-contracts-upgradeable/contracts/access/AccessControlUpgradeable.sol";
import {
    ERC20BurnableUpgradeable
} from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";

/// @notice A basic ERC20 compatible token contract with burn and minting roles.
/// @dev This contract has not been audited and is not yet approved for production use.
contract BurnMintERC20 is IBurnMintERC20, IGetCCIPAdmin, IERC165, ERC20BurnableUpgradeable, AccessControlUpgradeable {
    error InvalidRecipient(address recipient);

    event CCIPAdminTransferred(address indexed previousAdmin, address indexed newAdmin);

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    constructor() {
        _disableInitializers();
    }

    function initialize(string memory _name, string memory _symbol, address _admin) public initializer {
        __AccessControl_init();
        __ERC20_init(_name, _symbol);
        CCIPAdminAddress.set(_admin);
        // Set up the owner as the initial minter and burner
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
    }

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId)
        public
        pure
        virtual
        override(AccessControlUpgradeable, IERC165)
        returns (bool)
    {
        return interfaceId == type(IERC20).interfaceId || interfaceId == type(IBurnMintERC20).interfaceId
            || interfaceId == type(IERC165).interfaceId || interfaceId == type(IAccessControl).interfaceId
            || interfaceId == type(IGetCCIPAdmin).interfaceId;
    }

    // ================================================================
    // │                            ERC20                             │
    // ================================================================

    /// @dev Uses OZ ERC20 _transfer to disallow sending to address(0).
    /// @dev Disallows sending to address(this)
    function _transfer(address from, address to, uint256 amount) internal virtual override {
        if (to == address(this)) revert InvalidRecipient(to);

        super._transfer(from, to, amount);
    }

    /// @dev Uses OZ ERC20 _approve to disallow approving for address(0).
    /// @dev Disallows approving for address(this)
    function _approve(address owner, address spender, uint256 amount) internal virtual override {
        if (spender == address(this)) revert InvalidRecipient(spender);

        super._approve(owner, spender, amount);
    }

    // ================================================================
    // │                      Burning & minting                       │
    // ================================================================

    /// @inheritdoc ERC20BurnableUpgradeable
    /// @dev Uses OZ ERC20 _burn to disallow burning from address(0).
    /// @dev Decreases the total supply.
    function burn(uint256 amount) public override(IBurnMintERC20, ERC20BurnableUpgradeable) onlyRole(BURNER_ROLE) {
        super.burn(amount);
    }

    /// @inheritdoc IBurnMintERC20
    /// @dev Alias for BurnFrom for compatibility with the older naming convention.
    /// @dev Uses burnFrom for all validation & logic.
    function burn(address account, uint256 amount) public virtual override {
        burnFrom(account, amount);
    }

    /// @inheritdoc ERC20BurnableUpgradeable
    /// @dev Uses OZ ERC20 _burn to disallow burning from address(0).
    /// @dev Decreases the total supply.
    function burnFrom(address account, uint256 amount)
        public
        override(IBurnMintERC20, ERC20BurnableUpgradeable)
        onlyRole(BURNER_ROLE)
    {
        super.burnFrom(account, amount);
    }

    /// @inheritdoc IBurnMintERC20
    /// @dev Uses OZ ERC20 _mint to disallow minting to address(0).
    /// @dev Disallows minting to address(this)
    /// @dev Increases the total supply.
    function mint(address account, uint256 amount) external override onlyRole(MINTER_ROLE) {
        if (account == address(this)) revert InvalidRecipient(account);

        _mint(account, amount);
    }

    // ================================================================
    // │                            Roles                             │
    // ================================================================

    /// @notice grants both mint and burn roles to `burnAndMinter`.
    /// @dev calls public functions so this function does not require
    /// access controls. This is handled in the inner functions.
    function grantMintAndBurnRoles(address burnAndMinter) external {
        grantRole(MINTER_ROLE, burnAndMinter);
        grantRole(BURNER_ROLE, burnAndMinter);
    }

    /// @notice Returns the current CCIPAdmin
    function getCCIPAdmin() external view returns (address) {
        return CCIPAdminAddress.get();
    }

    /// @notice Transfers the CCIPAdmin role to a new address
    /// @dev only the owner can call this function, NOT the current ccipAdmin, and 1-step ownership transfer is used.
    /// @param newAdmin The address to transfer the CCIPAdmin role to. Setting to address(0) is a valid way to revoke
    /// the role
    function setCCIPAdmin(address newAdmin) public onlyRole(DEFAULT_ADMIN_ROLE) {
        address currentAdmin = CCIPAdminAddress.get();

        CCIPAdminAddress.set(newAdmin);

        emit CCIPAdminTransferred(currentAdmin, newAdmin);
    }
}
