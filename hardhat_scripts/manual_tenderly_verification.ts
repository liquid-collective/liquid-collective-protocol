import { tenderly } from "hardhat";

async function main() {
  // await tenderly.verify({
  //   name: "AllowlistV1",
  //   address: "0x35E1876E99167946294111897a3490A466E2CDEA",
  // });
  // await tenderly.verify({
  //   name: "CoverageFundV1",
  //   address: "0xF8466bf05e33817b016bc636Ef1903dBB4915E27",
  // });
  // await tenderly.verify({
  //   name: "ELFeeRecipientV1",
  //   address: "0x445016381E8c530B9eC099e30Bf03d3199B0a4E2",
  // });
  // await tenderly.verify({
  //   name: "OperatorsRegistryV1",
  //   address: "0x12E71D4b59C50D0B3cB90f7631056079d7638044",
  // });
  // await tenderly.verify({
  //   name: "OracleV1",
  //   address: "0x56aceC5EB3E88bae6bFE558cCaB3D25606EF2F0F",
  // });
  // await tenderly.verify({
  //   name: "RedeemManagerV1",
  //   address: "0x14444aa615aeb5948ADFA3E8934B26783BA235Ca",
  // });
  // await tenderly.verify({
  //   name: "RiverV1",
  //   address: "0x351dEdE42CbbEFdA417E9228B5B6AcE60a62308E",
  // });
  // await tenderly.verify({
  //   name: "WithdrawV1",
  //   address: "0xF8D0B47C99B613355781D7fA66DECAfe3C2d6aC5",
  // });
  // await tenderly.verify({
  //   name: "Firewall",
  //   address: "0x6d56f4618E4a72434EE17935BA2F80b768Fe81C4",
  // });
  // await tenderly.verify({
  //   name: "Firewall",
  //   address: "0x7868c60Fd426836C5360483F6902b4253aDb3479",
  // });
  // await tenderly.verify({
  //   name: "Firewall",
  //   address: "0x85E2743E77F4eF66a8B3Eca695A862A807dA9bC9",
  // });
  // await tenderly.verify({
  //   name: "Firewall",
  //   address: "0xe4791606f0Cc65FDf33dBBcE8f7a9F099db59860",
  // });
  // await tenderly.verify({
  //   name: "Firewall",
  //   address: "0xEE9093A79225329Ac3d288BE307eb0EBb958DcC1",
  // });
  // await tenderly.verify({
  //   name: "Firewall",
  //   address: "0x583306a70ec95E80a78Ec556b6d682fbB136c2e0",
  // });
  // await tenderly.verify({
  //   name: "Firewall",
  //   address: "0x4d9042dC24C76F9D34A6F7B0238897fB775a3f43",
  // });
  // await tenderly.verify({
  //   name: "Firewall",
  //   address: "0x750DE01a637f67039eAE36c88c1fA3376Ef5054f",
  // });
  // await tenderly.verify({
  //   name: "Firewall",
  //   address: "0xEd19dded9d63A628E73a5A7Fcb6e4c1A8A40a94D",
  // });
  // await tenderly.verify({
  //   name: "TUPProxy",
  //   address: "0x16c3AF238E519a5819e7CEFbd91Fc6339b514783",
  // });
  // await tenderly.verify({
  //   name: "TUPProxy",
  //   address: "0x50909EED24dF5821aec27ca7f60526e693F61808",
  // });
  // await tenderly.verify({
  //   name: "TUPProxy",
  //   address: "0x4b0c9eDdda81518BA9f3EC51E40714B89FE03a9a",
  // });
  // await tenderly.verify({
  //   name: "TUPProxy",
  //   address: "0x01B674120Ba12D9c0329Bf9A56a6D56d9DA7B6d6",
  // });
  // await tenderly.verify({
  //   name: "TUPProxy",
  //   address: "0xd694f0b15608027db926753097Cd5c30EB0cFFe3",
  // });
  // await tenderly.verify({
  //   name: "TUPProxy",
  //   address: "0x6EcA7b06B10D06A73dC5f30793E5C304eaa71b3a",
  // });
  // await tenderly.verify({
  //   name: "TUPProxy",
  //   address: "0xb8A2416e87E2C3bcc1C01Efd6CA89c05aF6e347E",
  // });
  // await tenderly.verify({
  //   name: "TUPProxy",
  //   address: "0xff13483Ae0164f1530060fCFc8478F346bfa5657",
  // });
  await tenderly.verify({
    name: "RedeemManagerV1",
    address: "0x2112744964FC5AdD36D81602fB29fcDF87F25042",
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});