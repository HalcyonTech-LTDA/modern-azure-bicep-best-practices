# Azure Deployment Stacks Architecture & Deny Settings

This reference guide explores the internal mechanics of Azure Deployment Stacks, comparing them with classic ARM deployments and detailing deny settings governance.

---

## 1. Why Azure Deployment Stacks?

Before Deployment Stacks, managing the full lifecycle of resources with ARM or Bicep had major gaps:

| Feature | Classic ARM / Bicep Deployments | Azure Deployment Stacks |
| :--- | :--- | :--- |
| **Lifecycle Entity** | No state tracking. Loose collection of resources. | Formal Azure resource representing the managed stack. |
| **Resource Removal** | Removing a resource from Bicep leaves it orphaned in Azure. | Automatically deletes or detaches resources removed from template. |
| **Drift & Tampering** | Anyone with Owner/Contributor can modify resources manually. | Enforces native **Deny Assignments** preventing out-of-band drift. |
| **Scoping** | Resource Group, Subscription, Management Group. | Resource Group, Subscription, Management Group. |
| **Blueprint Replacement**| N/A | Fully replaces deprecated Azure Blueprints. |

---

## 2. Deny Settings & Deny Assignments

Deployment Stacks leverage Azure RBAC **Deny Assignments** (`Microsoft.Authorization/denyAssignments`) to protect managed resources. Deny assignments take precedence over regular role assignments (even `Owner` roles).

### Modes of Protection (`denySettingsMode`)

- **`denyWriteAndDelete`**:
  - The strictest mode. Completely prevents creating, updating, or deleting any resource managed by the stack outside the stack itself.
  - Recommended for all production environments.
- **`denyWrite`**:
  - Prevents modifying managed resources, but permits deleting them.
  - Useful in non-production environments where cost containment may require deleting resources outside CI/CD.
- **`none`**:
  - Stack tracks managed resources and handles `actionOnUnmanage`, but does NOT apply deny assignments.
  - Useful during progressive migration to Deployment Stacks.

### Break-Glass & Exclusions

To avoid locking out automated monitoring systems, emergency disaster recovery operators, or platform administrators, configure exclusions:

1. **`denySettingsExcludedPrincipals`**:
   List of Entra ID Object IDs (users, groups, service principals) exempt from the deny assignment.
2. **`denySettingsExcludedActions`**:
   List of RBAC actions permitted even under deny settings. For example:
   - `'Microsoft.Compute/virtualMachines/restart/action'`
   - `'Microsoft.Web/sites/restart/action'`
   - `'Microsoft.App/containerApps/start/action'`

---

## 3. Scopes & Supported Stack Commands

Deployment Stacks can be applied at any level of the Azure resource hierarchy:

```bash
# Resource Group Scope
az stack group create --name <stack-name> --resource-group <rg> ...

# Subscription Scope
az stack sub create --name <stack-name> --location <region> ...

# Management Group Scope
az stack mg create --name <stack-name> --management-group-id <mg-id> --location <region> ...
```
