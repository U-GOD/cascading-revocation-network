// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {AgentRegistry, Agent, AgentType} from "../src/AgentRegistry.sol";

/**
 * @title AgentRegistryTest
 * @notice Unit tests for AgentRegistry contract
 * @dev Inherits from Foundry's Test contract for testing utilities
 */
contract AgentRegistryTest is Test {
    AgentRegistry public registry;
    
    address public user;        
    address public masterAgent; 
    address public childAgent1; 
    address public childAgent2; 
    address public childAgent3; 
    address public stranger;    
    
    function setUp() public {
        registry = new AgentRegistry();
        
        user = makeAddr("user");
        masterAgent = makeAddr("masterAgent");
        childAgent1 = makeAddr("childAgent1");
        childAgent2 = makeAddr("childAgent2");
        childAgent3 = makeAddr("childAgent3");
        stranger = makeAddr("stranger");
        
        console.log("Test setup complete");
        console.log("Registry deployed at:", address(registry));
    }
    
    /**
     * @dev Helper to register a master agent (reduces repetition in tests)
     */
    function _registerMaster() internal {
        bytes32 caps = registry.MASTER_DEFAULT_CAPS();
        vm.prank(user); 
        registry.registerMasterAgent(
            masterAgent,
            caps,
            "Test Master Agent"
        );
    }
    
    function test_SetUp_DeploysRegistry() public view {
        assertEq(registry.getAgentCount(), 0, "Should start with 0 agents");
    }

    /**
     * @dev Test that registering a master agent works correctly
     *      This tests the "happy path" - everything goes right
     */
    function test_RegisterMasterAgent_Success() public {
        bytes32 capabilities = registry.MASTER_DEFAULT_CAPS();
        string memory metadata = "My Master Agent";
        
        vm.prank(user);  
        registry.registerMasterAgent(masterAgent, capabilities, metadata);
        
        assertTrue(registry.isRegistered(masterAgent), "Agent should be registered");
        
        assertEq(registry.getAgentCount(), 1, "Should have 1 agent");
        
        Agent memory agent = registry.getAgent(masterAgent);
        assertEq(agent.agentAddress, masterAgent, "Address mismatch");
        assertEq(uint(agent.agentType), uint(AgentType.MASTER), "Should be MASTER type");
        assertEq(agent.capabilities, capabilities, "Capabilities mismatch");
        assertEq(agent.registeredBy, user, "RegisteredBy should be user");
        assertTrue(agent.isActive, "Should be active");
    }
    
    /**
     * @dev Test that registering the same agent twice fails
     *      This tests error handling
     */
    function test_RegisterMasterAgent_RevertIfAlreadyRegistered() public {
        _registerMaster();
        
        bytes32 caps = registry.MASTER_DEFAULT_CAPS(); 
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                AgentRegistry.AgentAlreadyRegistered.selector,
                masterAgent
            )
        );
        registry.registerMasterAgent(masterAgent, caps, "Duplicate");
    }

    /**
     * @dev Test that registering a child agent works correctly
     */
    function test_RegisterChildAgent_Success() public {
        _registerMaster();
        
        bytes32 childCaps = registry.CAP_DAO_VOTE();
        vm.prank(masterAgent);  // Child is registered BY the master
        registry.registerChildAgent(childAgent1, childCaps, "DAO Voter Bot");
        
        assertTrue(registry.isRegistered(childAgent1), "Child should be registered");
        assertEq(registry.getAgentCount(), 2, "Should have 2 agents (master + child)");
        
        // Check child data
        Agent memory child = registry.getAgent(childAgent1);
        assertEq(uint(child.agentType), uint(AgentType.CHILD), "Should be CHILD type");
        assertEq(child.registeredBy, masterAgent, "RegisteredBy should be master");
        
        // Check parent-child relationship
        assertEq(registry.getMaster(childAgent1), masterAgent, "Master should be set");
        address[] memory children = registry.getChildren(masterAgent);
        assertEq(children.length, 1, "Master should have 1 child");
        assertEq(children[0], childAgent1, "Child address should match");
    }
    
    /**
     * @dev Test that only a registered master can register children
     */
    function test_RegisterChildAgent_RevertIfNotMaster() public {
        // Try to register child without being a master
        bytes32 childCaps = registry.CAP_DAO_VOTE();
        
        vm.prank(stranger);  
        vm.expectRevert(
            abi.encodeWithSelector(
                AgentRegistry.MasterNotRegistered.selector,
                stranger
            )
        );
        registry.registerChildAgent(childAgent1, childCaps, "Should Fail");
    }

    /**
     * @dev Test that deregistering a master agent works (soft delete)
     */
    function test_DeregisterMasterAgent_Success() public {
        _registerMaster();
        assertTrue(registry.isActive(masterAgent), "Should be active initially");
        
        vm.prank(user);
        registry.deregisterAgent(masterAgent);

        assertTrue(registry.isRegistered(masterAgent), "Should still be registered");
        assertFalse(registry.isActive(masterAgent), "Should NOT be active");

        Agent memory agent = registry.getAgent(masterAgent);
        assertFalse(agent.isActive, "isActive should be false");
    }
    
    /**
     * @dev Test that only authorized address can deregister
     */
    function test_DeregisterAgent_RevertIfUnauthorized() public {
        _registerMaster();

        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(
                AgentRegistry.NotAuthorizedToDeregister.selector,
                stranger,
                masterAgent
            )
        );
        registry.deregisterAgent(masterAgent);
    }

    // ========================================================================
    // TEST: deregisterAllChildren()
    // ========================================================================
    
    /**
     * @dev Test cascade revocation - deactivating ALL children at once
     *      THIS IS THE CORE INNOVATION OF OUR PROJECT!
     */
    function test_DeregisterAllChildren_CascadeRevocation() public {
        _registerMaster();
        
        bytes32 cap1 = registry.CAP_DAO_VOTE();
        bytes32 cap2 = registry.CAP_NFT_BID();
        bytes32 cap3 = registry.CAP_TREASURY();
        
        vm.startPrank(masterAgent); 
        registry.registerChildAgent(childAgent1, cap1, "DAO Voter");
        registry.registerChildAgent(childAgent2, cap2, "NFT Bidder");
        registry.registerChildAgent(childAgent3, cap3, "Treasury Manager");
        vm.stopPrank();
        
        assertTrue(registry.isActive(childAgent1), "Child1 should be active");
        assertTrue(registry.isActive(childAgent2), "Child2 should be active");
        assertTrue(registry.isActive(childAgent3), "Child3 should be active");
        assertEq(registry.getAgentCount(), 4, "Should have 4 agents total");
        
        vm.prank(masterAgent);
        registry.deregisterAllChildren(masterAgent);
        
        assertFalse(registry.isActive(childAgent1), "Child1 should be INACTIVE");
        assertFalse(registry.isActive(childAgent2), "Child2 should be INACTIVE");
        assertFalse(registry.isActive(childAgent3), "Child3 should be INACTIVE");
        
        assertTrue(registry.isActive(masterAgent), "Master should still be active");
        
        assertTrue(registry.isRegistered(childAgent1), "Child1 still registered");
        assertTrue(registry.isRegistered(childAgent2), "Child2 still registered");
        assertTrue(registry.isRegistered(childAgent3), "Child3 still registered");
        
        console.log("CASCADE REVOCATION SUCCESS!");
        console.log("All 3 children deactivated in ONE transaction");
    }
}