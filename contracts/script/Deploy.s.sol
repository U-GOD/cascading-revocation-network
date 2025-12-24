// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {AgentRegistry} from "../src/AgentRegistry.sol";
import {PermissionManager} from "../src/PermissionManager.sol";
import {RevocationController} from "../src/RevocationController.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        //  Deploy AgentRegistry
        AgentRegistry registry = new AgentRegistry();
        console.log("AgentRegistry deployed at:", address(registry));
        
        //  Deploy PermissionManager 
        PermissionManager permManager = new PermissionManager(address(registry));
        console.log("PermissionManager deployed at:", address(permManager));
        
        //  Deploy RevocationController (needs permManager address)
        RevocationController revController = new RevocationController(address(permManager));
        console.log("RevocationController deployed at:", address(revController));
        
        vm.stopBroadcast();
        
        console.log("\n=== DEPLOYMENT COMPLETE ===");
        console.log("Save these addresses for frontend!");
    }
}