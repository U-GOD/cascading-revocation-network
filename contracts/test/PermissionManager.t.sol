// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {AgentRegistry, Agent, AgentType} from "../src/AgentRegistry.sol";
import {PermissionManager, PermissionNode, MasterAgentRecord} from "../src/PermissionManager.sol";

/**
 * @dev Simple mock DAO contract for testing executeAsChild
 */
contract MockDAO {
    uint256 public lastVote;
    uint256 public lastBid;
    address public lastCaller;
    
    function vote(uint256 proposalId) external {
        lastVote = proposalId;
        lastCaller = msg.sender;
    }
    
    function bid(uint256 amount) external payable {
        lastBid = amount;
        lastCaller = msg.sender;
    }
    
    // Function to receive ETH
    receive() external payable {}
}

/**
 * @title PermissionManagerTest
 * @notice Unit tests for PermissionManager grant logic
 */
contract PermissionManagerTest is Test {
    AgentRegistry public registry;
    PermissionManager public permManager;
    
    address public user;           
    address public masterAgent;    
    address public childAgent1;    
    address public childAgent2;    
    address public stranger;       
    

    bytes4 public constant VOTE_SELECTOR = bytes4(keccak256("vote(uint256)"));
    bytes4 public constant BID_SELECTOR = bytes4(keccak256("bid(uint256)"));
    address public targetDAO;
    MockDAO public mockDAO;
    
    function setUp() public {
        user = makeAddr("user");
        masterAgent = makeAddr("masterAgent");
        childAgent1 = makeAddr("childAgent1");
        childAgent2 = makeAddr("childAgent2");
        stranger = makeAddr("stranger");
        targetDAO = makeAddr("targetDAO");
        
        registry = new AgentRegistry();
        
        permManager = new PermissionManager(address(registry));
        
        mockDAO = new MockDAO();
        targetDAO = address(mockDAO);

        console.log("Setup complete");
        console.log("AgentRegistry:", address(registry));
        console.log("PermissionManager:", address(permManager));
    }
    
    /**
     * @dev Register a master agent in the registry
     */
    function _registerMasterInRegistry() internal {
        bytes32 caps = registry.MASTER_DEFAULT_CAPS();
        vm.prank(user);
        registry.registerMasterAgent(masterAgent, caps, "Test Master");
    }
    
    /**
     * @dev Register a child agent in the registry (under the master)
     */
    function _registerChildInRegistry(address child) internal {
        bytes32 caps = registry.CAP_DAO_VOTE();
        vm.prank(masterAgent);
        registry.registerChildAgent(child, caps, "Test Child");
    }
    
    /**
     * @dev Full setup: register master, register child, user sets master
     */
    function _fullSetup() internal {
        _registerMasterInRegistry();
        
        _registerChildInRegistry(childAgent1);
        
        vm.prank(user);
        permManager.setMasterAgent(masterAgent);
    }
    
    /**
     * @dev Get future timestamp (1 day from now)
     */
    function _futureExpiry() internal view returns (uint256) {
        return block.timestamp + 1 days;
    }
    
    /**
     * @dev Get past timestamp (1 day ago)
     */
     function _pastExpiry() internal pure returns (uint256) {
        return 1;  
    }
    
    /**
     * @dev Full setup + grant permission, ready for execution tests
     */
    function _setupForExecution() internal returns (uint256 permissionId) {
        _fullSetup();
        
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = VOTE_SELECTOR;
        selectors[1] = BID_SELECTOR;
        
        vm.prank(masterAgent);
        permissionId = permManager.grantChildPermission(
            childAgent1,
            targetDAO,
            selectors,
            1 ether,  
            _futureExpiry()
        );
    }

    function test_SetUp_DeploysContracts() public view {
        assertTrue(address(registry) != address(0), "Registry should be deployed");
        assertTrue(address(permManager) != address(0), "PermManager should be deployed");
        
        assertEq(address(permManager.agentRegistry()), address(registry), "Registry reference wrong");
    }

    // ========================================================================
    // TESTS: setMasterAgent()
    // ========================================================================
    
    /**
     * @dev Test successful master agent setting
     */
    function test_SetMasterAgent_Success() public {
        _registerMasterInRegistry();
        
        vm.prank(user);
        permManager.setMasterAgent(masterAgent);
        
        assertTrue(permManager.hasMasterAgent(user), "User should have master");
        
        MasterAgentRecord memory record = permManager.getMasterAgent(user);
        assertEq(record.masterAgent, masterAgent, "Master address wrong");
        assertEq(record.owner, user, "Owner should be user");
        assertTrue(record.active, "Should be active");
        
        assertEq(permManager.masterToOwner(masterAgent), user, "Reverse lookup wrong");
    }
    
    /**
     * @dev Test that user can't set master twice
     */
    function test_SetMasterAgent_RevertIfAlreadySet() public {
        _registerMasterInRegistry();
        vm.prank(user);
        permManager.setMasterAgent(masterAgent);
        
        address anotherMaster = makeAddr("anotherMaster");
        bytes32 caps = registry.MASTER_DEFAULT_CAPS();
        vm.prank(user);
        registry.registerMasterAgent(anotherMaster, caps, "Another Master");
        
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                PermissionManager.MasterAlreadySet.selector,
                user,
                masterAgent
            )
        );
        permManager.setMasterAgent(anotherMaster);
    }
    
    /**
     * @dev Test can't set unregistered address as master
     */
    function test_SetMasterAgent_RevertIfNotRegistered() public {
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                PermissionManager.AgentNotRegistered.selector,
                masterAgent
            )
        );
        permManager.setMasterAgent(masterAgent);
    }
    
    /**
     * @dev Test can't set CHILD type as master
     */
    function test_SetMasterAgent_RevertIfNotMasterType() public {
        _registerMasterInRegistry();
        
        _registerChildInRegistry(childAgent1);
        
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                PermissionManager.NotChildAgent.selector,
                childAgent1
            )
        );
        permManager.setMasterAgent(childAgent1);
    }

    // ========================================================================
    // TESTS: grantChildPermission()
    // ========================================================================
    
    /**
     * @dev Test successful permission grant
     */
    function test_GrantPermission_Success() public {
        _fullSetup();
        
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = VOTE_SELECTOR;
        
        vm.prank(masterAgent);
        uint256 permId = permManager.grantChildPermission(
            childAgent1,
            targetDAO,
            selectors,
            0,  
            _futureExpiry()
        );
        
        assertEq(permId, 1, "First permission should be ID 1");
        
        PermissionNode memory perm = permManager.getPermission(permId);
        assertEq(perm.permissionId, 1, "Permission ID wrong");
        assertEq(perm.grantedBy, masterAgent, "GrantedBy wrong");
        assertEq(perm.childAgent, childAgent1, "Child wrong");
        assertEq(perm.targetContract, targetDAO, "Target wrong");
        assertTrue(perm.active, "Should be active");
        
        uint256[] memory childPerms = permManager.getPermissionsByChild(childAgent1);
        assertEq(childPerms.length, 1, "Child should have 1 permission");
        assertEq(childPerms[0], permId, "Permission ID mismatch");
        
        uint256[] memory masterPerms = permManager.getPermissionsByMaster(masterAgent);
        assertEq(masterPerms.length, 1, "Master should have 1 permission");
    }
    
    /**
     * @dev Test non-master can't grant permissions
     */
    function test_GrantPermission_RevertIfNotMaster() public {
        _fullSetup();
        
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = VOTE_SELECTOR;
        
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(
                PermissionManager.AgentNotRegistered.selector,
                stranger
            )
        );
        permManager.grantChildPermission(
            childAgent1,
            targetDAO,
            selectors,
            0,
            _futureExpiry()
        );
    }
    
    /**
     * @dev Test master without owner can't grant
     */
    function test_GrantPermission_RevertIfMasterHasNoOwner() public {
        _registerMasterInRegistry();
        _registerChildInRegistry(childAgent1);
        
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = VOTE_SELECTOR;
        
        vm.prank(masterAgent);
        vm.expectRevert(
            abi.encodeWithSelector(
                PermissionManager.NotMasterAgent.selector,
                masterAgent,
                address(0)
            )
        );
        permManager.grantChildPermission(
            childAgent1,
            targetDAO,
            selectors,
            0,
            _futureExpiry()
        );
    }
    
    /**
     * @dev Test can't grant to unregistered child
     */
    function test_GrantPermission_RevertIfChildNotRegistered() public {
        _registerMasterInRegistry();
        vm.prank(user);
        permManager.setMasterAgent(masterAgent);
        
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = VOTE_SELECTOR;
        
        vm.prank(masterAgent);
        vm.expectRevert(
            abi.encodeWithSelector(
                PermissionManager.AgentNotRegistered.selector,
                childAgent1
            )
        );
        permManager.grantChildPermission(
            childAgent1,
            targetDAO,
            selectors,
            0,
            _futureExpiry()
        );
    }
    
    /**
     * @dev Test can't grant with past expiry
     */
    function test_GrantPermission_RevertIfExpired() public {
        _fullSetup();
        
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = VOTE_SELECTOR;
        
        vm.prank(masterAgent);
        vm.expectRevert(
            abi.encodeWithSelector(
                PermissionManager.PermissionExpired.selector,
                0,  
                _pastExpiry()
            )
        );
        permManager.grantChildPermission(
            childAgent1,
            targetDAO,
            selectors,
            0,
            _pastExpiry()
        );
    }

    // ========================================================================
    // TESTS: Query Functions & Edge Cases
    // ========================================================================
    
    /**
     * @dev Test hasPermission returns true for valid permission
     */
    function test_HasPermission_ReturnsTrue() public {
        _fullSetup();
        
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = VOTE_SELECTOR;
        
        vm.prank(masterAgent);
        permManager.grantChildPermission(
            childAgent1,
            targetDAO,
            selectors,
            0,
            _futureExpiry()
        );
        
        bool hasPerm = permManager.hasPermission(childAgent1, targetDAO, VOTE_SELECTOR);
        assertTrue(hasPerm, "Should have permission");
        
        bool hasWrongPerm = permManager.hasPermission(childAgent1, targetDAO, BID_SELECTOR);
        assertFalse(hasWrongPerm, "Should NOT have permission for wrong selector");
    }
    
    /**
     * @dev Test isPermissionValid returns false after expiry
     */
    function test_IsPermissionValid_ExpiredReturnsFalse() public {
        _fullSetup();
        
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = VOTE_SELECTOR;
        
        uint256 shortExpiry = block.timestamp + 1 hours;
        
        vm.prank(masterAgent);
        uint256 permId = permManager.grantChildPermission(
            childAgent1,
            targetDAO,
            selectors,
            0,
            shortExpiry
        );
        
        assertTrue(permManager.isPermissionValid(permId), "Should be valid initially");
        
        vm.warp(shortExpiry + 1);

        assertFalse(permManager.isPermissionValid(permId), "Should be invalid after expiry");
    }

    // ========================================================================
    // TESTS: revokeChildPermission()
    // ========================================================================
    
    /**
     * @dev Test master can revoke permission they granted
     */
    function test_RevokeChildPermission_Success() public {
        _fullSetup();
        
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = VOTE_SELECTOR;
        
        vm.prank(masterAgent);
        uint256 permId = permManager.grantChildPermission(
            childAgent1,
            targetDAO,
            selectors,
            0,
            _futureExpiry()
        );
        
        assertTrue(permManager.isPermissionValid(permId), "Should be valid before");
        
        vm.prank(masterAgent);
        permManager.revokeChildPermission(permId);
        
        assertFalse(permManager.isPermissionValid(permId), "Should be invalid after");
    }
    
    /**
     * @dev Test owner can also revoke (not just master)
     */
    function test_RevokeChildPermission_OwnerCanRevoke() public {
        _fullSetup();
        
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = VOTE_SELECTOR;
        
        vm.prank(masterAgent);
        uint256 permId = permManager.grantChildPermission(
            childAgent1,
            targetDAO,
            selectors,
            0,
            _futureExpiry()
        );
        
        vm.prank(user);
        permManager.revokeChildPermission(permId);
        
        assertFalse(permManager.isPermissionValid(permId), "Should be invalid after");
    }
    
    /**
     * @dev Test unauthorized can't revoke
     */
    function test_RevokeChildPermission_RevertIfUnauthorized() public {
        _fullSetup();
        
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = VOTE_SELECTOR;
        
        vm.prank(masterAgent);
        uint256 permId = permManager.grantChildPermission(
            childAgent1,
            targetDAO,
            selectors,
            0,
            _futureExpiry()
        );
        
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(
                PermissionManager.NotAuthorizedToRevoke.selector,
                stranger,
                permId
            )
        );
        permManager.revokeChildPermission(permId);
    }

    // ========================================================================
    // TESTS: revokeAllChildren() - CASCADE REVOCATION 
    // ========================================================================
    
    /**
     * @dev Test cascade revokes all permissions at once
     */
    function test_RevokeAllChildren_CascadeSuccess() public {
        _fullSetup();
        
        _registerChildInRegistry(childAgent2);
        
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = VOTE_SELECTOR;
        
        vm.prank(masterAgent);
        uint256 permId1 = permManager.grantChildPermission(
            childAgent1, targetDAO, selectors, 0, _futureExpiry()
        );
        
        vm.prank(masterAgent);
        uint256 permId2 = permManager.grantChildPermission(
            childAgent2, targetDAO, selectors, 0, _futureExpiry()
        );
        
        assertTrue(permManager.isPermissionValid(permId1), "Perm1 should be valid");
        assertTrue(permManager.isPermissionValid(permId2), "Perm2 should be valid");
        
        // CASCADE REVOKE! 
        vm.prank(masterAgent);
        uint256 revokedCount = permManager.revokeAllChildren(masterAgent);
        
        assertEq(revokedCount, 2, "Should revoke 2 permissions");
        
        assertFalse(permManager.isPermissionValid(permId1), "Perm1 should be invalid");
        assertFalse(permManager.isPermissionValid(permId2), "Perm2 should be invalid");
        
        console.log("CASCADE REVOCATION SUCCESS! Revoked:", revokedCount);
    }
    
    /**
     * @dev Test cascade returns correct count (skips already revoked)
     */
    function test_RevokeAllChildren_SkipsAlreadyRevoked() public {
        _fullSetup();
        _registerChildInRegistry(childAgent2);
        
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = VOTE_SELECTOR;
        
        vm.prank(masterAgent);
        uint256 permId1 = permManager.grantChildPermission(
            childAgent1, targetDAO, selectors, 0, _futureExpiry()
        );
        vm.prank(masterAgent);
        permManager.grantChildPermission(
            childAgent2, targetDAO, selectors, 0, _futureExpiry()
        );
        
        vm.prank(masterAgent);
        permManager.revokeChildPermission(permId1);
        
        vm.prank(masterAgent);
        uint256 revokedCount = permManager.revokeAllChildren(masterAgent);
        
        assertEq(revokedCount, 1, "Should only revoke 1 (other already revoked)");
    }

    // ========================================================================
    // TESTS: revokeMasterAgent() - FULL CASCADE
    // ========================================================================
    
    /**
     * @dev Test full cascade: master + all children deactivated
     */
    function test_RevokeMasterAgent_FullCascade() public {
        _fullSetup();
        _registerChildInRegistry(childAgent2);
        
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = VOTE_SELECTOR;
        
        vm.prank(masterAgent);
        uint256 permId1 = permManager.grantChildPermission(
            childAgent1, targetDAO, selectors, 0, _futureExpiry()
        );
        vm.prank(masterAgent);
        uint256 permId2 = permManager.grantChildPermission(
            childAgent2, targetDAO, selectors, 0, _futureExpiry()
        );
        
        assertTrue(permManager.hasMasterAgent(user), "Master should be active");
        
        // FULL CASCADE REVOKE!
        vm.prank(user);
        permManager.revokeMasterAgent();
        
        assertFalse(permManager.hasMasterAgent(user), "Master should be inactive");
        
        assertFalse(permManager.isPermissionValid(permId1), "Perm1 should be invalid");
        assertFalse(permManager.isPermissionValid(permId2), "Perm2 should be invalid");
        
        assertEq(permManager.masterToOwner(masterAgent), address(0), "Reverse lookup should be cleared");
        
        console.log("FULL CASCADE SUCCESS! Master + all children deactivated");
    }
    
    /**
     * @dev Test only owner can call revokeMasterAgent
     */
    function test_RevokeMasterAgent_OnlyOwnerCanCall() public {
        _fullSetup();
        
        vm.prank(masterAgent);
        vm.expectRevert(
            abi.encodeWithSelector(
                PermissionManager.MasterNotSet.selector,
                masterAgent  
            )
        );
        permManager.revokeMasterAgent();
        
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(
                PermissionManager.MasterNotSet.selector,
                stranger
            )
        );
        permManager.revokeMasterAgent();
    }

    // ========================================================================
    // GAS TEST: Cascade with many children
    // ========================================================================
    
    /**
     * @dev Test cascade revocation with 10 children to verify gas limits
     */
    function test_GasTest_CascadeWith10Children() public {
        _registerMasterInRegistry();
        
        vm.prank(user);
        permManager.setMasterAgent(masterAgent);
        
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = VOTE_SELECTOR;
        
        for (uint256 i = 0; i < 10; i++) {
            address child = makeAddr(string(abi.encodePacked("child", i)));
            
            bytes32 caps = registry.CAP_DAO_VOTE();
            vm.prank(masterAgent);
            registry.registerChildAgent(child, caps, "Test Child");
            
            vm.prank(masterAgent);
            permManager.grantChildPermission(
                child, targetDAO, selectors, 0, _futureExpiry()
            );
        }
        
        uint256[] memory masterPerms = permManager.getPermissionsByMaster(masterAgent);
        assertEq(masterPerms.length, 10, "Should have 10 permissions");
        
        // CASCADE REVOKE ALL 10!
        vm.prank(masterAgent);
        uint256 gasStart = gasleft();
        uint256 revokedCount = permManager.revokeAllChildren(masterAgent);
        uint256 gasUsed = gasStart - gasleft();

        assertEq(revokedCount, 10, "Should revoke 10 permissions");
        
        console.log("=== GAS REPORT ===");
        console.log("Children revoked:", revokedCount);
        console.log("Gas used:", gasUsed);
        console.log("Gas per child:", gasUsed / revokedCount);
        
        assertTrue(gasUsed < 1_000_000, "Gas should be under 1M");
    }

    // ========================================================================
    // TESTS: executeAsChild()
    // ========================================================================
    
    /**
     * @dev Test child can successfully execute action through permission
     */
    function test_ExecuteAsChild_Success() public {
        uint256 permId = _setupForExecution();
        
        bytes memory callData = abi.encodeWithSelector(VOTE_SELECTOR, uint256(42));
        
        vm.prank(childAgent1);
        (bool success, ) = permManager.executeAsChild(permId, callData);
        
        assertTrue(success, "Execution should succeed");
        
        assertEq(mockDAO.lastVote(), 42, "DAO should have received vote");
        
        assertEq(mockDAO.lastCaller(), address(permManager), "Caller should be PermissionManager");
        
        console.log("executeAsChild SUCCESS! Child executed vote(42) through proxy");
    }

    /**
     * @dev Test wrong caller can't execute
     */
    function test_ExecuteAsChild_RevertIfWrongCaller() public {
        uint256 permId = _setupForExecution();
        bytes memory callData = abi.encodeWithSelector(VOTE_SELECTOR, uint256(42));
        
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(
                PermissionManager.CallerNotChildAgent.selector,
                stranger,
                childAgent1
            )
        );
        permManager.executeAsChild(permId, callData);
    }
    
    /**
     * @dev Test revoked permission can't execute
     */
    function test_ExecuteAsChild_RevertIfRevoked() public {
        uint256 permId = _setupForExecution();
        bytes memory callData = abi.encodeWithSelector(VOTE_SELECTOR, uint256(42));
        
        vm.prank(masterAgent);
        permManager.revokeChildPermission(permId);
        
        vm.prank(childAgent1);
        vm.expectRevert(
            abi.encodeWithSelector(
                PermissionManager.PermissionNotActive.selector,
                permId
            )
        );
        permManager.executeAsChild(permId, callData);
    }
    
    /**
     * @dev Test wrong selector rejected
     */
    function test_ExecuteAsChild_RevertIfWrongSelector() public {
        uint256 permId = _setupForExecution();
        
        bytes4 wrongSelector = bytes4(keccak256("withdraw(uint256)"));
        bytes memory callData = abi.encodeWithSelector(wrongSelector, uint256(100));
        
        vm.prank(childAgent1);
        vm.expectRevert(
            abi.encodeWithSelector(
                PermissionManager.SelectorNotAllowed.selector,
                wrongSelector,
                permId
            )
        );
        permManager.executeAsChild(permId, callData);
    }
    
    /**
     * @dev Test value exceeding maxValue rejected
     */
    function test_ExecuteAsChild_RevertIfValueExceeds() public {
        uint256 permId = _setupForExecution();  
        bytes memory callData = abi.encodeWithSelector(BID_SELECTOR, uint256(100));
        
        vm.deal(childAgent1, 10 ether);
        
        vm.prank(childAgent1);
        vm.expectRevert(
            abi.encodeWithSelector(
                PermissionManager.ValueExceedsLimit.selector,
                2 ether,
                1 ether
            )
        );
        permManager.executeAsChild{value: 2 ether}(permId, callData);
    }
}