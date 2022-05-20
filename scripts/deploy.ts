// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
import { run, ethers } from "hardhat";
// let fs = require("fs");
const ETHERSCAN_TX_URL = "https://testnet.bscscan.io/tx/";

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  await run("compile");

  // We get the contract to deploy
  const PriceOracle = await ethers.getContractFactory("PriceOracle");
  const priceOracle = await PriceOracle.deploy();

  await priceOracle.deployed();

  priceOracle.initialize("0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff");

  console.log("priceOracle deployed to:", priceOracle.address);

  // We get the contract to deploy
  const IndexSwap = await ethers.getContractFactory("IndexSwap");
  const indexSwap = await IndexSwap.deploy(
    priceOracle.address,
    "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270", // manic
    "0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff", // pancake
    "0x6056773C28c258425Cf9BC8Ba5f86B8031863164" // vault
  );

  await indexSwap.deployed();

  console.log("indexSwap deployed to:", indexSwap.address);

  console.log(
    `You did it! View your tx here: ${ETHERSCAN_TX_URL}${priceOracle.deployTransaction.hash}`
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
