// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "./IndexSwap.sol";

contract AccessController is AccessControlUpgradeable {
    bytes32 public constant ASSET_MANAGER_ROLE =
        keccak256("ASSET_MANAGER_ROLE");

    function initialize() public initializer {
        __AccessControl_init();

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function isAssetManager(address account) external view returns (bool) {
        return hasRole(ASSET_MANAGER_ROLE, account);
    }
}
