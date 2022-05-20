// Sources flattened with hardhat v2.9.3 https://hardhat.org

// File contracts/lib/UQ112x112.sol

pragma solidity 0.8.4;

// a library for handling binary fixed point numbers (https://en.wikipedia.org/wiki/Q_(number_format))

// range: [0, 2**112 - 1]
// resolution: 1 / 2**112

library UQ112x112 {
  uint224 constant Q112 = 2**112;

  // Encode a uint112 as a UQ112x112
  function encode(uint112 y) internal pure returns (uint224 z) {
    z = uint224(y) * Q112; // never overflows
  }

  // Divide a UQ112x112 by a uint112, returning a UQ112x112
  function uqdiv(uint224 x, uint112 y) internal pure returns (uint224 z) {
    z = x / uint224(y);
  }
}


// File contracts/interfaces/IUniswapV2Pair.sol

// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.4;

interface IUniswapV2Pair {
  event Approval(address indexed owner, address indexed spender, uint value);
  event Transfer(address indexed from, address indexed to, uint value);

  function name() external pure returns (string memory);

  function symbol() external pure returns (string memory);

  function decimals() external pure returns (uint8);

  function totalSupply() external view returns (uint);

  function balanceOf(address owner) external view returns (uint);

  function allowance(address owner, address spender) external view returns (uint);

  function approve(address spender, uint value) external returns (bool);

  function transfer(address to, uint value) external returns (bool);

  function transferFrom(address from, address to, uint value) external returns (bool);

  function DOMAIN_SEPARATOR() external view returns (bytes32);

  function PERMIT_TYPEHASH() external pure returns (bytes32);

  function nonces(address owner) external view returns (uint);

  function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;

  event Mint(address indexed sender, uint amount0, uint amount1);
  event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
  event Swap(
    address indexed sender,
    uint amount0In,
    uint amount1In,
    uint amount0Out,
    uint amount1Out,
    address indexed to
  );
  event Sync(uint112 reserve0, uint112 reserve1);

  function MINIMUM_LIQUIDITY() external pure returns (uint);

  function factory() external view returns (address);

  function token0() external view returns (address);

  function token1() external view returns (address);

  function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);

  function price0CumulativeLast() external view returns (uint);

  function price1CumulativeLast() external view returns (uint);

  function kLast() external view returns (uint);

  function mint(address to) external returns (uint liquidity);

  function burn(address to) external returns (uint amount0, uint amount1);

  function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;

  function skim(address to) external;

  function sync() external;

  function initialize(address, address) external;
}


// File contracts/interfaces/IPriceOracle.sol

pragma solidity 0.8.4;


interface IPriceOracle {
  // event PriceUpdate(
  //   address indexed pair,
  //   uint priceCumulative,
  //   uint32 blockTimestamp,
  //   bool latestIsSlotA
  // );

  function MIN_T() external pure returns (uint32);

  function getPair(address uniswapV2Pair)
    external
    view
    returns (
      uint priceCumulativeSlotA,
      uint priceCumulativeSlotB,
      uint32 lastUpdateSlotA,
      uint32 lastUpdateSlotB,
      bool latestIsSlotA,
      bool initialized
    );

  function initialize(address uniswapV2Pair,address _uniSwapRouter) external;

  function getResult(address uniswapV2Pair) external returns (uint224 price, uint32 T);

  // function getTwoPairResult(address _assetOne, address _assetTwo) external returns (uint224 price, uint32 T) ;

  function getBlockTimestamp() external view returns (uint32);
}


// File contracts/interfaces/IUniswapV2Router02.sol

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.4;

interface IUniswapV2Router02 {
  function factory() external view returns (address);

  function WETH() external view returns (address);

  function addLiquidity(
    address tokenA,
    address tokenB,
    uint amountADesired,
    uint amountBDesired,
    uint amountAMin,
    uint amountBMin,
    address to,
    uint deadline
  ) external returns (uint amountA, uint amountB, uint liquidity);

  function addLiquidityETH(
    address token,
    uint amountTokenDesired,
    uint amountTokenMin,
    uint amountETHMin,
    address to,
    uint deadline
  ) external payable returns (uint amountToken, uint amountETH, uint liquidity);

  function removeLiquidity(
    address tokenA,
    address tokenB,
    uint liquidity,
    uint amountAMin,
    uint amountBMin,
    address to,
    uint deadline
  ) external returns (uint amountA, uint amountB);

  function removeLiquidityETH(
    address token,
    uint liquidity,
    uint amountTokenMin,
    uint amountETHMin,
    address to,
    uint deadline
  ) external returns (uint amountToken, uint amountETH);

  function removeLiquidityWithPermit(
    address tokenA,
    address tokenB,
    uint liquidity,
    uint amountAMin,
    uint amountBMin,
    address to,
    uint deadline,
    bool approveMax, uint8 v, bytes32 r, bytes32 s
  ) external returns (uint amountA, uint amountB);

  function removeLiquidityETHWithPermit(
    address token,
    uint liquidity,
    uint amountTokenMin,
    uint amountETHMin,
    address to,
    uint deadline,
    bool approveMax, uint8 v, bytes32 r, bytes32 s
  ) external returns (uint amountToken, uint amountETH);

  function swapExactTokensForTokens(
    uint amountIn,
    uint amountOutMin,
    address[] calldata path,
    address to,
    uint deadline
  ) external returns (uint[] memory amounts);

  function swapTokensForExactTokens(
    uint amountOut,
    uint amountInMax,
    address[] calldata path,
    address to,
    uint deadline
  ) external returns (uint[] memory amounts);

  function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
  external
  payable
  returns (uint[] memory amounts);

  function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
  external
  returns (uint[] memory amounts);

  function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
  external
  returns (uint[] memory amounts);

  function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
  external
  payable
  returns (uint[] memory amounts);

  function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);

  function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);

  function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);

  function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);

  function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);

  function removeLiquidityETHSupportingFeeOnTransferTokens(
    address token,
    uint liquidity,
    uint amountTokenMin,
    uint amountETHMin,
    address to,
    uint deadline
  ) external returns (uint amountETH);

  function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
    address token,
    uint liquidity,
    uint amountTokenMin,
    uint amountETHMin,
    address to,
    uint deadline,
    bool approveMax, uint8 v, bytes32 r, bytes32 s
  ) external returns (uint amountETH);

  function swapExactTokensForTokensSupportingFeeOnTransferTokens(
    uint amountIn,
    uint amountOutMin,
    address[] calldata path,
    address to,
    uint deadline
  ) external;

  function swapExactETHForTokensSupportingFeeOnTransferTokens(
    uint amountOutMin,
    address[] calldata path,
    address to,
    uint deadline
  ) external payable;

  function swapExactTokensForETHSupportingFeeOnTransferTokens(
    uint amountIn,
    uint amountOutMin,
    address[] calldata path,
    address to,
    uint deadline
  ) external;
}


// File contracts/interfaces/IUniswapV2Factory.sol

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.4;

interface IUniswapV2Factory {
  event PairCreated(address indexed token0, address indexed token1, address pair, uint);

  function getPair(address tokenA, address tokenB) external view returns (address pair);

  function allPairs(uint) external view returns (address pair);

  function allPairsLength() external view returns (uint);

  function feeTo() external view returns (address);

  function feeToSetter() external view returns (address);

  function createPair(address tokenA, address tokenB) external returns (address pair);
}


// File @openzeppelin/contracts/token/ERC20/IERC20.sol@v4.6.0

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}


// File @openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol@v4.6.0

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/IERC20Metadata.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface for the optional metadata functions from the ERC20 standard.
 *
 * _Available since v4.1._
 */
interface IERC20Metadata is IERC20 {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
}


// File contracts/PriceOracal.sol

pragma solidity ^0.8.4;


contract PriceOracle is IPriceOracle {
  using UQ112x112 for uint224;

  uint32 public override constant MIN_T = 1200;

  IUniswapV2Router02 public uniswapV2Router;


  struct Pair {
    uint priceCumulativeSlotA;
    uint priceCumulativeSlotB;
    uint32 lastUpdateSlotA;
    uint32 lastUpdateSlotB;
    bool latestIsSlotA;
    bool initialized;
  }
  
  mapping(address => Pair)  public override getPair;

  event PriceUpdate(
    address indexed pair,
    uint priceCumulative,
    uint32 blockTimestamp,
    bool latestIsSlotA
  );

  function toUint224(uint input) internal pure  returns (uint224) {
   // require(input <= uint224(-1), "PriceOracle: UINT224_OVERFLOW");
    return uint224(input);
  }

  function getPriceCumulativeCurrent(address uniswapV2Pair)
    internal
    view
    returns (uint priceCumulative)
  {
    priceCumulative = IUniswapV2Pair(uniswapV2Pair).price0CumulativeLast();
    (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast) = IUniswapV2Pair(
      uniswapV2Pair
    ).getReserves();
    uint224 priceLatest = UQ112x112.encode(reserve1).uqdiv(reserve0);
    uint32 timeElapsed = getBlockTimestamp() - blockTimestampLast; // Overflow is desired
    // * Never overflows, and + overflow is desired
    priceCumulative += uint(priceLatest) * timeElapsed;
  }

  function initialize(address uniswapV2Pair,address _uniSwapRouter) external override {

    IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(_uniSwapRouter);  

    Pair storage pairStorage = getPair[uniswapV2Pair];
    require(!pairStorage.initialized, "TarotPriceOracle: ALREADY_INITIALIZED");

    uint priceCumulativeCurrent = getPriceCumulativeCurrent(uniswapV2Pair);
    uint32 blockTimestamp = getBlockTimestamp();
    pairStorage.priceCumulativeSlotA = priceCumulativeCurrent;
    pairStorage.priceCumulativeSlotB = priceCumulativeCurrent;
    pairStorage.lastUpdateSlotA = blockTimestamp;
    pairStorage.lastUpdateSlotB = blockTimestamp;
    pairStorage.latestIsSlotA = true;
    pairStorage.initialized = true;
    emit PriceUpdate(uniswapV2Pair, priceCumulativeCurrent, blockTimestamp, true);
  }
  

  function getResult(address uniswapV2Pair) external override returns (uint224 price, uint32 T) {
    Pair memory pair = getPair[uniswapV2Pair];
    require(pair.initialized, "TarotPriceOracle: NOT_INITIALIZED");
    Pair storage pairStorage = getPair[uniswapV2Pair];

    uint32 blockTimestamp = getBlockTimestamp();
    uint32 lastUpdateTimestamp = pair.latestIsSlotA
      ? pair.lastUpdateSlotA
      : pair.lastUpdateSlotB;
    uint priceCumulativeCurrent = getPriceCumulativeCurrent(uniswapV2Pair);
    uint priceCumulativeLast;

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

  // function getTwoPairResult(address _assetOne, address _assetTwo) external returns (uint224 price, uint32 T) {
  //       address pair = IUniswapV2Factory(uniswapV2Router.factory()).getPair(_assetOne, _assetTwo);
  //       getResult(pair);
  //  }

      /**
     * @notice Fetches and sorts the reserves for a pair.
     * @param tokenA Address of tokenA contract
     * @param tokenB Address of tokenB contract
     */

    function getReserves(address tokenA, address tokenB) internal view returns (uint256 reserveA, uint256 reserveB) {
        address pair = IUniswapV2Factory(uniswapV2Router.factory()).getPair(tokenA, tokenB);
        (uint256 reserve0, uint256 reserve1, ) = IUniswapV2Pair(pair).getReserves();

        (address token0, ) = sortTokens(tokenA, tokenB);
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    /**
     * @notice Returns sorted token addresses, used to handle return values from pairs sorted in this order.
     * @param tokenA Address of tokenA contract
     * @param tokenB Address of tokenB contract
     */

    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, "PancakeLibrary: IDENTICAL_ADDRESSES");
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), "PancakeLibrary: ZERO_ADDRESS");
    }

    /**
     * @notice Returns the USD price for a particular BEP20 token.
     * @param token_address address of BEP20 token contract
     * @param USDT_address address of USDT token contract
     */
    // function getTokenPriceUSD(address token_address, address USDT_address) external view returns (uint256) {
    //     uint256 token_decimals = IERC20Metadata(token_address).decimals();
    //     uint256 min_amountIn = 1 * 10**token_decimals;
    //     address pair = IUniswapV2Factory(uniswapV2Router.factory()).getPair(token_address, USDT_address);
    //     (uint256 reserve0, uint256 reserve1, uint256 blockTimestampLast) = IUniswapV2Pair(pair).getReserves();
    //     uint256 price = uniswapV2Router.getAmountOut(min_amountIn, reserve0, reserve1);
    //     return price;
    // }

    /** **Ensures pairing between tokens.**
     * @notice Ensures pairing between tokens.
     * @param amountA Amount of token
     * @param path Array of addresses pairs
     */
    function getPrice(uint256 amountA, address[] calldata path) external view returns (uint256 amount) {
        require(path.length >= 2, "invalid number of params in path");
        //
        // tokenA, WBNB, tokenB -> if there is no pair between tokenA and tokenB
        amount = amountA;
        for (uint256 i = 1; i < path.length; i++) {
            (uint256 reserveA, uint256 reserveB) = getReserves(path[i - 1], path[i]);
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
        require(reserveA > 0 && reserveB > 0, "PancakeLibrary: INSUFFICIENT_LIQUIDITY");
        amountB = (amountA * reserveB) / reserveA;
    }



  /*** Utilities ***/

  function getBlockTimestamp() public view  override returns (uint32) {
    return uint32(block.timestamp % 2**32);
  }
}
