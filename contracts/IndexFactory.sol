// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4 || ^0.7.6 || ^0.8.0;

import "./core/IndexSwap.sol";

contract IndexFactory {
    event IndexCreation(
        IndexSwap index,
        string _name,
        string _symbol,
        address _outAsset,
        address _vault,
        uint256 _maxInvestmentAmount,
        address _indexSwapLibrary,
        address _portfolioManager
    );

    function createIndex(
        string memory _name,
        string memory _symbol,
        address _outAsset,
        address _vault,
        uint256 _maxInvestmentAmount,
        address _indexSwapLibrary,
        address payable _indexManager
    ) public returns (IndexSwap index) {
        index = new IndexSwap(
            _name,
            _symbol,
            _outAsset,
            _vault,
            _maxInvestmentAmount,
            _indexSwapLibrary,
            _indexManager
        );

        emit IndexCreation(
            index,
            _name,
            _symbol,
            _outAsset,
            _vault,
            _maxInvestmentAmount,
            _indexSwapLibrary,
            _indexManager
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
