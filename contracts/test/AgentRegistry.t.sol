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
            registry.MASTER_DEFAULT_CAPS(),
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
}