// TransferReverts.spec — Biconditional revert conditions for LsETH transfer/transferFrom
//
// Property: biconditional_revert_lseth_transfer (LCP-ACCESS-51 related)
//
// LsETH transfer must revert if and only if:
//   to == address(0) OR value == 0 OR balanceOf(sender) < value 
//   OR isDenied(sender) OR isDenied(to)
// transferFrom additionally requires: allowance(from, sender) >= value

import "MathSummaries.spec";

using RiverHarness as river;
using AllowlistHarness as allowlist;

methods {
    // River harness getters
    function river.getSharesPerOwner(address) external returns (uint256) envfree;
    function river.getTotalSupply() external returns (uint256) envfree;
    function river.getAllowlistAddress() external returns (address) envfree;
    function river.balanceOf(address) external returns (uint256) envfree;
    function river.allowance(address, address) external returns (uint256) envfree;

    // Allowlist harness getters
    function allowlist.isDeniedHarness(address) external returns (bool) envfree;
    function allowlist.isDenied(address) external returns (bool) envfree;

    // Summarize irrelevant external calls
    function _.onlyAllowed(address, uint256) external => NONDET;

    // Route isDenied calls to the actual AllowlistHarness implementation
    function _.isDenied(address) external => DISPATCHER(true);
}

// ════════════════════════════════════════════════════════════════════════════
// RULE: Biconditional revert for transfer
// ════════════════════════════════════════════════════════════════════════════

/// @notice LsETH transfer reverts if and only if one of the following holds:
///         - to == address(0)
///         - value == 0 (NullTransfer)
///         - balanceOf(msg.sender) < value (BalanceTooLow)
///         - isDenied(msg.sender) (Denied)
///         - isDenied(to) (Denied)
///         - msg.value != 0 (non-payable)
rule transfer_revert_conditions(env e, address to, uint256 value) {
    // Link allowlist
    require river.getAllowlistAddress() == allowlist;

    // Capture all revert conditions
    bool toIsZero = (to == 0);
    bool valueIsZero = (value == 0);
    bool insufficientBalance = (river.balanceOf(e.msg.sender) < value);
    bool senderDenied = allowlist.isDeniedHarness(e.msg.sender);
    bool toDenied = allowlist.isDeniedHarness(to);
    bool hasValue = (e.msg.value != 0);

    // Overflow when adding value to recipient balance (only when sender != recipient)
    bool recipientOverflow = (e.msg.sender != to) && 
        (to_mathint(river.balanceOf(to)) + to_mathint(value) > to_mathint(max_uint256));

    bool shouldRevert = toIsZero 
                     || valueIsZero 
                     || insufficientBalance 
                     || senderDenied 
                     || toDenied
                     || hasValue
                     || recipientOverflow;

    river.transfer@withrevert(e, to, value);

    assert lastReverted <=> shouldRevert,
        "transfer reverts iff: to==0, value==0, balance<value, sender denied, to denied, msg.value>0, or recipient overflow";
}

// ════════════════════════════════════════════════════════════════════════════
// RULE: Biconditional revert for transferFrom
// ════════════════════════════════════════════════════════════════════════════

/// @notice LsETH transferFrom reverts if and only if one of the following holds:
///         - to == address(0)
///         - value == 0 (NullTransfer)
///         - balanceOf(from) < value (BalanceTooLow)
///         - isDenied(from) (Denied)
///         - isDenied(to) (Denied)
///         - allowance(from, msg.sender) < value (AllowanceTooLow)
///         - msg.value != 0 (non-payable)
rule transferFrom_revert_conditions(env e, address from, address to, uint256 value) {
    // Link allowlist
    require river.getAllowlistAddress() == allowlist;

    // Capture all revert conditions
    bool toIsZero = (to == 0);
    bool valueIsZero = (value == 0);
    bool insufficientBalance = (river.balanceOf(from) < value);
    bool fromDenied = allowlist.isDeniedHarness(from);
    bool toDenied = allowlist.isDeniedHarness(to);
    uint256 currentAllowance = river.allowance(from, e.msg.sender);
    bool insufficientAllowance = (currentAllowance < value);
    bool hasValue = (e.msg.value != 0);

    // Overflow when adding value to recipient balance (only when from != to)
    bool recipientOverflow = (from != to) && 
        (to_mathint(river.balanceOf(to)) + to_mathint(value) > to_mathint(max_uint256));

    // msg.sender == 0 causes revert only when allowance != max_uint256, because
    // _spendAllowance skips _approve (and its _notZeroAddress check on spender)
    // when allowance is max_uint256
    bool senderIsZero = (e.msg.sender == 0) && (currentAllowance != max_uint256);

    // from == 0 causes revert only when allowance != max_uint256, because
    // _spendAllowance skips _approve (and its _notZeroAddress check on from/owner)
    // when allowance is max_uint256
    bool fromIsZero = (from == 0) && (currentAllowance != max_uint256);

    bool shouldRevert = senderIsZero
                     || fromIsZero
                     || toIsZero 
                     || valueIsZero 
                     || insufficientBalance 
                     || fromDenied 
                     || toDenied
                     || insufficientAllowance
                     || hasValue
                     || recipientOverflow;

    river.transferFrom@withrevert(e, from, to, value);

    assert lastReverted <=> shouldRevert,
        "transferFrom reverts iff: to==0, value==0, bal<value, from denied, to denied, allowance<value, msg.value>0, or recipient overflow";
}

// ════════════════════════════════════════════════════════════════════════════
// RULE: Transfer succeeds under valid conditions (liveness dual)
// ════════════════════════════════════════════════════════════════════════════

/// @notice When none of the revert conditions hold, transfer succeeds.
rule transfer_succeeds_when_valid(env e, address to, uint256 value) {
    // Link allowlist
    require river.getAllowlistAddress() == allowlist;

    // None of the revert conditions
    require to != 0;
    require value > 0;
    require e.msg.sender != 0;
    require river.balanceOf(e.msg.sender) >= value;
    require !allowlist.isDeniedHarness(e.msg.sender);
    require !allowlist.isDeniedHarness(to);
    require e.msg.value == 0;
    // Prevent arithmetic overflow on recipient balance addition
    // (when sender != recipient, the recipient balance must not overflow)
    require e.msg.sender == to || to_mathint(river.balanceOf(to)) + to_mathint(value) <= to_mathint(max_uint256);

    river.transfer@withrevert(e, to, value);

    assert !lastReverted,
        "transfer must succeed when all preconditions are met";
}

// ════════════════════════════════════════════════════════════════════════════
// RULE: Transfer integrity — balance changes are correct
// ════════════════════════════════════════════════════════════════════════════

/// @notice On successful transfer, sender balance decreases by value and 
///         receiver balance increases by value (when sender != receiver).
rule transfer_integrity(env e, address to, uint256 value) {
    // Link allowlist
    require river.getAllowlistAddress() == allowlist;
    require e.msg.sender != to; // non-self transfer
    require to != 0;

    uint256 senderBalBefore = river.balanceOf(e.msg.sender);
    uint256 receiverBalBefore = river.balanceOf(to);

    river.transfer@withrevert(e, to, value);
    require !lastReverted;

    uint256 senderBalAfter = river.balanceOf(e.msg.sender);
    uint256 receiverBalAfter = river.balanceOf(to);

    assert to_mathint(senderBalAfter) == to_mathint(senderBalBefore) - to_mathint(value),
        "Sender balance must decrease by exactly value";
    assert to_mathint(receiverBalAfter) == to_mathint(receiverBalBefore) + to_mathint(value),
        "Receiver balance must increase by exactly value";
}

// ════════════════════════════════════════════════════════════════════════════
// RULE: Self-transfer identity
// ════════════════════════════════════════════════════════════════════════════

/// @notice Transferring to yourself does not change your balance.
rule self_transfer_identity(env e, uint256 value) {
    require river.getAllowlistAddress() == allowlist;

    uint256 balBefore = river.balanceOf(e.msg.sender);

    river.transfer@withrevert(e, e.msg.sender, value);
    require !lastReverted;

    assert river.balanceOf(e.msg.sender) == balBefore,
        "Self-transfer must not change balance";
}
