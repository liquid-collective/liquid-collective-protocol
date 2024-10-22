import "./../specs/Sanity.spec";

use rule method_reachability;

methods {
    // function _.requestRedeem(uint256, address) external => DISPATCHER(true);

    // function allowance(address, address) external returns(uint256) envfree;
    // function balanceOf(address) external returns(uint256) envfree;
    // function balanceOfUnderlying(address) external returns(uint256) envfree;
    // function totalSupply() external returns(uint256) envfree;

    // Allowlist
    function isAllowed(address, uint256) external returns(bool) envfree;
    function isDenied(address) external returns(bool) envfree;
}

// @title isAllowed only changes when setAllowPermissions or setDenyPermissions is called
// Proved
// https://prover.certora.com/output/40577/c1ae7a4bdaac4833bf414adb75aa7b6d/?anonymousKey=6bfd0a5e18d36bb4bf256732fb26a0ef01ed73ed
rule isAllowedChangeRestrictively(env e, method f)
{
    address account;
    uint256 mask;
    bool isAllowedBefore = isAllowed(account, mask);
    calldataarg args;

    f(e, args);
    
    bool isAllowedAfter = isAllowed(account, mask);
    
    assert isAllowedAfter != isAllowedBefore =>
        f.selector == sig:setAllowPermissions(address[],uint256[]).selector ||
        f.selector == sig:setDenyPermissions(address[],uint256[]).selector;
}


// @title isDenied only changes when setAllowPermissions or setDenyPermissions is called
// Proved
// https://prover.certora.com/output/40577/c1ae7a4bdaac4833bf414adb75aa7b6d/?anonymousKey=6bfd0a5e18d36bb4bf256732fb26a0ef01ed73ed
rule isDeniedChangeRestrictively(env e, method f)
{
    address account;
    bool isDeniedBefore = isDenied(account);
    calldataarg args;

    f(e, args);
    
    bool isDeniedAfter = isDenied(account);
    
    assert isDeniedAfter != isDeniedBefore =>
        f.selector == sig:setAllowPermissions(address[],uint256[]).selector ||
        f.selector == sig:setDenyPermissions(address[],uint256[]).selector;
}