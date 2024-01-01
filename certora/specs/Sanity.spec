rule method_reachability(method f) {
    env e;
    calldataarg args;
    f(e, args);
    satisfy true;
}
