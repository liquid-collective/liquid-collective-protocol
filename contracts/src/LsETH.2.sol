//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import {IERC165} from "openzeppelin-contracts/contracts/interfaces/IERC165.sol";
import {IERC20} from "openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import {ILsETH2} from "./interfaces/ILsETH.2.sol";
import {IOptimismMintableERC20} from "./interfaces/IOptimisimMintableERC20.sol";
import {IStandardBridge} from "./interfaces/IStandardBridge.sol";

import {SharesManagerL2} from "./components/SharesManagerL2.sol";
import {FloatManagerL2} from "./components/FloatManagerL2.sol";
import {Administrable} from "./Administrable.sol";
import {Initializable} from "./Initializable.sol";

import {ExchangeRate} from "./state/lseth2/ExchangeRate.sol";
import {BridgeAddress} from "./state/lseth2/BridgeAddress.sol";
import {RemoteTokenAddress} from "./state/lseth2/RemoteTokenAddress.sol";
import {UserOPWETHBalance} from "./state/lseth2/UserOPWETHBalance.sol";
import {OPWETHAddress} from "./state/lseth2/OPWETHAddress.sol";

contract LsETH is FloatManagerL2, ILsETH2, IOptimismMintableERC20, SharesManagerL2, Initializable, Administrable {
    /// @notice A modifier that only allows the bridge to call.
    modifier onlyBridge() {
        if (msg.sender != BridgeAddress.get()) {
            revert OnlyBridge();
        }
        _;
    }

    /// @notice Initialize the contract
    /// @param _bridge Address of the bridge contract on L2
    /// @param _remoteToken Address of the remote token contract on L1
    /// @param _opWETH Address of the OPWETH contract on L2
    function initialize(address _bridge, address _remoteToken, address _opWETH, address _admin) external init(0) {
        BridgeAddress.set(_bridge);
        RemoteTokenAddress.set(_remoteToken);
        OPWETHAddress.set(_opWETH);
        _setAdmin(_admin);
    }

    // LSETH functions
    /// @notice Allow user to deposit ETH and get equivalent LsETH
    /// @param _amount Amount of ETH to be deposited
    function deposit(uint256 _amount) external {
        _deposit(msg.sender, _amount);
    }

    /// @notice Allow user to deposit ETH and transfer equivalent LsETH to the provided address
    /// @param _recipient Address to which LsETH should go to
    function depositAndTransfer(address _recipient, uint256 _amount) external {
        _deposit(_recipient, _amount);
    }

    function _deposit(address _recipient, uint256 _amount) internal {
        //Transfer OPWETH from the user
        IERC20(OPWETHAddress.get()).transferFrom(msg.sender, address(this), _amount);
        // Increase value of User deposited opweth balance tracker
        UserOPWETHBalance.set(UserOPWETHBalance.get() + _amount);
        // Mint LsETH shares to the recipient
        _mintShares(_recipient, _amount);
    }

    /// @notice Allow user to redeem LsETH for equivalent amount of ETH
    /// @param _amount Amount of LsETH to be redeemed
    function redeem(uint256 _amount) external {
        _redeem(msg.sender, _amount);
    }

    /// @notice Allow user to redeem LsETH for equivalent amount of ETH
    /// @param _amount Amount of LsETH to be redeemed
    /// @param _recipient Address to which redeemed ETH should go to
    function redeemTo(address _recipient, uint256 _amount) external {
        _redeem(_recipient, _amount);
    }

    function _redeem(address _to, uint256 _amount) internal {
        _transfer(msg.sender, address(this), _amount);
        // Calculate exchange amount
        uint256 opWETH = _balanceFromShares(_amount);
        // Reduce the userOPWETH balance
        UserOPWETHBalance.set(UserOPWETHBalance.get() - opWETH);
        // Transfer OPWETH to the to address
        IERC20(OPWETHAddress.get()).transfer(_to, opWETH);
    }

    // Cross chain functionalities
    /// @notice This function updates the exchange rate of LsETH/ETH
    ///         Is called from L1 once a day after oracle Update on L1
    /// @param _rate The LsETH to ETH exchange rate
    function exchangeRateUpdate(uint256 _rate) external onlyAdmin {
        ExchangeRate.set(_rate);
    }

    //--------------- Mint & Bridge------------------
    /// @notice Legacy getter for REMOTE_TOKEN.
    function remoteToken() public view returns (address) {
        return RemoteTokenAddress.get();
    }

    /// @notice Legacy getter for BRIDGE.
    function bridge() public view returns (address) {
        return BridgeAddress.get();
    }

    /// @notice ERC165 interface check function.
    /// @param _interfaceId Interface ID to check.
    /// @return Whether or not the interface is supported by this contract.
    function supportsInterface(bytes4 _interfaceId) external pure virtual returns (bool) {
        bytes4 iface1 = type(IERC165).interfaceId;
        // Interface corresponding to the updated OptimismMintableERC20 (this contract).
        bytes4 iface2 = type(IOptimismMintableERC20).interfaceId;
        return _interfaceId == iface1 || _interfaceId == iface2;
    }

    /// @notice Allows the StandardBridge on this network to mint tokens.
    /// @param _to     Address to mint tokens to.
    /// @param _amount Amount of tokens to mint.
    function mint(address _to, uint256 _amount) external onlyBridge {
        _mintRawShares(_to, _amount);
    }

    /// @notice Allows the StandardBridge on this network to burn tokens.
    /// @param _owner Address to burn tokens from.
    /// @param _value Amount of tokens to burn.
    function burn(address _owner, uint256 _value) external onlyBridge {
        _burnRawShares(_owner, _value);
    }

    //--------------- Shares Manager ------------------

    /// @notice Internal function to put control checks when transfers happen.
    ///         Currently undefined as we don't have any special transfer logic
    function _onTransfer(address _from, address _to) internal view override {}

    function _assetBalance() internal view override returns (uint256) {
        return UserOPWETHBalance.get();
    }

    /// @notice Internal utility to retrieve the underlying asset balance for the given shares
    /// @param _shares Amount of shares to convert
    /// @return The balance from the given shares
    function _balanceFromShares(uint256 _shares) internal view override returns (uint256) {
        // Use exchange rate to convert shares to underlying asset balance
        return (_shares * ExchangeRate.get()) / 1e18;
    }

    /// @notice Internal utility to retrieve the shares count for a given underlying asset amount
    /// @param _balance Amount of underlying asset balance to convert
    /// @return The shares from the given balance
    function _sharesFromBalance(uint256 _balance) internal view override returns (uint256) {
        // Use exchange rate to convert underlying asset balance to shares
        return (_balance * 1e18) / ExchangeRate.get();
    }

    //-------------- Float Operations --------------
    function _onFloatOperation() internal override onlyAdmin {}

    function _bridgeOperation(address _to, uint256 _amount, uint32 _minGasLimit, bytes calldata _extraData)
        internal
        override
        onlyAdmin
    {
        IStandardBridge(BridgeAddress.get()).bridgeERC20To(
            address(this), RemoteTokenAddress.get(), _to, _amount, _minGasLimit, _extraData
        );
    }
}
