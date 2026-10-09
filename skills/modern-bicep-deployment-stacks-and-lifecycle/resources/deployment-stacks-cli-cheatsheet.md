# Azure Deployment Stacks CLI & PowerShell Cheatsheet

A concise operational cheatsheet for managing Azure Deployment Stacks across Resource Group, Subscription, and Management Group scopes.

---

## 1. Resource Group Scope Commands (`az stack group`)

```bash
# Validate with What-If
az stack group create \
  --name <stack-name> \
  --resource-group <rg-name> \
  --template-file main.bicep \
  --parameters main.bicepparam \
  --action-on-unmanage deleteResources \
  --deny-settings-mode denyWriteAndDelete \
  --what-if

# Create or Update Stack
az stack group create \
  --name <stack-name> \
  --resource-group <rg-name> \
  --template-file main.bicep \
  --parameters main.bicepparam \
  --action-on-unmanage deleteResources \
  --deny-settings-mode denyWriteAndDelete \
  --yes

# Show Stack Status and Managed Resources
az stack group show \
  --name <stack-name> \
  --resource-group <rg-name> \
  --query "{name:name, status:status, resources:resources[].id}" \
  --output json

# List Stacks in Resource Group
az stack group list --resource-group <rg-name> --output table

# Delete Stack and Its Managed Resources
az stack group delete \
  --name <stack-name> \
  --resource-group <rg-name> \
  --action-on-unmanage deleteResources \
  --yes
```

---

## 2. Subscription Scope Commands (`az stack sub`)

```bash
# Create Subscription-Level Stack
az stack sub create \
  --name <stack-name> \
  --location eastus \
  --template-file landing-zone.bicep \
  --parameters landing-zone.bicepparam \
  --action-on-unmanage deleteResources \
  --deny-settings-mode denyWrite \
  --yes

# List Subscription-Level Stacks
az stack sub list --output table
```

---

## 3. Management Group Scope Commands (`az stack mg`)

```bash
# Create Management Group-Level Stack
az stack mg create \
  --name <stack-name> \
  --management-group-id <mg-id> \
  --location eastus \
  --template-file governance.bicep \
  --deny-settings-mode denyWriteAndDelete \
  --yes
```

---

## 4. Azure PowerShell Equivalents

```powershell
# Create RG Stack in PowerShell
New-AzResourceGroupDeploymentStack `
  -Name "stack-billing-prod" `
  -ResourceGroupName "rg-billing-prod" `
  -TemplateFile "main.bicep" `
  -TemplateParameterFile "main.bicepparam" `
  -ActionOnUnmanage DeleteResources `
  -DenySettingsMode DenyWriteAndDelete

# Get Stack Details
Get-AzResourceGroupDeploymentStack -Name "stack-billing-prod" -ResourceGroupName "rg-billing-prod"
```
