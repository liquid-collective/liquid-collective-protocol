import "./../specs/Sanity.spec";
import "./../specs/CVLMath.spec";
import "./../specs/OperatorRegistryV1_base.spec";

// some functions require loop_iter = 4 but loop_iter = 2 is sufficient for most. For this reason we run parametric rule and invariants in two versions
//_LI4 for methods that require loop_iter = 4 and _LI2 for the others.

rule validatorStateTransition_0in_M16(method f, env e, calldataarg args) filtered 
    { f -> !f.isView  && isMethodID(f, 16) }
{
    require isValidState();
    bytes validatorData;
    uint opIndex;
    require operatorStateIsValid(opIndex);  //key <= limit <= funded <= exited
    require getKeysCount(opIndex) <= 3; //should not be higher than loop_iter 
    uint stateBefore = getValidatorState(opIndex, validatorData);
    f(e, args);
    uint stateAfter = getValidatorState(opIndex, validatorData);
    assert (stateAfter == 0) =>
        (stateBefore == 2 || stateBefore == 1 || stateBefore == 0);
}

rule validatorStateTransition_1in_M16(method f, env e, calldataarg args) filtered 
    { f -> !f.isView  && isMethodID(f, 16) }
{
    require isValidState();
    bytes validatorData;
    uint opIndex;
    require operatorStateIsValid(opIndex);  //key <= limit <= funded <= exited
    require getKeysCount(opIndex) <= 3; //should not be higher than loop_iter 
    uint stateBefore = getValidatorState(opIndex, validatorData);
    f(e, args);
    uint stateAfter = getValidatorState(opIndex, validatorData);
    assert (stateAfter == 1) =>
        (stateBefore == 2 || stateBefore == 1 || stateBefore == 0);
}

rule validatorStateTransition_2in_M16(method f, env e, calldataarg args) filtered 
    { f -> !f.isView  && isMethodID(f, 16) }
{
    require isValidState();
    bytes validatorData;
    uint opIndex;
    require operatorStateIsValid(opIndex);  //key <= limit <= funded <= exited
    require getKeysCount(opIndex) <= 3; //should not be higher than loop_iter 
    uint stateBefore = getValidatorState(opIndex, validatorData);
    f(e, args);
    uint stateAfter = getValidatorState(opIndex, validatorData);
    assert (stateAfter == 2) =>
        (stateBefore == 2 || stateBefore == 1);
}

rule validatorStateTransition_3in_M16(method f, env e, calldataarg args) filtered 
    { f -> !f.isView && isMethodID(f, 16) }
{
    require isValidState();
    bytes validatorData;
    uint opIndex;
    require operatorStateIsValid(opIndex);  //key <= limit <= funded <= exited
    require getKeysCount(opIndex) <= 3; //should not be higher than loop_iter 
    uint stateBefore = getValidatorState(opIndex, validatorData);
    f(e, args);
    uint stateAfter = getValidatorState(opIndex, validatorData);
    assert (stateAfter == 3) =>
        (stateBefore == 3 || stateBefore == 2);
}

rule validatorStateTransition_3_4_M13(method f, env e, calldataarg args) filtered 
    { f -> isMethodID(f, 13) }
{
    require isValidState();
    bytes validatorData;
    uint opIndex;
    require operatorStateIsValid(opIndex);  //key <= limit <= funded <= exited
    require getKeysCount(opIndex) <= 4; //should not be higher than loop_iter 
    uint stateBefore = getValidatorState(opIndex, validatorData);
    f(e, args);
    uint stateAfter = getValidatorState(opIndex, validatorData);
    assert (stateBefore == 3) =>
        (stateAfter == 3 || stateAfter == 4);
}

rule validatorStateTransition_3_4_M16(method f, env e, calldataarg args) filtered 
    { f -> isMethodID(f, 16) }
{
    require isValidState();
    bytes validatorData;
    uint opIndex;
    require operatorStateIsValid(opIndex);  //key <= limit <= funded <= exited
    require getKeysCount(opIndex) <= 4; //should not be higher than loop_iter 
    uint stateBefore = getValidatorState(opIndex, validatorData);
    f(e, args);
    uint stateAfter = getValidatorState(opIndex, validatorData);
    assert (stateBefore == 3) =>
        (stateAfter == 3 || stateAfter == 4);
}
