// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AgentRegistry, AgentType} from "./AgentRegistry.sol";

/**
 * @title PermissionManager
 * @notice Manages hierarchical permissions for agents
 * @dev Part of the Cascading Revocation Network - handles WHAT agents can DO
 */

struct PermissionNode {
    uint256 permissionId;      
    address grantedBy;         
    address childAgent;        
    address targetContract;    
    bytes4[] allowedSelectors; 
    uint256 maxValue;          
    uint256 expiry;            
    bool active;               
    uint256 grantedAt;         
}

struct MasterAgentRecord {
    address masterAgent;           
    address owner;                 
    uint256 createdAt;             
    bool active;                   
    uint256[] childPermissionIds;  
}

contract PermissionManager {
    AgentRegistry public immutable agentRegistry;
    
    uint256 public nextPermissionId;
    
    mapping(address => MasterAgentRecord) public masterAgents;
    
    mapping(uint256 => PermissionNode) public permissions;
    
    mapping(address => uint256[]) public permissionsByChild;
    
    mapping(address => uint256[]) public permissionsByMaster;
    
    constructor(address _agentRegistry) {
        agentRegistry = AgentRegistry(_agentRegistry);
        nextPermissionId = 1; 
    }
}