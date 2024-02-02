import "Sanity.spec";
import "CVLMath.spec";
import "OperatorRegistryV1_base.spec";

use rule method_reachability;

rule validatorStateTransition_3_2(method f, env e, calldataarg args) filtered 
    { f -> !f.isView }// isMethodID(f, 7) }
{
    require isValidState();
    bytes validatorData;
    uint opIndex;
    require operatorStateIsValid(opIndex);  //key <= limit <= funded <= exited
    require getKeysCount(opIndex) <= 4; //should not be higher than loop_iter 
    uint stateBefore = getValidatorState(opIndex, validatorData);
    f(e, args);
    uint stateAfter = getValidatorState(opIndex, validatorData);
    assert (stateAfter == 3) =>
        (stateBefore == 3 || stateBefore == 2);
}

rule validatorStateTransition_3in(method f, env e, calldataarg args) filtered 
    { f -> !f.isView }// isMethodID(f, 7) }
{
    require isValidState();
    bytes validatorData;
    uint opIndex;
    require operatorStateIsValid(opIndex);  //key <= limit <= funded <= exited
    require getKeysCount(opIndex) <= 4; //should not be higher than loop_iter 
    uint stateBefore = getValidatorState(opIndex, validatorData);
    f(e, args);
    uint stateAfter = getValidatorState(opIndex, validatorData);
    assert (stateAfter == 3) =>
        (stateBefore == 3 || stateBefore == 2);
}

rule validatorStateTransition_2in(method f, env e, calldataarg args) filtered 
    { f -> !f.isView }// isMethodID(f, 7) }
{
    require isValidState();
    bytes validatorData;
    uint opIndex;
    require operatorStateIsValid(opIndex);  //key <= limit <= funded <= exited
    require getKeysCount(opIndex) <= 4; //should not be higher than loop_iter 
    uint stateBefore = getValidatorState(opIndex, validatorData);
    f(e, args);
    uint stateAfter = getValidatorState(opIndex, validatorData);
    assert (stateAfter == 2) =>
        (stateBefore == 2 || stateBefore == 1);
}

rule validatorStateTransition_3_4_M7(method f, env e, calldataarg args) filtered 
    { f -> isMethodID(f, 7) }
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

rule validatorStateTransition_3_4_M9(method f, env e, calldataarg args) filtered 
    { f -> isMethodID(f, 9) }
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

rule validatorStateTransition_3_4_M10(method f, env e, calldataarg args) filtered 
    { f -> isMethodID(f, 10) }
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

rule validatorStateTransition_3_4_M12(method f, env e, calldataarg args) filtered 
    { f -> isMethodID(f, 12) }
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

rule validatorStateTransition_3_4_M14(method f, env e, calldataarg args) filtered 
    { f -> isMethodID(f, 14) }
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

rule validatorStateTransition_3_4_M15(method f, env e, calldataarg args) filtered 
    { f -> isMethodID(f, 15) }
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

rule validatorStateTransition_4_3_M7(method f, env e, calldataarg args) filtered 
    { f -> isMethodID(f, 7) }
{
    require isValidState();
    bytes validatorData;
    uint opIndex;
    require operatorStateIsValid(opIndex);  //key <= limit <= funded <= exited
    require getKeysCount(opIndex) <= 4; //should not be higher than loop_iter 
    uint stateBefore = getValidatorState(opIndex, validatorData);
    f(e, args);
    uint stateAfter = getValidatorState(opIndex, validatorData);
    assert (stateAfter == 4) =>
        (stateBefore == 3 || stateBefore == 4);
}

rule validatorStateTransition_4_3_M9(method f, env e, calldataarg args) filtered 
    { f -> isMethodID(f, 9) }
{
    require isValidState();
    bytes validatorData;
    uint opIndex;
    require operatorStateIsValid(opIndex);  //key <= limit <= funded <= exited
    require getKeysCount(opIndex) <= 4; //should not be higher than loop_iter 
    uint stateBefore = getValidatorState(opIndex, validatorData);
    f(e, args);
    uint stateAfter = getValidatorState(opIndex, validatorData);
    assert (stateAfter == 4) =>
        (stateBefore == 3 || stateBefore == 4);
}

rule validatorStateTransition_4_3_M10(method f, env e, calldataarg args) filtered 
    { f -> isMethodID(f, 10) }
{
    require isValidState();
    bytes validatorData;
    uint opIndex;
    require operatorStateIsValid(opIndex);  //key <= limit <= funded <= exited
    require getKeysCount(opIndex) <= 4; //should not be higher than loop_iter 
    uint stateBefore = getValidatorState(opIndex, validatorData);
    f(e, args);
    uint stateAfter = getValidatorState(opIndex, validatorData);
    assert (stateAfter == 4) =>
        (stateBefore == 3 || stateBefore == 4);
}



rule validatorStateTransition_4_3_M12(method f, env e, calldataarg args) filtered 
    { f -> isMethodID(f, 12) }
{
    require isValidState();
    bytes validatorData;
    uint opIndex;
    require operatorStateIsValid(opIndex);  //key <= limit <= funded <= exited
    require getKeysCount(opIndex) <= 4; //should not be higher than loop_iter 
    uint stateBefore = getValidatorState(opIndex, validatorData);
    f(e, args);
    uint stateAfter = getValidatorState(opIndex, validatorData);
    assert (stateAfter == 4) =>
        (stateBefore == 3 || stateBefore == 4);
}

rule validatorStateTransition_4_3_M13(method f, env e, calldataarg args) filtered 
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
    assert (stateAfter == 4) =>
        (stateBefore == 3 || stateBefore == 4);
}

rule validatorStateTransition_4_3_M14(method f, env e, calldataarg args) filtered 
    { f -> isMethodID(f, 14) }
{
    require isValidState();
    bytes validatorData;
    uint opIndex;
    require operatorStateIsValid(opIndex);  //key <= limit <= funded <= exited
    require getKeysCount(opIndex) <= 4; //should not be higher than loop_iter 
    uint stateBefore = getValidatorState(opIndex, validatorData);
    f(e, args);
    uint stateAfter = getValidatorState(opIndex, validatorData);
    assert (stateAfter == 4) =>
        (stateBefore == 3 || stateBefore == 4);
}

rule validatorStateTransition_4_3_M15(method f, env e, calldataarg args) filtered 
    { f -> isMethodID(f, 15) }
{
    require isValidState();
    bytes validatorData;
    uint opIndex;
    require operatorStateIsValid(opIndex);  //key <= limit <= funded <= exited
    require getKeysCount(opIndex) <= 4; //should not be higher than loop_iter 
    uint stateBefore = getValidatorState(opIndex, validatorData);
    f(e, args);
    uint stateAfter = getValidatorState(opIndex, validatorData);
    assert (stateAfter == 4) =>
        (stateBefore == 3 || stateBefore == 4);
}



 


