// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

interface IPriceOracle {
    // event PriceUpdate(
    //   address indexed pair,
    //   uint priceCumulative,
    //   uint32 blockTimestamp,
    //   bool latestIsSlotA
    // );

    function MIN_T() external pure returns (uint32);

    function getPairDetails(address uniswapV2Pair)
        external
        view
        returns (
            uint256 priceCumulativeSlotA,
            uint256 priceCumulativeSlotB,
            uint32 lastUpdateSlotA,
            uint32 lastUpdateSlotB,
            bool latestIsSlotA,
            bool initialized
        );

    function initialize(address _uniSwapRouter) external;

    function addNewPair(address uniswapV2Pair) external;

    function getResult(address uniswapV2Pair)
        external
        returns (uint224 price, uint32 T);

    function updateIndexPrice() external returns (uint224 price);

    function getTokenPrice(address token_address, address token1_address)
        external
        view
        returns (uint256);

    function getPrice(uint256 amountA, address[] calldata path)
        external
        view
        returns (uint256);

    // function getTwoPairResult(address _assetOne, address _assetTwo) external returns (uint224 price, uint32 T) ;

    function getBlockTimestamp() external view returns (uint32);
}
