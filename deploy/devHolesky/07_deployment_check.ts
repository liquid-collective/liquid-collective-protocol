import { DeployFunction } from "hardhat-deploy/dist/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { isDeployed, logStep, logStepEnd } from "../../ts-utils/helpers/index";
import { getContractAddress } from "ethers/lib/utils";
import { verify } from "../../scripts/helpers";

const func: DeployFunction = async function ({
  deployments,
  getNamedAccounts,
  ethers,
  network,
}: HardhatRuntimeEnvironment) {
  const { deployer, governor, executor, proxyAdministrator, collector } = await getNamedAccounts();
  let proxyArtifact = await deployments.getArtifact("TUPProxy");
  let proxyInterface = new ethers.utils.Interface(proxyArtifact.abi);

  const riverDeployment = await deployments.get("River");
  const RiverContract = await ethers.getContractAt("RiverV1", riverDeployment.address);

  const riverFirewallDeployment = await deployments.get("RiverFirewall");
  const RiverFirewallContract = await ethers.getContractAt("Firewall", riverFirewallDeployment.address);

  const riverProxyFirewallDeployment = await deployments.get("RiverProxyFirewall");
  const RiverProxyFirewallContract = await ethers.getContractAt("Firewall", riverProxyFirewallDeployment.address);

  const oracleDeployment = await deployments.get("Oracle");
  const oracleContract = await ethers.getContractAt("OracleV1", oracleDeployment.address);

  const oracleFirewallDeployment = await deployments.get("OracleFirewall");
  const oracleFirewallContract = await ethers.getContractAt("Firewall", oracleFirewallDeployment.address);

  const oracleProxyFirewallDeployment = await deployments.get("OracleProxyFirewall");
  const oracleProxyFirewallContract = await ethers.getContractAt("Firewall", oracleProxyFirewallDeployment.address);

  const operatorsRegistryDeployment = await deployments.get("OperatorsRegistry");
  const operatorsRegistryContract = await ethers.getContractAt(
    "OperatorsRegistryV1",
    operatorsRegistryDeployment.address
  );

  const operatorsRegistryFirewallDeployment = await deployments.get("OperatorsRegistryFirewall");
  const operatorsRegistryFirewallContract = await ethers.getContractAt(
    "Firewall",
    operatorsRegistryFirewallDeployment.address
  );

  const operatorsRegistryProxyFirewallDeployment = await deployments.get("OperatorsRegistryProxyFirewall");
  const operatorsRegistryProxyFirewallContract = await ethers.getContractAt(
    "Firewall",
    operatorsRegistryProxyFirewallDeployment.address
  );

  const redeemManagerDeployment = await deployments.get("RedeemManager");
  const redeemManagerContract = await ethers.getContractAt("TUPProxy", redeemManagerDeployment.address);

  const redeemManagerFirewallDeployment = await deployments.get("RedeemManagerProxyFirewall");
  const redeemManagerFirewallContract = await ethers.getContractAt("Firewall", redeemManagerFirewallDeployment.address);

  const allowlistDeployment = await deployments.get("Allowlist");
  const allowlistContract = await ethers.getContractAt("AllowlistV1", allowlistDeployment.address);

  const allowlistFirewallDeployment = await deployments.get("AllowlistFirewall");
  const allowlistFirewallContract = await ethers.getContractAt("Firewall", allowlistFirewallDeployment.address);

  const allowlistProxyFirewallDeployment = await deployments.get("AllowlistProxyFirewall");
  const allowlistProxyFirewallContract = await ethers.getContractAt(
    "Firewall",
    allowlistProxyFirewallDeployment.address
  );

  const tlcDeployment = await deployments.get("TLC");
  const tlcContract = await ethers.getContractAt("TUPProxy", tlcDeployment.address);

  const tlcFirewallDeployment = await deployments.get("TLCProxyFirewall");
  const tlcFirewallContract = await ethers.getContractAt("Firewall", tlcFirewallDeployment.address);

  if (riverFirewallDeployment.address != (await RiverContract.callStatic.getAdmin())) {
    throw new Error("RiverFirewall address does not match River address");
  } else {
    console.log("RiverFirewall address matches River address");
  }

  if (governor != (await RiverFirewallContract.callStatic.getAdmin())) {
    throw new Error("Governor address does not match RiverFirewall address");
  } else {
    console.log("Governor address matches RiverFirewall address");
  }

  if (executor != (await RiverFirewallContract.callStatic.executor())) {
    throw new Error("Executor address does not match RiverFirewall address");
  } else {
    console.log("Executor address matches RiverFirewall address");
  }

  if (oracleDeployment.address != (await RiverContract.callStatic.getOracle())) {
    throw new Error("Oracle address does not match River address");
  } else {
    console.log("Oracle address matches River address");
  }

  if ((await oracleContract.getAdmin()) != oracleFirewallContract.address) {
    throw new Error("Oracle address does not match OracleFirewall address");
  } else {
    console.log("Oracle address matches OracleFirewall address");
  }

  if ((await oracleFirewallContract.getAdmin()) != governor) {
    throw new Error("Governor address does not match OracleFirewall address");
  } else {
    console.log("Governor address matches OracleFirewall address");
  }

  if ((await oracleFirewallContract.executor()) != executor) {
    throw new Error("Executor address does not match OracleFirewall address");
  } else {
    console.log("Executor address matches OracleFirewall address");
  }

  if ((await RiverContract.callStatic.getAllowlist()) != allowlistDeployment.address) {
    throw new Error("Allowlist address does not match River address");
  } else {
    console.log("Allowlist address matches River");
  }

  // Check if allowlist admin is allowlist firewall
  if ((await allowlistContract.callStatic.getAdmin()) != allowlistFirewallContract.address) {
    throw new Error("Allowlist address does not match AllowlistFirewall address");
  } else {
    console.log("Allowlist admin matches AllowlistFirewall address");
  }

  // Check if allowlist firewall admin is governor
  if ((await allowlistFirewallContract.callStatic.getAdmin()) != governor) {
    throw new Error("Governor address does not match AllowlistFirewall address");
  } else {
    console.log("Governor address matches AllowlistFirewall address");
  }

  // Check if allowlist firewall executor is executor
  if ((await allowlistFirewallContract.callStatic.executor()) != executor) {
    throw new Error("Executor address does not match AllowlistFirewall address");
  } else {
    console.log("Executor address matches AllowlistFirewall address");
  }

  // Check if operator registry is set correctly on river
  if ((await RiverContract.callStatic.getOperatorsRegistry()) != operatorsRegistryContract.address) {
    throw new Error("Operator registry address does not match River address");
  } else {
    console.log("Operator registry address matches River address");
  }

  // Check if operators registry admin is operator registry firewall
  if ((await operatorsRegistryContract.callStatic.getAdmin()) != operatorsRegistryFirewallContract.address) {
    throw new Error("Operator registry address does not match Operator registry firewall address");
  } else {
    console.log("Operator registry admin matches Operator registry firewall address");
  }

  // Check if operators registry firewall admin is governor
  if ((await operatorsRegistryFirewallContract.callStatic.getAdmin()) != governor) {
    throw new Error("Governor address does not match Operator registry firewall address");
  } else {
    console.log("Governor address matches Operator registry firewall address");
  }

  // Check if operators registry firewall executor is executor
  if ((await operatorsRegistryFirewallContract.callStatic.executor()) != executor) {
    throw new Error("Executor address does not match Operator registry firewall address");
  } else {
    console.log("Executor address matches Operator registry firewall address");
  }

  // Check if redeem manager firewall admin is proxyAdmin
  if ((await redeemManagerFirewallContract.callStatic.getAdmin()) != proxyAdministrator) {
    throw new Error("Redeem manager address does not match Redeem manager firewall address");
  } else {
    console.log("Redeem manager admin matches Redeem manager firewall address");
  }

  // Check if redeem manager firewall executor is executor
  if ((await redeemManagerFirewallContract.callStatic.executor()) != executor) {
    throw new Error("Executor address does not match Redeem manager firewall address");
  } else {
    console.log("Executor address matches Redeem manager firewall address");
  }

  // Permission check

  // Check if executor should not have permission to call addOperator
  if (
    await operatorsRegistryFirewallContract.callStatic.executorCanCall(
      operatorsRegistryContract.interface.getSighash("addOperator(string,address)")
    )
  ) {
    throw new Error("Executor have permission to call addOperator");
  } else {
    console.log("Executor should not have permission to call addOperator");
  }

  // Check if executor should not have permission to call setOperatorAddress
  if (
    await operatorsRegistryFirewallContract.callStatic.executorCanCall(
      operatorsRegistryContract.interface.getSighash("setOperatorAddress(uint256,address)")
    )
  ) {
    throw new Error("Executor have permission to call setOperatorAddress");
  } else {
    console.log("Executor should not have permission to call setOperatorAddress");
  }

  // Check if executor should not have permission to call setOperatorName
  if (
    await operatorsRegistryFirewallContract.callStatic.executorCanCall(
      operatorsRegistryContract.interface.getSighash("setOperatorName(uint256,string)")
    )
  ) {
    throw new Error("Executor have permission to call setOperatorName");
  } else {
    console.log("Executor should not have permission to call setOperatorName");
  }
  // Check if executor should not have permission to call setOperatorStatus
  if (
    await operatorsRegistryFirewallContract.callStatic.executorCanCall(
      operatorsRegistryContract.interface.getSighash("setOperatorStatus(uint256,bool)")
    )
  ) {
    throw new Error("Executor have permission to call setOperatorStatus");
  } else {
    console.log("Executor should not have permission to call setOperatorStatus");
  }

  // Check if executor should not have permission to call setOperatorLimits
  if (
    !(await operatorsRegistryFirewallContract.callStatic.executorCanCall(
      operatorsRegistryContract.interface.getSighash("setOperatorLimits(uint256[],uint32[],uint256)")
    ))
  ) {
    throw new Error("Executor have permission to call setOperatorLimits");
  } else {
    console.log("Executor should not have permission to call setOperatorLimits");
  }
  // Check if executor should not have permission to call addValidators
  if (
    await operatorsRegistryFirewallContract.callStatic.executorCanCall(
      operatorsRegistryContract.interface.getSighash("addValidators(uint256,uint32,bytes)")
    )
  ) {
    throw new Error("Executor have permission to call addValidators");
  } else {
    console.log("Executor should not have permission to call addValidators");
  }
  // Check if executor should not have permission to call removeValidators
  if (
    await operatorsRegistryFirewallContract.callStatic.executorCanCall(
      operatorsRegistryContract.interface.getSighash("removeValidators(uint256,uint256[])")
    )
  ) {
    throw new Error("Executor have permission to call removeValidators");
  } else {
    console.log("Executor should not have permission to call removeValidators");
  }

  // Check if executor should not have permission to call pause
  if (await operatorsRegistryFirewallContract.callStatic.executorCanCall(proxyInterface.getSighash("pause()"))) {
    throw new Error("Executor have permission to call pause");
  } else {
    console.log("Executor should not have permission to call pause");
  }
  // Check if executor should not have permission to call unpause
  if (await operatorsRegistryFirewallContract.callStatic.executorCanCall(proxyInterface.getSighash("unpause()"))) {
    throw new Error("Executor have permission to call unpause");
  } else {
    console.log("Executor should not have permission to call unpause");
  }

  //   Check if executor should not have permission to call changeAdmin
  if (
    await operatorsRegistryProxyFirewallContract.callStatic.executorCanCall(
      proxyInterface.getSighash("changeAdmin(address)")
    )
  ) {
    throw new Error("Executor have permission to call changeAdmin");
  } else {
    console.log("Executor should not have permission to call changeAdmin");
  }
  // Check if executor should not have permission to call upgrade
  if (
    await operatorsRegistryProxyFirewallContract.callStatic.executorCanCall(
      proxyInterface.getSighash("upgradeTo(address)")
    )
  ) {
    throw new Error("Executor have permission to call upgradeToAndCall");
  } else {
    console.log("Executor should not have permission to call upgradeToAndCall");
  }
  // Check if executor should not have permission to call upgradeToAndCall
  if (
    await operatorsRegistryProxyFirewallContract.callStatic.executorCanCall(
      proxyInterface.getSighash("upgradeToAndCall(address,bytes)")
    )
  ) {
    throw new Error("Executor have permission to call upgradeToAndCall");
  } else {
    console.log("Executor should not have permission to call upgradeToAndCall");
  }

  // Oracle Executor should not have permission to call addMember
  if (
    await oracleFirewallContract.callStatic.executorCanCall(
      oracleContract.interface.getSighash("addMember(address,uint256)")
    )
  ) {
    throw new Error("Executor have permission to call addMember");
  } else {
    console.log("Executor should not have permission to call addMember");
  }

  // Oracle Executor should not have permission to call removeMember
  if (
    await oracleFirewallContract.callStatic.executorCanCall(
      oracleContract.interface.getSighash("removeMember(address,uint256)")
    )
  ) {
    throw new Error("Executor have permission to call removeMember");
  } else {
    console.log("Executor should not have permission to call removeMember");
  }
  // Oracle Executor should not have permission to call setMember
  if (
    await oracleFirewallContract.callStatic.executorCanCall(
      oracleContract.interface.getSighash("setMember(address,address)")
    )
  ) {
    throw new Error("Executor have permission to call setMember");
  } else {
    console.log("Executor should not have permission to call setMember");
  }

  // Oracle Executor should not have permission to call setCLSpec
  if (await oracleFirewallContract.callStatic.executorCanCall("0x78a010e8")) {
    throw new Error("Executor have permission to call setCLSpec");
  } else {
    console.log("Executor should not have permission to call setCLSpec");
  }

  // Oracle Executor should not have permission to call setReportBounds
  if (
    await oracleFirewallContract.callStatic.executorCanCall(
      RiverContract.interface.getSighash("setReportBounds((uint256,uint256))")
    )
  ) {
    throw new Error("Executor have permission to call setReportBounds");
  } else {
    console.log("Executor should not have permission to call setReportBounds");
  }

  // Oracle Executor should not have permission to call setQuorum
  if (
    await oracleFirewallContract.callStatic.executorCanCall(oracleContract.interface.getSighash("setQuorum(uint256)"))
  ) {
    throw new Error("Executor have permission to call setQuorum");
  } else {
    console.log("Executor should not have permission to call setQuorum");
  }

  // Oracle Executor should not have permission to call reportConsensusLayerData
  if (
    await oracleFirewallContract.callStatic.executorCanCall(
      oracleContract.interface.getSighash(
        "reportConsensusLayerData((uint256,uint256,uint256,uint256,uint256,uint32,uint32[],bool,bool))"
      )
    )
  ) {
    throw new Error("Executor have permission to call reportConsensusLayerData");
  } else {
    console.log("Executor should not have permission to call reportConsensusLayerData");
  }

  // Oracle Executor should not have permission to call pause
  if (await oracleFirewallContract.callStatic.executorCanCall(proxyInterface.getSighash("pause()"))) {
    throw new Error("Executor have permission to call pause");
  } else {
    console.log("Executor should not have permission to call pause");
  }
  // Oracle Executor should not have permission to call unpause
  if (await oracleFirewallContract.callStatic.executorCanCall(proxyInterface.getSighash("unpause()"))) {
    throw new Error("Executor have permission to call unpause");
  } else {
    console.log("Executor should not have permission to call unpause");
  }
  // Oracle Executor should not have permission to call changeAdmin
  if (await oracleFirewallContract.callStatic.executorCanCall(proxyInterface.getSighash("changeAdmin(address)"))) {
    throw new Error("Executor have permission to call changeAdmin");
  } else {
    console.log("Executor should not have permission to call changeAdmin");
  }

  // Oracle Executor should not have permission to call upgrade
  if (await oracleFirewallContract.callStatic.executorCanCall(proxyInterface.getSighash("upgradeTo(address)"))) {
    throw new Error("Executor have permission to call upgradeToAndCall");
  } else {
    console.log("Executor should not have permission to call upgradeToAndCall");
  }
  // Oracle Executor should not have permission to call upgradeToAndCall
  if (
    await oracleFirewallContract.callStatic.executorCanCall(
      proxyInterface.getSighash("upgradeToAndCall(address,bytes)")
    )
  ) {
    throw new Error("Executor have permission to call upgradeToAndCall");
  } else {
    console.log("Executor should not have permission to call upgradeToAndCall");
  }

  // Allowlist Executor should not have permission to call setAllower
  if (
    await allowlistFirewallContract.callStatic.executorCanCall(
      allowlistContract.interface.getSighash("setAllower(address)")
    )
  ) {
    throw new Error("Executor have permission to call setAllower");
  } else {
    console.log("Executor should not have permission to call setAllower");
  }

  // Allowlist Executor should not have permission to call allow
  if (
    await allowlistFirewallContract.callStatic.executorCanCall(
      allowlistContract.interface.getSighash("allow(address[],uint256[])")
    )
  ) {
    throw new Error("Executor have permission to call allow");
  } else {
    console.log("Executor should not have permission to call allow");
  }

  // Allowlist Executor should not have permission to call pause
  if (await allowlistFirewallContract.callStatic.executorCanCall(proxyInterface.getSighash("pause()"))) {
    throw new Error("Executor have permission to call pause");
  } else {
    console.log("Executor should not have permission to call pause");
  }

  // Allowlist Executor should not have permission to call unpause
  if (await allowlistFirewallContract.callStatic.executorCanCall(proxyInterface.getSighash("unpause()"))) {
    throw new Error("Executor have permission to call unpause");
  } else {
    console.log("Executor should not have permission to call unpause");
  }

  // Allowlist Executor should not have permission to call changeAdmin
  if (await allowlistFirewallContract.callStatic.executorCanCall(proxyInterface.getSighash("changeAdmin(address)"))) {
    throw new Error("Executor have permission to call changeAdmin");
  } else {
    console.log("Executor should not have permission to call changeAdmin");
  }

  // Allowlist Executor should not have permission to call upgrade
  if (await allowlistFirewallContract.callStatic.executorCanCall(proxyInterface.getSighash("upgradeTo(address)"))) {
    throw new Error("Executor have permission to call upgradeToAndCall");
  } else {
    console.log("Executor should not have permission to call upgradeToAndCall");
  }
  // Allowlist Executor should not have permission to call upgradeToAndCall
  if (
    await allowlistFirewallContract.callStatic.executorCanCall(
      proxyInterface.getSighash("upgradeToAndCall(address,bytes)")
    )
  ) {
    throw new Error("Executor have permission to call upgradeToAndCall");
  } else {
    console.log("Executor should not have permission to call upgradeToAndCall");
  }

  // River Executor should not have permission to call setGlobalFee
  if (
    await RiverFirewallContract.callStatic.executorCanCall(RiverContract.interface.getSighash("setGlobalFee(uint256)"))
  ) {
    throw new Error("Executor have permission to call setGlobalFee");
  } else {
    console.log("Executor should not have permission to call setGlobalFee");
  }
  // River Executor should not have permission to call setRiver
  // if (
  //     await RiverFirewallContract.callStatic.executorCanCall(
  //     RiverContract.interface.getSighash("setRiver(address)")
  //     )
  // ) {
  //     throw new Error("Executor have permission to call setRiver");
  // } else {
  //     console.log("Executor should not have permission to call setRiver");
  // }
  // River Executor should not have permission to call setCollector
  if (
    await RiverFirewallContract.callStatic.executorCanCall(RiverContract.interface.getSighash("setCollector(address)"))
  ) {
    throw new Error("Executor have permission to call setCollector");
  } else {
    console.log("Executor should not have permission to call setCollector");
  }
  // River Executor should not have permission to call setELFeeRecipient
  if (
    await RiverFirewallContract.callStatic.executorCanCall(
      RiverContract.interface.getSighash("setELFeeRecipient(address)")
    )
  ) {
    throw new Error("Executor have permission to call setELFeeRecipient");
  } else {
    console.log("Executor should not have permission to call setELFeeRecipient");
  }
  // River Executor should not have permission to call setOracle
  if (
    await RiverFirewallContract.callStatic.executorCanCall(RiverContract.interface.getSighash("setOracle(address)"))
  ) {
    throw new Error("Executor have permission to call setOracle");
  } else {
    console.log("Executor should not have permission to call setOracle");
  }
  // River Executor should not have permission to call setConsensusLayerData
  if (
    await RiverFirewallContract.callStatic.executorCanCall(
      RiverContract.interface.getSighash(
        "setConsensusLayerData((uint256,uint256,uint256,uint256,uint256,uint32,uint32[],bool,bool))"
      )
    )
  ) {
    throw new Error("Executor have permission to call setConsensusLayerData");
  } else {
    console.log("Executor should not have permission to call setConsensusLayerData");
  }
  // River Executor should not have permission to call setDailyCommittableLimits
  if (
    await RiverFirewallContract.callStatic.executorCanCall(
      RiverContract.interface.getSighash("setDailyCommittableLimits((uint128,uint128))")
    )
  ) {
    throw new Error("Executor have permission to call setDailyCommittableLimits");
  } else {
    console.log("Executor should not have permission to call setDailyCommittableLimits");
  }
  // River Executor should not have permission to call setAllowlist
  if (
    await RiverFirewallContract.callStatic.executorCanCall(RiverContract.interface.getSighash("setAllowlist(address)"))
  ) {
    throw new Error("Executor have permission to call setAllowlist");
  } else {
    console.log("Executor should not have permission to call setAllowlist");
  }
  
  // River Executor should not have permission to call setCoverageFund
  if (
    await RiverFirewallContract.callStatic.executorCanCall(RiverContract.interface.getSighash("setCoverageFund(address)"))
  ) {
    throw new Error("Executor have permission to call setCoverageFund");
  } else {
    console.log("Executor should not have permission to call setCoverageFund");
  }

  // River Executor should not have permission to call setMetadataURI
  if (
    await RiverFirewallContract.callStatic.executorCanCall(RiverContract.interface.getSighash("setMetadataURI(string)"))
  ) {
    throw new Error("Executor have permission to call setMetadataURI");
  } else {
    console.log("Executor should not have permission to call setMetadataURI");
  }

  // River Executor should not have permission to call pause
    if (await RiverFirewallContract.callStatic.executorCanCall(proxyInterface.getSighash("pause()"))) {
        throw new Error("Executor have permission to call pause");
    } else {
        console.log("Executor should not have permission to call pause");
    }

  // River Executor should not have permission to call unpause
  if (await RiverFirewallContract.callStatic.executorCanCall(proxyInterface.getSighash("unpause()"))) {
    throw new Error("Executor have permission to call unpause");
  } else {
    console.log("Executor should not have permission to call unpause");
  }
  // River Executor should not have permission to call changeAdmin
  if (await RiverFirewallContract.callStatic.executorCanCall(proxyInterface.getSighash("changeAdmin(address)"))) {
    throw new Error("Executor have permission to call changeAdmin");
  } else {
    console.log("Executor should not have permission to call changeAdmin");
  }
  // River Executor should not have permission to call upgrade
  if (await RiverFirewallContract.callStatic.executorCanCall(proxyInterface.getSighash("upgradeTo(address)"))) {
    throw new Error("Executor have permission to call upgrade");
  } else {
    console.log("Executor should not have permission to call upgrade");
  }
  // River Executor should not have permission to call upgradeToAndCall
  if (await RiverFirewallContract.callStatic.executorCanCall(proxyInterface.getSighash("upgradeToAndCall(address,bytes)"))) {
    throw new Error("Executor have permission to call upgradeToAndCall");
  } else {
    console.log("Executor should not have permission to call upgradeToAndCall");
  }

  // Redeem Manager Executor should not have permission to call pause
    if (!await redeemManagerFirewallContract.callStatic.executorCanCall(proxyInterface.getSighash("pause()"))) {
        throw new Error("Executor have permission to call pause");
    } else {
        console.log("Executor should not have permission to call pause");
    }


  // Redeem Manager Executor should not have permission to call unpause
  if (await redeemManagerFirewallContract.callStatic.executorCanCall(proxyInterface.getSighash("unpause()"))) {
    throw new Error("Executor have permission to call unpause");
  } else {
    console.log("Executor should not have permission to call unpause");
  }
  
  // Redeem Manager Executor should not have permission to call changeAdmin
  if (await redeemManagerFirewallContract.callStatic.executorCanCall(proxyInterface.getSighash("changeAdmin(address)"))) {
    throw new Error("Executor have permission to call changeAdmin");
  } else {
    console.log("Executor should not have permission to call changeAdmin");
  }
  // Redeem Manager Executor should not have permission to call upgrade
  if (await redeemManagerFirewallContract.callStatic.executorCanCall(proxyInterface.getSighash("upgradeTo(address)"))) {
    throw new Error("Executor have permission to call upgrade");
  } else {
    console.log("Executor should not have permission to call upgrade");
  }
  // Redeem Manager Executor should not have permission to call upgradeToAndCall
  if (await redeemManagerFirewallContract.callStatic.executorCanCall(proxyInterface.getSighash("upgradeToAndCall(address,bytes)"))) {
    throw new Error("Executor have permission to call upgradeToAndCall");
  } else {
    console.log("Executor should not have permission to call upgradeToAndCall");
  }

  // TLC Executor should not have permission to call pause
  if (!await tlcFirewallContract.callStatic.executorCanCall(proxyInterface.getSighash("pause()"))) {
    throw new Error("Executor have permission to call pause");
  } else {
    console.log("Executor should not have permission to call pause");
  }
  // TLC Executor should not have permission to call unpause
  if (await tlcFirewallContract.callStatic.executorCanCall(proxyInterface.getSighash("unpause()"))) {
    throw new Error("Executor have permission to call unpause");
  } else {
    console.log("Executor should not have permission to call unpause");
  }
  // TLC Executor should not have permission to call changeAdmin
  if (await tlcFirewallContract.callStatic.executorCanCall(proxyInterface.getSighash("changeAdmin(address)"))) {
    throw new Error("Executor have permission to call changeAdmin");
  } else {
    console.log("Executor should not have permission to call changeAdmin");
  }
  // TLC Executor should not have permission to call upgrade
  if (await tlcFirewallContract.callStatic.executorCanCall(proxyInterface.getSighash("upgradeTo(address)"))) {
    throw new Error("Executor have permission to call upgrade");
  } else {
    console.log("Executor should not have permission to call upgrade");
  }
  // TLC Executor should not have permission to call upgradeToAndCall
  if (await tlcFirewallContract.callStatic.executorCanCall(proxyInterface.getSighash("upgradeToAndCall(address,bytes)"))) {
    throw new Error("Executor have permission to call upgradeToAndCall");
  } else {
    console.log("Executor should not have permission to call upgradeToAndCall");
  }

  // Operators Registry Executor should not have permission to call legacy setOperatorStoppedValidatorCount = $(cast call ${OPERATORS_REGISTRY_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast sig "setOperatorStoppedValidatorCount(uint256,uint256)"))"
  if (await operatorsRegistryFirewallContract.callStatic.executorCanCall(operatorsRegistryContract.interface.getSighash("reportStoppedValidatorCounts(uint32[],uint256)"))) {
    throw new Error("Executor have permission to call setOperatorStoppedValidatorCount");
  } else {
    console.log("Executor should not have permission to call setOperatorStoppedValidatorCount");
  }
  // Operators Registry Executor should not have permission to call legacy setOperatorLimits  = $(cast call ${OPERATORS_REGISTRY_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast sig "setOperatorLimits(uint256[],uint256[],uint256)"))"
  if (!await operatorsRegistryFirewallContract.callStatic.executorCanCall(operatorsRegistryContract.interface.getSighash("setOperatorLimits(uint256[],uint32[],uint256)"))) {
    throw new Error("Executor have permission to call setOperatorLimits");
  } else {
    console.log("Executor should not have permission to call setOperatorLimits");
  }
  // Operators Registry Executor should not have permission to call legacy addValidators = $(cast call ${OPERATORS_REGISTRY_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast sig "addValidators(uint256,uint256,bytes)"))"
  if (await operatorsRegistryFirewallContract.callStatic.executorCanCall(operatorsRegistryContract.interface.getSighash("addValidators(uint256,uint32,bytes)"))) {
    throw new Error("Executor have permission to call addValidators");
  } else {
    console.log("Executor should not have permission to call addValidators");
  }
  // Operators Registry Executor should not have permission to call legacy pickNextValidators = $(cast call ${OPERATORS_REGISTRY_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast sig "pickNextValidators(uint256)"))"
  if (await operatorsRegistryFirewallContract.callStatic.executorCanCall(operatorsRegistryContract.interface.getSighash("pickNextValidatorsToDeposit(uint256)"))) {
    throw new Error("Executor have permission to call pickNextValidators");
  } else {
    console.log("Executor should not have permission to call pickNextValidators");
  }

  // River Executor should not have permission to call legacy setConsensusLayerData = $(cast call ${RIVER_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast sig "setConsensusLayerData(uint256,uint256,bytes32,uint256)"))"
  if (await RiverFirewallContract.callStatic.executorCanCall(RiverContract.interface.getSighash("setConsensusLayerData((uint256,uint256,uint256,uint256,uint256,uint32,uint32[],bool,bool))"))) {
    throw new Error("Executor have permission to call setConsensusLayerData");
  } else {
    console.log("Executor should not have permission to call setConsensusLayerData");
  }
  // River Executor should not have permission to call legacy depositToConsensusLayer = $(cast call ${RIVER_FIREWALL} "executorCanCall(bytes4)(bool)" $(cast sig "depositToConsensusLayer(uint256)"))"
  if (await RiverFirewallContract.callStatic.executorCanCall(RiverContract.interface.getSighash("depositToConsensusLayer(uint256)"))) {
    throw new Error("Executor have permission to call depositToConsensusLayer");
  } else {
    console.log("Executor should not have permission to call depositToConsensusLayer");
  }

  //TODO: Also add tests for checking correct initialization of the contracts
  // EG: Check if redeem manager, elfeerecepient, etc. have been set correctly on river,etc.
};

func.skip = async function ({ deployments }: HardhatRuntimeEnvironment): Promise<boolean> {
  logStep(__filename);

  return false;
};

export default func;
