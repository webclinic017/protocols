// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.4 || ^0.7.6 || ^0.8.0;

import "./IndexSwap.sol";

contract IndexFactory {
    IndexSwap public index;
    event IndexCreation(IndexSwap index);

    function createIndex(
        address _oracal,
        address _outAsset,
        address _pancakeSwapAddress,
        address _vault,
        address _myModule
    ) public returns (IndexSwap _index) {
        _index = new IndexSwap(
            _oracal,
            _outAsset,
            _pancakeSwapAddress,
            _vault,
            _myModule
        );

        index = _index;
        emit IndexCreation(_index);
    }

    function getIndex() public view returns (address) {
        return address(index);
    }

    function initializeTokens(
        address _indexAddress,
        address[] calldata _tokens,
        uint96[] calldata _denorms
    ) public {
        IndexSwap _index = IndexSwap(payable(_indexAddress));
        _index.initialize(_tokens, _denorms);
    }

    function addAssetManager(address _indexAddress, address _assetManager)
        public
    {
        IndexSwap _index = IndexSwap(payable(_indexAddress));
        _index.addAssetManager(_assetManager);
    }
}
