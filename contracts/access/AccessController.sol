// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/AccessControl.sol";
import "../core/IndexSwap.sol";

contract AccessController is AccessControl {
    bytes32 public constant ASSET_MANAGER_ROLE =
        keccak256("ASSET_MANAGER_ROLE");

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    modifier onlyAdmin(bytes32 role) {
        hasRole(getRoleAdmin(role), msg.sender);
        _;
    }

    function isAssetManager(address account) external view returns (bool) {
        return hasRole(ASSET_MANAGER_ROLE, account);
    }

    function setupRole(bytes32 role, address account) public onlyAdmin(role) {
        _setupRole(role, account);
    }

    function setRoleAdmin(bytes32 role, bytes32 adminRole)
        public
        onlyAdmin(role)
    {
        _setRoleAdmin(role, adminRole);
    }
}
