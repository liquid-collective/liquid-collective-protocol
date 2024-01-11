pragma solidity 0.8.20;


import "../munged/contracts/src/RedeemManager.1.sol";

contract RedeemManagerV1Harness is RedeemManagerV1{


    function get_CLAIM_FULLY_CLAIMED() view external returns (uint8) { return CLAIM_FULLY_CLAIMED; }
    function get_CLAIM_PARTIALLY_CLAIMED() view external returns (uint8) { return CLAIM_PARTIALLY_CLAIMED; }
    function get_CLAIM_SKIPPED() view external returns (uint8) { return CLAIM_SKIPPED; }
}