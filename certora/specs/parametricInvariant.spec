/**
    # Example specification - using parametric rules and invariants
**/

methods {
    function getOperatorsCount() external returns (uint256) envfree;
    function operatorIsActive(uint256) external returns (bool) envfree;
    function operatorStateIsValid_cond2(uint256 opIndex) external returns (bool) envfree;
}


/** 
    @title Only `addOperator` can increase the number of operators
    This is an example of a parametric rule.
    This rule is missing another function that can increase the number of operators.
**/
rule onlyAddOperatorIncreasesOperatorsNum(method f) {
    uint256 numOperatorsBefore = getOperatorsCount();

    env e;
    calldataarg args;
    f(e, args);

    uint256 numOperatorsAfter = getOperatorsCount();

    assert (
        numOperatorsAfter > numOperatorsBefore =>
        f.selector == sig:addOperator(string, address).selector
    ), "Only addOperator can add an operator";
}


/** 
    @title The number of operators can only grow by 1
    This rule has a common type error.
**/
/*
rule numOperatorsOnlyIncreasesByOne(method f) {
    uint256 numOperatorsBefore = getOperatorsCount();

    env e;
    calldataarg args;
    f(e, args);

    uint256 numOperatorsAfter = getOperatorsCount();

    assert (
        numOperatorsAfter <= numOperatorsBefore + 1,
        "Only one operator can be added"
    );
}*/


/**
    @title Active operators are in a valid state
**/
invariant operatorsAreValidlyFunded(uint256 opIndex)
    operatorStateIsValid_cond2(opIndex)
    {
        preserved {
            require opIndex < getOperatorsCount();
            require getOperatorsCount() < 2^32;
        }
    }
