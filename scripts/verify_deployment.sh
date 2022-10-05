#! /bin/bash

# Set RIVER env variable to the address of the river contract

RIVER_FIREWALL=$(cast call ${RIVER} "getAdmin()(address)")
echo "River admin is ${RIVER_FIREWALL}"

RIVER_GOVERNOR=$(cast call ${RIVER_FIREWALL} "getAdmin()(address)")
echo "River Firewall governor is ${RIVER_GOVERNOR}"

RIVER_EXECUTOR=$(cast call ${RIVER_FIREWALL} "executor()(address)")
echo "River Firewall executor is ${RIVER_EXECUTOR}"

echo "River Global Fee is $(cast call ${RIVER} "getGlobalFee()(uint256)")"
echo "River Collector is $(cast call ${RIVER} "getCollector()(address)")"

ORACLE=$(cast call ${RIVER} "getOracle()(address)")
echo "River oracle is ${ORACLE}"

ORACLE_FIREWALL=$(cast call ${ORACLE} "getAdmin()(address)")
echo "Oracle admin is ${ORACLE_FIREWALL}"

ORACLE_GOVERNOR=$(cast call ${ORACLE_FIREWALL} "getAdmin()(address)")
echo "Oracle Firewall governor is ${ORACLE_GOVERNOR}"

ORACLE_EXECUTOR=$(cast call ${ORACLE_FIREWALL} "executor()(address)")
echo "Oracle Firewall executor is ${ORACLE_EXECUTOR}"

ALLOWLIST=$(cast call ${RIVER} "getAllowlist()(address)")
echo "River allowlist is ${ALLOWLIST}"

ALLOWLIST_FIREWALL=$(cast call ${ALLOWLIST} "getAdmin()(address)")
echo "Allowlist admin is ${ALLOWLIST_FIREWALL}"

ALLOWLIST_GOVERNOR=$(cast call ${ALLOWLIST_FIREWALL} "getAdmin()(address)")
echo "Allowlist Firewall governor is ${ALLOWLIST_GOVERNOR}"

ALLOWLIST_EXECUTOR=$(cast call ${ALLOWLIST_FIREWALL} "executor()(address)")
echo "Allowlist Firewall executor is ${ALLOWLIST_EXECUTOR}"

echo "Allowlist allower is $(cast call ${ALLOWLIST} "getAllower()(address)")"

OPERATORS_REGISTRY=$(cast call ${RIVER} "getOperatorsRegistry()(address)")
echo "River operators registry is ${OPERATORS_REGISTRY}"

OPERATORS_REGISTRY_FIREWALL=$(cast call ${OPERATORS_REGISTRY} "getAdmin()(address)")
echo "OperatorsRegistry admin is ${OPERATORS_REGISTRY_FIREWALL}"

OPERATORS_REGISTRY_GOVERNOR=$(cast call ${OPERATORS_REGISTRY_FIREWALL} "getAdmin()(address)")
echo "OperatorsRegistry Firewall governor is ${OPERATORS_REGISTRY_GOVERNOR}"

OPERATORS_REGISTRY_EXECUTOR=$(cast call ${OPERATORS_REGISTRY_FIREWALL} "executor()(address)")
echo "OperatorsRegistry Firewall executor is ${OPERATORS_REGISTRY_EXECUTOR}"

echo "Operators Registry's River is $(cast call ${OPERATORS_REGISTRY} "getRiver()(address)")"

echo "River el fee recipient is $(cast call ${RIVER} "getELFeeRecipient()(address)")"

echo "River withdrawal credentials are $(cast call ${RIVER} "getWithdrawalCredentials()(bytes32)")"

echo "Operators Registry Executor permission to call addOperator = $(cast call ${OPERATORS_REGISTRY_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast keccak "addOperator(string,address)" | head -c 10))"
echo "Operators Registry Executor permission to call setOperatorAddress = $(cast call ${OPERATORS_REGISTRY_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast keccak "setOperatorAddress(uint256,address)" | head -c 10))"
echo "Operators Registry Executor permission to call setOperatorName = $(cast call ${OPERATORS_REGISTRY_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast keccak "setOperatorName(uint256,string)" | head -c 10))"
echo "Operators Registry Executor permission to call setOperatorStatus = $(cast call ${OPERATORS_REGISTRY_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast keccak "setOperatorStatus(uint256,bool)" | head -c 10))"
echo "Operators Registry Executor permission to call setStoppedValidatorCount = $(cast call ${OPERATORS_REGISTRY_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast keccak "setOperatorStoppedValidatorCount(uint256,uint256)" | head -c 10))"
echo "Operators Registry Executor permission to call setOperatorLimits  = $(cast call ${OPERATORS_REGISTRY_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast keccak "setOperatorLimits(uint256[],uint256[],uint256)" | head -c 10))"
echo "Operators Registry Executor permission to call addValidators = $(cast call ${OPERATORS_REGISTRY_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast keccak "addValidators(uint256,uint256,bytes)" | head -c 10))"
echo "Operators Registry Executor permission to call removeValidators = $(cast call ${OPERATORS_REGISTRY_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast keccak "removeValidators(uint256,uint256[])" | head -c 10))"
echo "Operators Registry Executor permission to call pickNextValidators = $(cast call ${OPERATORS_REGISTRY_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast keccak "pickNextValidators(uint256)" | head -c 10))"

echo "Oracle Executor permission to call addMember = $(cast call ${ORACLE_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast keccak "addMember(address,uint256)" | head -c 10))"
echo "Oracle Executor permission to call removeMember = $(cast call ${ORACLE_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast keccak "removeMember(address,uint256)" | head -c 10))"
echo "Oracle Executor permission to call setMember = $(cast call ${ORACLE_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast keccak "setMember(address,address)" | head -c 10))"
echo "Oracle Executor permission to call setCLSpec = $(cast call ${ORACLE_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast keccak "setCLSpec(uint64,uint64,uint64,uint64)" | head -c 10))"
echo "Oracle Executor permission to call setReportBounds = $(cast call ${ORACLE_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast keccak "setReportBounds(uint256,uint256)" | head -c 10))"
echo "Oracle Executor permission to call setQuorum = $(cast call ${ORACLE_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast keccak "setQuorum(uint256)" | head -c 10))"
echo "Oracle Executor permission to call reportConsensusLayerData = $(cast call ${ORACLE_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast keccak "reportConsensusLayerData(uint256,uint64,uint32)" | head -c 10))"

echo "Allowlist Executor permission to call setAllower = $(cast call ${ALLOWLIST_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast keccak "setAllower(address)" | head -c 10))"
echo "Allowlist Executor permission to call allow = $(cast call ${ALLOWLIST_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast keccak "allow(address[],uint256[])" | head -c 10))"

echo "River Executor permission to call setGlobalFee = $(cast call ${RIVER_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast keccak "setGlobalFee(uint256)" | head -c 10))"
echo "River Executor permission to call setRiver = $(cast call ${RIVER_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast keccak "setRiver(address)" | head -c 10))"
echo "River Executor permission to call setCollector = $(cast call ${RIVER_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast keccak "setCollector(address)" | head -c 10))"
echo "River Executor permission to call setELFeeRecipient = $(cast call ${RIVER_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast keccak "setELFeeRecipient(address)" | head -c 10))"
echo "River Executor permission to call setOracle = $(cast call ${RIVER_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast keccak "setOracle(address)" | head -c 10))"
echo "River Executor permission to call setConsensusLayerData = $(cast call ${RIVER_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast keccak "setConsensusLayerData(uint256,uint256,bytes32,uint256)" | head -c 10))"
echo "River Executor permission to call depositToConsensusLayer = $(cast call ${RIVER_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast keccak "depositToConsensusLayer(uint256)" | head -c 10))"
