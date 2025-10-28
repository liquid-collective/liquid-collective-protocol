/// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.26;

import "../../SYBaseUpg.sol";
import "../../interfaces/IWLSETH.1.sol";

contract PendleLsETHETHSY is SYBaseUpg {
    address public constant LSETH = 0x8c1BEd5b9a0928467c9B1341Da1D7BD5e10b6549; // Liquid Collective LsETH on Ethereum mainnet

    constructor() SYBaseUpg(LSETH) {}

    function initialize() external initializer {
        __SYBaseUpg_init("SY Pendle LsETH", "SY-LsETH");

        //  _safeApproveInf(LSETH, WLSETHV1(LSETH).RiverAddress());
    }

    /*///////////////////////////////////////////////////////////////
                   DEPOSIT/REDEEM USING BASE TOKENS
   //////////////////////////////////////////////////////////////*/

    function _deposit(
        address /*tokenIn*/,
        uint256 amountDeposited
    ) internal virtual override returns (uint256 /*amountSharesOut*/) {
        return amountDeposited;
    }

    function _redeem(
        address receiver,
        address tokenOut,
        uint256 amountSharesToRedeem
    ) internal override returns (uint256) {
        _transferOut(LSETH, receiver, amountSharesToRedeem);
        return amountSharesToRedeem;
    }

    /*///////////////////////////////////////////////////////////////
                              EXCHANGE-RATE
   //////////////////////////////////////////////////////////////*/

    /// @notice Returns the ETH-per-LsETH exchange rate
    /// @dev This is monotonic (never decreases) as staking rewards accrue
    /// @return The amount of ETH (1e18 scaled) that 1 LsETH is worth
    function exchangeRate() public view virtual override returns (uint256) {
        return ILsETH(LSETH).underlyingBalanceFromShares(1e18);
    }

    /*///////////////////////////////////////////////////////////////
               MISC FUNCTIONS FOR METADATA
   //////////////////////////////////////////////////////////////*/

    function _previewDeposit(
        address /*tokenIn*/,
        uint256 amountTokenToDeposit
    ) internal pure override returns (uint256 /*amountSharesOut*/) {
        return amountTokenToDeposit;
    }

    function _previewRedeem(
        address /*tokenOut*/,
        uint256 amountSharesToRedeem
    ) internal pure override returns (uint256 /*amountTokenOut*/) {
        return amountSharesToRedeem;
    }

    function getTokensIn() public pure override returns (address[] memory res) {
        return ArrayLib.create(LSETH);
    }

    function getTokensOut() public pure override returns (address[] memory res) {
        return ArrayLib.create(LSETH);
    }

    function isValidTokenIn(address token) public pure override returns (bool) {
        return token == LSETH;
    }

    function isValidTokenOut(address token) public pure override returns (bool) {
        return token == LSETH;
    }

    function assetInfo() external view returns (AssetType assetType, address assetAddress, uint8 assetDecimals) {
        return (AssetType.TOKEN, LSETH, IERC20Metadata(LSETH).decimals());
    }
}
