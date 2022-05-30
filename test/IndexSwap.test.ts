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
      "0x02B9eDF79660c2b5A24f2C379294bDe265Fd5c34", // vault
      "0x7250C7A64C5BCbe4815E905C10F822C2DA7358Ef" // myModule
    );

    await indexSwap.deployed();

    console.log("priceOracle deployed to:", indexSwap.address);

    const myModule = await ethers.getContractFactory("MyModule");
    const module = myModule.attach(
      "0x7250C7A64C5BCbe4815E905C10F822C2DA7358Ef"
    );
    await module.addOwner(indexSwap.address);
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

  // This will fail if we use a used safe where some tokens are already included!!!
  it("Equally weighted token allocation", async () => {
    // get current weights and check
    const values = await indexSwap.getTokenAndVaultBalance();
    const tokenBalances = values[0];
    const vaultBalance = values[1];
    const t1 = Number(tokenBalances[0]) / Number(vaultBalance);
    const t2 = Number(tokenBalances[1]) / Number(vaultBalance);
    const t3 = Number(tokenBalances[2]) / Number(vaultBalance);
    const t4 = Number(tokenBalances[3]) / Number(vaultBalance);
    const t5 = Number(tokenBalances[4]) / Number(vaultBalance);
    const t6 = Number(tokenBalances[5]) / Number(vaultBalance);
    const t7 = Number(tokenBalances[6]) / Number(vaultBalance);
    const t8 = Number(tokenBalances[7]) / Number(vaultBalance);
    const t9 = Number(tokenBalances[8]) / Number(vaultBalance);
    const t10 = Number(tokenBalances[9]) / Number(vaultBalance);

    console.log("t1", Math.round(t1 * 100));
    console.log("t2", Math.round(t2 * 100));
    console.log("t3", Math.round(t3 * 100));
    console.log("t4", Math.round(t4 * 100));
    console.log("t5", Math.round(t5 * 100));
    console.log("t6", Math.round(t6 * 100));
    console.log("t7", Math.round(t7 * 100));
    console.log("t8", Math.round(t8 * 100));
    console.log("t9", Math.round(t9 * 100));
    console.log("t10", Math.round(t10 * 100));

    // 2% +/- for slippage and rounding
    expect(Math.round(t1 * 100)).to.be.equal(10);

    expect(Math.round(t2 * 100)).to.be.equal(10);

    expect(Math.round(t3 * 100)).to.be.equal(10);

    expect(Math.round(t4 * 100)).to.be.equal(10);

    expect(Math.round(t5 * 100)).to.be.equal(10);

    expect(Math.round(t6 * 100)).to.be.equal(10);

    expect(Math.round(t7 * 100)).to.be.equal(10);

    expect(Math.round(t8 * 100)).to.be.equal(10);

    expect(Math.round(t9 * 100)).to.be.equal(10);

    expect(Math.round(t10 * 100)).to.be.equal(10);
  });

  it("Withdraw evreything from fund", async () => {
    const indexAmount = await indexSwap.balanceOf(owner.address);
    await indexSwap.withdrawFromFundNew(indexAmount);

    const indexAmountAfterWithdrawal = await indexSwap.balanceOf(owner.address);
    expect(indexAmountAfterWithdrawal).to.be.equal(0);
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

  it("Withdrawing more index token than possible, supposed to fail", async () => {
    const indexAmount = await indexSwap.balanceOf(owner.address);
    console.log(indexAmount);
    await expect(
      indexSwap.withdrawFromFundNew(indexAmount.mul(2))
    ).to.be.revertedWith("not balance");
  });

  it("Rebalance to 30/10/10/20/5/5/5/5/5/5", async () => {
    let newWeights = [3000, 1000, 1000, 2000, 500, 500, 500, 500, 500, 500];
    await indexSwap.rebalance(newWeights);

    // get current weights and check
    const values = await indexSwap.getTokenAndVaultBalance();
    const tokenBalances = values[0];
    const vaultBalance = values[1];
    const t1 = Number(tokenBalances[0]) / Number(vaultBalance);
    const t2 = Number(tokenBalances[1]) / Number(vaultBalance);
    const t3 = Number(tokenBalances[2]) / Number(vaultBalance);
    const t4 = Number(tokenBalances[3]) / Number(vaultBalance);
    const t5 = Number(tokenBalances[4]) / Number(vaultBalance);
    const t6 = Number(tokenBalances[5]) / Number(vaultBalance);
    const t7 = Number(tokenBalances[6]) / Number(vaultBalance);
    const t8 = Number(tokenBalances[7]) / Number(vaultBalance);
    const t9 = Number(tokenBalances[8]) / Number(vaultBalance);
    const t10 = Number(tokenBalances[9]) / Number(vaultBalance);

    console.log("t1", Math.round(t1 * 100));
    console.log("t2", Math.round(t2 * 100));
    console.log("t3", Math.round(t3 * 100));
    console.log("t4", Math.round(t4 * 100));
    console.log("t5", Math.round(t5 * 100));
    console.log("t6", Math.round(t6 * 100));
    console.log("t7", Math.round(t7 * 100));
    console.log("t8", Math.round(t8 * 100));
    console.log("t9", Math.round(t9 * 100));
    console.log("t10", Math.round(t10 * 100));

    // 2% +/- for slippage and rounding
    expect(Math.round(t1 * 100))
      .to.be.greaterThanOrEqual(28)
      .and.to.be.lessThanOrEqual(32);

    expect(Math.round(t2 * 100))
      .to.be.greaterThanOrEqual(8)
      .and.to.be.lessThanOrEqual(12);

    expect(Math.round(t3 * 100))
      .to.be.greaterThanOrEqual(8)
      .and.to.be.lessThanOrEqual(12);

    expect(Math.round(t4 * 100))
      .to.be.greaterThanOrEqual(18)
      .and.to.be.lessThanOrEqual(22);

    expect(Math.round(t5 * 100))
      .to.be.greaterThanOrEqual(3)
      .and.to.be.lessThanOrEqual(7);

    expect(Math.round(t6 * 100))
      .to.be.greaterThanOrEqual(3)
      .and.to.be.lessThanOrEqual(7);

    expect(Math.round(t7 * 100))
      .to.be.greaterThanOrEqual(3)
      .and.to.be.lessThanOrEqual(7);

    expect(Math.round(t8 * 100))
      .to.be.greaterThanOrEqual(3)
      .and.to.be.lessThanOrEqual(7);

    expect(Math.round(t9 * 100))
      .to.be.greaterThanOrEqual(3)
      .and.to.be.lessThanOrEqual(7);

    expect(Math.round(t10 * 100))
      .to.be.greaterThan(3)
      .and.to.be.lessThanOrEqual(7);
  });

  it("Rebalance to equally weighted (10% each)", async () => {
    let newWeights = [
      1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000,
    ];
    await indexSwap.rebalance(newWeights);

    // get current weights and check
    const values = await indexSwap.getTokenAndVaultBalance();
    const tokenBalances = values[0];
    const vaultBalance = values[1];
    const t1 = Number(tokenBalances[0]) / Number(vaultBalance);
    const t2 = Number(tokenBalances[1]) / Number(vaultBalance);
    const t3 = Number(tokenBalances[2]) / Number(vaultBalance);
    const t4 = Number(tokenBalances[3]) / Number(vaultBalance);
    const t5 = Number(tokenBalances[4]) / Number(vaultBalance);
    const t6 = Number(tokenBalances[5]) / Number(vaultBalance);
    const t7 = Number(tokenBalances[6]) / Number(vaultBalance);
    const t8 = Number(tokenBalances[7]) / Number(vaultBalance);
    const t9 = Number(tokenBalances[8]) / Number(vaultBalance);
    const t10 = Number(tokenBalances[9]) / Number(vaultBalance);

    console.log("t1", Math.round(t1 * 100));
    console.log("t2", Math.round(t2 * 100));
    console.log("t3", Math.round(t3 * 100));
    console.log("t4", Math.round(t4 * 100));
    console.log("t5", Math.round(t5 * 100));
    console.log("t6", Math.round(t6 * 100));
    console.log("t7", Math.round(t7 * 100));
    console.log("t8", Math.round(t8 * 100));
    console.log("t9", Math.round(t9 * 100));
    console.log("t10", Math.round(t10 * 100));

    // 2% +/- for slippage and rounding
    expect(Math.round(t1 * 100)).to.be.equal(10);

    expect(Math.round(t2 * 100)).to.be.equal(10);

    expect(Math.round(t3 * 100)).to.be.equal(10);

    expect(Math.round(t4 * 100)).to.be.equal(10);

    expect(Math.round(t5 * 100)).to.be.equal(10);

    expect(Math.round(t6 * 100)).to.be.equal(10);

    expect(Math.round(t7 * 100)).to.be.equal(10);

    expect(Math.round(t8 * 100)).to.be.equal(10);

    expect(Math.round(t9 * 100)).to.be.equal(10);

    expect(Math.round(t10 * 100)).to.be.equal(10);
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
