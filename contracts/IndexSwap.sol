pragma solidity ^0.8.4 || ^0.7.6 || ^0.8.0;

import "./interfaces/IUniswapV2Router02.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@uniswap/lib/contracts/libraries/TransferHelper.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IPriceOracle.sol";
import "./interfaces/IBalancerLib.sol";


contract TokenBase is ERC20, ERC20Burnable, Ownable {
    constructor() ERC20("INDEXLY", "IDX") {}
}

contract IndexSwap is TokenBase, BMath {

    IUniswapV2Router02 public pancakeSwapRouter;

    // IERC20 public token;
    using SafeMath for uint256;

    uint256 public indexPrice;

    address private vault;// = 0x07C0737fdc21adf93200bd625cc70a66B835Cf8b;

    uint96[2] denormsDefult = [1, 1];
    //uint96[10] denormsDefult = [1, 1, 1, 1, 1, 1, 1, 1, 1, 1];
    //uint totalSum;

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

    uint256 public investedAmountAfterSlippage;
    uint256 public vaultBalance;
    uint256[] amount;
    uint256[] tokenBalanceInBNB;

    constructor(
        address _oracal,
        address _outAssest,
        address _pancakeSwapAddress,
        address _vault
    ) {
        pancakeSwapRouter = IUniswapV2Router02(_pancakeSwapAddress);
        oracal = IPriceOracle(_oracal);
        vault = _vault;
        outAssest = _outAssest; //As now we are tacking 
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
            totalWeight = badd(totalWeight, denormsDefult[i]);
        }
        _totalWeight = totalWeight;
        indexDivisor = sumPrice.div(len);
        _publicSwap = true;
        emit LOG_PUBLIC_SWAP_ENABLED();
    }

    // function initializeDefult() external onlyOwner {
    //     uint256 len = tokenDefult.length;
    //     uint256 totalWeight = 0;
    //     uint256 sumPrice = 0;

    //     for (uint256 i = 0; i < len; i++) {
    //         _records[tokenDefult[i]] = Record({
    //             ready: true,
    //             lastDenormUpdate: uint40(block.timestamp),
    //             denorm: denormsDefult[i],
    //             desiredDenorm: denormsDefult[i],
    //             index: uint8(i),
    //             balance: 0
    //         });
    //         _tokens.push(tokenDefult[i]);
    //         uint256 priceToken = oracal.getTokenPrice(_tokens[i], outAssest);
    //         sumPrice = sumPrice.add(priceToken);
    //         totalWeight = badd(totalWeight, denormsDefult[i]);
    //     }

    //     _totalWeight = totalWeight;
    //     indexDivisor = sumPrice.div(len);
    //     _publicSwap = true;
    //     emit LOG_PUBLIC_SWAP_ENABLED();
    // }

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

    function mintShareAmount(uint256 amount, uint256 sumPrice)
        internal
        view
        returns (uint256 price)
    {
        uint256 indexTokenSupply = totalSupply();

        return
            amount.mul(indexTokenSupply).mul(1000000000000000000).div(sumPrice);
    }

    function investInFund(uint256 cryptoAmount) public payable {
        uint256 amountEth = msg.value;
        uint256 tokenAmount = cryptoAmount;
        investedAmountAfterSlippage = 0;
        vaultBalance = 0;

        if (totalSupply() > 0) {
            /* 
                calculate the balance of all tokens in the vault (in BNB)
                has to be calculated before the swap because after the balance will change 
            */
            uint256 len = _tokens.length;
            for (uint256 i = 0; i < len; i++) {
                IERC20 token = IERC20(_tokens[i]);
                uint256 tokenBalance = token.balanceOf(vault);

               uint256 priceToken = oracal.getTokenPrice(
                    _tokens[i],
                    outAssest
                );
                uint256 tokenBalanceBNB = priceToken.mul(tokenBalance);
                tokenBalanceInBNB.push(tokenBalanceBNB);
                vaultBalance = vaultBalance.add(tokenBalanceBNB);

                require(vaultBalance > 0, "sum price is not greater than 0");
            }

            /* 
                calculate the swap amount for each token
                ensures that the ratio (weight in the portfolio) stays constant
            */
            for (uint256 i = 0; i < _tokens.length; i++) {
                amount.push(
                    tokenBalanceInBNB[i].mul(cryptoAmount).div(vaultBalance)
                );
            }
        }

        uint256 deadline = block.timestamp + 15; // using 'now' for convenience, for mainnet pass deadline from frontend!
        for (uint256 i = 0; i < _tokens.length; i++) {
            address t = _tokens[i];
            Record memory record = _records[t];
            uint256 swapAmount;
            if (totalSupply() == 0) {
                swapAmount = amountEth.mul(record.denorm).div(_totalWeight);
            } else {

                swapAmount = amount[i];
            }
            /*
                swap tokens from BNB to tokens in portfolio
                swapResult[1]: swapped token amount

                1=  10 token token
                1= eth
            */
            uint256[] memory swapResult;
            swapResult = pancakeSwapRouter.swapExactETHForTokens{
                value: swapAmount
            }(0, getPathForETH(t), vault, deadline);

            /*
                take the amount actually being swapped and convert it to BNB
                for calculation of the index token amount to mint
            */
            uint256 swapResultBNB = oracal.getTokenPrice(_tokens[i], outAssest);
            investedAmountAfterSlippage = investedAmountAfterSlippage.add(
                swapResultBNB.mul(swapResult[1]).div(1000000000000000000)
            );
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
        require(tokenAmount <= balanceOf(msg.sender), "caller is not holding given token amount");

        uint256 deadline = block.timestamp + 15;

        uint256 totalSupplyIndex = totalSupply();

        _burn(msg.sender, tokenAmount);

        for (uint256 i = 0; i < _tokens.length; i++) {
            address t = _tokens[i];

            IERC20 token = IERC20(t);
            uint256 tokenBalance = token.balanceOf(vault);
            uint256 amount = tokenBalance.mul(tokenAmount).div(
                totalSupplyIndex
            );

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

    function getPathForETH(address crypto)
        public
        view
        returns (address[] memory)
    {
        address[] memory path = new address[](2);
        path[0] = pancakeSwapRouter.WETH();
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
        path[1] = pancakeSwapRouter.WETH();

        return path;
    }

    function getETH() public view returns (address) {
        return pancakeSwapRouter.WETH();
    }

    // important to receive ETH
    receive() external payable {}
}
