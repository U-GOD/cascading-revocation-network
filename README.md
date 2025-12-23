#  Cascading Revocation Network

> **Hierarchical agent permission system with one-call cascade revocation**

Built for the MetaMask Advanced Permissions Hackathon | ERC-7715 + ERC-8004 + EIP-7702

---

##  The Problem

In the era of AI agents acting on behalf of users, **permission management becomes critical**:

- A user delegates to a **Master Agent**
- The Master Agent re-delegates to multiple **Child Agents**
- If something goes wrong, the user needs to revoke ALL permissions **immediately**

**Traditional approach:** Revoke permissions one by one → Slow, expensive, risky

**Our solution:** **CASCADE REVOCATION** → One call revokes everything! 

---

##  Key Innovation
Before Cascade Revocation: 5 permissions = 5 transactions = 5x gas = takes time

After Cascade Revocation: revokeAllChildren() = 1 transaction = ~2,949 gas per child = instant

---

## Architecture
                              ┌──────────┐
                              │   USER   │
                              └────┬─────┘
                                   │ setMasterAgent()
                                   ▼
                            ┌──────────────┐
                            │ MASTER AGENT │
                            └──────┬───────┘
                                   │ grantChildPermission()
                 ┌─────────────────┼─────────────────┐
                 │                 │                 │
                 ▼                 ▼                 ▼
           ┌─────────┐       ┌─────────┐       ┌─────────┐
           │ Child 1 │       │ Child 2 │       │ Child 3 │
           └────┬────┘       └────┬────┘       └────┬────┘
                │                 │                 │
                └────────────┬────┴────┬────────────┘
                             │         │
                             ▼         ▼
                    ┌────────────────────────┐
                    │    TARGET CONTRACTS    │
                    │  (via executeAsChild)  │
                    └────────────────────────┘

         ════════════════════════════════════════════
                        CASCADE REVOKE 
                     revokeAllChildren(master)
                              ═══
                    ALL CHILDREN REVOKED AT ONCE
         ════════════════════════════════════════════

---

## Smart Contracts
| Contract | Description |
|----------|-------------|
| **AgentRegistry.sol** | ERC-8004 agent registry |
| **PermissionManager.sol** | Permission grant/execute/revoke |
| **RevocationController.sol** | EIP-7702 batch operations |

---

##  Quick Start
```bash
cd contracts
forge install
forge build
forge test -vv

License
MIT

Cascade Revocation Network - Because trust can be revoked in an instant. 