# Action on Unmanage & Lifecycle Cleanup

This guide details how Deployment Stacks handle resource lifecycle when resources are updated, removed from templates, or when the entire stack is deleted.

---

## 1. What Happens When a Resource is Removed?

In classic Bicep deployments, if you delete a resource definition from `main.bicep` and redeploy, Azure ARM ignores the removed resource and it stays active in the cloud indefinitely.

With Azure Deployment Stacks, any resource omitted from the new template version transitions to the **unmanaged** state.

---

## 2. The `actionOnUnmanage` Setting Matrix

The `--action-on-unmanage` CLI flag specifies how unmanaged resources and unmanaged resource groups are treated:

| Action on Unmanage Flag | Unmanaged Resources Behavior | Unmanaged Resource Groups Behavior | Recommended Use Case |
| :--- | :--- | :--- | :--- |
| **`deleteResources`** | **Deleted** permanently | Kept in Azure | Workload / Resource Group scope production stacks. |
| **`deleteResourceGroups`** | **Deleted** permanently | **Deleted** permanently | Subscription-scope ephemeral or test environment stacks. |
| **`detachAll`** | Retained in Azure (unmanaged) | Retained in Azure | Safe exploratory adoption; migrating existing infrastructure into stacks. |

### CLI Usage Example

```bash
# Deletes individual resources when removed from the template
az stack group create \
  --name stack-billing-api \
  --resource-group rg-billing-prod \
  --template-file main.bicep \
  --parameters main.bicepparam \
  --action-on-unmanage "deleteResources" \
  --deny-settings-mode "denyWriteAndDelete"
```

---

## 3. Safeguarding Stateful Resources

When using `actionOnUnmanage: deleteResources`, take strict precautions to prevent accidental drops of business-critical state:

1. **Apply Management Locks**:
   Add a `CanNotDelete` lock on Storage Accounts, Cosmos DB, and Azure SQL instances. Deployment Stacks will respect management locks and fail loudly if an unmanage operation attempts to delete locked resources.
2. **Review What-If Diffs**:
   Never apply a stack update without inspecting the What-If diff for unexpected resource deletions (`Delete` operation).
3. **Soft-Delete on PaaS Services**:
   Enable Azure Soft-Delete on Storage Blobs and Key Vaults so accidental deletions can be restored within retention windows.
