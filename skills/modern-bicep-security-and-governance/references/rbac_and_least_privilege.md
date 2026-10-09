# Granular RBAC & Least-Privilege Architecture in Bicep

This guide details best practices for authoring declarative Role-Based Access Control (RBAC) role assignments in Bicep, ensuring idempotent deployment and least-privilege scoping.

---

## 1. Declarative Role Assignments

In Azure Resource Manager, RBAC is implemented through the `Microsoft.Authorization/roleAssignments` resource type.

### The Role Assignment Formula

Every role assignment resource requires:
1. **A Globally Unique Resource Name (`name`)**: Must be a valid UUID/GUID.
2. **Scope**: The resource, resource group, subscription, or management group where the role applies.
3. **Role Definition ID**: The fully qualified resource ID of the role definition.
4. **Principal ID**: The object ID of the user, group, or managed identity receiving the grant.
5. **Principal Type**: Explicitly declared as `'ServicePrincipal'`, `'User'`, or `'Group'`.

---

## 2. Deterministic GUID Generation with `guid()`

### The Collision & Flakiness Anti-Pattern
Never use random GUIDs or hardcoded static GUIDs across multiple environments. Random GUIDs cause duplicate assignment attempts or deployment state churn.

### The Best Practice Formula
Generate the role assignment name deterministically using the Bicep `guid()` function seeded with three inputs:
1. Target resource scope ID.
2. Principal ID.
3. Role Definition ID.

```bicep
resource resStorageRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  // Deterministic GUID guarantees idempotency across repeated deployments
  name: guid(resStorageAccount.id, managedIdentityPrincipalId, storageBlobDataContributorRoleId)
  scope: resStorageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataContributorRoleId)
    principalId: managedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}
```

> **Critical Compiler Insight: Avoiding BCP120 on Role Assignment Names**
> Resource names in Bicep must be calculable at the start of deployment before execution begins.
> - If `managedIdentityPrincipalId` is passed in as a **parameter**, using it inside `guid()` is valid because parameters are known ahead of execution.
> - If the identity is declared as a resource in the **same template**, referencing `resIdentity.properties.principalId` inside `name: guid(...)` will fail with **Error BCP120** because runtime properties are only resolved after resource creation. In that scenario, seed `guid()` with `resIdentity.id` instead (which is calculable at deployment start):
>   `name: guid(resStorageAccount.id, resIdentity.id, storageBlobDataContributorRoleId)`


---

## 3. Scoping Principle: Least Privilege

### Scope Hierarchy

```text
Management Group  (Broadest - Governance & Policy only)
    └── Subscription (Subscription-level operations)
            └── Resource Group (Resource group shared services)
                    └── Resource (Preferred: Single Service Scope)
```

### Granular Resource-Level Scoping
Always scope role assignments to the specific target resource:
- Granting access to a single Key Vault: `scope: resKeyVault`
- Granting access to a single Storage Account: `scope: resStorageAccount`
- Granting access to a single Cosmos DB account: `scope: resCosmosAccount`

Avoid subscription-wide grants like `Contributor` or `Owner` for application workloads.

---

## 4. Built-In Role Definition IDs

Always leverage standard Azure built-in roles rather than creating redundant custom roles:

```bicep
var roles = {
  keyVaultSecretsUser: '4633458b-17de-408a-b874-0445c86b69e6'
  keyVaultCryptoUser: '12338081-198d-4476-aa5f-447c423ea692'
  storageBlobDataContributor: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
  storageBlobDataReader: '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'
  acrPull: '7f951dda-4ed3-4680-a7ca-43fe172d538d'
  serviceBusDataSender: '69a216fc-b8fb-44d8-bc22-1f3c2cd27a39'
  serviceBusDataReceiver: '4f6d3b9b-027b-4f4c-9142-0e5a2a2247e0'
}
```
