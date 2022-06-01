// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
import { run, ethers } from "hardhat";
import { chainIdToAddresses } from "./networkVariables";
// let fs = require("fs");
const ETHERSCAN_TX_URL = "https://testnet.bscscan.io/tx/";

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  await run("compile");

  // get current chainId
  const chainId = ethers.provider.network.chainId;
  const addresses = chainIdToAddresses[chainId];

  // We get the contract to deploy
  const PriceOracle = await ethers.getContractFactory("PriceOracle");
  const priceOracle = await PriceOracle.deploy();

  await priceOracle.deployed();

  priceOracle.initialize(addresses.PancakeSwapRouterAddress);

  console.log("priceOracle deployed to:", priceOracle.address);

  // We get the contract to deploy
  const IndexSwap = await ethers.getContractFactory("IndexSwap");
  const indexSwap = await IndexSwap.deploy(
    priceOracle.address,
    addresses.WETH_Address,
    addresses.PancakeSwapRouterAddress,
    addresses.Vault
  );

  await indexSwap.deployed();

  console.log("indexSwap deployed to:", indexSwap.address);

  //initialize index based on network
  await indexSwap.initialize(
    [addresses.ETH_Address, addresses.BTC_Address],
    [1, 1]
  );

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
