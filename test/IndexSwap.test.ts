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
    await priceOracle.initialize("0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3");

    const IndexSwap = await ethers.getContractFactory("IndexSwap");
    indexSwap = await IndexSwap.deploy(
      priceOracle.address, // price oracle
      "0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd", // wbnb
      "0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3", // pancake router
      "0xa05Ae01a56779a75FDBAa299965E0C1087E11cbc" // vault
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
    await indexSwap.investInFund({
      value: "1000000000000000000",
    });
  });

  it("Invest 1BNB into Top10 fund", async () => {
    const indexSupplyBefore = await indexSwap.totalSupply();
    //console.log(indexSupplyBefore);
    await indexSwap.investInFund({
      value: "1000000000000000000",
    });
  });

  it("Invest 2BNB into Top10 fund", async () => {
    const indexSupplyBefore = await indexSwap.totalSupply();
    //console.log(indexSupplyBefore);
    await indexSwap.investInFund({
      value: "2000000000000000000",
    });
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
    const wbnb = "0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd";
    const btc = "0x4b1851167f74FF108A994872A160f1D6772d474b";

    let p = [wbnb, btc];
    const path = await indexSwap.getPathForETH(btc);

    expect(p[0]).to.be.equal(path[0]);
    expect(p[1]).to.be.equal(path[1]);
    expect(p.length).to.be.equal(path.length).to.be.equal(2);
  });

  it("Get BTC/WBNB path", async () => {
    const wbnb = "0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd";
    const btc = "0x4b1851167f74FF108A994872A160f1D6772d474b";

    let p = [btc, wbnb];
    const path = await indexSwap.getPathForToken(btc);

    expect(p[0]).to.be.equal(path[0]);
    expect(p[1]).to.be.equal(path[1]);
    expect(p.length).to.be.equal(path.length).to.be.equal(2);
  });

  it("Get WBNB/ETH path", async () => {
    const wbnb = "0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd";
    const eth = "0x8BaBbB98678facC7342735486C851ABD7A0d17Ca";

    let p = [wbnb, eth];
    const path = await indexSwap.getPathForETH(eth);

    expect(p[0]).to.be.equal(path[0]);
    expect(p[1]).to.be.equal(path[1]);
    expect(p.length).to.be.equal(path.length).to.be.equal(2);
  });

  it("Get ETH/WBNB path", async () => {
    const wbnb = "0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd";
    const eth = "0x8BaBbB98678facC7342735486C851ABD7A0d17Ca";

    let p = [eth, wbnb];
    const path = await indexSwap.getPathForToken(eth);

    expect(p[0]).to.be.equal(path[0]);
    expect(p[1]).to.be.equal(path[1]);
    expect(p.length).to.be.equal(path.length).to.be.equal(2);
  });
});
