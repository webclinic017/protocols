import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { ethers } from "hardhat";
import { PriceOracle } from "../typechain";

describe("Price Oracle", () => {
    let priceOracle: PriceOracle;
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
      await priceOracle.initialize("0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd");

      console.log("priceOracle deployed to:", priceOracle.address);
    });

    it("Get token price of BTC", async () => {
        const btc = "0x4b1851167f74FF108A994872A160f1D6772d474b";
        const wbnb = "0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd";
        const price = await priceOracle.getTokenPrice(wbnb, btc);
        expect(price).to.greaterThan(0);
    });

    it("Get price of BTC for 10 BNB", async () => {
        const btc = "0x4b1851167f74FF108A994872A160f1D6772d474b";
        const wbnb = "0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd";
        const path = [btc, wbnb];
        const price = await priceOracle.getTokenPrice("100", path.toString());
        expect(price).to.greaterThan(0);
    });

    it("Get pair address of BNB and WBNB", async () => {
        const btc = "0x4b1851167f74FF108A994872A160f1D6772d474b";
        const wbnb = "0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd";
        const pairAdress = await priceOracle.getPairAddress(btc, wbnb);
        expect(pairAdress).not.to.equal("0x0000000000000000000000000000000000000000");
    });
});