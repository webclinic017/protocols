import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { ethers } from "hardhat";
import { IndexSwap, PriceOracle, IERC20__factory } from "../typechain";
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

  describe.only("Tests for IndexSwap contract", () => {
    before(async () => {
      accounts = await ethers.getSigners();
      [owner, investor1, nonOwner, vault, addr1, addr2, ...addrs] = accounts;
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

    describe("IndexSwap Contract", function () {
      it("Initialize IndexFund Tokens", async () => {
        await indexSwap
          .connect(owner)
          .initialize(
            [busdInstance.address, ethInstance.address],
            [5000, 5000]
          );
      });

      it("Invest 0.1BNB into Top10 fund", async () => {
        const indexSupplyBefore = await indexSwap.totalSupply();
        //console.log("0.1 before", indexSupplyBefore);
        await indexSwap.investInFund({
          value: ethers.utils.parseEther("0.1"),
        });
        const indexSupplyAfter = await indexSwap.totalSupply();
        //console.log("0.1 after", indexSupplyAfter);
      });

      it("Invest 0.1BNB into Top10 fund", async () => {
        const indexSupplyBefore = await indexSwap.totalSupply();
        //console.log("0.1 before", indexSupplyBefore);
        await indexSwap.investInFund({
          value: ethers.utils.parseEther("0.1"),
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
          value: ethers.utils.parseEther("0.2"),
        });
        const indexSupplyAfter = await indexSwap.totalSupply();
        const valuesAfter = await indexSwap.getTokenAndVaultBalance();
        const balancesAfter = valuesAfter[0];
        bnbAfter = Number(balancesAfter[1]);
      });

      it("BNB amount increases after investing", async () => {
        expect(bnbAfter).to.be.greaterThan(bnbBefore);
      });

      it("should Rebalance", async () => {
        await indexSwap.rebalance();
      });

      it("should Update Weights and Rebalance", async () => {
        const {
          tokenXBalance: beforeTokenXBalance,
          vaultValue: beforeVaultValue,
        } = await indexSwap.getTokenAndVaultBalance();

        await indexSwap.updateWeights([3333, 6667]);

        const {
          tokenXBalance: afterTokenXBalance,
          vaultValue: afterVaultValue,
        } = await indexSwap.getTokenAndVaultBalance();

        console.log({
          beforeToken0Bal: ethers.utils.formatEther(beforeTokenXBalance[0]),
          beforeToken1Bal: ethers.utils.formatEther(beforeTokenXBalance[1]),
          beforeVaultValue: ethers.utils.formatEther(beforeVaultValue),
          afterToken0Bal: ethers.utils.formatEther(afterTokenXBalance[0]),
          afterToken1Bal: ethers.utils.formatEther(afterTokenXBalance[1]),
          afterVaultValue: ethers.utils.formatEther(afterVaultValue),
        });
      });

      it("should update tokens", async () => {
        // current = BUSD:ETH = 1:2
        // target = ETH:DAI:WBNB = 1:3:1

        const {
          tokenXBalance: beforeTokenXBalance,
          vaultValue: beforeVaultValue,
        } = await indexSwap.getTokenAndVaultBalance();

        await indexSwap.updateTokens(
          [ethInstance.address, daiInstance.address, wbnbInstance.address],
          [2000, 6000, 2000]
        );

        const {
          tokenXBalance: afterTokenXBalance,
          vaultValue: afterVaultValue,
        } = await indexSwap.getTokenAndVaultBalance();

        console.log({
          beforeBUSDBal: ethers.utils.formatEther(beforeTokenXBalance[0]),
          beforeETHBal: ethers.utils.formatEther(beforeTokenXBalance[1]),
          beforeVaultValue: ethers.utils.formatEther(beforeVaultValue),
          afterETHBal: ethers.utils.formatEther(afterTokenXBalance[0]),
          afterDAIBal: ethers.utils.formatEther(afterTokenXBalance[1]),
          afterWBNBBal: ethers.utils.formatEther(afterTokenXBalance[2]),
          afterVaultValue: ethers.utils.formatEther(afterVaultValue),
        });
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
