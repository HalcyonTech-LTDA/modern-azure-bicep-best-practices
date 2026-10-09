# Bicep Dependency Graph, DAG & Idempotency

This reference guide explains how the Bicep compilation engine calculates dependency graphs, optimizes concurrent resource execution, and maintains strict deployment idempotency.

---

## 1. How Bicep Builds the Dependency Graph (DAG)

Unlike imperative scripts (Bash, PowerShell, Python), Bicep is purely **declarative**. The ARM deployment engine analyzes all resources in a template and constructs a Directed Acyclic Graph (DAG) of dependencies.

### Implicit Dependencies via Symbolic References

When a resource references another resource's properties, Bicep automatically registers an implicit dependency:

```bicep
resource resSubnet 'Microsoft.Network/virtualNetworks/subnets@2025-01-01' = { ... }

resource resNic 'Microsoft.Network/networkInterfaces@2025-01-01' = {
  // Implicit dependency: resNic depends on resSubnet automatically!
  properties: {
    ipConfigurations: [
      {
        properties: {
          subnet: {
            id: resSubnet.id
          }
        }
      }
    ]
  }
}
```

---

## 2. The Anti-Pattern: Redundant Explicit `dependsOn`

### Why Unnecessary `dependsOn` Hurts
- **Serializes Execution**: When resources do not depend on each other, ARM deploys them in parallel (up to 800 resources concurrently). Unnecessary `dependsOn` forces sequential execution, increasing deployment time from 2 minutes to 20 minutes.
- **Obscures Real Relationships**: Explicit `dependsOn` creates clutter and obscures real architecture boundaries.

### When Explicit `dependsOn` IS Required
Explicit `dependsOn` is required **only** in rare scenarios where an asynchronous control-plane dependency exists with no property reference:
1. **Azure Policy & RBAC Propagation**: Waiting for a policy assignment or role assignment to take effect before creating resources governed by it.
2. **Diagnostic Extension Agents**: Waiting for a VM extension or OMS agent to initialize before kicking off a custom script extension.
3. **App Service Configuration Ordering**: Setting connection strings or app settings only after a secondary backend database is completely initialized.

---

## 3. Idempotency Invariants

Every Bicep template must be strictly **idempotent**: running the template 10 times consecutively against the same Azure environment must produce the exact same end state without error, data corruption, or duplicate resource creation.

### Invariant Rules:
1. Never generate non-deterministic names inside templates (avoid `newGuid()`, `utcNow()` for resource naming).
2. Use predictable deterministic seeds for names and role assignments (`guid(...)`).
3. Ensure child resource names match standard deterministic patterns.
