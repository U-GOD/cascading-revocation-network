// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

enum AgentType {
    NONE,       
    MASTER,     
    CHILD       
}

struct Agent {
    address agentAddress;      
    AgentType agentType;       
    bytes32 capabilities;      
    string metadata;           
    bool isActive;             
    uint256 registeredAt;      
    address registeredBy;      
}

contract AgentRegistry {
    mapping(address => Agent) public agents;
    
    mapping(address => bool) private _isRegistered;
    
    mapping(address => address[]) public masterToChildren;
    
    mapping(address => address) public childToMaster;
    
    address[] public allAgents;
    
    bytes32 public constant CAP_DELEGATE   = bytes32(uint256(1 << 0));
    bytes32 public constant CAP_REVOKE     = bytes32(uint256(1 << 1));
    bytes32 public constant CAP_DAO_VOTE   = bytes32(uint256(1 << 2));
    bytes32 public constant CAP_NFT_BID    = bytes32(uint256(1 << 3));
    bytes32 public constant CAP_TREASURY   = bytes32(uint256(1 << 4));
    bytes32 public constant CAP_AUTOMATION = bytes32(uint256(1 << 5));
    

    bytes32 public constant MASTER_DEFAULT_CAPS = 
        bytes32(uint256(1 << 0) | uint256(1 << 1)); // DELEGATE + REVOKE

    // CUSTOM ERRORS
    error AgentAlreadyRegistered(address agent);
    error InvalidAgentAddress();
    error OnlyMasterCanRegisterChild();
    error MasterNotRegistered(address master);
    error AgentNotRegistered(address agent);
    error NotAuthorizedToDeregister(address caller, address agent);
    error AgentAlreadyDeactivated(address agent);
    error AgentNotActive(address agent);
    error NotAuthorizedToUpdate(address caller, address agent);

    // EVENTS
    event AgentRegistered(
        address indexed agent,
        AgentType indexed agentType,
        address indexed registeredBy,
        bytes32 capabilties
    );

    event AgentDeregistered(
        address indexed agent,
        address indexed deregisteredBy
    );

    event CapabilitiesUpdated (
        address indexed agent,
        bytes32 oldCapabilities,
        bytes32 newCapabilities,
        address indexed updatedBy
    );

    /**
     * @notice Register a new master agent (called by users)
     * @param agent The address of the master agent
     * @param capabilities The capabilities to grant (or use MASTER_DEFAULT_CAPS)
     * @param metadata Human-readable description
     */
    function registerMasterAgent(
        address agent,
        bytes32 capabilities,
        string calldata metadata
    ) external {
        if (agent == address(0)) revert InvalidAgentAddress();
        if (_isRegistered[agent]) revert AgentAlreadyRegistered(agent);

        Agent memory newAgent = Agent({
            agentAddress: agent,
            agentType: AgentType.MASTER,
            capabilities: capabilities,
            metadata: metadata,
            isActive: true,
            registeredAt: block.timestamp,
            registeredBy: msg.sender
        });

        agents[agent] = newAgent;

        _isRegistered[agent] = true;

        allAgents.push(agent);

        emit AgentRegistered(agent, AgentType.MASTER, msg.sender, capabilities);
    }

    /**
     * @notice Register a child agent (called by master agents only)
     * @param child The address of the child agent
     * @param capabilities What this child can do
     * @param metadata Human-readable description
     */
    function registerChildAgent(
        address child,
        bytes32 capabilities,
        string calldata metadata
    ) external {
        address master = msg.sender;

        if (child == address(0)) revert InvalidAgentAddress();
        if(_isRegistered[child]) revert AgentAlreadyRegistered(child);
        if (!_isRegistered[master]) revert MasterNotRegistered(master);
        if (agents[master].agentType != AgentType.MASTER) {
            revert OnlyMasterCanRegisterChild();
        }

        Agent memory newAgent = Agent({
            agentAddress: child,
            agentType: AgentType.CHILD,
            capabilities: capabilities,
            metadata: metadata,
            isActive: true,
            registeredAt: block.timestamp,
            registeredBy: master
        });

        agents[child] = newAgent;
        _isRegistered[child] = true;
        allAgents.push(child);

        // Track parent-child relationship
        masterToChildren[master].push(child);
        childToMaster[child] = master;

        emit AgentRegistered(child, AgentType.CHILD, master, capabilities);
    }

    /**
     * @notice Deactivate an agent (soft delete)
     * @param agent The agent address to deregister
     * @dev Can be called by:
     *      - For MASTER: the user who registered it (registeredBy)
     *      - For CHILD: the master agent OR the user who owns the master
     */
    function deregisterAgent(address agent) external {
        if (!_isRegistered[agent]) revert AgentNotRegistered(agent);

        Agent storage agentData = agents[agent];

        if (!agentData.isActive) revert AgentAlreadyDeactivated(agent);

        bool isAuthorized = false;

        if (agentData.agentType == AgentType.MASTER) {
            isAuthorized = (msg.sender == agentData.registeredBy);
        } else if (agentData.agentType == AgentType.CHILD) {
            address master = childToMaster[agent];
            address masterOwner = agents[master].registeredBy;
            isAuthorized = (msg.sender == master || msg.sender == masterOwner);
        }

        if (!isAuthorized) {
            revert NotAuthorizedToDeregister(msg.sender, agent);
        }

        agentData.isActive = false;

        emit AgentDeregistered(agent, msg.sender);
    }

    /**
     * @notice Deactivate all children of a master agent (CASCADE REVOCATION!)
     * @param master The master agent whose children should be deactivated
     * @dev This is the KEY FEATURE of our hackathon project!
     */
    function deregisterAllChildren(address master) external {
        if (!_isRegistered[master]) revert AgentNotRegistered(master);
        if (agents[master].agentType != AgentType.MASTER) {
            revert OnlyMasterCanRegisterChild();
        }

        // Authorization: master itself or the user who owns it
        address masterOwner = agents[master].registeredBy;
        if (msg.sender != master && msg.sender != masterOwner) {
            revert NotAuthorizedToDeregister(msg.sender, master);
        }

        address[] storage children = masterToChildren[master];

        for (uint256 i = 0; i < children.length; i++) {
            address child = children[i];

            if (agents[child].isActive) {
                agents[child].isActive = false;
                emit AgentDeregistered(child, msg.sender);
            }
        }
    }

    /**
     * @notice Update an agent's capabilities
     * @param agent The agent to update
     * @param newCapabilities The new capability flags
     * @dev Can be called by:
     *      - For MASTER: the user who registered it
     *      - For CHILD: the master agent
     */
    function updateCapabilities(address agent, bytes32 newCapabilities) external {
        if (!_isRegistered[agent]) revert AgentNotRegistered(agent);
        if (!agents[agent].isActive) revert AgentNotActive(agent);

        Agent storage agentData = agents[agent];
        bool isAuthorized = false;

        if (agentData.agentType == AgentType.MASTER) {
            isAuthorized = (msg.sender == agentData.registeredBy);
        } else if (agentData.agentType == AgentType.CHILD) {
            address master = childToMaster[agent];
            isAuthorized = (msg.sender == master);
        }

        if (!isAuthorized) {
            revert NotAuthorizedToUpdate(msg.sender, agent);
        }

        bytes32 oldCapabilities = agentData.capabilities;

        agentData.capabilities = newCapabilities;

        emit CapabilitiesUpdated(agent, oldCapabilities, newCapabilities, msg.sender);
    }

    // QUERY FUNCTIONS
    function getAgent(address agent) external view returns (Agent memory) {
        return agents[agent];
    }

    function getCapabilities(address agent) external view returns (bytes32) {
        return agents[agent].capabilities;
    }

    function hasCapability(address agent, bytes32 capability) external view returns (bool) {
        return (agents[agent].capabilities & capability) != bytes32(0);
    }

    function getAllAgents() external view returns (address[] memory) {
        return allAgents;
    }

    function getChildren(address master) external view returns (address[] memory) {
        return masterToChildren[master];
    }

    function getMaster(address child) external view returns (address) {
        return childToMaster[child];
    }

    function isActive(address agent) external view returns (bool) {
        return _isRegistered[agent] && agents[agent].isActive;
    }
    

    // HELPER FUNCTIONS
    function isRegistered(address agent) public view returns (bool) {
        return _isRegistered[agent];
    }
    
    function getAgentCount() public view returns (uint256) {
        return allAgents.length;
    }
}