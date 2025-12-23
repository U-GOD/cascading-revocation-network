// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {PermissionManager} from "./PermissionManager.sol";

/**
 * @title RevocationController
 * @notice Batch revocation contract designed for EIP-7702 delegation
 * @dev When an EOA delegates to this contract via EIP-7702, they gain
 *      the ability to batch revoke multiple permissions in a single transaction.
 */
contract RevocationController {
    PermissionManager public immutable permManager;

    event BatchRevocationExecuted(
        address indexed caller,
        uint256 count,
        uint256[] permissionIds
    );
     
    error EmptyBatchRevocation();
    
    /**
     * @notice Deploy with reference to PermissionManager
     * @param _permManager The PermissionManager contract address
     */
    constructor(address _permManager) {
        permManager = PermissionManager(_permManager);
    }

    /**
     * @notice Revoke multiple permissions in a single transaction
     * @param permissionIds Array of permission IDs to revoke
     * @return revokedCount Number of permissions successfully revoked
     * @dev This is the main function that EIP-7702 delegation enables.
     *      When an EOA delegates to this contract, they can call this
     *      function to revoke many permissions atomically.
     */
    function batchRevoke(
        uint256[] calldata permissionIds
    ) external returns (uint256 revokedCount) {
        if (permissionIds.length == 0) {
            revert EmptyBatchRevocation();
        }
        
        for (uint256 i = 0; i < permissionIds.length; i++) {
            try permManager.revokeChildPermission(permissionIds[i]) {
                revokedCount++;
            } catch {

            }
        }

        emit BatchRevocationExecuted(msg.sender, revokedCount, permissionIds);
        
        return revokedCount;
    }
}