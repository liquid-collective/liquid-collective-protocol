/**
@title Example specification with Certora Prover. 
@note See https://docs.certora.com for a complete guide.
***/


/*
    Declaration of methods that are used in the rules. `envfree` indicates that
    the method is not dependent on the environment (`msg.value`, `msg.sender`).
    Methods that are not declared here are assumed to be dependent on the
    environment.
*/

methods {
    function getOperatorAddress(uint256) external returns(address) envfree;
    function getLatestKeysEditBlockNumber(uint256 opIndex) external 
        returns (uint64) envfree;
    function getOperatorState(uint256 opIndex) external 
        returns (uint32, uint32, uint32, uint32, uint32, bool, address) envfree;
    function getAdmin() external returns (address) envfree;
    
}

/**
    @title - integrity of a successful (non reverting) to setOperatorLimits()
    // todo - violated, undersntad why and fix  
**/
rule integritySetOperatorLimits() {
    env e; // represents global solidity variables such as msg.sender, block.timestamp 
    
    // arbitrary arguments to setOperatorLimits
    uint256[] operatorIndexes;
    uint32[] newLimits;
    uint256 snapshotBlock;
    
    // select an element from the array 
    uint256 i;
    require i < operatorIndexes.length;
    uint256 opIndex = operatorIndexes[i];
    
    uint32 limitAfter;
    _, limitAfter, _, _, _, _, _ = getOperatorState(e, opIndex);
    setOperatorLimits(e, operatorIndexes, newLimits, snapshotBlock );

    assert limitAfter == newLimits[i];
    
}



/** 
    @title  Revert case of setOperatorLimits
    @dev lastReverted references the last call to solidity 
**/  
rule revertSetOperatorLimits() {
    env e;
    
    uint256[] operatorIndexes;
    uint32[] newLimits;
    uint256 snapshotBlock;
    
    setOperatorLimits@withrevert(e, operatorIndexes, newLimits, snapshotBlock );
    bool reverted = lastReverted;
    // todo - is this correct? 
    assert getAdmin() == e.msg.sender || reverted; 

}


/** 
    @title Check that some case can occur 
**/  
rule witnessSetOperatorLimits() {
    uint256 i;

    uint256[] operatorIndexes;
    uint32[] newLimits;
    uint256 snapshotBlock;

    require i < operatorIndexes.length;
    uint256 opIndex = operatorIndexes[i];
    env e;

    uint32 limitBefore;
    uint256 latestKeysEditBlockNumber;

    _, limitBefore, _, _, _, _, _ = getOperatorState(opIndex);
    latestKeysEditBlockNumber = getLatestKeysEditBlockNumber(opIndex);

    setOperatorLimits(e, operatorIndexes, newLimits, snapshotBlock );
    
    uint32 limitAfter;
    _, limitAfter, _, _, _, _, _ = getOperatorState(opIndex);
    satisfy limitAfter == limitBefore;

}

/** 
    @title Relational property - compares two cases on the same state
**/  
rule compare() {

    env e;
    uint256[] operatorIndexes;
    uint32[] newLimits;
    uint256 snapshotBlock;
    
    storage init = lastStorage;  //take a snapshot of the storage
    setOperatorLimits(e, operatorIndexes, newLimits, snapshotBlock );

    uint256 snapshotBlock2;
    setOperatorLimits@withrevert(e, operatorIndexes, newLimits, snapshotBlock2 ) at init; //back to the init state
    //todo - continue 
    assert true; 


} 