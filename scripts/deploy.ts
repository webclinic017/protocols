// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
import { run, ethers } from "hardhat";
import { PriceOracle } from "../typechain";
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

  await priceOracle.initialize("0x10ED43C718714eb63d5aA57B78B54704E256024E"); // pancake router

  console.log("priceOracle deployed to:", priceOracle.address);

  // We get the contract to deploy
  const IndexSwap = await ethers.getContractFactory("IndexSwap");
  const indexSwap = await IndexSwap.deploy(
    priceOracle.address,
    "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c", // wbnb
    "0x10ED43C718714eb63d5aA57B78B54704E256024E", // pancake router
    "0xD2aDa2CC6f97cfc1045B1cF70b3149139aC5f2a2" // vault
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
