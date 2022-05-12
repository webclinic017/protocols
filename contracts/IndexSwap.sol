pragma solidity ^0.8.4 || ^0.7.6 || ^0.8.0;

import "./interfaces/IUniswapV2Router02.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@uniswap/lib/contracts/libraries/TransferHelper.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IPriceOracle.sol";
import "./MyModule.sol";

// // SPDX-License-Identifier: MIT
// pragma solidity <=0.7.6;

/************************************************************************************************
Originally from https://github.com/balancer-labs/balancer-core/blob/master/contracts/BConst.sol

This source code has been modified from the original, which was copied from the github repository
at commit hash f4ed5d65362a8d6cec21662fb6eae233b0babc1f.

Subject to the GPL-3.0 license
*************************************************************************************************/

contract BConst {
    uint256 public constant VERSION_NUMBER = 1;

    /* ---  Weight Updates  --- */

    // Minimum time passed between each weight update for a token.
    uint256 internal constant WEIGHT_UPDATE_DELAY = 1 hours;

    // Maximum percent by which a weight can adjust at a time
    // relative to the current weight.
    // The number of iterations needed to move from weight A to weight B is the floor of:
    // (A > B): (ln(A) - ln(B)) / ln(1.01)
    // (B > A): (ln(A) - ln(B)) / ln(0.99)
    uint256 internal constant WEIGHT_CHANGE_PCT = BONE / 100;

    uint256 internal constant BONE = 10**18;

    uint256 internal constant MIN_BOUND_TOKENS = 2;
    uint256 internal constant MAX_BOUND_TOKENS = 25;

    // Minimum swap fee.
    uint256 internal constant MIN_FEE = BONE / 10**6;
    // Maximum swap or exit fee.
    uint256 internal constant MAX_FEE = BONE / 10;
    // Actual exit fee. 1%
    uint256 internal constant EXIT_FEE = 1e16;

    // Default total of all desired weights. Can differ by up to BONE.
    uint256 internal constant DEFAULT_TOTAL_WEIGHT = BONE * 25;
    // Minimum weight for any token (1/100).
    uint256 internal constant MIN_WEIGHT = BONE / 8;
    uint256 internal constant MAX_WEIGHT = BONE * 25;
    // Maximum total weight.
    uint256 internal constant MAX_TOTAL_WEIGHT = BONE * 26;
    // Minimum balance for a token (only applied at initialization)
    uint256 internal constant MIN_BALANCE = BONE / 10**12;
    // Initial pool tokens
    uint256 internal constant INIT_POOL_SUPPLY = BONE * 100;

    uint256 internal constant MIN_BPOW_BASE = 1 wei;
    uint256 internal constant MAX_BPOW_BASE = (2 * BONE) - 1 wei;
    uint256 internal constant BPOW_PRECISION = BONE / 10**10;

    // Maximum ratio of input tokens to balance for swaps.
    uint256 internal constant MAX_IN_RATIO = BONE / 2;
    // Maximum ratio of output tokens to balance for swaps.
    uint256 internal constant MAX_OUT_RATIO = (BONE / 3) + 1 wei;
}

/************************************************************************************************
Originally from https://github.com/balancer-labs/balancer-core/blob/master/contracts/BNum.sol

This source code has been modified from the original, which was copied from the github repository
at commit hash f4ed5d65362a8d6cec21662fb6eae233b0babc1f.

Subject to the GPL-3.0 license
*************************************************************************************************/

contract BNum is BConst {
    function btoi(uint256 a) internal pure returns (uint256) {
        return a / BONE;
    }

    function bfloor(uint256 a) internal pure returns (uint256) {
        return btoi(a) * BONE;
    }

    function badd(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "ERR_ADD_OVERFLOW");
        return c;
    }

    function bsub(uint256 a, uint256 b) internal pure returns (uint256) {
        (uint256 c, bool flag) = bsubSign(a, b);
        require(!flag, "ERR_SUB_UNDERFLOW");
        return c;
    }

    function bsubSign(uint256 a, uint256 b)
        internal
        pure
        returns (uint256, bool)
    {
        if (a >= b) {
            return (a - b, false);
        } else {
            return (b - a, true);
        }
    }

    function bmul(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c0 = a * b;
        require(a == 0 || c0 / a == b, "ERR_MUL_OVERFLOW");
        uint256 c1 = c0 + (BONE / 2);
        require(c1 >= c0, "ERR_MUL_OVERFLOW");
        uint256 c2 = c1 / BONE;
        return c2;
    }

    function bdiv(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0, "ERR_DIV_ZERO");
        uint256 c0 = a * BONE;
        require(a == 0 || c0 / a == BONE, "ERR_DIV_INTERNAL"); // bmul overflow
        uint256 c1 = c0 + (b / 2);
        require(c1 >= c0, "ERR_DIV_INTERNAL"); //  badd require
        uint256 c2 = c1 / b;
        return c2;
    }

    // DSMath.wpow
    function bpowi(uint256 a, uint256 n) internal pure returns (uint256) {
        uint256 z = n % 2 != 0 ? a : BONE;

        for (n /= 2; n != 0; n /= 2) {
            a = bmul(a, a);

            if (n % 2 != 0) {
                z = bmul(z, a);
            }
        }
        return z;
    }

    // Compute b^(e.w) by splitting it into (b^e)*(b^0.w).
    // Use `bpowi` for `b^e` and `bpowK` for k iterations
    // of approximation of b^0.w
    function bpow(uint256 base, uint256 exp) internal pure returns (uint256) {
        require(base >= MIN_BPOW_BASE, "ERR_BPOW_BASE_TOO_LOW");
        require(base <= MAX_BPOW_BASE, "ERR_BPOW_BASE_TOO_HIGH");

        uint256 whole = bfloor(exp);
        uint256 remain = bsub(exp, whole);

        uint256 wholePow = bpowi(base, btoi(whole));

        if (remain == 0) {
            return wholePow;
        }

        uint256 partialResult = bpowApprox(base, remain, BPOW_PRECISION);
        return bmul(wholePow, partialResult);
    }

    function bpowApprox(
        uint256 base,
        uint256 exp,
        uint256 precision
    ) internal pure returns (uint256) {
        // term 0:
        uint256 a = exp;
        (uint256 x, bool xneg) = bsubSign(base, BONE);
        uint256 term = BONE;
        uint256 sum = term;
        bool negative = false;

        // term(k) = numer / denom
        //         = (product(a - i - 1, i=1-->k) * x^k) / (k!)
        // each iteration, multiply previous term by (a-(k-1)) * x / k
        // continue until term is less than precision
        for (uint256 i = 1; term >= precision; i++) {
            uint256 bigK = i * BONE;
            (uint256 c, bool cneg) = bsubSign(a, bsub(bigK, BONE));
            term = bmul(term, bmul(c, x));
            term = bdiv(term, bigK);
            if (term == 0) break;

            if (xneg) negative = !negative;
            if (cneg) negative = !negative;
            if (negative) {
                sum = bsub(sum, term);
            } else {
                sum = badd(sum, term);
            }
        }

        return sum;
    }
}

/*
Originally from https://github.com/balancer-labs/balancer-core/blob/master/contracts/BMath.sol
This source code has been modified from the original, which was copied from the github repository
at commit hash f4ed5d65362a8d6cec21662fb6eae233b0babc1f.
Subject to the GPL-3.0 license
*/

contract BMath is BConst, BNum {
    /*
    // calcSpotPrice                                                                             
    // sP = spotPrice                                                                            
    // bI = tokenBalanceIn                ( bI / wI )         1                                  
    // bO = tokenBalanceOut         sP =  -----------  *  ----------                             
    // wI = tokenWeightIn                 ( bO / wO )     ( 1 - sF )                             
    // wO = tokenWeightOut                                                                       
    // sF = swapFee                                                                              
  */
    function calcSpotPrice(
        uint256 tokenBalanceIn,
        uint256 tokenWeightIn,
        uint256 tokenBalanceOut,
        uint256 tokenWeightOut,
        uint256 swapFee
    ) internal pure returns (uint256 spotPrice) {
        uint256 numer = bdiv(tokenBalanceIn, tokenWeightIn);
        uint256 denom = bdiv(tokenBalanceOut, tokenWeightOut);
        uint256 ratio = bdiv(numer, denom);
        uint256 scale = bdiv(BONE, bsub(BONE, swapFee));
        return (spotPrice = bmul(ratio, scale));
    }

    /*
    // calcOutGivenIn                                                                            
    // aO = tokenAmountOut                                                                       
    // bO = tokenBalanceOut                                                                      
    // bI = tokenBalanceIn              /      /            bI             \    (wI / wO) \      
    // aI = tokenAmountIn    aO = bO * |  1 - | --------------------------  | ^            |     
    // wI = tokenWeightIn               \      \ ( bI + ( aI * ( 1 - sF )) /              /      
    // wO = tokenWeightOut                                                                       
    // sF = swapFee                                                                              
  */
    function calcOutGivenIn(
        uint256 tokenBalanceIn,
        uint256 tokenWeightIn,
        uint256 tokenBalanceOut,
        uint256 tokenWeightOut,
        uint256 tokenAmountIn,
        uint256 swapFee
    ) internal pure returns (uint256 tokenAmountOut) {
        uint256 weightRatio = bdiv(tokenWeightIn, tokenWeightOut);
        uint256 adjustedIn = bsub(BONE, swapFee);
        adjustedIn = bmul(tokenAmountIn, adjustedIn);
        uint256 y = bdiv(tokenBalanceIn, badd(tokenBalanceIn, adjustedIn));
        uint256 foo = bpow(y, weightRatio);
        uint256 bar = bsub(BONE, foo);
        tokenAmountOut = bmul(tokenBalanceOut, bar);
        return tokenAmountOut;
    }

    /*
    // calcInGivenOut                                                                            
    // aI = tokenAmountIn                                                                        
    // bO = tokenBalanceOut               /  /     bO      \    (wO / wI)      \                 
    // bI = tokenBalanceIn          bI * |  | ------------  | ^            - 1  |                
    // aO = tokenAmountOut    aI =        \  \ ( bO - aO ) /                   /                 
    // wI = tokenWeightIn           --------------------------------------------                 
    // wO = tokenWeightOut                          ( 1 - sF )                                   
    // sF = swapFee                                                                              
  */
    function calcInGivenOut(
        uint256 tokenBalanceIn,
        uint256 tokenWeightIn,
        uint256 tokenBalanceOut,
        uint256 tokenWeightOut,
        uint256 tokenAmountOut,
        uint256 swapFee
    ) internal pure returns (uint256 tokenAmountIn) {
        uint256 weightRatio = bdiv(tokenWeightOut, tokenWeightIn);
        uint256 diff = bsub(tokenBalanceOut, tokenAmountOut);
        uint256 y = bdiv(tokenBalanceOut, diff);
        uint256 foo = bpow(y, weightRatio);
        foo = bsub(foo, BONE);
        tokenAmountIn = bsub(BONE, swapFee);
        tokenAmountIn = bdiv(bmul(tokenBalanceIn, foo), tokenAmountIn);
        return tokenAmountIn;
    }

    // calcPoolOutGivenSingleIn
    // pAo = poolAmountOut         /                                              \
    // tAi = tokenAmountIn        ///      /     //    wI \      \\       \     wI \
    // wI = tokenWeightIn        //| tAi *| 1 - || 1 - --  | * sF || + tBi \    --  \
    // tW = totalWeight     pAo=||  \      \     \\    tW /      //         | ^ tW   | * pS - pS
    // tBi = tokenBalanceIn      \\  ------------------------------------- /        /
    // pS = poolSupply            \\                    tBi               /        /
    // sF = swapFee                \                                              /

    // Charge the trading fee for the proportion of tokenAi
    ///  which is implicitly traded to the other pool tokens.
    // That proportion is (1- weightTokenIn)
    // tokenAiAfterFee = tAi * (1 - (1-weightTi) * poolFee);
    function calcPoolOutGivenSingleIn(
        uint256 tokenBalanceIn,
        uint256 tokenWeightIn,
        uint256 poolSupply,
        uint256 totalWeight,
        uint256 tokenAmountIn,
        uint256 swapFee
    ) internal pure returns (uint256 poolAmountOut) {
        uint256 normalizedWeight = bdiv(tokenWeightIn, totalWeight);
        uint256 zaz = bmul(bsub(BONE, normalizedWeight), swapFee);
        uint256 tokenAmountInAfterFee = bmul(tokenAmountIn, bsub(BONE, zaz));

        uint256 newTokenBalanceIn = badd(tokenBalanceIn, tokenAmountInAfterFee);
        uint256 tokenInRatio = bdiv(newTokenBalanceIn, tokenBalanceIn);

        // uint newPoolSupply = (ratioTi ^ weightTi) * poolSupply;
        uint256 poolRatio = bpow(tokenInRatio, normalizedWeight);
        uint256 newPoolSupply = bmul(poolRatio, poolSupply);
        poolAmountOut = bsub(newPoolSupply, poolSupply);
        return poolAmountOut;
    }

    /*
    // calcSingleInGivenPoolOut                                                                  
    // tAi = tokenAmountIn              //(pS + pAo)\     /    1    \\                           
    // pS = poolSupply                 || ---------  | ^ | --------- || * bI - bI                
    // pAo = poolAmountOut              \\    pS    /     \(wI / tW)//                           
    // bI = balanceIn          tAi =  --------------------------------------------               
    // wI = weightIn                              /      wI  \                                   
    // tW = totalWeight                          |  1 - ----  |  * sF                            
    // sF = swapFee                               \      tW  /                                  
  */
    function calcSingleInGivenPoolOut(
        uint256 tokenBalanceIn,
        uint256 tokenWeightIn,
        uint256 poolSupply,
        uint256 totalWeight,
        uint256 poolAmountOut,
        uint256 swapFee
    ) internal pure returns (uint256 tokenAmountIn) {
        uint256 normalizedWeight = bdiv(tokenWeightIn, totalWeight);
        uint256 newPoolSupply = badd(poolSupply, poolAmountOut);
        uint256 poolRatio = bdiv(newPoolSupply, poolSupply);

        //uint newBalTi = poolRatio^(1/weightTi) * balTi;
        uint256 boo = bdiv(BONE, normalizedWeight);
        uint256 tokenInRatio = bpow(poolRatio, boo);
        uint256 newTokenBalanceIn = bmul(tokenInRatio, tokenBalanceIn);
        uint256 tokenAmountInAfterFee = bsub(newTokenBalanceIn, tokenBalanceIn);
        // Do reverse order of fees charged in joinswap_ExternAmountIn, this way
        //     ``` pAo == joinswap_ExternAmountIn(Ti, joinswap_PoolAmountOut(pAo, Ti)) ```
        //uint tAi = tAiAfterFee / (1 - (1-weightTi) * swapFee) ;
        uint256 zar = bmul(bsub(BONE, normalizedWeight), swapFee);
        tokenAmountIn = bdiv(tokenAmountInAfterFee, bsub(BONE, zar));
        return tokenAmountIn;
    }

    /*
    // calcSingleOutGivenPoolIn                                                                  
    // tAo = tokenAmountOut            /      /                                             \\   
    // bO = tokenBalanceOut           /      // pS - (pAi * (1 - eF)) \     /    1    \      \\  
    // pAi = poolAmountIn            | bO - || ----------------------- | ^ | --------- | * b0 || 
    // ps = poolSupply                \      \\          pS           /     \(wO / tW)/      //  
    // wI = tokenWeightIn      tAo =   \      \                                             //   
    // tW = totalWeight                    /     /      wO \       \                             
    // sF = swapFee                    *  | 1 - |  1 - ---- | * sF  |                            
    // eF = exitFee                        \     \      tW /       /                             
  */
    function calcSingleOutGivenPoolIn(
        uint256 tokenBalanceOut,
        uint256 tokenWeightOut,
        uint256 poolSupply,
        uint256 totalWeight,
        uint256 poolAmountIn,
        uint256 swapFee
    ) internal pure returns (uint256 tokenAmountOut) {
        uint256 normalizedWeight = bdiv(tokenWeightOut, totalWeight);
        // charge exit fee on the pool token side
        // pAiAfterExitFee = pAi*(1-exitFee)
        uint256 poolAmountInAfterExitFee = bmul(
            poolAmountIn,
            bsub(BONE, EXIT_FEE)
        );
        uint256 newPoolSupply = bsub(poolSupply, poolAmountInAfterExitFee);
        uint256 poolRatio = bdiv(newPoolSupply, poolSupply);

        // newBalTo = poolRatio^(1/weightTo) * balTo;
        uint256 tokenOutRatio = bpow(poolRatio, bdiv(BONE, normalizedWeight));
        uint256 newTokenBalanceOut = bmul(tokenOutRatio, tokenBalanceOut);

        uint256 tokenAmountOutBeforeSwapFee = bsub(
            tokenBalanceOut,
            newTokenBalanceOut
        );

        // charge swap fee on the output token side
        //uint tAo = tAoBeforeSwapFee * (1 - (1-weightTo) * swapFee)
        uint256 zaz = bmul(bsub(BONE, normalizedWeight), swapFee);
        tokenAmountOut = bmul(tokenAmountOutBeforeSwapFee, bsub(BONE, zaz));
        return tokenAmountOut;
    }

    /*
    // calcPoolInGivenSingleOut                                                                  
    // pAi = poolAmountIn               // /               tAo             \\     / wO \     \   
    // bO = tokenBalanceOut            // | bO - -------------------------- |\   | ---- |     \  
    // tAo = tokenAmountOut      pS - ||   \     1 - ((1 - (tO / tW)) * sF)/  | ^ \ tW /  * pS | 
    // ps = poolSupply                 \\ -----------------------------------/                /  
    // wO = tokenWeightOut  pAi =       \\               bO                 /                /   
    // tW = totalWeight           -------------------------------------------------------------  
    // sF = swapFee                                        ( 1 - eF )                            
    // eF = exitFee                                                                              
    */
    function calcPoolInGivenSingleOut(
        uint256 tokenBalanceOut,
        uint256 tokenWeightOut,
        uint256 poolSupply,
        uint256 totalWeight,
        uint256 tokenAmountOut,
        uint256 swapFee
    ) internal pure returns (uint256 poolAmountIn) {
        // charge swap fee on the output token side
        uint256 normalizedWeight = bdiv(tokenWeightOut, totalWeight);
        //uint tAoBeforeSwapFee = tAo / (1 - (1-weightTo) * swapFee) ;
        uint256 zoo = bsub(BONE, normalizedWeight);
        uint256 zar = bmul(zoo, swapFee);
        uint256 tokenAmountOutBeforeSwapFee = bdiv(
            tokenAmountOut,
            bsub(BONE, zar)
        );

        uint256 newTokenBalanceOut = bsub(
            tokenBalanceOut,
            tokenAmountOutBeforeSwapFee
        );
        uint256 tokenOutRatio = bdiv(newTokenBalanceOut, tokenBalanceOut);

        //uint newPoolSupply = (ratioTo ^ weightTo) * poolSupply;
        uint256 poolRatio = bpow(tokenOutRatio, normalizedWeight);
        uint256 newPoolSupply = bmul(poolRatio, poolSupply);
        uint256 poolAmountInAfterExitFee = bsub(poolSupply, newPoolSupply);

        // charge exit fee on the pool token side
        // pAi = pAiAfterExitFee/(1-exitFee)
        poolAmountIn = bdiv(poolAmountInAfterExitFee, bsub(BONE, EXIT_FEE));
        return poolAmountIn;
    }
}

// interface itoken {
//   function mint(address to, uint256 amount) external;

//   function burn(address to, uint amount) external;

//   function allowance(address owner, address spender) external view returns (uint256);

//   function approve(address spender, uint256 amount) external returns (bool);

//   function transferFrom(
//         address from,
//         address to,
//         uint256 amount
//     ) external returns (bool);
// }

contract TokenBase is ERC20, ERC20Burnable, Ownable {
    constructor() ERC20("INDEXLY", "IDX") {}
}

contract IndexSwap is TokenBase, BMath {
    //address internal constant pancakeSwapAddress = 0x10ED43C718714eb63d5aA57B78B54704E256024E; //Router for bsc mainnet

    IUniswapV2Router02 public pancakeSwapRouter;

    // IERC20 public token;

    using SafeMath for uint256;

    uint256 public indexPrice;

    MyModule gnosisSafe = MyModule(0xEf73E58650868f316461936A092818d5dF96102E);
    address private vault = 0xD2aDa2CC6f97cfc1045B1cF70b3149139aC5f2a2;

    address[2] tokenDefult = [
        0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c, // BTC
        0x2170Ed0880ac9A755fd29B2688956BD959F933F8 // ETH
        /*0x2859e4544C4bB03966803b044A93563Bd2D0DD4D, // SHIBA
        0x1D2F0da169ceB9fC7B3144628dB156f3F6c60dBE, // XRP
        0x4338665CBB7B2485A8855A139b75D5e34AB0DB94, // LTC
        0x1CE0c2827e2eF14D5C4f29a091d735A204794041, // AVAX
        0xbA2aE424d960c26247Dd6c32edC70B295c744C43, // DOGECOIN
        0xF8A0BF9cF54Bb92F17374d9e9A321E6a111a51bD, // LINK
        0xBf5140A22578168FD562DCcF235E5D43A02ce9B1, // UNI
        0x3EE2200Efb3400fAbB9AacF31297cBdD1d435D47 // Cardano*/
    ];

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

    uint256 internal indexTokenPrice;

    mapping(address => uint256) admins;

    // True if PUBLIC can call SWAP & JOIN functions
    bool internal _publicSwap;

    rate public currentRate;

    IPriceOracle oracal;

    address outAssest;

    uint256 public amount1;
    uint256 public amount2;
    /*uint256 public amount3;
    uint256 public amount4;
    uint256 public amount5;
    uint256 public amount6;
    uint256 public amount7;
    uint256 public amount8;
    uint256 public amount9;
    uint256 public amount10;*/

    uint256 public t1Supply;
    uint256 public t1SupplyUSD;

    uint256 public t2Supply;
    uint256 public t2SupplyUSD;

    /*uint256 public t3Supply;
    uint256 public t3SupplyUSD;

    uint256 public t4Supply;
    uint256 public t4SupplyUSD;

    uint256 public t5Supply;
    uint256 public t5SupplyUSD;

    uint256 public t6Supply;
    uint256 public t6SupplyUSD;

    uint256 public t7Supply;
    uint256 public t7SupplyUSD;

    uint256 public t8Supply;
    uint256 public t8SupplyUSD;

    uint256 public t9Supply;
    uint256 public t9SupplyUSD;

    uint256 public t10Supply;
    uint256 public t10SupplyUSD;*/

    uint256 public totalVaultValue;

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
            totalWeight = badd(totalWeight, denorms[i]);
        }
        _totalWeight = totalWeight;
        _publicSwap = true;
        indexDivisor = 1;
        emit LOG_PUBLIC_SWAP_ENABLED();
    }

    function initializeDefult() external onlyOwner {
        uint256 len = tokenDefult.length;
        uint256 totalWeight = 0;
        uint256 sumPrice = 0;

        for (uint256 i = 0; i < len; i++) {
            _records[tokenDefult[i]] = Record({
                ready: true,
                lastDenormUpdate: uint40(block.timestamp),
                denorm: denormsDefult[i],
                desiredDenorm: denormsDefult[i],
                index: uint8(i),
                balance: 0
            });
            _tokens.push(tokenDefult[i]);
            uint256 priceToken = oracal.getTokenPrice(_tokens[i], outAssest);
            sumPrice = sumPrice.add(priceToken);
            totalWeight = badd(totalWeight, denormsDefult[i]);
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

    function mintShareAmount(uint256 amount) internal returns (uint256 price) {
        uint256 len = _tokens.length;
        uint256 sumPrice = 0;
        for (uint256 i = 0; i < len; i++) {
            tokenDefult[i] = _tokens[i];
            uint256 priceToken = oracal.getTokenPrice(_tokens[i], outAssest);
            sumPrice = sumPrice.add(priceToken);
        }
        // price tokens / indextokenprice = price per index token
        indexPrice = sumPrice.div(indexTokenPrice);

        // bnb amount to invest / price per index token = # index tokens to mint
        return amount.div(indexPrice);
    }

    function investInFund(uint256 cryptoAmount) public payable {
        uint256 amountEth = msg.value;

        if (totalSupply() > 0) {
            // t1
            IERC20 t1 = IERC20(_tokens[0]);
            t1Supply = t1.balanceOf(vault);
            t1SupplyUSD = pancakeSwapRouter.getAmountsOut(
                t1Supply,
                getPathForToken(_tokens[0])
            )[1];

            // t2
            IERC20 t2 = IERC20(_tokens[1]);
            t2Supply = t2.balanceOf(vault);
            t2SupplyUSD = pancakeSwapRouter.getAmountsOut(
                t2Supply,
                getPathForToken(_tokens[1])
            )[1];

            /*// t3
            IERC20 t3 = IERC20(_tokens[2]);
            t3Supply = t3.balanceOf(vault);
            t3SupplyUSD = pancakeSwapRouter.getAmountsOut(
                t3Supply,
                getPathForToken(_tokens[2])
            )[1];

            // t4
            IERC20 t4 = IERC20(_tokens[3]);
            t4Supply = t4.balanceOf(vault);
            t4SupplyUSD = pancakeSwapRouter.getAmountsOut(
                t4Supply,
                getPathForToken(_tokens[3])
            )[1];

            // t5
            IERC20 t5 = IERC20(_tokens[4]);
            t5Supply = t5.balanceOf(vault);
            t5SupplyUSD = pancakeSwapRouter.getAmountsOut(
                t5Supply,
                getPathForToken(_tokens[4])
            )[1];

            // t6
            IERC20 t6 = IERC20(_tokens[5]);
            t6Supply = t6.balanceOf(vault);
            t6SupplyUSD = pancakeSwapRouter.getAmountsOut(
                t6Supply,
                getPathForToken(_tokens[5])
            )[1];

            // t7
            IERC20 t7 = IERC20(_tokens[6]);
            t7Supply = t7.balanceOf(vault);
            t7SupplyUSD = pancakeSwapRouter.getAmountsOut(
                t7Supply,
                getPathForToken(_tokens[6])
            )[1];

            // t8
            IERC20 t8 = IERC20(_tokens[7]);
            t8Supply = t8.balanceOf(vault);
            t8SupplyUSD = pancakeSwapRouter.getAmountsOut(
                t8Supply,
                getPathForToken(_tokens[7])
            )[1];

            // t9
            IERC20 t9 = IERC20(_tokens[8]);
            t9Supply = t9.balanceOf(vault);
            t9SupplyUSD = pancakeSwapRouter.getAmountsOut(
                t9Supply,
                getPathForToken(_tokens[8])
            )[1];

            // t10
            IERC20 t10 = IERC20(_tokens[9]);
            t10Supply = t10.balanceOf(vault);
            t10SupplyUSD = pancakeSwapRouter.getAmountsOut(
                t10Supply,
                getPathForToken(_tokens[9])
            )[1];*/

            totalVaultValue = t1SupplyUSD.add(t2SupplyUSD);
            /*.add(t3SupplyUSD)
                .add(t4SupplyUSD)
                .add(t5SupplyUSD)
                .add(t6SupplyUSD)
                .add(t7SupplyUSD)
                .add(t8SupplyUSD)
                .add(t9SupplyUSD)
                .add(t10SupplyUSD)*/

            amount1 = t1SupplyUSD.mul(cryptoAmount).div(totalVaultValue);
            amount2 = t2SupplyUSD.mul(cryptoAmount).div(totalVaultValue);
            /*amount3 = t3SupplyUSD.mul(cryptoAmount).div(totalVaultValue);
            amount4 = t4SupplyUSD.mul(cryptoAmount).div(totalVaultValue);
            amount5 = t5SupplyUSD.mul(cryptoAmount).div(totalVaultValue);
            amount6 = t6SupplyUSD.mul(cryptoAmount).div(totalVaultValue);
            amount7 = t7SupplyUSD.mul(cryptoAmount).div(totalVaultValue);
            amount8 = t8SupplyUSD.mul(cryptoAmount).div(totalVaultValue);
            amount9 = t9SupplyUSD.mul(cryptoAmount).div(totalVaultValue);
            amount10 = t10SupplyUSD.mul(cryptoAmount).div(totalVaultValue);*/
        }

        uint256 deadline = block.timestamp + 15; // using 'now' for convenience, for mainnet pass deadline from frontend!
        for (uint256 i = 0; i < _tokens.length; i++) {
            address t = _tokens[i];
            Record memory record = _records[t];
            uint256 swapAmount;
            if (totalSupply() == 0) {
                swapAmount = amountEth.mul(record.denorm).div(_totalWeight);
            } else if (i == 0) {
                swapAmount = amount1;
            } else {
                swapAmount = amount2;
            } /*else if (i == 2) {
                swapAmount = amount3;
            } else if (i == 2) {
                swapAmount = amount3;
            } else if (i == 3) {
                swapAmount = amount4;
            } else if (i == 4) {
                swapAmount = amount5;
            } else if (i == 5) {
                swapAmount = amount6;
            } else if (i == 6) {
                swapAmount = amount7;
            } else if (i == 7) {
                swapAmount = amount8;
            } else if (i == 8) {
                swapAmount = amount9;
            } else if (i == 9) {
                swapAmount = amount10;
            }*/

            pancakeSwapRouter.swapExactETHForTokens{value: swapAmount}(
                0,
                getPathForETH(t),
                vault,
                deadline
            );
        }

        uint256 tokenAmount = mintShareAmount(cryptoAmount);

        _mint(msg.sender, tokenAmount);

        // refund leftover ETH to user
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        require(success, "refund failed");
    }

    function withdrawFromFundNew(uint256 tokenAmount) public payable {
        require(tokenAmount <= balanceOf(msg.sender), "not balance");

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

            gnosisSafe.executeTransactionOther(
                address(this),
                amount,
                address(t)
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

    function getPathForUSDT(address token)
        public
        view
        returns (address[] memory)
    {
        address[] memory path = new address[](2);
        path[0] = token;
        path[1] = 0xfD5840Cd36d94D7229439859C0112a4185BC0255;

        return path;
    }

    function getETH() public view returns (address) {
        return pancakeSwapRouter.WETH();
    }

    // important to receive ETH
    receive() external payable {}
}
