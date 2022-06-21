import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { ethers } from "hardhat";
import {
  IndexSwap,
  PriceOracle,
  IERC20__factory,
  IndexSwapLibrary,
  IndexManager,
  Rebalancing,
  AccessController,
} from "../typechain";
import { chainIdToAddresses } from "../scripts/networkVariables";

//use default BigNumber
// chai.use(require("chai-bignumber")());

describe.only("Tests for IndexSwap", () => {
  let accounts;
  let priceOracle: PriceOracle;
  let indexSwap: IndexSwap;
  let indexSwapLibrary: IndexSwapLibrary;
  let indexManager: IndexManager;
  let rebalancing: Rebalancing;
  let accessController: AccessController;
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
  const chainId: any = forkChainId ? forkChainId : 56;
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

      await priceOracle.initialize(addresses.PancakeSwapV2RouterAddress);

      const IndexSwapLibrary = await ethers.getContractFactory(
        "IndexSwapLibrary"
      );
      indexSwapLibrary = await IndexSwapLibrary.deploy(
        priceOracle.address,
        addresses.WETH_Address
      );
      await indexSwapLibrary.deployed();

      const AccessController = await ethers.getContractFactory(
        "AccessController"
      );
      accessController = await AccessController.deploy();
      await accessController.deployed();

      const IndexManager = await ethers.getContractFactory("IndexManager");
      indexManager = await IndexManager.deploy(
        accessController.address,
        "0x7250C7A64C5BCbe4815E905C10F822C2DA7358Ef",
        addresses.PancakeSwapV2RouterAddress
      );
      await indexManager.deployed();

      const IndexSwap = await ethers.getContractFactory("IndexSwap");
      indexSwap = await IndexSwap.deploy(
        "INDEXLY",
        "IDX",
        addresses.WETH_Address,
        addresses.Vault, // vault
        "500000000000000000000", // max investment amount
        indexSwapLibrary.address,
        indexManager.address,
        accessController.address
      );
      await indexSwap.deployed();

      const Rebalancing = await ethers.getContractFactory("Rebalancing");
      rebalancing = await Rebalancing.deploy(
        indexSwapLibrary.address,
        indexManager.address,
        accessController.address
      );
      await rebalancing.deployed();

      const MyModule = ethers.getContractFactory("MyModule");
      let myModule = (await MyModule).attach(addresses.Module);
      myModule.addOwner(indexManager.address);

      console.log("indexSwap deployed to:", indexSwap.address);
    });

    describe("IndexSwap Contract", function () {
      it("should check Index token name and symbol", async () => {
        expect(await indexSwap.name()).to.eq("INDEXLY");
        expect(await indexSwap.symbol()).to.eq("IDX");
      });
      it("initialize should revert if total Weights not equal 10,000", async () => {
        await expect(
          indexSwap.initialize(
            [btcInstance.address, ethInstance.address],
            [5000, 1000]
          )
        ).to.be.revertedWith("INVALID_WEIGHTS");
      });
      it("Initialize IndexFund Tokens", async () => {
        await indexSwap.initialize(
          [btcInstance.address, ethInstance.address],
          [5000, 5000]
        );
      });

      it("Invest 0.1BNB into Top10 fund", async () => {
        const indexSupplyBefore = await indexSwap.totalSupply();

        await indexSwap.investInFund({
          value: ethers.utils.parseEther("0.1"),
        });
        const indexSupplyAfter = await indexSwap.totalSupply();
        const valuesAfter = await indexSwapLibrary.getTokenAndVaultBalance(
          indexSwap.address
        );
        const balancesAfter = valuesAfter[0];
        bnbBefore = Number(balancesAfter[1]);

        expect(Number(indexSupplyAfter)).to.be.gt(Number(indexSupplyBefore));
      });

      it("Invest 0.2BNB into Top10 fund", async () => {
        const indexSupplyBefore = await indexSwap.totalSupply();

        await indexSwap.investInFund({
          value: ethers.utils.parseEther("0.2"),
        });
        const indexSupplyAfter = await indexSwap.totalSupply();
        const valuesAfter = await indexSwapLibrary.getTokenAndVaultBalance(
          indexSwap.address
        );
        const balancesAfter = valuesAfter[0];
        bnbAfter = Number(balancesAfter[1]);

        expect(Number(indexSupplyAfter)).to.be.gt(Number(indexSupplyBefore));
      });

      it("BNB amount increases after investing", async () => {
        expect(bnbAfter).to.be.gt(bnbBefore);
      });

      it("should Rebalance", async () => {
        await rebalancing.rebalance(indexSwap.address);
      });

      it("should revert when Rebalance is called from an account which is not assigned as asset manager", async () => {
        await expect(
          rebalancing.connect(nonOwner).rebalance(indexSwap.address)
        ).to.be.revertedWith("Caller is not an Asset Manager");
      });

      it("updateWeights should revert if total Weights not equal 10,000", async () => {
        await expect(
          rebalancing.updateWeights(indexSwap.address, [100, 200])
        ).to.be.revertedWith("INVALID_WEIGHTS");
      });
      it("should Update Weights and Rebalance", async () => {
        const {
          tokenXBalance: beforeTokenXBalance,
          vaultValue: beforeVaultValue,
        } = await indexSwapLibrary.getTokenAndVaultBalance(indexSwap.address);

        await rebalancing.updateWeights(indexSwap.address, [3333, 6667]);

        const {
          tokenXBalance: afterTokenXBalance,
          vaultValue: afterVaultValueBN,
        } = await indexSwapLibrary.getTokenAndVaultBalance(indexSwap.address);

        // console.log({
        //   beforeToken0Bal: ethers.utils.formatEther(beforeTokenXBalance[0]),
        //   beforeToken1Bal: ethers.utils.formatEther(beforeTokenXBalance[1]),
        //   beforeVaultValue: ethers.utils.formatEther(beforeVaultValue),
        //   afterToken0Bal: ethers.utils.formatEther(afterTokenXBalance[0]),
        //   afterToken1Bal: ethers.utils.formatEther(afterTokenXBalance[1]),
        //   afterVaultValue: ethers.utils.formatEther(afterVaultValueBN),
        // });

        const afterToken0Bal = Number(
          ethers.utils.formatEther(afterTokenXBalance[0])
        );
        const afterToken1Bal = Number(
          ethers.utils.formatEther(afterTokenXBalance[1])
        );
        const afterVaultValue = Number(
          ethers.utils.formatEther(afterVaultValueBN)
        );

        expect(Math.ceil((afterToken0Bal * 10) / afterVaultValue)).to.be.gte(
          (3333 * 10) / 10000
        );
        expect(Math.ceil((afterToken1Bal * 10) / afterVaultValue)).to.be.gte(
          (6667 * 10) / 10000
        );
      });

      it("updateTokens should revert if total Weights not equal 10,000", async () => {
        await expect(
          rebalancing.updateTokens(
            indexSwap.address,
            [ethInstance.address, daiInstance.address, wbnbInstance.address],
            [2000, 6000, 1000]
          )
        ).to.be.revertedWith("INVALID_WEIGHTS");
      });
      it("should update tokens", async () => {
        // current = BUSD:ETH = 1:2
        // target = ETH:DAI:WBNB = 1:3:1

        const {
          tokenXBalance: beforeTokenXBalance,
          vaultValue: beforeVaultValue,
        } = await indexSwapLibrary.getTokenAndVaultBalance(indexSwap.address);

        await rebalancing.updateTokens(
          indexSwap.address,
          [ethInstance.address, daiInstance.address, wbnbInstance.address],
          [2000, 6000, 2000]
        );

        const {
          tokenXBalance: afterTokenXBalance,
          vaultValue: afterVaultValueBN,
        } = await indexSwapLibrary.getTokenAndVaultBalance(indexSwap.address);

        // console.log({
        //   beforeBUSDBal: ethers.utils.formatEther(beforeTokenXBalance[0]),
        //   beforeETHBal: ethers.utils.formatEther(beforeTokenXBalance[1]),
        //   beforeVaultValue: ethers.utils.formatEther(beforeVaultValue),
        //   afterETHBal: ethers.utils.formatEther(afterTokenXBalance[0]),
        //   afterDAIBal: ethers.utils.formatEther(afterTokenXBalance[1]),
        //   afterWBNBBal: ethers.utils.formatEther(afterTokenXBalance[2]),
        //   afterVaultValue: ethers.utils.formatEther(afterVaultValue),
        // });
        const afterETHBal = Number(
          ethers.utils.formatEther(afterTokenXBalance[0])
        );
        const afterDAIBal = Number(
          ethers.utils.formatEther(afterTokenXBalance[1])
        );
        const afterWBNBBal = Number(
          ethers.utils.formatEther(afterTokenXBalance[2])
        );
        const afterVaultValue = Number(
          ethers.utils.formatEther(afterVaultValueBN)
        );

        expect(Math.ceil((afterETHBal * 10) / afterVaultValue)).to.be.gte(
          (2000 * 10) / 10000
        );
        expect(Math.ceil((afterDAIBal * 10) / afterVaultValue)).to.be.gte(
          (6000 * 10) / 10000
        );
        expect(Math.ceil((afterWBNBBal * 10) / afterVaultValue)).to.be.gte(
          (2000 * 10) / 10000
        );
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
