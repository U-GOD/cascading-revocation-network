import assert from "assert";
import { 
  TestHelpers,
  AgentRegistry_AgentDeregistered
} from "generated";
const { MockDb, AgentRegistry } = TestHelpers;

describe("AgentRegistry contract AgentDeregistered event tests", () => {
  // Create mock db
  const mockDb = MockDb.createMockDb();

  // Creating mock for AgentRegistry contract AgentDeregistered event
  const event = AgentRegistry.AgentDeregistered.createMockEvent({/* It mocks event fields with default values. You can overwrite them if you need */});

  it("AgentRegistry_AgentDeregistered is created correctly", async () => {
    // Processing the event
    const mockDbUpdated = await AgentRegistry.AgentDeregistered.processEvent({
      event,
      mockDb,
    });

    // Getting the actual entity from the mock database
    let actualAgentRegistryAgentDeregistered = mockDbUpdated.entities.AgentRegistry_AgentDeregistered.get(
      `${event.chainId}_${event.block.number}_${event.logIndex}`
    );

    // Creating the expected entity
    const expectedAgentRegistryAgentDeregistered: AgentRegistry_AgentDeregistered = {
      id: `${event.chainId}_${event.block.number}_${event.logIndex}`,
      agent: event.params.agent,
      deregisteredBy: event.params.deregisteredBy,
    };
    // Asserting that the entity in the mock database is the same as the expected entity
    assert.deepEqual(actualAgentRegistryAgentDeregistered, expectedAgentRegistryAgentDeregistered, "Actual AgentRegistryAgentDeregistered should be the same as the expectedAgentRegistryAgentDeregistered");
  });
});
