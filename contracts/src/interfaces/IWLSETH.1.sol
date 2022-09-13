//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

interface IWLSETHV1 {
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);

    error BalanceTooLow();
    error UnauthorizedOperation();
    error AllowanceTooLow(address _from, address _operator, uint256 _allowance, uint256 _value);
    error NullTransfer();
    error TokenTransferError();
    error UnauthorizedTransfer(address _from, address _to);

    function initWLSETHV1(address _river) external;
    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint256);
    function balanceOf(address _owner) external view returns (uint256 balance);
    function allowance(address _owner, address _spender) external view returns (uint256 remaining);
    function transfer(address _to, uint256 _value) external returns (bool);
    function transferFrom(address _from, address _to, uint256 _value) external returns (bool);
    function approve(address _spender, uint256 _value) external returns (bool success);
    function increaseAllowance(address _spender, uint256 _additionalValue) external returns (bool success);
    function decreaseAllowance(address _spender, uint256 _subtractableValue) external returns (bool success);
    function mint(address _recipient, uint256 _value) external;
    function burn(address _recipient, uint256 _value) external;
}
