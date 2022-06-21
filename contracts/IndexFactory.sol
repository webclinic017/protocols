// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4 || ^0.7.6 || ^0.8.0;

import "./core/IndexSwap.sol";
import "./access/AccessController.sol";

contract IndexFactory {
    event IndexCreation(
        IndexSwap index,
        string _name,
        string _symbol,
        address _outAsset,
        address _vault,
        uint256 _maxInvestmentAmount,
        IndexSwapLibrary _indexSwapLibrary,
        IndexManager _indexManager,
        AccessController _accessController
    );

    function createIndex(
        string memory _name,
        string memory _symbol,
        address _outAsset,
        address _vault,
        uint256 _maxInvestmentAmount,
        IndexSwapLibrary _indexSwapLibrary,
        IndexManager _indexManager,
        AccessController _accessController
    ) public returns (IndexSwap index) {
        index = new IndexSwap(
            _name,
            _symbol,
            _outAsset,
            _vault,
            _maxInvestmentAmount,
            _indexSwapLibrary,
            _indexManager,
            _accessController
        );

        emit IndexCreation(
            index,
            _name,
            _symbol,
            _outAsset,
            _vault,
            _maxInvestmentAmount,
            _indexSwapLibrary,
            _indexManager,
            _accessController
        );
    }

    function initializeTokens(
        IndexSwap _index,
        address[] calldata _tokens,
        uint96[] calldata _denorms
    ) public {
        _index.initialize(_tokens, _denorms);
    }
}
