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

  it("Update rate to 1,1", async () => {
    const numerator = 1;
    const denominator = 1;
    await indexSwap.updateRate(numerator, denominator);
    const currentRate = await indexSwap.currentRate();

    expect(currentRate.numerator).to.be.equal(numerator);
    expect(currentRate.denominator).to.be.equal(denominator);
  });

  it("Invest 1BNB into Top10 fund", async () => {
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

  it("Invest 2BNB into Top10 fund", async () => {
    const indexSupplyBefore = await indexSwap.totalSupply();
    //console.log(indexSupplyBefore);
    await indexSwap.investInFund("2000000000000000000", {
      value: "2000000000000000000",
    });
    const indexSupplyAfter = await indexSwap.totalSupply();
    //console.log(indexSupplyAfter);

    expect(Number(indexSupplyAfter)).to.be.greaterThanOrEqual(
      Number(indexSupplyBefore)
    );
  });

  it("Invest 0.1BNB into Top10 fund", async () => {
    const indexSupplyBefore = await indexSwap.totalSupply();
    //console.log(indexSupplyBefore);
    await indexSwap.investInFund("100000000000000000", {
      value: "100000000000000000",
    });
    const indexSupplyAfter = await indexSwap.totalSupply();
    //console.log(indexSupplyAfter);

    expect(Number(indexSupplyAfter)).to.be.greaterThanOrEqual(
      Number(indexSupplyBefore)
    );
  });

  it("Invest 0.2BNB into Top10 fund", async () => {
    const indexSupplyBefore = await indexSwap.totalSupply();
    //console.log(indexSupplyBefore);
    await indexSwap.investInFund("200000000000000000", {
      value: "200000000000000000",
    });
    const indexSupplyAfter = await indexSwap.totalSupply();
    //console.log(indexSupplyAfter);

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

  it("Get BTC/USDT path", async () => {
    const usdt = "0xfD5840Cd36d94D7229439859C0112a4185BC0255";
    const btc = "0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c";

    let p = [btc, usdt];
    const path = await indexSwap.getPathForUSDT(btc);

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

  it("Get ETH/USDT path", async () => {
    const usdt = "0xfD5840Cd36d94D7229439859C0112a4185BC0255";
    const eth = "0x2170Ed0880ac9A755fd29B2688956BD959F933F8";

    let p = [eth, usdt];
    const path = await indexSwap.getPathForUSDT(eth);

    expect(p[0]).to.be.equal(path[0]);
    expect(p[1]).to.be.equal(path[1]);
    expect(p.length).to.be.equal(path.length).to.be.equal(2);
  });
});
