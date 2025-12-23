// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {AgentRegistry, Agent, AgentType} from "../src/AgentRegistry.sol";
import {PermissionManager, PermissionNode, MasterAgentRecord} from "../src/PermissionManager.sol";
import {RevocationController} from "../src/RevocationController.sol";

contract MockDAO {
    uint256 public lastVote;
    uint256 public voteCount;
    address public lastCaller;
    
    function vote(uint256 proposalId) external {
        lastVote = proposalId;
        lastCaller = msg.sender;
        voteCount++;
    }
    
    receive() external payable {}
}

/**
 * @title IntegrationTest
 * @notice End-to-end integration tests for the Cascading Revocation Network
 */
contract IntegrationTest is Test {
    AgentRegistry public registry;
    PermissionManager public permManager;
    RevocationController public revController;
    MockDAO public mockDAO;
     
    address public user;           
    address public masterAgent;    
    address public childAgent1;
    address public childAgent2;
    address public childAgent3;
    
    bytes4 public constant VOTE_SELECTOR = bytes4(keccak256("vote(uint256)"));
    
    function setUp() public {
        user = makeAddr("user");
        masterAgent = makeAddr("masterAgent");
        childAgent1 = makeAddr("childAgent1");
        childAgent2 = makeAddr("childAgent2");
        childAgent3 = makeAddr("childAgent3");
        
        registry = new AgentRegistry();
        permManager = new PermissionManager(address(registry));
        revController = new RevocationController(address(permManager));
        mockDAO = new MockDAO();
        
        console.log("=== INTEGRATION TEST SETUP ===");
        console.log("AgentRegistry:", address(registry));
        console.log("PermissionManager:", address(permManager));
        console.log("RevocationController:", address(revController));
        console.log("MockDAO:", address(mockDAO));
    }
    
    function _futureExpiry() internal view returns (uint256) {
        return block.timestamp + 1 days;
    }

    /**
     * @dev Complete end-to-end test of the Cascading Revocation Network
     * 
     * Flow:
     * 1. User registers Master Agent
     * 2. User sets Master in PermissionManager
     * 3. Master registers 3 Child Agents
     * 4. Master grants permissions to all 3 children
     * 5. Child1 executes action successfully
     * 6. CASCADE REVOKE ALL CHILDREN 
     * 7. Verify all children can no longer execute
     */
    function test_FullFlow_UserToMasterToChildrenToRevokeAll() public {
        console.log("\n=== FULL FLOW INTEGRATION TEST ===\n");
        
        console.log("Step 1: Register Master Agent");
        
        bytes32 masterCaps = registry.MASTER_DEFAULT_CAPS();
        vm.prank(user);
        registry.registerMasterAgent(masterAgent, masterCaps, "Master Bot");
        
        assertTrue(registry.isRegistered(masterAgent), "Master should be registered");
        console.log("  -> Master registered at:", masterAgent);
        
        console.log("Step 2: User sets Master Agent");
        
        vm.prank(user);
        permManager.setMasterAgent(masterAgent);
        
        assertTrue(permManager.hasMasterAgent(user), "User should have master");
        console.log("  -> Master set for user");
        
        console.log("Step 3: Register 3 Child Agents");
        
        bytes32 childCaps = registry.CAP_DAO_VOTE();
        
        vm.startPrank(masterAgent);
        registry.registerChildAgent(childAgent1, childCaps, "DAO Voter 1");
        registry.registerChildAgent(childAgent2, childCaps, "DAO Voter 2");
        registry.registerChildAgent(childAgent3, childCaps, "DAO Voter 3");
        vm.stopPrank();
        
        assertEq(registry.getAgentCount(), 4, "Should have 4 agents (1 master + 3 children)");
        console.log("  -> 3 children registered");
        
        console.log("Step 4: Grant permissions to children");
        
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = VOTE_SELECTOR;
        
        uint256[] memory permIds = new uint256[](3);
        
        vm.startPrank(masterAgent);
        permIds[0] = permManager.grantChildPermission(
            childAgent1, address(mockDAO), selectors, 0, _futureExpiry()
        );
        permIds[1] = permManager.grantChildPermission(
            childAgent2, address(mockDAO), selectors, 0, _futureExpiry()
        );
        permIds[2] = permManager.grantChildPermission(
            childAgent3, address(mockDAO), selectors, 0, _futureExpiry()
        );
        vm.stopPrank();
        
        console.log("  -> Permission IDs:", permIds[0], permIds[1], permIds[2]);
        
        console.log("Step 5: Child1 executes vote");
        
        bytes memory voteCalldata = abi.encodeWithSelector(VOTE_SELECTOR, uint256(42));
        
        vm.prank(childAgent1);
        (bool success, ) = permManager.executeAsChild(permIds[0], voteCalldata);
        
        assertTrue(success, "Child1 execution should succeed");
        assertEq(mockDAO.lastVote(), 42, "DAO should have vote 42");
        console.log("  -> Child1 voted successfully! Proposal:", mockDAO.lastVote());
        
        console.log("Step 6: CASCADE REVOKE ALL CHILDREN!");
        
        vm.prank(masterAgent);
        uint256 revokedCount = permManager.revokeAllChildren(masterAgent);
        
        assertEq(revokedCount, 3, "Should revoke 3 permissions");
        console.log("  -> Revoked", revokedCount, "permissions in ONE call!");
        
        console.log("Step 7: Verify children cannot execute");
        
        vm.prank(childAgent1);
        vm.expectRevert();
        permManager.executeAsChild(permIds[0], voteCalldata);
        console.log("  -> Child1 correctly blocked");
        
        vm.prank(childAgent2);
        vm.expectRevert();
        permManager.executeAsChild(permIds[1], voteCalldata);
        console.log("  -> Child2 correctly blocked");
        
        vm.prank(childAgent3);
        vm.expectRevert();
        permManager.executeAsChild(permIds[2], voteCalldata);
        console.log("  -> Child3 correctly blocked");
        
        console.log("\n=== FULL FLOW TEST PASSED! ===");
        console.log("User -> Master -> 3 Children -> Execute -> CASCADE REVOKE");
        console.log("All children revoked in ONE transaction!");
    }
}