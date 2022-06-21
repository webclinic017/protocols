// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4 || ^0.7.6 || ^0.8.0;

import "./AccessController.sol";
import "./IndexSwap.sol";

contract IndexFactory {
    event IndexCreation(
        IndexSwap index,
        address _oracle,
        address _outAssest,
        address _pancakeSwapAddress,
        address _vault
    );

    function createIndex(
        string memory _name,
        string memory _symbol,
        address _oracle,
        address _outAssest,
        address _pancakeSwapAddress,
        address _vault,
        AccessController _accessController
    ) public returns (IndexSwap index) {
        index = new IndexSwap();
        index.initialize(
            _name,
            _symbol,
            _oracle,
            _outAssest,
            _pancakeSwapAddress,
            _vault,
            _accessController
        );

        emit IndexCreation(
            index,
            _oracle,
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
        index.init(_tokens, _denorms);
    }
}
