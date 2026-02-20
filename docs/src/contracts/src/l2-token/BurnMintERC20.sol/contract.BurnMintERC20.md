# BurnMintERC20
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/l2-token/BurnMintERC20.sol)

**Inherits:**
[IBurnMintERC20](/contracts/src/l2-token/IBurnMintERC20.sol/interface.IBurnMintERC20.md), [IGetCCIPAdmin](/contracts/src/l2-token/IGetCCIPAdmin.sol/interface.IGetCCIPAdmin.md), IERC165, ERC20BurnableUpgradeable, AccessControlUpgradeable

A basic ERC20 compatible token contract with burn and minting roles.

This contract has not been audited and is not yet approved for production use.


## State Variables
### MINTER_ROLE

```solidity
bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE")
```


### BURNER_ROLE

```solidity
bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE")
```


## Functions
### constructor


```solidity
constructor() ;
```

### initialize


```solidity
function initialize(string memory _name, string memory _symbol, address _admin) public initializer;
```

### supportsInterface

Returns true if this contract implements the interface defined by
`interfaceId`. See the corresponding
https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
to learn more about how these ids are created.
This function call must use less than 30 000 gas.


```solidity
function supportsInterface(bytes4 interfaceId)
    public
    pure
    virtual
    override(AccessControlUpgradeable, IERC165)
    returns (bool);
```

### _transfer

Uses OZ ERC20 _transfer to disallow sending to address(0).

Disallows sending to address(this)


```solidity
function _transfer(address from, address to, uint256 amount) internal virtual override;
```

### _approve

Uses OZ ERC20 _approve to disallow approving for address(0).

Disallows approving for address(this)


```solidity
function _approve(address owner, address spender, uint256 amount) internal virtual override;
```

### burn

Uses OZ ERC20 _burn to disallow burning from address(0).

Decreases the total supply.


```solidity
function burn(uint256 amount) public override(IBurnMintERC20, ERC20BurnableUpgradeable) onlyRole(BURNER_ROLE);
```

### burn

Burns tokens from a given address..

Alias for BurnFrom for compatibility with the older naming convention.

Uses burnFrom for all validation & logic.


```solidity
function burn(address account, uint256 amount) public virtual override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|The address to burn tokens from.|
|`amount`|`uint256`|The number of tokens to be burned.|


### burnFrom

Uses OZ ERC20 _burn to disallow burning from address(0).

Decreases the total supply.


```solidity
function burnFrom(address account, uint256 amount)
    public
    override(IBurnMintERC20, ERC20BurnableUpgradeable)
    onlyRole(BURNER_ROLE);
```

### mint

Mints new tokens for a given address.

Uses OZ ERC20 _mint to disallow minting to address(0).

Disallows minting to address(this)

Increases the total supply.


```solidity
function mint(address account, uint256 amount) external override onlyRole(MINTER_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|The address to mint the new tokens to.|
|`amount`|`uint256`|The number of tokens to be minted.|


### grantMintAndBurnRoles

grants both mint and burn roles to `burnAndMinter`.

calls public functions so this function does not require
access controls. This is handled in the inner functions.


```solidity
function grantMintAndBurnRoles(address burnAndMinter) external;
```

### getCCIPAdmin

Returns the current CCIPAdmin


```solidity
function getCCIPAdmin() external view returns (address);
```

### setCCIPAdmin

Transfers the CCIPAdmin role to a new address

only the owner can call this function, NOT the current ccipAdmin, and 1-step ownership transfer is used.


```solidity
function setCCIPAdmin(address newAdmin) public onlyRole(DEFAULT_ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newAdmin`|`address`|The address to transfer the CCIPAdmin role to. Setting to address(0) is a valid way to revoke the role|


## Events
### CCIPAdminTransferred

```solidity
event CCIPAdminTransferred(address indexed previousAdmin, address indexed newAdmin);
```

## Errors
### InvalidRecipient

```solidity
error InvalidRecipient(address recipient);
```

