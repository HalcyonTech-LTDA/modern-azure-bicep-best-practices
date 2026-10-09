# Modern Parameter Configuration with `.bicepparam`

This guide covers modern configuration management using native `.bicepparam` files, environment decoupling, secret management, and migration from legacy ARM JSON parameter files.

---

## 1. The `.bicepparam` Standard

Historically, ARM templates relied on JSON files (`parameters.json`) with verbose, boilerplate structures:

```json
// DEPRECATED LEGACY FORMAT
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "environment": { "value": "prod" }
  }
}
```

Bicep introduced native `.bicepparam` parameter files, which offer:
- 70% less syntax boilerplate.
- Direct compile-time binding to the target Bicep template via the `using` statement.
- First-class expressions and functions (`toLower()`, `replace()`, etc.).
- Reading local environment variables with `readEnvironmentVariable()`.
- Direct Key Vault secret resolution syntax.

---

## 2. Anatomy of a `.bicepparam` File

```bicep
// 1. Mandatory declaration linking this parameter file to its target template
using 'main.bicep'

// 2. Direct parameter assignments
param environment = 'prod'
param workloadName = 'ecommerce'
param instanceCount = 3

// 3. Expressions and functions in parameters
param deploymentTimestamp = utcNow('yyyyMMdd-HHmmss')

// 4. Reading CI/CD environment variables
param buildNumber = readEnvironmentVariable('BUILD_BUILDNUMBER', 'local-dev')

// 5. Complex typed objects
param subnets = [
  {
    name: 'snet-app'
    addressPrefix: '10.0.1.0/24'
  }
  {
    name: 'snet-db'
    addressPrefix: '10.0.2.0/24'
  }
]
```

---

## 3. Environment Decoupling Strategy

Organize parameter files by deployment tier rather than duplicating Bicep code:

```text
infra/
├── main.bicep
├── env/
│   ├── dev.bicepparam
│   ├── staging.bicepparam
│   └── prod.bicepparam
└── modules/
```

### Execution Example

```bash
# Deploy to Dev
az deployment group create \
  --resource-group rg-billing-dev \
  --template-file main.bicep \
  --parameters env/dev.bicepparam

# Deploy to Prod
az deployment group create \
  --resource-group rg-billing-prod \
  --template-file main.bicep \
  --parameters env/prod.bicepparam
```

---

## 4. Secure Secrets with Key Vault Integration

Never store secrets in `.bicepparam`. Instead, reference existing secrets from an Azure Key Vault directly at deployment time:

```bicep
using 'main.bicep'

param environment = 'prod'

// Retrieve secret securely from Key Vault during deployment execution
param dbAdminPassword = getSecret(
  'sub-prod-id',
  'rg-security-prod',
  'kv-prod-shared',
  'DbAdminPassword'
)
```

Requirements for `getSecret()`:
- The user or Service Principal / Managed Identity running the deployment must possess the **Key Vault Secrets User** role on the target Key Vault.
- The secret parameter in `main.bicep` must be marked with `@secure()`.
