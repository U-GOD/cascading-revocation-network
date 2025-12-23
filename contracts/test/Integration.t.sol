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
}