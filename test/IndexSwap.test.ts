import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { ethers } from "hardhat";
import { IndexSwap, PriceOracle,IERC20 ,IERC20__factory } from "../typechain";
import { BigNumber } from "ethers";
import { chainIdToAddresses } from "../scripts/networkVariables";

//use default BigNumber
// chai.use(require("chai-bignumber")());

describe.only("Tests for IndexSwap", () => {
  let accounts;
  let priceOracle: PriceOracle;
  let indexSwap: IndexSwap;
  let txObject;
  let owner: SignerWithAddress;
  let nonOwner: SignerWithAddress;
  let investor1: SignerWithAddress;
  let addr2: SignerWithAddress;
  let addr1: SignerWithAddress;
  let vault: SignerWithAddress;
  let addrs: SignerWithAddress[];
  //const APPROVE_INFINITE = ethers.BigNumber.from(1157920892373161954235); //115792089237316195423570985008687907853269984665640564039457
   let approve_amount = '115792089237316195423570985008687907853269984665640564039457584007913129639935'; //(2^256 - 1 )
  let token
  const forkChainId: any  = process.env.FORK_CHAINID;
  const provider = ethers.provider;
  const chainId:any = forkChainId ? forkChainId:97;
  const addresses = chainIdToAddresses[chainId];
 
  
  const wbnbInstance = new ethers.Contract(addresses.WETH_Address, IERC20__factory.abi, ethers.getDefaultProvider());
  const btcInstance = new ethers.Contract(addresses.BTC_Address, IERC20__factory.abi, ethers.getDefaultProvider());
  const ethInstance = new ethers.Contract(addresses.ETH_Address, IERC20__factory.abi, ethers.getDefaultProvider());

  // const wbnbInstance.address =addresses.WETH_Address;
  // const btcInstance.address = addresses.BTC_Address;
  // const ethInstance.address = addresses.ETH_Address;
  describe.only("Tests for IndexSwap contract", () => {
    before(async () => {
      accounts = await ethers.getSigners();
      [owner, investor1, nonOwner, vault,addr1, addr2, ...addrs] =accounts;

      const PriceOracle = await ethers.getContractFactory("PriceOracle");
      priceOracle = await PriceOracle.deploy();

      await priceOracle.deployed();
      await priceOracle.initialize(addresses.PancakeSwapRouterAddress);

      const IndexSwap = await ethers.getContractFactory("IndexSwap");
      indexSwap = await IndexSwap.deploy(
        priceOracle.address, // price oracle
        addresses.WETH_Address,
        addresses.PancakeSwapRouterAddress,
        vault.address
      );

      await indexSwap.deployed();

      await wbnbInstance.connect(vault).approve(indexSwap.address,approve_amount);
      await btcInstance.connect(vault).approve(indexSwap.address,approve_amount);
      await ethInstance.connect(vault).approve(indexSwap.address,approve_amount);
      

      console.log("indexSwap deployed to:", indexSwap.address);
    });
  
    describe("IndexSwap Contract", function () {  
      it("Initialize IndexFund Tokens", async () => {
        await indexSwap.initialize([
          wbnbInstance.address,
          btcInstance.address,
        ],[1,1]);
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
        const AMOUNT = ethers.BigNumber.from("1000000000000000000"); //1BNB
        //console.log(indexSupplyBefore);
        await indexSwap.investInFund(AMOUNT, {
          value: AMOUNT,
        });
        const indexSupplyAfter = await indexSwap.totalSupply();

        const investedAmountAfterSlippage =
          indexSwap.investedAmountAfterSlippage();
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

      it("Invest 1BNB into Top10 fund", async () => {
        const indexSupplyBefore = await indexSwap.totalSupply();
        //console.log(indexSupplyBefore);
        const AMOUNT = ethers.BigNumber.from("1000000000000000000"); //1BNB

        await indexSwap.investInFund(AMOUNT, {
          value: AMOUNT,
        });
        const indexSupplyAfter = await indexSwap.totalSupply();

        const investedAmountAfterSlippage =
          await indexSwap.investedAmountAfterSlippage();
        console.log("for 2 bnb", investedAmountAfterSlippage);

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

      it("Update rate to 2,2", async () => {
        const numerator = 2;
        const denominator = 2;
        await indexSwap.updateRate(numerator, denominator);
        const currentRate = await indexSwap.currentRate();

        expect(currentRate.numerator).to.be.equal(numerator);
        expect(currentRate.denominator).to.be.equal(denominator);
      });

      it("Get WBNB/BTC path", async () => {
        let p = [wbnbInstance.address, btcInstance.address];
        const path = await indexSwap.getPathForETH(btcInstance.address);

        expect(p[0].toUpperCase()).to.be.equal(path[0].toUpperCase());
        expect(p[1].toUpperCase()).to.be.equal(path[1].toUpperCase());
        expect(p.length).to.be.equal(path.length).to.be.equal(2);
      });

      it("Get BTC/WBNB path", async () => {
        let p = [btcInstance.address, wbnbInstance.address];
        const path = await indexSwap.getPathForToken(btcInstance.address);

        expect(p[0].toUpperCase()).to.be.equal(path[0].toUpperCase());
        expect(p[1].toUpperCase()).to.be.equal(path[1].toUpperCase());
        expect(p.length).to.be.equal(path.length).to.be.equal(2);
      });

      it("Get WBNB/ETH path", async () => {
        let p = [wbnbInstance.address, ethInstance.address];
        const path = await indexSwap.getPathForETH(ethInstance.address);

        expect(p[0].toUpperCase()).to.be.equal(path[0].toUpperCase());
        expect(p[1].toUpperCase()).to.be.equal(path[1].toUpperCase());
        expect(p.length).to.be.equal(path.length).to.be.equal(2);
      });

      it("Get ETH/WBNB path", async () => {
        let p = [ethInstance.address, wbnbInstance.address];
        const path = await indexSwap.getPathForToken(ethInstance.address);

        expect(p[0].toUpperCase()).to.be.equal(path[0].toUpperCase());
        expect(p[1].toUpperCase()).to.be.equal(path[1].toUpperCase());
        expect(p.length).to.be.equal(path.length).to.be.equal(2);
      });

      it("when withdraw fund more then balance", async () => {
        const amountIndexToken= await indexSwap.balanceOf(owner.address);
        const updateAmount=parseInt(amountIndexToken.toString()) + 1;
        const AMOUNT = ethers.BigNumber.from(updateAmount.toString()); //

        await expect(await indexSwap.connect(nonOwner).withdrawFund(AMOUNT)).to.be.revertedWith(
          "caller is not holding given token amount",
        );
      });

      it("should withdraw fund and burn index token successfully", async () => {
        const amountIndexToken= await indexSwap.balanceOf(owner.address);
        console.log(amountIndexToken,"amountIndexToken");
        const AMOUNT = ethers.BigNumber.from(amountIndexToken); //1BNB

        txObject = await indexSwap.withdrawFund(AMOUNT);

        expect(txObject.confirmations).to.equal(1);
      });
    });  
  });
});
