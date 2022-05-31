// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "./lib/UQ112x112.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IPriceOracle.sol";
import "./interfaces/IUniswapV2Router02.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract PriceOracle is IPriceOracle {
    using SafeMath for uint256;

    using UQ112x112 for uint224;

    uint32 public constant override MIN_T = 1200;

    IUniswapV2Router02 public uniswapV2Router;

    uint256 public indexPrice;

    struct Pair {
        uint256 priceCumulativeSlotA;
        uint256 priceCumulativeSlotB;
        uint32 lastUpdateSlotA;
        uint32 lastUpdateSlotB;
        bool latestIsSlotA;
        bool initialized;
    }

    mapping(address => Pair) public override getPairDetails;

    address[] indexTokenPair;

    uint256 internal indexDivisor;

    event PriceUpdate(
        address indexed pair,
        uint256 priceCumulative,
        uint32 blockTimestamp,
        bool latestIsSlotA
    );

    function initialize(address _uniSwapRouter) external override {
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(
            _uniSwapRouter
        );
        uniswapV2Router = _uniswapV2Router;
        indexDivisor = 1;
    }

    function addNewPair(address uniswapV2Pair) external override {
        Pair storage pairStorage = getPairDetails[uniswapV2Pair];

        uint256 priceCumulativeCurrent = getPriceCumulativeCurrent(
            uniswapV2Pair
        );
        uint32 blockTimestamp = getBlockTimestamp();
        pairStorage.priceCumulativeSlotA = priceCumulativeCurrent;
        pairStorage.priceCumulativeSlotB = priceCumulativeCurrent;
        pairStorage.lastUpdateSlotA = blockTimestamp;
        pairStorage.lastUpdateSlotB = blockTimestamp;
        pairStorage.latestIsSlotA = true;
        pairStorage.initialized = true;

        indexTokenPair.push(uniswapV2Pair);
        emit PriceUpdate(
            uniswapV2Pair,
            priceCumulativeCurrent,
            blockTimestamp,
            true
          );
    }

    function toUint224(uint256 input) internal pure returns (uint224) {
        // require(input <= uint224(-1), "PriceOracle: UINT224_OVERFLOW");
        return uint224(input);
    }

    function updateIndexPrice() external override returns (uint224 price) {
        uint256 len = indexTokenPair.length;
        uint256 sumPrice;
        for (uint256 i = 0; i < len; i++) {
            uint256 min_amountIn = 1 * 10**18;
            (
                uint256 reserve0,
                uint256 reserve1,
                uint256 blockTimestampLast
            ) = IUniswapV2Pair(indexTokenPair[i]).getReserves();
            uint256 price = uniswapV2Router.getAmountOut(
                min_amountIn,
                reserve0,
                reserve1
            );
            sumPrice = price;
        }
        indexPrice = sumPrice.div(indexDivisor);
    }

    function getPriceCumulativeCurrent(address uniswapV2Pair)
        internal
        view
        returns (uint256 priceCumulative)
    {
        priceCumulative = IUniswapV2Pair(uniswapV2Pair).price0CumulativeLast();
        (
            uint112 reserve0,
            uint112 reserve1,
            uint32 blockTimestampLast
        ) = IUniswapV2Pair(uniswapV2Pair).getReserves();
        uint224 priceLatest = UQ112x112.encode(reserve1).uqdiv(reserve0);
        uint32 timeElapsed = getBlockTimestamp() - blockTimestampLast; // Overflow is desired
        // * Never overflows, and + overflow is desired
        priceCumulative += uint256(priceLatest) * timeElapsed;
    }

    function getResult(address uniswapV2Pair)
        external
        override
        returns (uint224 price, uint32 T)
    {
        Pair memory pair = getPairDetails[uniswapV2Pair];
        require(pair.initialized, "TarotPriceOracle: NOT_INITIALIZED");
        Pair storage pairStorage = getPairDetails[uniswapV2Pair];

        uint32 blockTimestamp = getBlockTimestamp();
        uint32 lastUpdateTimestamp = pair.latestIsSlotA
            ? pair.lastUpdateSlotA
            : pair.lastUpdateSlotB;
        uint256 priceCumulativeCurrent = getPriceCumulativeCurrent(
            uniswapV2Pair
        );
        uint256 priceCumulativeLast;

        if (blockTimestamp - lastUpdateTimestamp >= MIN_T) {
            // Update price
            priceCumulativeLast = pair.latestIsSlotA
                ? pair.priceCumulativeSlotA
                : pair.priceCumulativeSlotB;
            if (pair.latestIsSlotA) {
                pairStorage.priceCumulativeSlotB = priceCumulativeCurrent;
                pairStorage.lastUpdateSlotB = blockTimestamp;
            } else {
                pairStorage.priceCumulativeSlotA = priceCumulativeCurrent;
                pairStorage.lastUpdateSlotA = blockTimestamp;
            }
            pairStorage.latestIsSlotA = !pair.latestIsSlotA;

            emit PriceUpdate(
                uniswapV2Pair,
                priceCumulativeCurrent,
                blockTimestamp,
                !pair.latestIsSlotA
            );
        } else {
            // Don't update; return price using previous priceCumulative
            lastUpdateTimestamp = pair.latestIsSlotA
                ? pair.lastUpdateSlotB
                : pair.lastUpdateSlotA;
            priceCumulativeLast = pair.latestIsSlotA
                ? pair.priceCumulativeSlotB
                : pair.priceCumulativeSlotA;
        }

        T = blockTimestamp - lastUpdateTimestamp; // Overflow is desired
        require(T >= MIN_T, "PriceOracle: NOT_READY"); // Reverts only if the pair has just been initialized
        // Is safe, and - overflow is desired
        price = toUint224((priceCumulativeCurrent - priceCumulativeLast) / T);
    }

    function getPairAddress(address _assetOne, address _assetTwo)
        external
        view
        returns (address)
    {
        address pair = IUniswapV2Factory(uniswapV2Router.factory()).getPair(
            _assetOne,
            _assetTwo
        );
        return pair;
    }

    /**
     * @notice Fetches and sorts the reserves for a pair.
     * @param tokenA Address of tokenA contract
     * @param tokenB Address of tokenB contract
     */

    function getReserves(address tokenA, address tokenB)
        internal
        view
        returns (uint256 reserveA, uint256 reserveB)
    {
        address pair = IUniswapV2Factory(uniswapV2Router.factory()).getPair(
            tokenA,
            tokenB
        );
        (uint256 reserve0, uint256 reserve1, ) = IUniswapV2Pair(pair)
            .getReserves();

        (address token0, ) = sortTokens(tokenA, tokenB);
        (reserveA, reserveB) = tokenA == token0
            ? (reserve0, reserve1)
            : (reserve1, reserve0);
    }

    /**
     * @notice Returns sorted token addresses, used to handle return values from pairs sorted in this order.
     * @param tokenA Address of tokenA contract
     * @param tokenB Address of tokenB contract
     */

    function sortTokens(address tokenA, address tokenB)
        internal
        pure
        returns (address token0, address token1)
    {
        require(tokenA != tokenB, "PancakeLibrary: IDENTICAL_ADDRESSES");
        (token0, token1) = tokenA < tokenB
            ? (tokenA, tokenB)
            : (tokenB, tokenA);
        require(token0 != address(0), "PancakeLibrary: ZERO_ADDRESS");
    }

      /**
     * @notice Returns the USD price for a particular BEP20 token.
     * @param token_address address of BEP20 token contract
     * @param token1_address address of USDT token contract
     */
    function getTokenPrice(address token_address, address token1_address)
        external
        view
        override
        returns (uint256 price)
    {
        uint256 token_decimals = IERC20Metadata(token_address).decimals();
        uint256 min_amountIn = 1 * 10**token_decimals;
        if (token_address == token1_address) {
            price = min_amountIn;
        } else {
            address _pair = IUniswapV2Factory(uniswapV2Router.factory())
                .getPair(token_address, token1_address);
            (
                uint256 reserve0,
                uint256 reserve1,
                uint256 blockTimestampLast
            ) = IUniswapV2Pair(_pair).getReserves();
            price = uniswapV2Router.getAmountOut(
                min_amountIn,
                reserve0,
                reserve1
            );
        }
    }

    /** **Ensures pairing between tokens.**
     * @notice Ensures pairing between tokens.
     * @param amountA Amount of token
     * @param path Array of addresses pairs
     */
    function getPrice(uint256 amountA, address[] calldata path)
        external
        view
        override
        returns (uint256 amount)
    {
        require(path.length >= 2, "invalid number of params in path");
        //
        // tokenA, WBNB, tokenB -> if there is no pair between tokenA and tokenB
        amount = amountA;
        for (uint256 i = 1; i < path.length; i++) {
            (uint256 reserveA, uint256 reserveB) = getReserves(
                path[i - 1],
                path[i]
            );
            require(reserveA > 0, "Pair Non Existent || No Liquidity");
            amount = quote(amount, reserveA, reserveB);
        }
    }

    /**
     * @notice Given some amount of an asset and pair reserves, returns an equivalent amount of the other asset.
     * @param amountA Amount of token
     * @param reserveA reserveA
     * @param reserveB reserveB
     */
    function quote(
        uint256 amountA,
        uint256 reserveA,
        uint256 reserveB
    ) internal pure returns (uint256 amountB) {
        require(amountA > 0, "PancakeLibrary: INSUFFICIENT_AMOUNT");
        require(
            reserveA > 0 && reserveB > 0,
            "PancakeLibrary: INSUFFICIENT_LIQUIDITY"
        );
        amountB = (amountA * reserveB) / reserveA;
    }

    /*** Utilities ***/

    function getBlockTimestamp() public view override returns (uint32) {
        return uint32(block.timestamp % 2**32);
    }
}
