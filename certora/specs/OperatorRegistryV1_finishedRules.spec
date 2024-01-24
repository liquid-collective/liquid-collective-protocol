import "Sanity.spec";
import "CVLMath.spec";
import "OperatorRegistryV1_base.spec";

//Holds for loop iter 3 and at most 3 operators
//https://prover.certora.com/output/6893/3a9868a0e6644417a20fc6ab467b2674/?anonymousKey=9120cd1a469c6f54a750187052fdd95efdd53c9f
rule exitingValidatorsDecreasesDiscrepancy(env e) 
{
    require isValidState();
    uint index1; uint index2;
    uint discrepancyBefore = getOperatorsSaturationDiscrepancy(index1, index2);
    uint count;
    require count <= 1;
    requestValidatorExits(e, count);
    uint discrepancyAfter = getOperatorsSaturationDiscrepancy(index1, index2);
    assert discrepancyBefore > 0 => discrepancyBefore >= discrepancyAfter;
}

rule witness4_3ExitingValidatorsDecreasesDiscrepancy(env e) 
{
    require isValidState();
    uint index1; uint index2;
    uint discrepancyBefore = getOperatorsSaturationDiscrepancy(index1, index2);
    uint count;
    require count <= 1;
    requestValidatorExits(e, count);
    uint discrepancyAfter = getOperatorsSaturationDiscrepancy(index1, index2);
    satisfy discrepancyBefore == 4 && discrepancyAfter == 3;
}


