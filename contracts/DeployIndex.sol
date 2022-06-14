// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4 || ^0.7.6 || ^0.8.0;

import "./IndexFactory.sol";

contract DeployIndex {
    IndexFactory indexFactory =
        IndexFactory(0x398333146484a989bf9A847Ea61e556FDbC93b8A);

    IndexSwap public index;

    function createNewIndex(
        string memory _name,
        string memory _symbol,
        address _oracle,
        address _outAssest,
        address _pancakeSwapAddress,
        address _vault
    ) public {
        index = indexFactory.createIndex(
            _name,
            _symbol,
            _oracle,
            _outAssest,
            _pancakeSwapAddress,
            _vault
        );
    }

    function init(address[] calldata _tokens, uint96[] calldata _denorms)
        public
    {
        indexFactory.initializeTokens(address(index), _tokens, _denorms);
    }
}
