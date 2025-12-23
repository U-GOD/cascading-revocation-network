// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AgentRegistry, Agent, AgentType} from "./AgentRegistry.sol";

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

    // ========================================================================
    // QUERY FUNCTIONS
    // ========================================================================
    
    function getMasterAgent(address owner) external view returns (MasterAgentRecord memory) {
        return masterAgents[owner];
    }
    
    function hasMasterAgent(address owner) external view returns (bool) {
        return masterAgents[owner].active;
    }
    
    function getPermission(uint256 permissionId) external view returns (PermissionNode memory) {
        return permissions[permissionId];
    }
    
    function getPermissionsByChild(address child) external view returns (uint256[] memory) {
        return permissionsByChild[child];
    }

    function getPermissionsByMaster(address master) external view returns (uint256[] memory) {
        return permissionsByMaster[master];
    }
    
    function isPermissionValid(uint256 permissionId) public view returns (bool) {
        PermissionNode storage perm = permissions[permissionId];
        
        if (perm.permissionId == 0) return false;
        
        if (!perm.active) return false;
        
        if (block.timestamp > perm.expiry) return false;
        
        return true;
    }
    
    /**
     * @notice Check if a child has a specific permission for a target and function
     * @param child The child agent address
     * @param target The target contract address
     * @param selector The function selector to check
     * @return True if child has valid permission for this action
     */
    function hasPermission(
        address child,
        address target,
        bytes4 selector
    ) external view returns (bool) {
        uint256[] storage childPerms = permissionsByChild[child];
        
        for (uint256 i = 0; i < childPerms.length; i++) {
            uint256 permId = childPerms[i];
            PermissionNode storage perm = permissions[permId];

            if (perm.targetContract != target) continue;

            if (!isPermissionValid(permId)) continue;
            
            for (uint256 j = 0; j < perm.allowedSelectors.length; j++) {
                if (perm.allowedSelectors[j] == selector) {
                    return true;
                }
            }
        }
        
        return false;
    }

    /**
     * @notice Set a master agent for the caller (user)
     * @param masterAgent The address of the master agent
     * @dev User calls this to delegate control to a master agent.
     *      The master can then grant permissions to child agents.
     */
    function setMasterAgent(address masterAgent) external {
        address owner = msg.sender;
        
        if (masterAgents[owner].active) {
            revert MasterAlreadySet(owner, masterAgents[owner].masterAgent);
        }

        if (!agentRegistry.isRegistered(masterAgent)) {
            revert AgentNotRegistered(masterAgent);
        }
        
        (
            address agentAddr,
            AgentType agentType,
            , 
            , 
            bool isActive,
            ,  
               
        ) = _getAgentData(masterAgent);
        
        if (agentType != AgentType.MASTER) {
            revert NotChildAgent(masterAgent); 
        }
        
        if (!isActive) {
            revert AgentNotRegistered(masterAgent); 
        }
        
        MasterAgentRecord storage record = masterAgents[owner];
        record.masterAgent = masterAgent;
        record.owner = owner;
        record.createdAt = block.timestamp;
        record.active = true;
        
        emit MasterAgentSet(owner, masterAgent);
    }    

    /**
     * @dev Helper to get agent data from registry
     *      Returns tuple to avoid struct compatibility issues
     */
    function _getAgentData(address agent) internal view returns (
        address agentAddress,
        AgentType agentType,
        bytes32 capabilities,
        string memory metadata,
        bool isActive,
        uint256 registeredAt,
        address registeredBy
    ) {
        return agentRegistry.agents(agent);
    }
}