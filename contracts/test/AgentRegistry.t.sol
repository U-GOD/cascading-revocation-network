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
}