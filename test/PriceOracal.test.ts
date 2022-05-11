import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { Price } from "@uniswap/sdk";
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
    await priceOracle.initialize("0x10ED43C718714eb63d5aA57B78B54704E256024E");
  });
  // BTC
  it("Get token price of BTC", async () => {
    const btc = "0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c";
    const wbnb = "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c";
    priceOracle.getTokenPrice(wbnb, btc).then((resp) => {
      expect(resp).to.be.greaterThanOrEqual(0);
    });
  });

  it("Get price of BTC for 100 BNB", async () => {
    const btc = "0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c";
    const wbnb = "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c";
    const path = [btc, wbnb];
    priceOracle.getPrice("100", path).then((resp) => {
      expect(resp).to.be.greaterThanOrEqual(0);
    });
  });

  it("Get pair address of BTC and WBNB", async () => {
    const btc = "0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c";
    const wbnb = "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c";
    let pairAdress = "0x0000000000000000000000000000000000000000";
    priceOracle.getPairAddress(btc, wbnb).then((resp) => {
      expect(pairAdress).not.to.be.equal(
        "0x0000000000000000000000000000000000000000"
      );
    });
  });

  // ETH
  it("Get price of ETH for 100 BNB", async () => {
    const eth = "0x2170Ed0880ac9A755fd29B2688956BD959F933F8";
    const wbnb = "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c";
    const path = [eth, wbnb];
    priceOracle.getPrice("100", path).then((resp) => {
      expect(resp).to.be.greaterThanOrEqual(0);
    });
  });

  it("Get pair address of ETH and WBNB", async () => {
    const eth = "0x2170Ed0880ac9A755fd29B2688956BD959F933F8";
    const wbnb = "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c";
    priceOracle.getPairAddress(eth, wbnb).then((resp) => {
      expect(resp).not.to.be.equal(
        "0x0000000000000000000000000000000000000000"
      );
    });
  });

  it("Get ETH token price of WBNB", async () => {
    const eth = "0x2170Ed0880ac9A755fd29B2688956BD959F933F8";
    const wbnb = "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c";
    priceOracle.getTokenPrice(wbnb, eth).then((resp) => {
      expect(resp).to.be.greaterThanOrEqual(0);
    });
  });

  // USDT
  it("Get price of USDT for 100 BNB", async () => {
    const usd = "0xfD5840Cd36d94D7229439859C0112a4185BC0255";
    const wbnb = "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c";
    const path = [usd, wbnb];
    priceOracle.getPrice("100", path).then((resp) => {
      expect(resp).to.be.greaterThanOrEqual(0);
    });
  });

  it("Get pair address of USDT and WBNB", async () => {
    const usd = "0xfD5840Cd36d94D7229439859C0112a4185BC0255";
    const wbnb = "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c";
    priceOracle.getPairAddress(usd, wbnb).then((resp) => {
      expect(resp).not.to.be.equal(
        "0x0000000000000000000000000000000000000000"
      );
    });
  });

  it("Get USDT token price of WBNB", async () => {
    const usd = "0xfD5840Cd36d94D7229439859C0112a4185BC0255";
    const wbnb = "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c";
    priceOracle.getTokenPrice(wbnb, usd).then((resp) => {
      expect(resp).to.be.greaterThanOrEqual(0);
    });
  });
  // LINK
  it("Get token price of LINK", async () => {
    const link = "0xF8A0BF9cF54Bb92F17374d9e9A321E6a111a51bD";
    const wbnb = "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c";
    priceOracle.getTokenPrice(wbnb, link).then((resp) => {
      expect(resp).to.be.greaterThanOrEqual(0);
    });
  });

  it("Get price of LINK for 100 BNB", async () => {
    const link = "0xF8A0BF9cF54Bb92F17374d9e9A321E6a111a51bD";
    const wbnb = "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c";
    const path = [link, wbnb];
    priceOracle.getPrice("100", path).then((resp) => {
      expect(resp).to.be.greaterThanOrEqual(0);
    });
  });

  it("Get pair address of LINK and WBNB", async () => {
    const link = "0xF8A0BF9cF54Bb92F17374d9e9A321E6a111a51bD";
    const wbnb = "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c";
    let pairAdress = "0x0000000000000000000000000000000000000000";
    priceOracle.getPairAddress(link, wbnb).then((resp) => {
      expect(pairAdress).not.to.be.equal(
        "0x0000000000000000000000000000000000000000"
      );
    });
  });

  it("Update index price", async () => {
    priceOracle.updateIndexPrice().then((resp) => {
      expect(resp).to.be.greaterThanOrEqual(0);
    });
  });
});
