import "Sanity.spec";
import "CVLMath.spec";
import "OperatorRegistryV1_base.spec";

use rule method_reachability;

rule validatorStateTransition_0in_index(method f, env e, calldataarg args) filtered 
    { f -> !f.isView }// isMethodID(f, 7) }
{
    require isValidState();
    uint opIndex; uint valIndex;
    require operatorStateIsValid(opIndex);  //key <= limit <= funded <= exited
    require getKeysCount(opIndex) <= 4; //should not be higher than loop_iter 
    require isValIndexInBounds(opIndex, valIndex);
    uint stateBefore = getValidatorStateByIndex(opIndex, valIndex);
    f(e, args);
    uint stateAfter = getValidatorStateByIndex(opIndex, valIndex);
    assert (stateAfter == 0) =>
        (stateBefore == 2 || stateBefore == 1 || stateBefore == 0);
}

rule validatorStateTransition_1in_index(method f, env e, calldataarg args) filtered 
    { f -> !f.isView }// isMethodID(f, 7) }
{
    require isValidState();
    uint opIndex; uint valIndex;
    require operatorStateIsValid(opIndex);  //key <= limit <= funded <= exited
    require getKeysCount(opIndex) <= 4; //should not be higher than loop_iter 
    require isValIndexInBounds(opIndex, valIndex);
    uint stateBefore = getValidatorStateByIndex(opIndex, valIndex);
    f(e, args);
    uint stateAfter = getValidatorStateByIndex(opIndex, valIndex);
    assert (stateAfter == 1) =>
        (stateBefore == 2 || stateBefore == 1 || stateBefore == 0);
}

rule validatorStateTransition_2in_index(method f, env e, calldataarg args) filtered 
    { f -> !f.isView }// isMethodID(f, 7) }
{
    require isValidState();
    uint opIndex; uint valIndex;
    require operatorStateIsValid(opIndex);  //key <= limit <= funded <= exited
    require getKeysCount(opIndex) <= 4; //should not be higher than loop_iter 
    require isValIndexInBounds(opIndex, valIndex);
    uint stateBefore = getValidatorStateByIndex(opIndex, valIndex);
    f(e, args);
    uint stateAfter = getValidatorStateByIndex(opIndex, valIndex);
    assert (stateAfter == 2) =>
        (stateBefore == 2 || stateBefore == 1);
}

rule validatorStateTransition_3in_index(method f, env e, calldataarg args) filtered 
    { f -> !f.isView }// isMethodID(f, 7) }
{
    require isValidState();
    uint opIndex; uint valIndex;
    require operatorStateIsValid(opIndex);  //key <= limit <= funded <= exited
    require getKeysCount(opIndex) <= 4; //should not be higher than loop_iter 
    require isValIndexInBounds(opIndex, valIndex);
    uint stateBefore = getValidatorStateByIndex(opIndex, valIndex);
    f(e, args);
    uint stateAfter = getValidatorStateByIndex(opIndex, valIndex);
    assert (stateAfter == 3) =>
        (stateBefore == 3 || stateBefore == 2);
}

rule validatorStateTransition_4in_index(method f, env e, calldataarg args) filtered 
    { f -> !f.isView }// isMethodID(f, 7) }
{
    require isValidState();
    uint opIndex; uint valIndex;
    require operatorStateIsValid(opIndex);  //key <= limit <= funded <= exited
    require getKeysCount(opIndex) <= 4; //should not be higher than loop_iter 
    require isValIndexInBounds(opIndex, valIndex);
    uint stateBefore = getValidatorStateByIndex(opIndex, valIndex);
    f(e, args);
    uint stateAfter = getValidatorStateByIndex(opIndex, valIndex);
    assert (stateAfter == 4) =>
        (stateBefore == 3 || stateBefore == 4);
}

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

rule validatorStateTransition_3in_M15(method f, env e, calldataarg args) filtered 
    { f -> !f.isView && isMethodID(f, 15) }
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

rule validatorStateTransition_3in_M9(env e)
{
    require isValidState();
    bytes validatorData;
    uint opIndex;
    require operatorStateIsValid(opIndex);  //key <= limit <= funded <= exited
    require getKeysCount(opIndex) <= 3; //should not be higher than loop_iter 
    uint stateBefore = getValidatorState(opIndex, validatorData);
    uint256[] _indexes;
    require _indexes.length <= 2;
    removeValidators(opIndex, _indexes);
    uint stateAfter = getValidatorState(opIndex, validatorData);
    assert (stateAfter == 3) =>
        (stateBefore == 3 || stateBefore == 2);
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

rule validatorStateTransition_2in_M15(method f, env e, calldataarg args) filtered 
    { f -> !f.isView  && isMethodID(f, 15) }
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

rule validatorStateTransition_2in_M9(env e)
{
    require isValidState();
    bytes validatorData;
    uint opIndex;
    require operatorStateIsValid(opIndex);  //key <= limit <= funded <= exited
    require getKeysCount(opIndex) <= 3; //should not be higher than loop_iter 
    uint stateBefore = getValidatorState(opIndex, validatorData);
    uint256[] _indexes;
    require _indexes.length <= 2;
    removeValidators(opIndex, _indexes);
    uint stateAfter = getValidatorState(opIndex, validatorData);
    assert (stateAfter == 2) =>
        (stateBefore == 2 || stateBefore == 1);
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

rule validatorStateTransition_1in_M15(method f, env e, calldataarg args) filtered 
    { f -> !f.isView  && isMethodID(f, 15) }
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

rule validatorStateTransition_1in_M9(env e)
{
    require isValidState();
    bytes validatorData;
    uint opIndex;
    require operatorStateIsValid(opIndex);  //key <= limit <= funded <= exited
    require getKeysCount(opIndex) <= 3; //should not be higher than loop_iter 
    uint stateBefore = getValidatorState(opIndex, validatorData);
    uint256[] _indexes;
    require _indexes.length <= 2;
    removeValidators(opIndex, _indexes);
    uint stateAfter = getValidatorState(opIndex, validatorData);
    assert (stateAfter == 1) =>
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

rule validatorStateTransition_0in_M9(method f, env e, calldataarg args) filtered 
    { f -> !f.isView  && isMethodID(f, 9) }
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

rule validatorStateTransition_4in_M9(env e)
{
    require isValidState();
    bytes validatorData;
    uint opIndex;
    require operatorStateIsValid(opIndex);  //key <= limit <= funded <= exited
    require getKeysCount(opIndex) <= 4; //should not be higher than loop_iter 
    uint stateBefore = getValidatorState(opIndex, validatorData);
    uint256[] _indexes;
    require _indexes.length <= 2;
    removeValidators(opIndex, _indexes);
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
    require getKeysCount(opIndex) <= 3; //should not be higher than loop_iter 
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

rule validatorStateTransition_4_3_M15(env e)
{
    require isValidState();
    bytes validatorData;
    uint opIndex;
    require operatorStateIsValid(opIndex);  //key <= limit <= funded <= exited
    require getKeysCount(opIndex) <= 3; //should not be higher than loop_iter 
    uint stateBefore = getValidatorState(opIndex, validatorData);
    uint256[] _indexes;
    require _indexes.length <= 2;
    removeValidators(opIndex, _indexes);
    uint stateAfter = getValidatorState(opIndex, validatorData);
    assert (stateAfter == 4) =>
        (stateBefore == 3 || stateBefore == 4);
}

rule validatorStateTransition_4_3_M16(method f, env e, calldataarg args) filtered 
    { f -> isMethodID(f, 16) }
{
    require isValidState();
    bytes validatorData;
    uint opIndex;
    require operatorStateIsValid(opIndex);  //key <= limit <= funded <= exited
    require getKeysCount(opIndex) <= 3; //should not be higher than loop_iter 
    uint stateBefore = getValidatorState(opIndex, validatorData);
    f(e, args);
    uint stateAfter = getValidatorState(opIndex, validatorData);
    assert (stateAfter == 4) =>
        (stateBefore == 3 || stateBefore == 4);
}

// if the key is below limit and goes above the limit, it could only happen when limi decreased
rule _2_1_index_limit_15(method f, env e, calldataarg args) filtered 
    { f -> !f.isView && (isMethodID(f, 15)) }
{
    require isValidState();
    bytes validatorData;
    uint opIndex;
    require operatorStateIsValid(opIndex);  //key <= limit <= funded <= exited
    uint limitBefore;
    _, limitBefore, _, _, _, _, _ = getOperatorState(e, opIndex);
    require getKeysCount(opIndex) <= 3; //should not be higher than loop_iter 
    uint stateBefore = getValidatorState(opIndex, validatorData);
    f(e,args);
    uint stateAfter = getValidatorState(opIndex, validatorData);
    uint limitAfter;
    _, limitAfter, _, _, _, _, _ = getOperatorState(e, opIndex);
    assert (stateBefore == 2 && stateAfter == 1) => limitAfter < limitBefore;
}

 


