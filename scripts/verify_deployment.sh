#! /bin/bash

# Set RIVER env variable to the address of the river contract
# Set RIVER_PROXY_FIREWALL env variable to the address of the river proxy firewall contract
# Set ORACLE_PROXY_FIREWALL env variable to the address of the oracle proxy firewall contract
# Set ALLOWLIST_PROXY_FIREWALL env variable to the address of the allowlist proxy firewall contract
# Set OPERATORS_REGISTRY_PROXY_FIREWALL env variable to the address of the operators registry proxy firewall contract
# Set REDEEM_MANAGER_PROXY_FIREWALL env variable to the address of the redeem manager proxy firewall contract
# Set TLC_PROXY_FIREWALL env variable to the address of the tlc proxy firewall contract

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

echo "River coverage fund is $(cast call ${RIVER} "getCoverageFund()(address)")"
echo "River metadata uri is $(cast call ${RIVER} "getMetadataURI()(string)")"

echo "River withdrawal credentials are $(cast call ${RIVER} "getWithdrawalCredentials()(bytes32)")"

echo "Redeem Manager Proxy Firewall is ${REDEEM_MANAGER_PROXY_FIREWALL}"

REDEEM_MANAGER_PROXY_FIREWALL_ADMIN=$(cast call ${REDEEM_MANAGER_PROXY_FIREWALL} "getAdmin()(address)")
echo "Redeem Manager Proxy Firewall Governor is ${REDEEM_MANAGER_PROXY_FIREWALL_ADMIN}"

REDEEM_MANAGER_PROXY_FIREWALL_EXECUTOR=$(cast call ${REDEEM_MANAGER_PROXY_FIREWALL} "executor()(address)")
echo "Redeem Manager Proxy Firewall Executor is ${REDEEM_MANAGER_PROXY_FIREWALL_EXECUTOR}"

echo "Operators Registry Executor permission to call addOperator = $(cast call ${OPERATORS_REGISTRY_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast sig "addOperator(string,address)"))"
echo "Operators Registry Executor permission to call setOperatorAddress = $(cast call ${OPERATORS_REGISTRY_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast sig "setOperatorAddress(uint256,address)"))"
echo "Operators Registry Executor permission to call setOperatorName = $(cast call ${OPERATORS_REGISTRY_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast sig "setOperatorName(uint256,string)"))"
echo "Operators Registry Executor permission to call setOperatorStatus = $(cast call ${OPERATORS_REGISTRY_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast sig "setOperatorStatus(uint256,bool)"))"
echo "Operators Registry Executor permission to call setOperatorLimits  = $(cast call ${OPERATORS_REGISTRY_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast sig "setOperatorLimits(uint256[],uint32[],uint256)"))"
echo "Operators Registry Executor permission to call addValidators = $(cast call ${OPERATORS_REGISTRY_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast sig "addValidators(uint256,uint32,bytes)"))"
echo "Operators Registry Executor permission to call removeValidators = $(cast call ${OPERATORS_REGISTRY_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast sig "removeValidators(uint256,uint256[])"))"
echo "Operators Registry Executor permission to call pause = $(cast call ${OPERATORS_REGISTRY_PROXY_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast sig "pause()"))"
echo "Operators Registry Executor permission to call unpause = $(cast call ${OPERATORS_REGISTRY_PROXY_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast sig "unpause()"))"
echo "Operators Registry Executor permission to call changeAdmin = $(cast call ${OPERATORS_REGISTRY_PROXY_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast sig "changeAdmin()"))"
echo "Operators Registry Executor permission to call upgrade = $(cast call ${OPERATORS_REGISTRY_PROXY_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast sig "upgrade()"))"
echo "Operators Registry Executor permission to call upgradeToAndCall = $(cast call ${OPERATORS_REGISTRY_PROXY_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast sig "upgradeToAndCall()"))"

echo "Oracle Executor permission to call addMember = $(cast call ${ORACLE_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast sig "addMember(address,uint256)"))"
echo "Oracle Executor permission to call removeMember = $(cast call ${ORACLE_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast sig "removeMember(address,uint256)"))"
echo "Oracle Executor permission to call setMember = $(cast call ${ORACLE_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast sig "setMember(address,address)"))"
echo "Oracle Executor permission to call setCLSpec = $(cast call ${ORACLE_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast sig "setCLSpec(uint64,uint64,uint64,uint64)"))"
echo "Oracle Executor permission to call setReportBounds = $(cast call ${ORACLE_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast sig "setReportBounds(uint256,uint256)"))"
echo "Oracle Executor permission to call setQuorum = $(cast call ${ORACLE_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast sig "setQuorum(uint256)"))"
echo "Oracle Executor permission to call reportConsensusLayerData = $(cast call ${ORACLE_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast sig "reportConsensusLayerData(uint256,uint64,uint32)"))"
echo "Oracle Executor permission to call pause = $(cast call ${ORACLE_PROXY_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast sig "pause()"))"
echo "Oracle Executor permission to call unpause = $(cast call ${ORACLE_PROXY_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast sig "unpause()"))"
echo "Oracle Executor permission to call changeAdmin = $(cast call ${ORACLE_PROXY_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast sig "changeAdmin()"))"
echo "Oracle Executor permission to call upgrade = $(cast call ${ORACLE_PROXY_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast sig "upgrade()"))"
echo "Oracle Executor permission to call upgradeToAndCall = $(cast call ${ORACLE_PROXY_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast sig "upgradeToAndCall()"))"

echo "Allowlist Executor permission to call setAllower = $(cast call ${ALLOWLIST_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast sig "setAllower(address)"))"
echo "Allowlist Executor permission to call allow = $(cast call ${ALLOWLIST_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast sig "allow(address[],uint256[])"))"
echo "Allowlist Executor permission to call pause = $(cast call ${ALLOWLIST_PROXY_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast sig "pause()"))"
echo "Allowlist Executor permission to call unpause = $(cast call ${ALLOWLIST_PROXY_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast sig "unpause()"))"
echo "Allowlist Executor permission to call changeAdmin = $(cast call ${ALLOWLIST_PROXY_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast sig "changeAdmin()"))"
echo "Allowlist Executor permission to call upgrade = $(cast call ${ALLOWLIST_PROXY_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast sig "upgrade()"))"
echo "Allowlist Executor permission to call upgradeToAndCall = $(cast call ${ALLOWLIST_PROXY_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast sig "upgradeToAndCall()"))"

echo "River Executor permission to call setGlobalFee = $(cast call ${RIVER_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast sig "setGlobalFee(uint256)"))"
echo "River Executor permission to call setRiver = $(cast call ${RIVER_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast sig "setRiver(address)"))"
echo "River Executor permission to call setCollector = $(cast call ${RIVER_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast sig "setCollector(address)"))"
echo "River Executor permission to call setELFeeRecipient = $(cast call ${RIVER_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast sig "setELFeeRecipient(address)"))"
echo "River Executor permission to call setOracle = $(cast call ${RIVER_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast sig "setOracle(address)"))"
echo "River Executor permission to call setConsensusLayerData = $(cast call ${RIVER_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast sig "setConsensusLayerData(uint256,uint256,uint256,uint256,uint256,uint32,uint32[],bool,bool)"))"
echo "River Executor permission to call setDailyCommittableLimits = $(cast call ${RIVER_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast sig "setDailyCommittableLimits(uint128,uint128)"))"
echo "River Executor permission to call setAllowlist = $(cast call ${RIVER_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast sig "setAllowlist(address)"))"
echo "River Executor permission to call setCoverageFund = $(cast call ${RIVER_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast sig "setCoverageFund(address)"))"
echo "River Executor permission to call setMetadataURI = $(cast call ${RIVER_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast sig "setMetadataURI(string)"))"
echo "River Executor permission to call pause = $(cast call ${RIVER_PROXY_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast sig "pause()"))"
echo "River Executor permission to call unpause = $(cast call ${RIVER_PROXY_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast sig "unpause()"))"
echo "River Executor permission to call changeAdmin = $(cast call ${RIVER_PROXY_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast sig "changeAdmin()"))"
echo "River Executor permission to call upgrade = $(cast call ${RIVER_PROXY_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast sig "upgrade()"))"
echo "River Executor permission to call upgradeToAndCall = $(cast call ${RIVER_PROXY_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast sig "upgradeToAndCall()"))"

echo "Redeem Manager Executor permission to call pause = $(cast call ${REDEEM_MANAGER_PROXY_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast sig "pause()"))"
echo "Redeem Manager Executor permission to call unpause = $(cast call ${REDEEM_MANAGER_PROXY_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast sig "unpause()"))"
echo "Redeem Manager Executor permission to call changeAdmin = $(cast call ${REDEEM_MANAGER_PROXY_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast sig "changeAdmin()"))"
echo "Redeem Manager Executor permission to call upgrade = $(cast call ${REDEEM_MANAGER_PROXY_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast sig "upgrade()"))"
echo "Redeem Manager Executor permission to call upgradeToAndCall = $(cast call ${REDEEM_MANAGER_PROXY_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast sig "upgradeToAndCall()"))"

echo "TLC Executor permission to call pause = $(cast call ${TLC_PROXY_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast sig "pause()"))"
echo "TLC Executor permission to call unpause = $(cast call ${TLC_PROXY_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast sig "unpause()"))"
echo "TLC Executor permission to call changeAdmin = $(cast call ${TLC_PROXY_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast sig "changeAdmin()"))"
echo "TLC Executor permission to call upgrade = $(cast call ${TLC_PROXY_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast sig "upgrade()"))"
echo "TLC Executor permission to call upgradeToAndCall = $(cast call ${TLC_PROXY_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast sig "upgradeToAndCall()"))"

# Legacy functions checks

echo "Operators Registry Executor permission to call legacy setOperatorStoppedValidatorCount = $(cast call ${OPERATORS_REGISTRY_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast sig "setOperatorStoppedValidatorCount(uint256,uint256)"))"
echo "Operators Registry Executor permission to call legacy setOperatorLimits  = $(cast call ${OPERATORS_REGISTRY_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast sig "setOperatorLimits(uint256[],uint256[],uint256)"))"
echo "Operators Registry Executor permission to call legacy addValidators = $(cast call ${OPERATORS_REGISTRY_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast sig "addValidators(uint256,uint256,bytes)"))"
echo "Operators Registry Executor permission to call legacy pickNextValidators = $(cast call ${OPERATORS_REGISTRY_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast sig "pickNextValidators(uint256)"))"

echo "River Executor permission to call legacy setConsensusLayerData = $(cast call ${RIVER_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast sig "setConsensusLayerData(uint256,uint256,bytes32,uint256)"))"
echo "River Executor permission to call legacy depositToConsensusLayer = $(cast call ${RIVER_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast sig "depositToConsensusLayer(uint256)"))"
