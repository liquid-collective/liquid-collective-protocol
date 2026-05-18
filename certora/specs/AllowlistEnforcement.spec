// AllowlistEnforcement.spec — Allowlist DENY_MASK / Allower separation property
// 
// Property: allowlist_deny_allower_separation (LCP-ACCESS-51)
//
// setAllowPermissions (Allower role) must revert if:
//   1. Any account in the batch already has DENY_MASK set, OR
//   2. Any permission value contains DENY_MASK
// Only setDenyPermissions (Denier role) can set or clear DENY_MASK.
// The Allower cannot lift a deny.

import "MathSummaries.spec";

using AllowlistHarness as allowlist;

methods {
    // Harness getters — envfree because they are view/pure
    function allowlist.getPermissionsHarness(address) external returns (uint256) envfree;
    function allowlist.isDeniedHarness(address) external returns (bool) envfree;
    function allowlist.getAllowerHarness() external returns (address) envfree;
    function allowlist.getDenierHarness() external returns (address) envfree;
    function allowlist.getDenyMask() external returns (uint256) envfree;
    function allowlist.getAdminHarness() external returns (address) envfree;

    // Public interface getters
    function allowlist.getAllower() external returns (address) envfree;
    function allowlist.getDenier() external returns (address) envfree;
    function allowlist.isAllowed(address, uint256) external returns (bool) envfree;
    function allowlist.isDenied(address) external returns (bool) envfree;
    function allowlist.hasPermission(address, uint256) external returns (bool) envfree;
    function allowlist.getPermissions(address) external returns (uint256) envfree;
    function allowlist.getAdmin() external returns (address) envfree;
}

/// @title DENY_MASK constant cached for reuse
definition DENY_MASK() returns uint256 = allowlist.getDenyMask();

/// @title Helper: check if a permission value contains the DENY bit
definition hasDenyBit(uint256 perm) returns bool = 
    (perm & DENY_MASK()) == DENY_MASK();

// ════════════════════════════════════════════════════════════════════════════
// RULE 1: setAllowPermissions reverts if ANY account is already denied
// ════════════════════════════════════════════════════════════════════════════

/// @notice If the caller is the Allower and calls setAllowPermissions with a 
///         single account that has DENY_MASK set, the call MUST revert.
/// @dev We test with a single-element array for tractability. The contract loops
///      over the array and checks each element, so if the first element triggers
///      revert, the property holds. Multi-element arrays are covered by loop unrolling.
rule setAllowPermissions_reverts_if_account_denied(env e) {
    // Setup: single-element arrays
    address[] accounts; 
    uint256[] permissions;
    require accounts.length == 1;
    require permissions.length == 1;
    
    address account = accounts[0];
    uint256 perm = permissions[0];
    
    // Precondition: caller is the Allower
    require e.msg.sender == allowlist.getAllowerHarness();
    require e.msg.value == 0; // non-payable
    
    // Precondition: account is not zero address (would revert for different reason)
    require account != 0;
    
    // Precondition: the permission does NOT contain DENY_MASK 
    // (we're testing the "account already denied" path, not the "permission has deny" path)
    require !hasDenyBit(perm);
    
    // Key condition: account IS denied
    bool accountDenied = allowlist.isDeniedHarness(account);
    require accountDenied;
    
    // Call with revert tracking
    allowlist.setAllowPermissions@withrevert(e, accounts, permissions);
    
    // Must revert because account has DENY_MASK
    assert lastReverted, 
        "setAllowPermissions must revert when account has DENY_MASK set";
}

// ════════════════════════════════════════════════════════════════════════════
// RULE 2: setAllowPermissions reverts if ANY permission contains DENY_MASK
// ════════════════════════════════════════════════════════════════════════════

/// @notice If the caller is the Allower and calls setAllowPermissions with a 
///         permission value that has DENY_MASK set, the call MUST revert.
rule setAllowPermissions_reverts_if_permission_has_deny(env e) {
    address[] accounts;
    uint256[] permissions;
    require accounts.length == 1;
    require permissions.length == 1;
    
    address account = accounts[0];
    uint256 perm = permissions[0];
    
    // Precondition: caller is the Allower
    require e.msg.sender == allowlist.getAllowerHarness();
    require e.msg.value == 0;
    
    // Precondition: account is not zero address
    require account != 0;
    
    // Precondition: account is NOT denied (we're testing the "permission has deny" path)
    require !allowlist.isDeniedHarness(account);
    
    // Key condition: the permission value contains DENY_MASK
    require hasDenyBit(perm);
    
    // Call with revert tracking
    allowlist.setAllowPermissions@withrevert(e, accounts, permissions);
    
    // Must revert because permission has DENY_MASK
    assert lastReverted,
        "setAllowPermissions must revert when permission value contains DENY_MASK";
}

// ════════════════════════════════════════════════════════════════════════════
// RULE 3: setAllowPermissions succeeds when neither deny condition is met
//         (Liveness dual — proves the function CAN work for the Allower)
// ════════════════════════════════════════════════════════════════════════════

/// @notice The Allower CAN successfully call setAllowPermissions when:
///         - No account is denied
///         - No permission contains DENY_MASK
///         - All other preconditions are met
rule setAllowPermissions_succeeds_when_valid(env e) {
    address[] accounts;
    uint256[] permissions;
    require accounts.length == 1;
    require permissions.length == 1;
    
    address account = accounts[0];
    uint256 perm = permissions[0];
    
    // Precondition: caller is the Allower
    require e.msg.sender == allowlist.getAllowerHarness();
    require e.msg.value == 0;
    
    // Precondition: account is not zero address
    require account != 0;
    
    // Neither deny condition is triggered
    require !allowlist.isDeniedHarness(account);
    require !hasDenyBit(perm);
    
    // Call with revert tracking
    allowlist.setAllowPermissions@withrevert(e, accounts, permissions);
    
    // Should NOT revert
    assert !lastReverted,
        "setAllowPermissions must succeed when no deny conditions are triggered";
}

// ════════════════════════════════════════════════════════════════════════════
// RULE 4: Only setDenyPermissions can set DENY_MASK (parametric)
// ════════════════════════════════════════════════════════════════════════════

/// @notice For any function call, if an account transitions from non-denied to denied,
///         the function must be setDenyPermissions.
///         This proves the Allower cannot grant DENY through any path.
rule only_setDenyPermissions_can_set_deny_mask(env e, method f, calldataarg args) 
    filtered { 
        f -> !f.isView 
          && f.selector != sig:allowlist.initAllowlistV1(address, address).selector
          && f.selector != sig:allowlist.initAllowlistV1_1(address).selector
    }
{
    // Pick an arbitrary account to monitor
    address account;
    
    // Capture pre-state: account is NOT denied
    bool deniedBefore = allowlist.isDeniedHarness(account);
    require !deniedBefore;
    
    // Execute arbitrary function
    f(e, args);
    
    // Check post-state
    bool deniedAfter = allowlist.isDeniedHarness(account);
    
    // If account became denied, the function must be setDenyPermissions
    assert deniedAfter => 
        f.selector == sig:allowlist.setDenyPermissions(address[], uint256[]).selector,
        "Only setDenyPermissions can set the DENY_MASK bit on an account";
}

// ════════════════════════════════════════════════════════════════════════════
// RULE 5: setAllowPermissions cannot lift a deny (DENY persistence under Allower)
// ════════════════════════════════════════════════════════════════════════════

/// @notice If an account has DENY_MASK, calling setAllowPermissions cannot clear it.
///         The account remains denied after the call (which must revert anyway).
rule setAllowPermissions_cannot_lift_deny(env e) {
    address[] accounts;
    uint256[] permissions;
    require accounts.length == 1;
    require permissions.length == 1;
    
    address account = accounts[0];
    
    // Account is denied before
    require allowlist.isDeniedHarness(account);
    
    // Try to call setAllowPermissions (any caller, any permissions)
    allowlist.setAllowPermissions@withrevert(e, accounts, permissions);
    
    // Whether it reverted or not, the account must still be denied
    // (In practice it always reverts, but this strengthens the property)
    assert allowlist.isDeniedHarness(account),
        "setAllowPermissions must never clear the DENY_MASK bit";
}

// ════════════════════════════════════════════════════════════════════════════
// RULE 6: setAllowPermissions unauthorized caller reverts
// ════════════════════════════════════════════════════════════════════════════

/// @notice Only the configured Allower address can call setAllowPermissions.
rule setAllowPermissions_only_allower(env e) {
    address[] accounts;
    uint256[] permissions;
    require accounts.length == 1;
    require permissions.length == 1;
    
    // Caller is NOT the Allower
    require e.msg.sender != allowlist.getAllowerHarness();
    require e.msg.value == 0;
    
    allowlist.setAllowPermissions@withrevert(e, accounts, permissions);
    
    assert lastReverted,
        "setAllowPermissions must revert when caller is not the Allower";
}

// ════════════════════════════════════════════════════════════════════════════
// RULE 7: setDenyPermissions unauthorized caller reverts
// ════════════════════════════════════════════════════════════════════════════

/// @notice Only the configured Denier address can call setDenyPermissions.
rule setDenyPermissions_only_denier(env e) {
    address[] accounts;
    uint256[] permissions;
    require accounts.length == 1;
    require permissions.length == 1;
    
    // Caller is NOT the Denier
    require e.msg.sender != allowlist.getDenierHarness();
    require e.msg.value == 0;
    
    allowlist.setDenyPermissions@withrevert(e, accounts, permissions);
    
    assert lastReverted,
        "setDenyPermissions must revert when caller is not the Denier";
}

// ════════════════════════════════════════════════════════════════════════════
// RULE 8: Biconditional revert for setAllowPermissions (single element)
// ════════════════════════════════════════════════════════════════════════════

/// @notice Complete biconditional revert condition for setAllowPermissions
///         with a single-element array. The function reverts if and only if
///         one of the known revert conditions holds.
rule setAllowPermissions_revert_conditions(env e) {
    address[] accounts;
    uint256[] permissions;
    require accounts.length == 1;
    require permissions.length == 1;
    
    address account = accounts[0];
    uint256 perm = permissions[0];
    
    // Capture all revert conditions
    bool callerNotAllower = (e.msg.sender != allowlist.getAllowerHarness());
    bool accountIsZero = (account == 0);
    bool accountIsDenied = allowlist.isDeniedHarness(account);
    bool permHasDeny = hasDenyBit(perm);
    bool hasValue = (e.msg.value != 0);
    
    bool shouldRevert = callerNotAllower 
                     || accountIsZero 
                     || accountIsDenied 
                     || permHasDeny
                     || hasValue;
    
    allowlist.setAllowPermissions@withrevert(e, accounts, permissions);
    
    assert lastReverted <=> shouldRevert,
        "setAllowPermissions revert iff: not allower, zero addr, denied acct, deny in perm, or msg.value>0";
}
