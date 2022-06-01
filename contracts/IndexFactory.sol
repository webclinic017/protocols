// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4 || ^0.7.6 || ^0.8.0;

import "./IndexSwap.sol";

contract IndexFactory {
    event IndexCreation(
        IndexSwap index,
        address _oracal,
        address _outAssest,
        address _pancakeSwapAddress,
        address _vault
    );

    function createIndex(
        address _oracal,
        address _outAssest,
        address _pancakeSwapAddress,
        address _vault
    ) public returns (IndexSwap index) {
        index = new IndexSwap(_oracal, _outAssest, _pancakeSwapAddress, _vault);

        emit IndexCreation(
            index,
            _oracal,
            _outAssest,
            _pancakeSwapAddress,
            _vault
        );
    }

    function initializeTokens(
        address _indexAddress,
        address[] calldata _tokens,
        uint96[] calldata _denorms
    ) public {
        IndexSwap index = IndexSwap(payable(_indexAddress));
        index.initialize(_tokens, _denorms);
    }
}
