import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { ethers } from "hardhat";
import { IndexSwap, PriceOracle } from "../typechain";
import { BigNumber } from "ethers";

var chai = require("chai");

//use default BigNumber
chai.use(require("chai-bignumber")());

describe("Top 10 Index", () => {
  let priceOracle: PriceOracle;
  let indexSwap: IndexSwap;
  let owner: SignerWithAddress;
  let addr1: SignerWithAddress;
  let addr2: SignerWithAddress;
  let addrs: SignerWithAddress[];

  const provider = ethers.provider;

  before(async () => {
    [owner, addr1, addr2, ...addrs] = await ethers.getSigners();

    const PriceOracle = await ethers.getContractFactory("PriceOracle");
    priceOracle = await PriceOracle.deploy();

    await priceOracle.deployed();
    await priceOracle.initialize("0x10ED43C718714eb63d5aA57B78B54704E256024E");

    const IndexSwap = await ethers.getContractFactory("IndexSwap");
    indexSwap = await IndexSwap.deploy(
      priceOracle.address, // price oracle
      "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c", // wbnb
      "0x10ED43C718714eb63d5aA57B78B54704E256024E", // pancake router
      "0xD2aDa2CC6f97cfc1045B1cF70b3149139aC5f2a2" // vault
    );

    await indexSwap.deployed();

    console.log("priceOracle deployed to:", indexSwap.address);
  });

  it("Initialize default", async () => {
    await indexSwap.initializeDefult();
  });

  it("Update rate", async () => {
    await indexSwap.updateRate(1, 1);
  });

  it("Invest in fund", async () => {
    const indexSupplyBefore = await indexSwap.totalSupply();
    //console.log(indexSupplyBefore);
    await indexSwap.investInFund("1000000000000000000", {
      value: "1000000000000000000",
    });
    const indexSupplyAfter = await indexSwap.totalSupply();
    //console.log(indexSupplyAfter);

    expect(Number(indexSupplyAfter)).to.be.greaterThanOrEqual(
      Number(indexSupplyBefore)
    );
  });
});
