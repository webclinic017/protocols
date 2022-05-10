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
    await priceOracle.initialize("0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3");
  });

  it("Get token price of BTC", async () => {
    const btc = "0x4b1851167f74FF108A994872A160f1D6772d474b";
    const wbnb = "0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd";
    priceOracle.getTokenPrice(wbnb, btc).then((resp) => {
      expect(resp).to.be.greaterThanOrEqual(0);
    });
  });

  it("Get price of BTC for 100 BNB", async () => {
    const btc = "0x4b1851167f74FF108A994872A160f1D6772d474b";
    const wbnb = "0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd";
    const path = [btc, wbnb];
    priceOracle.getPrice("100", path).then((resp) => {
      expect(resp).to.be.greaterThanOrEqual(0);
    });
  });

  it("Get pair address of BTC and WBNB", async () => {
    const btc = "0x4b1851167f74FF108A994872A160f1D6772d474b";
    const wbnb = "0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd";
    const pairAdress = priceOracle.getPairAddress(btc, wbnb);
    expect(pairAdress).not.to.be.equal(
      "0x0000000000000000000000000000000000000000"
    );
  });

  it("Get token price of ETH", async () => {
    const eth = "0x8BaBbB98678facC7342735486C851ABD7A0d17Ca";
    const wbnb = "0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd";
    priceOracle.getTokenPrice(wbnb, eth).then((resp) => {
      expect(resp).to.be.greaterThanOrEqual(0);
    });
  });

  it("Get price of ETH for 100 BNB", async () => {
    const eth = "0x8BaBbB98678facC7342735486C851ABD7A0d17Ca";
    const wbnb = "0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd";
    const path = [eth, wbnb];
    priceOracle.getPrice("100", path).then((resp) => {
      expect(resp).to.be.greaterThanOrEqual(0);
    });
  });

  it("Get pair address of ETH and WBNB", async () => {
    const eth = "0x8BaBbB98678facC7342735486C851ABD7A0d17Ca";
    const wbnb = "0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd";
    const pairAdress = priceOracle.getPairAddress(eth, wbnb);
    expect(pairAdress).not.to.be.equal(
      "0x0000000000000000000000000000000000000000"
    );
  });
});
