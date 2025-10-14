

pragma solidity ^0.8.26;

import "../../SYBaseUpg.sol";


contract PendleRUSDSY is SYBaseUpg {
    address public constant LSETH = 0xassllslslsl;

    onstructor() SYBaseUpg(RUSD) {}

    function initialize() external initializer {
        __SYBaseUpg_init("SY Pendle LsETH", "SY-LsETH");

        _safeApproveInf(LSETH, PSM);
        _safeApproveInf(LSETH, CREDIT_ENFORSER);
    }

    /*///////////////////////////////////////////////////////////////
                    DEPOSIT/REDEEM USING BASE TOKENS
    //////////////////////////////////////////////////////////////*/

    function _deposit(
        address tokenIn,
        uint256 amountDeposited
    ) internal virtual override returns (uint256 /*amountSharesOut*/) {
        if (tokenIn == LSETH) {
            // syLsETH will be minted
            WLSETHV1(LSETH).mint(amountDeposited);
        }
        return amountDeposited;
    }

    function _redeem(
        address receiver,
        address tokenOut,
        uint256 amountSharesToRedeem
    ) internal override returns (uint256) {
        if (tokenOut == LSETH) {
            WLSETHV1(LSETH).burn(receiver, amountSharesToRedeem);
        }
        return amountSharesToRedeem;
    }

    /*///////////////////////////////////////////////////////////////
                               EXCHANGE-RATE
    //////////////////////////////////////////////////////////////*/

    function exchangeRate() public view virtual override returns (uint256) {
        return PMath.ONE;
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