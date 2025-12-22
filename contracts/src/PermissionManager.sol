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
  
    event MasterAgentSet(
        address indexed owner, 
        address indexed masterAgent
    );
    
    event MasterAgentRevoked(
        address indexed owner, 
        address indexed masterAgent
    );
    
    event PermissionGranted(
        uint256 indexed permissionId,
        address indexed masterAgent,
        address indexed childAgent,
        address targetContract
    );
    
    event PermissionRevoked(
        uint256 indexed permissionId, 
        address indexed revokedBy
    );
    
    event AllPermissionsRevoked(
        address indexed masterAgent, 
        uint256 count
    );
    
    error MasterAlreadySet(address owner, address existingMaster);
    
    error MasterNotSet(address owner);
    
    error NotMasterAgent(address caller, address expectedMaster);
    
    error PermissionNotFound(uint256 permissionId);
    
    error PermissionExpired(uint256 permissionId, uint256 expiry);
    
    error PermissionNotActive(uint256 permissionId);
    
    error NotAuthorizedToRevoke(address caller, uint256 permissionId);
    
    error InvalidTargetContract(address target);
    
    error NoSelectorsProvided();
    
    error AgentNotRegistered(address agent);
    
    error NotChildAgent(address agent);
    
    constructor(address _agentRegistry) {
        agentRegistry = AgentRegistry(_agentRegistry);
        nextPermissionId = 1; 
    }
}