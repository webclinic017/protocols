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
      "0xD2aDa2CC6f97cfc1045B1cF70b3149139aC5f2a2", // vault
      "0xEf73E58650868f316461936A092818d5dF96102E" // myModule
    );

    await indexSwap.deployed();

    console.log("priceOracle deployed to:", indexSwap.address);
  });

  it("Initialize default", async () => {
    await indexSwap.initializeDefult();
  });

  it("Update rate to 1,1", async () => {
    const numerator = 1;
    const denominator = 1;
    await indexSwap.updateRate(numerator, denominator);
    const currentRate = await indexSwap.currentRate();

    expect(currentRate.numerator).to.be.equal(numerator);
    expect(currentRate.denominator).to.be.equal(denominator);
  });

  it("Test amount and vault values", async () => {
    const values = await indexSwap.getTokenAndVaultBalance();
    console.log("tokenBalances", values[0]);
    console.log("vault", values[1]);
  });

  it("Invest 0.11BNB into Top10 fund", async () => {
    const indexSupplyBefore = await indexSwap.totalSupply();
    console.log("0.1bnb before", indexSupplyBefore);
    await indexSwap.investInFund({
      value: "100000000000000000",
    });
    const indexSupplyAfter = await indexSwap.totalSupply();
    console.log("0.1bnb after", indexSupplyAfter);

    expect(Number(indexSupplyAfter)).to.be.greaterThanOrEqual(
      Number(indexSupplyBefore)
    );
  });

  it("Test amount and vault values", async () => {
    const values = await indexSwap.getTokenAndVaultBalance();
    console.log("tokenBalances", values[0]);
    console.log("vault", values[1]);
  });

  it("Invest 0.2BNB into Top10 fund", async () => {
    const indexSupplyBefore = await indexSwap.totalSupply();
    console.log("0.2bnb before", indexSupplyBefore);
    await indexSwap.investInFund({
      value: "200000000000000000",
    });
    const indexSupplyAfter = await indexSwap.totalSupply();
    console.log("0.2bnb after", indexSupplyAfter);

    expect(Number(indexSupplyAfter)).to.be.greaterThanOrEqual(
      Number(indexSupplyBefore)
    );
  });

  it("Test amount and vault values", async () => {
    const values = await indexSwap.getTokenAndVaultBalance();
    console.log("tokenBalances", values[0]);
    console.log("vault", values[1]);
  });

  it("Invest 0.1BNB into Top10 fund", async () => {
    const indexSupplyBefore = await indexSwap.totalSupply();
    console.log("0.1bnb before", indexSupplyBefore);
    await indexSwap.investInFund({
      value: "100000000000000000",
    });
    const indexSupplyAfter = await indexSwap.totalSupply();
    console.log("0.1bnb after", indexSupplyAfter);

    expect(Number(indexSupplyAfter)).to.be.greaterThanOrEqual(
      Number(indexSupplyBefore)
    );
  });

  it("Invest 0.2BNB into Top10 fund", async () => {
    const indexSupplyBefore = await indexSwap.totalSupply();
    console.log("0.2bnb before", indexSupplyBefore);
    await indexSwap.investInFund({
      value: "200000000000000000",
    });
    const indexSupplyAfter = await indexSwap.totalSupply();
    console.log("0.2bnb after", indexSupplyAfter);

    expect(Number(indexSupplyAfter)).to.be.greaterThanOrEqual(
      Number(indexSupplyBefore)
    );
  });

  it("Update rate to 2,2", async () => {
    const numerator = 2;
    const denominator = 2;
    await indexSwap.updateRate(numerator, denominator);
    const currentRate = await indexSwap.currentRate();

    expect(currentRate.numerator).to.be.equal(numerator);
    expect(currentRate.denominator).to.be.equal(denominator);
  });

  it("Get WBNB/BTC path", async () => {
    const wbnb = "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c";
    const btc = "0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c";

    let p = [wbnb, btc];
    const path = await indexSwap.getPathForETH(btc);

    expect(p[0]).to.be.equal(path[0]);
    expect(p[1]).to.be.equal(path[1]);
    expect(p.length).to.be.equal(path.length).to.be.equal(2);
  });

  it("Get BTC/WBNB path", async () => {
    const wbnb = "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c";
    const btc = "0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c";

    let p = [btc, wbnb];
    const path = await indexSwap.getPathForToken(btc);

    expect(p[0]).to.be.equal(path[0]);
    expect(p[1]).to.be.equal(path[1]);
    expect(p.length).to.be.equal(path.length).to.be.equal(2);
  });

  it("Get WBNB/ETH path", async () => {
    const wbnb = "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c";
    const eth = "0x2170Ed0880ac9A755fd29B2688956BD959F933F8";

    let p = [wbnb, eth];
    const path = await indexSwap.getPathForETH(eth);

    expect(p[0]).to.be.equal(path[0]);
    expect(p[1]).to.be.equal(path[1]);
    expect(p.length).to.be.equal(path.length).to.be.equal(2);
  });

  it("Get ETH/WBNB path", async () => {
    const wbnb = "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c";
    const eth = "0x2170Ed0880ac9A755fd29B2688956BD959F933F8";

    let p = [eth, wbnb];
    const path = await indexSwap.getPathForToken(eth);

    expect(p[0]).to.be.equal(path[0]);
    expect(p[1]).to.be.equal(path[1]);
    expect(p.length).to.be.equal(path.length).to.be.equal(2);
  });
});
