import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { ethers } from "hardhat";
import {
  IndexSwap,
  PriceOracle,
  IERC20__factory,
  IndexFactory,
} from "../typechain";
import { chainIdToAddresses } from "../scripts/networkVariables";

//use default BigNumber
// chai.use(require("chai-bignumber")());

describe.skip("Tests for IndexFactory", () => {
  let accounts;
  let priceOracle: PriceOracle;
  let indexSwap: IndexSwap;
  let indexFactory: IndexFactory;
  let txObject;
  let owner: SignerWithAddress;
  let nonOwner: SignerWithAddress;
  let investor1: SignerWithAddress;
  let addr2: SignerWithAddress;
  let addr1: SignerWithAddress;
  let vault: SignerWithAddress;
  let addrs: SignerWithAddress[];
  //const APPROVE_INFINITE = ethers.BigNumber.from(1157920892373161954235); //115792089237316195423570985008687907853269984665640564039457
  let approve_amount = ethers.constants.MaxUint256; //(2^256 - 1 )
  let token;
  const forkChainId: any = process.env.FORK_CHAINID;
  const provider = ethers.provider;
  const chainId: any = forkChainId ? forkChainId : 97;
  const addresses = chainIdToAddresses[chainId];
  var bnbBefore = 0;
  var bnbAfter = 0;

  const wbnbInstance = new ethers.Contract(
    addresses.WETH_Address,
    IERC20__factory.abi,
    ethers.getDefaultProvider()
  );
  const busdInstance = new ethers.Contract(
    addresses.BUSD,
    IERC20__factory.abi,
    ethers.getDefaultProvider()
  );
  const daiInstance = new ethers.Contract(
    addresses.DAI_Address,
    IERC20__factory.abi,
    ethers.getDefaultProvider()
  );
  const ethInstance = new ethers.Contract(
    addresses.ETH_Address,
    IERC20__factory.abi,
    ethers.getDefaultProvider()
  );
  const btcInstance = new ethers.Contract(
    addresses.BTC_Address,
    IERC20__factory.abi,
    ethers.getDefaultProvider()
  );
  // const wbnbInstance.address =addresses.WETH_Address;
  // const btcInstance.address = addresses.BTC_Address;
  // const ethInstance.address = addresses.ETH_Address;
  describe.only("Tests for IndexFactory contract", () => {
    before(async () => {
      accounts = await ethers.getSigners();
      [owner, investor1, nonOwner, vault, addr1, addr2, ...addrs] = accounts;
      const PriceOracle = await ethers.getContractFactory("PriceOracle");
      priceOracle = await PriceOracle.deploy();

      await priceOracle.deployed();
      await priceOracle.initialize(addresses.PancakeSwapRouterAddress);

      const IndexFactory = await ethers.getContractFactory("IndexFactory");
      indexFactory = await IndexFactory.deploy();
      await indexFactory.deployed();

      let indexAddress = "";

      const index = await indexFactory.createIndex(
        "INDEXLY",
        "IDX",
        priceOracle.address,
        addresses.WETH_Address,
        addresses.PancakeSwapRouterAddress,
        addresses.Vault,
        "500000000000000000000"
      );

      const result = index.to;
      if (result) {
        indexAddress = result.toString();
      }

      const IndexSwap = await ethers.getContractFactory("IndexSwap");
      indexSwap = await IndexSwap.attach(indexAddress);

      await busdInstance
        .connect(vault)
        .approve(indexSwap.address, approve_amount);
      await wbnbInstance
        .connect(vault)
        .approve(indexSwap.address, approve_amount);
      await daiInstance
        .connect(vault)
        .approve(indexSwap.address, approve_amount);
      await ethInstance
        .connect(vault)
        .approve(indexSwap.address, approve_amount);
      await btcInstance
        .connect(vault)
        .approve(indexSwap.address, approve_amount);

      console.log("indexSwap deployed to:", indexSwap.address);
    });

    describe("IndexFactory Contract", function () {
      it("init", async () => {
        let indexAddress = "";

        const index = await indexFactory.createIndex(
          "INDEXLY",
          "IDX",
          priceOracle.address,
          addresses.WETH_Address,
          addresses.PancakeSwapRouterAddress,
          addresses.Vault,
          "500000000000000000000"
        );

        console.log("index return from factory", index);

        const result = index.to;
        if (result) {
          indexAddress = result.toString();
        }

        const IndexSwap = await ethers.getContractFactory("IndexSwap");
        indexSwap = await IndexSwap.attach(indexAddress);
      });

      it("Initialize IndexFund Tokens", async () => {
        console.log(indexSwap.address);
      });

      it("Initialize IndexFund Tokens", async () => {
        await indexSwap
          .connect(owner)
          .initialize([busdInstance.address, ethInstance.address], [1, 1]);
      });

      it("Invest 0.1BNB into Top10 fund", async () => {
        const indexSupplyBefore = await indexSwap.totalSupply();
        //console.log("0.1 before", indexSupplyBefore);
        await indexSwap.investInFund({
          value: "100000000000000000",
        });
        const indexSupplyAfter = await indexSwap.totalSupply();
        //console.log("0.1 after", indexSupplyAfter);
      });

      it("Invest 0.1BNB into Top10 fund", async () => {
        const indexSupplyBefore = await indexSwap.totalSupply();
        //console.log("0.1 before", indexSupplyBefore);
        await indexSwap.investInFund({
          value: "100000000000000000",
        });
        const indexSupplyAfter = await indexSwap.totalSupply();
        const valuesAfter = await indexSwap.getTokenAndVaultBalance();
        const balancesAfter = valuesAfter[0];
        bnbBefore = Number(balancesAfter[1]);
      });

      it("Invest 0.2BNB into Top10 fund", async () => {
        const indexSupplyBefore = await indexSwap.totalSupply();
        //console.log("0.2 before", indexSupplyBefore);
        await indexSwap.investInFund({
          value: "200000000000000000",
        });
        const indexSupplyAfter = await indexSwap.totalSupply();
        const valuesAfter = await indexSwap.getTokenAndVaultBalance();
        const balancesAfter = valuesAfter[0];
        bnbAfter = Number(balancesAfter[1]);
      });

      it("BNB amount increases after investing", async () => {
        expect(bnbAfter).to.be.greaterThan(bnbBefore);
      });

      it("Test amount and vault values", async () => {
        const values = await indexSwap.getTokenAndVaultBalance();
        //console.log("tokenBalances", values[0]);
        //console.log("vault", values[1]);
      });

      it("should Rebalance", async () => {
        await indexSwap.rebalance();
      });

      it("when withdraw fund more then balance", async () => {
        const amountIndexToken = await indexSwap.balanceOf(owner.address);
        const updateAmount = parseInt(amountIndexToken.toString()) + 1;
        const AMOUNT = ethers.BigNumber.from(updateAmount.toString()); //

        await expect(
          indexSwap.connect(nonOwner).withdrawFund(AMOUNT)
        ).to.be.revertedWith("caller is not holding given token amount");
      });

      it("should withdraw fund and burn index token successfully", async () => {
        const amountIndexToken = await indexSwap.balanceOf(owner.address);
        //console.log(amountIndexToken, "amountIndexToken");
        const AMOUNT = ethers.BigNumber.from(amountIndexToken); //1BNB

        txObject = await indexSwap.withdrawFund(AMOUNT);

        expect(txObject.confirmations).to.equal(1);
      });
    });
  });
});
