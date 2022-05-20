import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { ethers } from "hardhat";
import { IndexSwap, PriceOracle } from "../typechain";
import { BigNumber } from "ethers";

//use default BigNumber
// chai.use(require("chai-bignumber")());

describe.only('Tests for IndexSwap', () => {
  let accounts;
  let priceOracle: PriceOracle;
  let indexSwap: IndexSwap;
  let txObject;
  let owner: SignerWithAddress;
  let  nonOwner:SignerWithAddress, newOwner: SignerWithAddress;
  let addr1: SignerWithAddress;
  let vault: SignerWithAddress;
  let addrs: SignerWithAddress[];

  const provider = ethers.provider;
  describe('IndexSwap tests', () => {
    before(async () => {
      [owner, nonOwner,newOwner,addr1, addr2, ...addrs] = await ethers.getSigners();

      const PriceOracle = await ethers.getContractFactory("PriceOracle");
      priceOracle = await PriceOracle.deploy();

      await priceOracle.deployed();
      await priceOracle.initialize("0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3");

      const IndexSwap = await ethers.getContractFactory("IndexSwap");
      indexSwap = await IndexSwap.deploy(
        priceOracle.address, // price oracle
        "0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd", // wbnb
        "0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3", // pancake router
        vault
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

      const investedAmountAfterSlippage = indexSwap.investedAmountAfterSlippage();
      console.log("for 1bnb", investedAmountAfterSlippage);

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

      const investedAmountAfterSlippage =
        await indexSwap.investedAmountAfterSlippage();
      console.log("for 2 bnb", investedAmountAfterSlippage);

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
      const investedAmountAfterSlippage =
        await indexSwap.investedAmountAfterSlippage();
      console.log("for 0.2 bnb", investedAmountAfterSlippage);

      const sumPrice = await indexSwap.vaultBalance();
      console.log("sum for 0.2 bnb", sumPrice);

      const indexSupplyAfter = await indexSwap.totalSupply();

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
    describe("WithDraw funds(burn token)", () => {
      context("reverts", () => {
     
      });
      context("sucess", () => {
        it("should withdraw fund successfully", async () => {
          // const AMOUNT = ethers.BigNumber.from('100000000000000000') //1K

          txObject = await indexSwap.withdrawFromFundNew("100000000000000000");
      
           expect(txObject.confirmations).to.equal(1);
        });
      });
    });  
  });  
});
