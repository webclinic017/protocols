pragma solidity ^0.8.4 || ^0.7.6 || ^0.8.0;

import "./interfaces/IUniswapV2Router02.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@uniswap/lib/contracts/libraries/TransferHelper.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IPriceOracle.sol";
import "./interfaces/IBalancerLib.sol";
import "./interfaces/IWETH.sol";

contract TokenBase is ERC20, ERC20Burnable, Ownable {
    constructor() ERC20("INDEXLY", "IDX") {}
}

contract IndexSwap is TokenBase, BMath {
    IUniswapV2Router02 public pancakeSwapRouter;

    // IERC20 public token;
    using SafeMath for uint256;

    uint256 public indexPrice;

    address private vault;

    struct rate {
        uint256 numerator;
        uint256 denominator;
    }

    /**
     * @dev Token record data structure
     * @param bound is token bound to pool
     * @param ready has token been initialized
     * @param lastDenormUpdate timestamp of last denorm change
     * @param denorm denormalized weight
     * @param desiredDenorm desired denormalized weight (used for incremental changes)
     * @param index index of address in tokens array
     * @param balance token balance
     */
    struct Record {
        bool ready;
        uint40 lastDenormUpdate;
        uint96 denorm;
        uint96 desiredDenorm;
        uint8 index;
        uint256 balance;
    }
    // Array of underlying tokens in the pool.
    address[] internal _tokens;

    // Internal records of the pool's underlying tokens
    mapping(address => Record) internal _records;

    // Total denormalized weight of the pool.
    uint256 internal _totalWeight;

    uint256 internal indexDivisor;

    mapping(address => uint256) admins;

    // True if PUBLIC can call SWAP & JOIN functions
    bool internal _publicSwap;

    rate public currentRate;

    IPriceOracle oracal;

    address outAssest;

    constructor(
        address _oracal,
        address _outAssest,
        address _pancakeSwapAddress,
        address _vault
    ) {
        pancakeSwapRouter = IUniswapV2Router02(_pancakeSwapAddress);
        oracal = IPriceOracle(_oracal);
        vault = _vault;
        outAssest = _outAssest; //As now we are tacking busd
        assetManagers[msg.sender] = true;
    }

    mapping(address => bool) public assetManagers;

    modifier onlyAssetManager() {
        require(assetManagers[msg.sender]);
        _;
    }

    function addAssetManager(address assetManager) public onlyAssetManager {
        require(
            assetManager != address(0),
            "Ownable: new manager is the zero address"
        );
        assetManagers[assetManager] = true;
    }

    /** @dev Emitted when public trades are enabled. */
    event LOG_PUBLIC_SWAP_ENABLED();

    /**
     * @dev Sets up the initial assets for the pool.
     *
     * @param tokens Underlying tokens to initialize the pool with
     * @param denorms Initial denormalized weights for the tokens
     */
    function initialize(address[] calldata tokens, uint96[] calldata denorms)
        external
        onlyOwner
    {
        require(_tokens.length == 0, "INITIALIZED");
        uint256 len = tokens.length;
        uint256 totalWeight = 0;
        uint256 sumPrice = 0;
        for (uint256 i = 0; i < len; i++) {
            _records[tokens[i]] = Record({
                ready: true,
                lastDenormUpdate: uint40(block.timestamp),
                denorm: denorms[i],
                desiredDenorm: denorms[i],
                index: uint8(i),
                balance: 0
            });
            _tokens.push(tokens[i]);
            uint256 priceToken = oracal.getTokenPrice(_tokens[i], outAssest);

            sumPrice = sumPrice.add(priceToken);
            totalWeight = badd(totalWeight, denorms[i]);
        }
        _totalWeight = totalWeight;
        indexDivisor = sumPrice.div(len);
        _publicSwap = true;
        emit LOG_PUBLIC_SWAP_ENABLED();
    }

    function _pushUnderlying(
        address erc20,
        address to,
        uint256 amount
    ) internal {
        (bool success, bytes memory data) = erc20.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "ERC20_FALSE"
        );
    }

    function updateRate(uint256 _numerator, uint256 _denominator) public {
        require(_numerator != 0);
        require(_denominator != 0);
        currentRate.numerator = _numerator;
        currentRate.denominator = _denominator;
    }

    function mintShareAmount(uint256 _amount, uint256 sumPrice)
        internal
        view
        returns (uint256 price)
    {
        uint256 indexTokenSupply = totalSupply();

        return _amount.mul(indexTokenSupply).div(sumPrice);
    }

    function getTokenAndVaultBalance()
        public
        view
        returns (uint256[] memory tokenXBalance, uint256 vaultValue)
    {
        uint256 len = _tokens.length;
        uint256[] memory tokenBalanceInBNB = new uint256[](len);
        uint256 vaultBalance = 0;

        if (totalSupply() > 0) {
            /* 
                calculate the balance of all tokens in the vault (in BNB)
                has to be calculated before the swap because after the balance will change 
            */
            for (uint256 i = 0; i < len; i++) {
                IERC20 token = IERC20(_tokens[i]);
                uint256 tokenBalance = token.balanceOf(vault);
                uint256 priceToken;
                uint256 tokenBalanceBNB;
                if (_tokens[i] == getETH()) {
                    tokenBalanceBNB = tokenBalance;
                } else {
                    uint256 decimal = oracal.getDecimal(_tokens[i]);
                    priceToken = oracal.getTokenPrice(_tokens[i], outAssest);
                    tokenBalanceBNB = priceToken.mul(tokenBalance).div(
                        10**decimal
                    );
                }
                tokenBalanceInBNB[i] = tokenBalanceBNB;
                vaultBalance = vaultBalance.add(tokenBalanceBNB);

                require(vaultBalance > 0, "sum price is not greater than 0");
            }
            return (tokenBalanceInBNB, vaultBalance);
        } else {
            return (new uint256[](0), 0);
        }
    }

    function investInFund() public payable {
        uint256 tokenAmount = msg.value;
        uint256 investedAmountAfterSlippage = 0;
        uint256 vaultBalance = 0;
        uint256 len = _tokens.length;
        uint256[] memory amount = new uint256[](len);
        uint256[] memory tokenBalanceInBNB = new uint256[](len);

        (tokenBalanceInBNB, vaultBalance) = getTokenAndVaultBalance();

        //calculate the swap amount for each token to ensure that the ratio (weight in the portfolio) stays constant
        if (totalSupply() > 0) {
            for (uint256 i = 0; i < _tokens.length; i++) {
                amount[i] = tokenBalanceInBNB[i].mul(tokenAmount).div(
                    vaultBalance
                );
            }
        }

        // swap tokens from BNB to tokens in portfolio swapResult[1]: swapped token amount
        uint256 deadline = block.timestamp; // using 'now' for convenience, for mainnet pass deadline from frontend!
        for (uint256 i = 0; i < _tokens.length; i++) {
            IERC20Metadata t = IERC20Metadata(_tokens[i]);
            Record memory record = _records[address(t)];
            uint256 swapAmount;
            if (totalSupply() == 0) {
                swapAmount = tokenAmount.mul(record.denorm).div(_totalWeight);
            } else {
                swapAmount = amount[i];
            }

            uint256 swapResultBNB;

            if (address(t) == getETH()) {
                require(address(this).balance >= swapAmount, "not enough bnb");
                IWETH token = IWETH(address(t));
                token.deposit{value: swapAmount}();
                token.transfer(vault, swapAmount);
                swapResultBNB = swapAmount;
                investedAmountAfterSlippage = investedAmountAfterSlippage.add(
                    swapAmount
                );
            } else {
                uint256[] memory swapResult;
                swapResult = pancakeSwapRouter.swapExactETHForTokens{
                    value: swapAmount
                }(0, getPathForETH(address(t)), vault, deadline);

                // take the amount actually being swapped and convert it to BNB for calculation of the index token amount to mint
                swapResultBNB = oracal.getTokenPrice(_tokens[i], outAssest);
                uint256 decimal = t.decimals();
                investedAmountAfterSlippage = investedAmountAfterSlippage.add(
                    swapResultBNB.mul(swapResult[1]).div(10**decimal)
                );
            }

            /*
                take the amount actually being swapped and convert it to BNB
                for calculation of the index token amount to mint
            */
            // uint256 swapResultBNB = oracal.getTokenPrice(_tokens[i], outAssest);
        }
        require(
            investedAmountAfterSlippage <= tokenAmount,
            "amount after slippage can't be greater than before"
        );
        /*
            calculates the index token amount to mint invested amount after slippage is considered
            to make sure the index token amount represents the invested amount after slippage
        */
        if (totalSupply() > 0) {
            tokenAmount = mintShareAmount(
                investedAmountAfterSlippage,
                vaultBalance
            );
        } else {
            tokenAmount = investedAmountAfterSlippage;
        }

        _mint(msg.sender, tokenAmount);

        // refund leftover ETH to user
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        require(success, "refund failed");
    }

    function withdrawFund(uint256 tokenAmount) public {
        require(
            tokenAmount <= balanceOf(msg.sender),
            "caller is not holding given token amount"
        );

        uint256 deadline = block.timestamp;
        uint256 totalSupplyIndex = totalSupply();

        _burn(msg.sender, tokenAmount);

        for (uint256 i = 0; i < _tokens.length; i++) {
            address t = _tokens[i];

            IERC20 token = IERC20(t);
            uint256 tokenBalance = token.balanceOf(vault);
            uint256 amount = tokenBalance.mul(tokenAmount).div(
                totalSupplyIndex
            );

            if (_tokens[i] == getETH()) {
                TransferHelper.safeTransferFrom(
                    address(t),
                    vault,
                    msg.sender,
                    amount
                );
            } else {
                TransferHelper.safeTransferFrom(
                    address(t),
                    vault,
                    address(this),
                    amount
                );
                TransferHelper.safeApprove(
                    address(t),
                    address(pancakeSwapRouter),
                    amount
                );
                pancakeSwapRouter.swapExactTokensForETH(
                    amount,
                    0,
                    getPathForToken(t),
                    msg.sender,
                    deadline
                );
            }
        }
    }

    function rebalance() public onlyAssetManager {
        uint256 sumWeightsToSwap = 0;
        uint256 totalBNBAmount = 0;
        uint256 vaultBalance = 0;
        uint256 len = _tokens.length;
        
        uint256[] memory newWeights = new uint256[](len);
        uint256[] memory oldWeights = new uint256[](len);
        uint256[] memory tokenBalanceInBNB = new uint256[](len);

        // get current rates xx.xx% (*10000)
        (tokenBalanceInBNB, vaultBalance) = getTokenAndVaultBalance();

        if (totalSupply() > 0) {
            for (uint256 i = 0; i < _tokens.length; i++) {
                oldWeights[i] = tokenBalanceInBNB[i].mul(10000).div(
                    vaultBalance
                );
                newWeights[i] = uint256(_records[_tokens[i]].denorm)
                    .mul(10000)
                    .div(_totalWeight);
            }

            // sell - swap to BNB
            uint256 deadline = block.timestamp;
            for (uint256 i = 0; i < _tokens.length; i++) {
                if (newWeights[i] < oldWeights[i]) {
                    IERC20 token = IERC20(_tokens[i]);
                    uint256 tokenBalance = token.balanceOf(vault);
                    uint256 weightDiff = oldWeights[i].sub(newWeights[i]);
                    uint256 _swapAmount = tokenBalance.mul(weightDiff).div(
                        oldWeights[i]
                    );

                    TransferHelper.safeTransferFrom(
                        _tokens[i],
                        vault,
                        address(this),
                        _swapAmount
                    );

                    uint256 swapResult;
                    if (_tokens[i] == getETH()) {
                        IWETH(_tokens[i]).withdraw(_swapAmount);
                        swapResult = _swapAmount;
                    } else {
                        TransferHelper.safeApprove(
                            _tokens[i],
                            address(pancakeSwapRouter),
                            _swapAmount
                        );
                        swapResult = pancakeSwapRouter.swapExactTokensForETH(
                            _swapAmount,
                            0,
                            getPathForToken(_tokens[i]),
                            address(this),
                            deadline
                        )[1];
                    }

                    totalBNBAmount.add(swapResult);
                } else if (newWeights[i] > oldWeights[i]) {
                    uint256 diff = newWeights[i].sub(oldWeights[i]);
                    sumWeightsToSwap = sumWeightsToSwap.add(diff);
                }
                _records[_tokens[i]].denorm = uint96(newWeights[i]);
            }

            // buy - swap from BNB to token
            totalBNBAmount = address(this).balance;
            for (uint256 i = 0; i < len; i++) {
                address t = _tokens[i];
                if (newWeights[i] > oldWeights[i]) {
                    uint256 weightToSwap = newWeights[i].sub(oldWeights[i]);
                    require(weightToSwap > 0, "weight not greater than 0");
                    require(sumWeightsToSwap > 0, "div by 0, sumweight");
                    uint256 swapAmount = totalBNBAmount.mul(weightToSwap).div(
                        sumWeightsToSwap
                    );
                    if (t == getETH()) {
                        IWETH(t).deposit{value: swapAmount}();
                        TransferHelper.safeTransfer(t, vault, swapAmount);
                    } else {
                        pancakeSwapRouter.swapExactETHForTokens{
                            value: swapAmount
                        }(0, getPathForETH(t), vault, deadline);
                    }
                }
            }
        }
    }

    function updateWeights(uint96[] calldata denorms) public onlyAssetManager {
        uint256 len = _tokens.length;
        require(denorms.length == len, "Lengths don't match");

        uint256 totalWeight = 0;
        for (uint256 i = 0; i < len; i++) {
            Record storage record = _records[_tokens[i]];
            record.lastDenormUpdate = uint40(block.timestamp);
            record.denorm = denorms[i];
            record.desiredDenorm = denorms[i];

            totalWeight = badd(totalWeight, denorms[i]);
        }
        _totalWeight = totalWeight;

        rebalance();
    }

    function getPathForETH(address crypto)
        public
        view
        returns (address[] memory)
    {
        address[] memory path = new address[](2);
        path[0] = getETH();
        path[1] = crypto;

        return path;
    }

    function getPathForToken(address token)
        public
        view
        returns (address[] memory)
    {
        address[] memory path = new address[](2);
        path[0] = token;
        path[1] = getETH();

        return path;
    }

    function getETH() public view returns (address) {
        return pancakeSwapRouter.WETH();
    }

    // important to receive ETH
    receive() external payable {}
}
