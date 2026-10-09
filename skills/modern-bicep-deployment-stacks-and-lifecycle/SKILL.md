---
name: modern-bicep-deployment-stacks-and-lifecycle
description: >-
  Use this skill when managing cloud infrastructure lifecycles and governance with Azure Deployment Stacks:
  atomic stack lifecycle management, drift & tampering prevention with Deny Settings (denyWriteAndDelete, denyWrite),
  orphaned resource elimination with Action on Unmanage (delete vs detach), What-If pre-flight validation,
  multi-scope orchestration (Management Group, Subscription, Resource Group), and dependency graph optimization.
---

# Modern Azure Bicep Deployment Stacks & Lifecycle Governance

This skill provides comprehensive architectural guidelines, operational patterns, and CLI recipes for orchestrating infrastructure using **Azure Deployment Stacks**, preventing configuration drift, and automating resource lifecycle management.

---

## Core Principles

1. **Deployment Stacks over Loose ARM Deployments**:
   - Traditional ARM/Bicep deployments (`az deployment group create`) are fire-and-forget operations: ARM does not track the lifecycle of the collection of resources as an atomic entity. When a resource is removed from a template, loose deployments leave behind an orphaned resource running in the cloud.
   - **Azure Deployment Stacks** treat resources defined in a Bicep template as an atomically managed unit with lifecycle governance across subscriptions, resource groups, or management groups.

2. **Drift & Tampering Protection with Deny Settings**:
   - Deployment Stacks enforce native Azure RBAC **Deny Assignments** through `denySettingsMode`:
     - `'denyWriteAndDelete'`: Blocks all users (including Owners) from modifying or deleting resources managed by the stack outside the stack deployment pipeline.
     - `'denyWrite'`: Blocks modifications, but allows deletions outside the stack.
     - `'none'`: Tracks resource lifecycle without locking modifications.
   - For production environments, mandate `denySettingsMode: 'denyWriteAndDelete'`.
   - Configure `denySettingsExcludedPrincipals` for break-glass emergency administrator identities and `denySettingsExcludedActions` for harmless operations (e.g., restarting a VM or Container App).

3. **Eliminating Orphaned Resources with `actionOnUnmanage`**:
   - When resources are removed from the Bicep template, Deployment Stacks automatically clean them up based on the `actionOnUnmanage` configuration:
     - `resources: 'delete'`: Deletes resources removed from the stack template.
     - `resources: 'detach'`: Keeps resources in Azure but unmanages them from the stack.
     - `resourceGroups: 'delete'`: Deletes child resource groups when removed from subscription-level stacks.
   - Always configure `actionOnUnmanage: { resources: 'delete' }` in production CI/CD pipelines to guarantee zero orphaned resources and zero cost leaks.

4. **Mandatory Pre-Flight What-If Verification**:
   - Always run What-If change analysis (`az stack group create ... --what-if` or `az deployment group what-if`) before applying any stack update.
   - Verify predicted creations, modifications, and deletions to prevent catastrophic unintended drops of stateful data stores.

5. **Multi-Scope Hierarchy & Landing Zones**:
   - Orchestrate infrastructure hierarchically:
     - **Management Group Scope**: Deploy platform policies and subscription vending stacks.
     - **Subscription Scope**: Deploy core resource groups, role assignments, and shared landing zone networking stacks.
     - **Resource Group Scope**: Deploy workload applications and microservice stacks.

6. **Implicit Dependency Graph Optimization**:
   - The Bicep compiler automatically builds an internal Directed Acyclic Graph (DAG) using symbolic resource references (e.g. `subnetId: resSubnet.id`).
   - Absolute ban on unnecessary explicit `dependsOn` declarations when a symbolic property reference is already present. Explicit `dependsOn` serializes deployments unnecessarily and creates brittle code.
   - Use explicit `dependsOn` strictly when resources have asynchronous control-plane dependencies that cannot be inferred via resource properties (such as Azure Policy assignments and role propagation delays).

---

## Detailed Topic Guides

1. **Azure Deployment Stacks Architecture**:
   - Differences between classic ARM deployments, Azure Blueprints, and Deployment Stacks.
   - Deny assignments mechanics, excluded principals, and break-glass workflows.
   - [Read Guide](./references/deployment_stacks_architecture.md)

2. **Action on Unmanage & Lifecycle Cleanup**:
   - Cleaning up deleted resources (`delete` vs `detach`).
   - Subscription-level resource group lifecycle governance.
   - Safeguarding stateful resources from accidental cascading deletion.
   - [Read Guide](./references/action_on_unmanage_and_cleanup.md)

3. **What-If Analysis & Change Validation**:
   - Interpreting What-If operations (`Create`, `Delete`, `Deploy`, `Ignore`, `Modify`, `NoChange`).
   - Noise filtering and CI/CD validation gates.
   - [Read Guide](./references/what_if_analysis_and_change_validation.md)

4. **Bicep Dependency Graph & Idempotency**:
   - DAG calculation, parallel execution, and implicit reference optimization.
   - When to use explicit `dependsOn` and when to avoid it.
   - [Read Guide](./references/dependency_graph_and_idempotency.md)

---

## Blueprint Example: Creating a Production Deployment Stack

### Managing Stacks via Azure CLI

```bash
#!/usr/bin/env bash
set -euo pipefail

STACK_NAME="stack-billing-prod"
RESOURCE_GROUP="rg-billing-prod"
TEMPLATE_FILE="main.bicep"
PARAMETERS_FILE="main.bicepparam"

# 1. Pre-flight What-If verification
echo "==> Running pre-flight What-If analysis..."
az stack group create \
  --name "${STACK_NAME}" \
  --resource-group "${RESOURCE_GROUP}" \
  --template-file "${TEMPLATE_FILE}" \
  --parameters "${PARAMETERS_FILE}" \
  --deny-settings-mode "denyWriteAndDelete" \
  --action-on-unmanage "deleteResources" \
  --what-if

# 2. Deploy and Lock Infrastructure Stack
echo "==> Applying Deployment Stack with Deny Assignments..."
az stack group create \
  --name "${STACK_NAME}" \
  --resource-group "${RESOURCE_GROUP}" \
  --template-file "${TEMPLATE_FILE}" \
  --parameters "${PARAMETERS_FILE}" \
  --deny-settings-mode "denyWriteAndDelete" \
  --action-on-unmanage "deleteResources" \
  --yes

# 3. Inspect Managed Resources in Stack
echo "==> Listing managed resources in stack..."
az stack group show \
  --name "${STACK_NAME}" \
  --resource-group "${RESOURCE_GROUP}" \
  --query "resources[].{id:id, status:status}" \
  --output table
```
