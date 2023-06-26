import hre from "hardhat";
import path from 'path';
import fs from 'fs';
import rimraf from 'rimraf';

const merge = (a: any, afs: string[], b: any, bfs: string[]): any => {
  const m = {}

  for (const af of afs) {
    if (bfs.includes(af)) {
      throw new Error(`Conflicting field in artifacts ${af}`)
    }
  }

  const fields = Object.keys(a);
  for (const field of fields) {
    if (bfs.includes(field)) {
      m[field] = b[field]
    } else {
      m[field] = a[field]
    }
  }

  return m;
}

const mergeImplemsAndProxy = (imps: any[], impNames: string[], proxy: any): any => ({
  address: proxy.address,
  abi: [...imps[imps.length - 1].abi, ...proxy.abi].filter((a: any) => a.type !== "constructor"),
  transactionHash: proxy.transactionHash,
  receipt: proxy.receipt,
  args: proxy.args,
  numDeployments: proxy.numDeployments,
  solcInputHash: proxy.solcInputHash,
  metadata: proxy.metadata,
  bytecode: imps[imps.length - 1].bytecode,
  deployedBytecode: imps[imps.length - 1].deployedBytecode,
  devdoc: proxy.devdoc,
  userdoc: proxy.userdoc,
  storageLayout: proxy.storageLayout,
  implementations: {
    names: impNames,
    transactionHash: imps.map(i => i.transactionHash),
    receipt: imps.map(i => i.receipt),
    args: imps.map(i => i.args),
    numDeployments: imps.map(i => i.numDeployments),
    solcInputHash: imps.map(i => i.solcInputHash),
    metadata: imps.map(i => i.metadata),
    bytecode: imps.map(i => i.bytecode),
    deployedBytecode: imps.map(i => i.deployedBytecode),
    devdoc: imps.map(i => i.devdoc),
    userdoc: imps.map(i => i.userdoc),
    storageLayout: imps.map(i => i.storageLayout),
  }
})

const generateMainArtifact = (network: string, cfg: Config) => {
  const artifactPath = path.join(process.cwd(), "deployments", network);
  const proxyArtifact = JSON.parse(fs.readFileSync(path.join(artifactPath, cfg.proxy)).toString())
  const implemsArtifact = cfg.implementations.map(i => JSON.parse(fs.readFileSync(path.join(artifactPath, i)).toString()))

  const mergedArtifact = mergeImplemsAndProxy(implemsArtifact, cfg.implementations, proxyArtifact);
  fs.writeFileSync(path.join(artifactPath, cfg.target), JSON.stringify(mergedArtifact, null, 4))
}

const aggregateImplemsAndProxy = (imps: any[], impNames: string[], proxy: any): any => ({
  address: proxy.address,
  abi: [...[].concat(...imps.map(i => i.abi)), ...proxy.abi],
  transactionHash: proxy.transactionHash,
  receipt: proxy.receipt,
  args: proxy.args,
  numDeployments: proxy.numDeployments,
  solcInputHash: proxy.solcInputHash,
  metadata: proxy.metadata,
  bytecode: imps[imps.length - 1].bytecode,
  deployedBytecode: imps[imps.length - 1].deployedBytecode,
  devdoc: proxy.devdoc,
  userdoc: proxy.userdoc,
  storageLayout: proxy.storageLayout,
  implementations: {
    names: impNames,
    transactionHash: imps.map(i => i.transactionHash),
    receipt: imps.map(i => i.receipt),
    args: imps.map(i => i.args),
    numDeployments: imps.map(i => i.numDeployments),
    solcInputHash: imps.map(i => i.solcInputHash),
    metadata: imps.map(i => i.metadata),
    bytecode: imps.map(i => i.bytecode),
    deployedBytecode: imps.map(i => i.deployedBytecode),
    devdoc: imps.map(i => i.devdoc),
    userdoc: imps.map(i => i.userdoc),
    storageLayout: imps.map(i => i.storageLayout),
  }
})

const generateAggregatedArtifact = (network: string, cfg: Config) => {
  const artifactPath = path.join(process.cwd(), "deployments", network);
  const proxyArtifact = JSON.parse(fs.readFileSync(path.join(artifactPath, cfg.proxy)).toString())
  const implemsArtifact = cfg.implementations.map(i => JSON.parse(fs.readFileSync(path.join(artifactPath, i)).toString()))

  const aggregatedArtifact = aggregateImplemsAndProxy(implemsArtifact, cfg.implementations, proxyArtifact)

  const combinedArtifactPath = path.join(artifactPath, "combinedImplementations", `${path.basename(cfg.target, '.json')}_combined_implementations.json`)

  fs.writeFileSync(combinedArtifactPath, JSON.stringify(aggregatedArtifact, null, 4));
}

interface Config {
  target: string;
  implementations: string[];
  proxy: string;
}

interface AllNetsConfigs {
  [key: string]: Config[]
}

const config: AllNetsConfigs = {
  "mockedGoerli": [
    {
      target: "Allowlist.json",
      implementations: [
        "AllowlistV1_Implementation_0_2_2.json",
        "AllowlistV1_Implementation_0_5_0.json"
      ],
      proxy: "Allowlist_Proxy.json"
    },
    {
      target: "CoverageFund.json",
      implementations: [
        "CoverageFundV1_Implementation_0_5_0.json",
      ],
      proxy: "CoverageFund_Proxy.json"
    },
    {
      target: "ELFeeRecipient.json",
      implementations: [
        "ELFeeRecipientV1_Implementation_0_2_2.json",
      ],
      proxy: "ELFeeRecipient_Proxy.json"
    },
    {
      target: "OperatorsRegistry.json",
      implementations: [
        "OperatorsRegistryV1_Implementation_0_2_2.json",
        "OperatorsRegistryV1_Implementation_0_4_0.json",
      ],
      proxy: "OperatorsRegistry_Proxy.json"
    },
    {
      target: "Oracle.json",
      implementations: [
        "OracleV1_Implementation_0_2_2.json",
        "OracleV1_Implementation_0_4_0.json",
      ],
      proxy: "Oracle_Proxy.json"
    },
    {
      target: "River.json",
      implementations: [
        "RiverV1_Implementation_0_2_2.json",
        "RiverV1_Implementation_0_4_0.json",
        "RiverV1_Implementation_0_5_0.json",
      ],
      proxy: "River_Proxy.json"
    },
    {
      target: "TLC.json",
      implementations: [
        "TLCV1_Implementation_0_4_0.json",
        "TLCV1_Implementation_0_5_0.json",
      ],
      proxy: "TLC_Proxy.json"
    },
    {
      target: "Withdraw.json",
      implementations: [
        "WithdrawV1_Implementation_0_2_2.json",
      ],
      proxy: "Withdraw_Proxy.json"
    },
    {
      target: "WLSETH.json",
      implementations: [
        "WLSETHV1_Implementation_0_2_2.json",
        "WLSETHV1_Implementation_0_4_0.json",
      ],
      proxy: "WLSETH_Proxy.json"
    },
  ],
  "devGoerli": [
    {
      target: "Allowlist.json",
      implementations: [
        "AllowlistV1_Implementation_0_6_0.json"
      ],
      proxy: "Allowlist_Proxy.json"
    },
    {
      target: "CoverageFund.json",
      implementations: [
        "CoverageFundV1_Implementation_0_6_0.json",
      ],
      proxy: "CoverageFund_Proxy.json"
    },
    {
      target: "ELFeeRecipient.json",
      implementations: [
        "ELFeeRecipientV1_Implementation_0_6_0.json",
      ],
      proxy: "ELFeeRecipient_Proxy.json"
    },
    {
      target: "OperatorsRegistry.json",
      implementations: [
        "OperatorsRegistryV1_Implementation_0_6_0.json",
      ],
      proxy: "OperatorsRegistry_Proxy.json"
    },
    {
      target: "Oracle.json",
      implementations: [
        "OracleV1_Implementation_0_6_0.json",
      ],
      proxy: "Oracle_Proxy.json"
    },
    {
      target: "River.json",
      implementations: [
        "RiverV1_Implementation_0_6_0.json",
      ],
      proxy: "River_Proxy.json"
    },
    {
      target: "Withdraw.json",
      implementations: [
        "WithdrawV1_Implementation_0_6_0.json",
      ],
      proxy: "Withdraw_Proxy.json"
    }
  ],
  "goerli": [
    {
      target: "Allowlist.json",
      implementations: [
        "AllowlistV1_Implementation_0_2_2.json",
        "AllowlistV1_Implementation_0_5_0.json"
      ],
      proxy: "Allowlist_Proxy.json"
    },
    {
      target: "CoverageFund.json",
      implementations: [
        "CoverageFundV1_Implementation_0_5_0.json",
      ],
      proxy: "CoverageFund_Proxy.json"
    },
    {
      target: "ELFeeRecipient.json",
      implementations: [
        "ELFeeRecipientV1_Implementation_0_2_2.json",
        "ELFeeRecipientV1_Implementation_0_6_0_rc2.json",
        "ELFeeRecipientV1_Implementation_1_0_0.json",
      ],
      proxy: "ELFeeRecipient_Proxy.json"
    },
    {
      target: "OperatorsRegistry.json",
      implementations: [
        "OperatorsRegistryV1_Implementation_0_2_2.json",
        "OperatorsRegistryV1_Implementation_0_4_0.json",
        "OperatorsRegistryV1_Implementation_0_6_0_rc2.json",
        "OperatorsRegistryV1_Implementation_1_0_0.json",
      ],
      proxy: "OperatorsRegistry_Proxy.json"
    },
    {
      target: "Oracle.json",
      implementations: [
        "OracleV1_Implementation_0_2_2.json",
        "OracleV1_Implementation_0_4_0.json",
        "OracleV1_Implementation_0_6_0_rc2.json",
        "OracleV1_Implementation_1_0_0.json",
      ],
      proxy: "Oracle_Proxy.json"
    },
    {
      target: "RedeemManager.json",
      implementations: [
        "RedeemManagerV1_Implementation_0_6_0_rc2.json",
        "RedeemManagerV1_Implementation_1_0_0.json",
      ],
      proxy: "RedeemManager_Proxy.json"
    },
    {
      target: "River.json",
      implementations: [
        "RiverV1_Implementation_0_2_2.json",
        "RiverV1_Implementation_0_4_0.json",
        "RiverV1_Implementation_0_5_0.json",
        "RiverV1_Implementation_0_6_0_rc2.json",
        "RiverV1_Implementation_1_0_0.json",
      ],
      proxy: "River_Proxy.json"
    },
    {
      target: "TLC.json",
      implementations: [
        "TLCV1_Implementation_0_4_0.json",
        "TLCV1_Implementation_0_5_0.json",
        "TLCV1_Implementation_0_6_0_rc2.json",
        "TLCV1_Implementation_1_0_0.json",
      ],
      proxy: "TLC_Proxy.json"
    },
    {
      target: "Withdraw.json",
      implementations: [
        "WithdrawV1_Implementation_0_2_2.json",
        "WithdrawV1_Implementation_0_6_0_rc2.json",
        "WithdrawV1_Implementation_1_0_0.json",
      ],
      proxy: "Withdraw_Proxy.json"
    },
    {
      target: "WLSETH.json",
      implementations: [
        "WLSETHV1_Implementation_0_2_2.json",
        "WLSETHV1_Implementation_0_4_0.json",
      ],
      proxy: "WLSETH_Proxy.json"
    },
  ],
  "mainnet": [
    {
      target: "Allowlist.json",
      implementations: [
        "AllowlistV1_Implementation_0_4_0.json",
        "AllowlistV1_Implementation_0_5_0.json"
      ],
      proxy: "Allowlist_Proxy.json"
    },
    {
      target: "CoverageFund.json",
      implementations: [
        "CoverageFundV1_Implementation_0_5_0.json",
      ],
      proxy: "CoverageFund_Proxy.json"
    },
    {
      target: "ELFeeRecipient.json",
      implementations: [
        "ELFeeRecipientV1_Implementation_0_4_0.json",
        "ELFeeRecipientV1_Implementation_1_0_0.json",
      ],
      proxy: "ELFeeRecipient_Proxy.json"
    },
    {
      target: "OperatorsRegistry.json",
      implementations: [
        "OperatorsRegistryV1_Implementation_0_4_0.json",
        "OperatorsRegistryV1_Implementation_1_0_0.json",
      ],
      proxy: "OperatorsRegistry_Proxy.json"
    },
    {
      target: "Oracle.json",
      implementations: [
        "OracleV1_Implementation_0_4_0.json",
        "OracleV1_Implementation_1_0_0.json",
      ],
      proxy: "Oracle_Proxy.json"
    },
    {
      target: "River.json",
      implementations: [
        "RiverV1_Implementation_0_4_0.json",
        "RiverV1_Implementation_0_5_0.json",
        "RiverV1_Implementation_1_0_0.json",
      ],
      proxy: "River_Proxy.json"
    },
    {
      target: "TLC.json",
      implementations: [
        "TLCV1_Implementation_0_4_0.json",
        "TLCV1_Implementation_0_5_0.json",
        "TLCV1_Implementation_1_0_0.json",
      ],
      proxy: "TLC_Proxy.json"
    },
    {
      target: "Withdraw.json",
      implementations: [
        "WithdrawV1_Implementation_0_4_0.json",
        "WithdrawV1_Implementation_1_0_0.json",
      ],
      proxy: "Withdraw_Proxy.json"
    },
  ]
}

const main = async () => {
  const net = hre.network.name
  const dirPath = path.join(process.cwd(), "deployments", net, "combinedImplementations")
  if (fs.existsSync(dirPath)) {
    rimraf.sync(dirPath)
  }
  fs.mkdirSync(dirPath)
  for (const contractConfig of config[net]) {
    generateMainArtifact(net, contractConfig);
    generateAggregatedArtifact(net, contractConfig)
  }
}


main();



