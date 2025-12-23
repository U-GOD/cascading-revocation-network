// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {AgentRegistry, AgentType} from "../src/AgentRegistry.sol";
import {PermissionManager} from "../src/PermissionManager.sol";
import {RevocationController} from "../src/RevocationController.sol";

/**
 * @title RevocationControllerTest
 * @notice Unit tests for RevocationController batch revocation
 */
contract RevocationControllerTest is Test {
    
    AgentRegistry public registry;
    PermissionManager public permManager;
    RevocationController public revController;
    
    address public user;
    address public masterAgent;
    address public childAgent1;
    address public childAgent2;
    address public childAgent3;
    address public targetDAO;
    
    bytes4 public constant VOTE_SELECTOR = bytes4(keccak256("vote(uint256)"));
    
    function setUp() public {
        user = makeAddr("user");
        masterAgent = makeAddr("masterAgent");
        childAgent1 = makeAddr("childAgent1");
        childAgent2 = makeAddr("childAgent2");
        childAgent3 = makeAddr("childAgent3");
        targetDAO = makeAddr("targetDAO");
        
        registry = new AgentRegistry();
        permManager = new PermissionManager(address(registry));
        revController = new RevocationController(address(permManager));
        
        console.log("Setup complete");
    }
    
    function _fullSetupWithPermissions() internal returns (uint256[] memory permIds) {
        bytes32 caps = registry.MASTER_DEFAULT_CAPS();
        vm.prank(user);
        registry.registerMasterAgent(masterAgent, caps, "Master");
        
        vm.prank(user);
        permManager.setMasterAgent(masterAgent);
        
        bytes32 childCaps = registry.CAP_DAO_VOTE();
        vm.startPrank(masterAgent);
        registry.registerChildAgent(childAgent1, childCaps, "Child1");
        registry.registerChildAgent(childAgent2, childCaps, "Child2");
        registry.registerChildAgent(childAgent3, childCaps, "Child3");
        vm.stopPrank();
        
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = VOTE_SELECTOR;
        uint256 expiry = block.timestamp + 1 days;
        
        permIds = new uint256[](3);
        
        vm.startPrank(masterAgent);
        permIds[0] = permManager.grantChildPermission(childAgent1, targetDAO, selectors, 0, expiry);
        permIds[1] = permManager.grantChildPermission(childAgent2, targetDAO, selectors, 0, expiry);
        permIds[2] = permManager.grantChildPermission(childAgent3, targetDAO, selectors, 0, expiry);
        vm.stopPrank();
        
        return permIds;
    }
       
    /**
     * @dev Test batch revoke multiple permissions
     */
    function test_BatchRevoke_Success() public {
        uint256[] memory permIds = _fullSetupWithPermissions();
        
        assertTrue(permManager.isPermissionValid(permIds[0]), "Perm1 should be valid");
        assertTrue(permManager.isPermissionValid(permIds[1]), "Perm2 should be valid");
        assertTrue(permManager.isPermissionValid(permIds[2]), "Perm3 should be valid");
        
        vm.prank(masterAgent);
        uint256 revokedCount = revController.batchRevoke(permIds);
        
        assertEq(revokedCount, 3, "Should revoke 3 permissions");
        
        assertFalse(permManager.isPermissionValid(permIds[0]), "Perm1 should be invalid");
        assertFalse(permManager.isPermissionValid(permIds[1]), "Perm2 should be invalid");
        assertFalse(permManager.isPermissionValid(permIds[2]), "Perm3 should be invalid");
        
        console.log("BATCH REVOKE SUCCESS! Revoked:", revokedCount);
    }
    
    /**
     * @dev Test empty array reverts
     */
    function test_BatchRevoke_RevertIfEmpty() public {
        uint256[] memory emptyArray = new uint256[](0);
        
        vm.prank(masterAgent);
        vm.expectRevert(RevocationController.EmptyBatchRevocation.selector);
        revController.batchRevoke(emptyArray);
    }
    
    /**
     * @dev Test batch revoke skips unauthorized/already revoked
     */
    function test_BatchRevoke_SkipsFailures() public {
        uint256[] memory permIds = _fullSetupWithPermissions();
        
        vm.prank(masterAgent);
        permManager.revokeChildPermission(permIds[0]);
        
        vm.prank(masterAgent);
        uint256 revokedCount = revController.batchRevoke(permIds);
        
        assertEq(revokedCount, 2, "Should revoke 2 (1 was already revoked)");
    }
}