/*
 * Please refer to https://docs.envio.dev for a thorough guide on all Envio indexer features
 */
import {
  AgentRegistry,
  AgentRegistry_AgentDeregistered,
  AgentRegistry_AgentRegistered,
  AgentRegistry_CapabilitiesUpdated,
  PermissionManager,
  PermissionManager_AllPermissionsRevoked,
  PermissionManager_ChildActionExecuted,
  PermissionManager_MasterAgentRevoked,
  PermissionManager_MasterAgentSet,
  PermissionManager_PermissionGranted,
  PermissionManager_PermissionRevoked,
} from "generated";

AgentRegistry.AgentDeregistered.handler(async ({ event, context }) => {
  const entity: AgentRegistry_AgentDeregistered = {
    id: `${event.chainId}_${event.block.number}_${event.logIndex}`,
    agent: event.params.agent,
    deregisteredBy: event.params.deregisteredBy,
  };

  context.AgentRegistry_AgentDeregistered.set(entity);
});

AgentRegistry.AgentRegistered.handler(async ({ event, context }) => {
  const entity: AgentRegistry_AgentRegistered = {
    id: `${event.chainId}_${event.block.number}_${event.logIndex}`,
    agent: event.params.agent,
    agentType: event.params.agentType,
    registeredBy: event.params.registeredBy,
    capabilties: event.params.capabilties,
  };

  context.AgentRegistry_AgentRegistered.set(entity);
});

AgentRegistry.CapabilitiesUpdated.handler(async ({ event, context }) => {
  const entity: AgentRegistry_CapabilitiesUpdated = {
    id: `${event.chainId}_${event.block.number}_${event.logIndex}`,
    agent: event.params.agent,
    oldCapabilities: event.params.oldCapabilities,
    newCapabilities: event.params.newCapabilities,
    updatedBy: event.params.updatedBy,
  };

  context.AgentRegistry_CapabilitiesUpdated.set(entity);
});

PermissionManager.AllPermissionsRevoked.handler(async ({ event, context }) => {
  const entity: PermissionManager_AllPermissionsRevoked = {
    id: `${event.chainId}_${event.block.number}_${event.logIndex}`,
    masterAgent: event.params.masterAgent,
    count: event.params.count,
  };

  context.PermissionManager_AllPermissionsRevoked.set(entity);
});

PermissionManager.ChildActionExecuted.handler(async ({ event, context }) => {
  const entity: PermissionManager_ChildActionExecuted = {
    id: `${event.chainId}_${event.block.number}_${event.logIndex}`,
    permissionId: event.params.permissionId,
    childAgent: event.params.childAgent,
    target: event.params.target,
    selector: event.params.selector,
    value: event.params.value,
    success: event.params.success,
  };

  context.PermissionManager_ChildActionExecuted.set(entity);
});

PermissionManager.MasterAgentRevoked.handler(async ({ event, context }) => {
  const entity: PermissionManager_MasterAgentRevoked = {
    id: `${event.chainId}_${event.block.number}_${event.logIndex}`,
    owner: event.params.owner,
    masterAgent: event.params.masterAgent,
  };

  context.PermissionManager_MasterAgentRevoked.set(entity);
});

PermissionManager.MasterAgentSet.handler(async ({ event, context }) => {
  const entity: PermissionManager_MasterAgentSet = {
    id: `${event.chainId}_${event.block.number}_${event.logIndex}`,
    owner: event.params.owner,
    masterAgent: event.params.masterAgent,
  };

  context.PermissionManager_MasterAgentSet.set(entity);
});

PermissionManager.PermissionGranted.handler(async ({ event, context }) => {
  const entity: PermissionManager_PermissionGranted = {
    id: `${event.chainId}_${event.block.number}_${event.logIndex}`,
    permissionId: event.params.permissionId,
    masterAgent: event.params.masterAgent,
    childAgent: event.params.childAgent,
    targetContract: event.params.targetContract,
  };

  context.PermissionManager_PermissionGranted.set(entity);
});

PermissionManager.PermissionRevoked.handler(async ({ event, context }) => {
  const entity: PermissionManager_PermissionRevoked = {
    id: `${event.chainId}_${event.block.number}_${event.logIndex}`,
    permissionId: event.params.permissionId,
    revokedBy: event.params.revokedBy,
  };

  context.PermissionManager_PermissionRevoked.set(entity);
});
