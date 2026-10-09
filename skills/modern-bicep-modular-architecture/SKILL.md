---
name: modern-bicep-modular-architecture
description: >-
  Use this skill when designing, authoring, or refactoring modular Azure Bicep codebases:
  Azure Verified Modules (AVM) compliance, User-Defined Types (UDT with type keyword), User-Defined Functions (func keyword),
  native .bicepparam parameter files, private/public Bicep Registries (ACR/MCR), multi-scope deployments
  (Tenant, Management Group, Subscription, Resource Group), child/extension resources, and deterministic loops.
---

# Modern Azure Bicep Modular Architecture

This skill provides comprehensive architectural guidelines, clean coding standards, and structural best practices for authoring modular, maintainable, and type-safe Azure Bicep infrastructure as code.

---

## Core Principles

1. **Modular Composition & Azure Verified Modules (AVM)**:
   - Deconstruct complex infrastructure into focused, single-responsibility modules.
   - Align module interfaces with the **Azure Verified Modules (AVM)** standard:
     - Standard input parameters: `name`, `location` (defaulting to `resourceGroup().location`), `tags`, `enableTelemetry`.
     - Standard outputs: expose resource `id`, resource `name`, and symbolic object references.
     - Never emit secrets, passwords, or connection strings in module outputs.
   - Isolate environment-agnostic resource definitions in reusable modules, while root orchestrators (`main.bicep`) wire modules together.

2. **Strict Compile-Time Typing with User-Defined Types (UDT)**:
   - Prohibit untyped `object` or `array` parameters for complex contracts. Untyped objects degrade IntelliSense, permit silent typos, and defer validation failures to runtime.
   - Use the `type` keyword to declare strongly typed schemas, tagged unions, and nullable types:
     ```bicep
     @description('Network subnet configuration specification.')
     type SubnetConfig = {
       name: string
       addressPrefix: string
       privateEndpointNetworkPolicies: ('Enabled' | 'Disabled')?
       serviceEndpoints: string[]?
     }
     ```
   - Use `@sealed()` on object types where unexpected properties must trigger a compiler error.

3. **User-Defined Functions (`func`) for Deterministic Logic**:
   - Encapsulate reusable string transformations, naming convention enforcement, and CIDR math into native User-Defined Functions (`func`):
     ```bicep
     func buildResourceName(prefix string, app string, env string, resourceType string) string =>
       toLower('${prefix}-${app}-${env}-${resourceType}')
     ```
   - Keep user-defined functions pure, deterministic, and free of side effects.

4. **Mandatory `.bicepparam` Parameter Files**:
   - Completely deprecate legacy ARM JSON parameter files (`*.parameters.json`).
   - Use native `.bicepparam` files linked to their target Bicep file via `using 'main.bicep'`.
   - Take advantage of native Bicep expressions, environment variable injection via `readEnvironmentVariable('ENV_NAME', 'defaultValue')`, and secret resolution from Azure Key Vault.

5. **Bicep Registry Distribution (Public MCR & Private ACR)**:
   - In enterprise ecosystems, centralize shared modules in Azure Container Registry (ACR) repositories:
     `br:<registry>.azurecr.io/bicep/modules/<module-name>:<semantic-version>`
   - Alternatively, consume verified community modules directly from Microsoft's public registry:
     `br/public:avm/res/network/virtual-network:0.5.1`
   - Always pin specific, immutable semantic versions. Never consume floating `:latest` tags.

6. **Scope-Aware Orchestration**:
   - Explicitly declare `targetScope` at the top of templates (`'resourceGroup'`, `'subscription'`, `'managementGroup'`, or `'tenant'`).
   - Use subscription-level or management-group-level orchestrators to create resource groups and policy assignments, delegating child resource provisioning to modules scoped to the target resource group via `scope: resourceGroup(rgName)`.

7. **Symbolic Resource Names & Child/Extension Syntax**:
   - Always use clean symbolic names (e.g., `resVnet`, `resKeyVault`, `resApp`).
   - Model parent-child relationships using the nested child resource syntax or the `parent` property rather than string concatenation in resource names.
   - Model RBAC, Diagnostic Settings, and Locks as extension resources referencing their target via `scope: targetResource`.

8. **Deterministic Resource Loops & Concurrency Control**:
   - Use array comprehension `[for item in items: { ... }]` for resource loops.
   - When deploying resources with rate-limiting constraints or sequential dependencies, apply the `@batchSize(n)` decorator (e.g., `@batchSize(1)` for sequential execution).

---

## Detailed Topic Guides

1. **Azure Verified Modules (AVM) & Bicep Registry Standards**:
   - Interface contracts, required parameters, telemetry standards.
   - Private ACR publishing with `az bicep publish` and alias configuration in `bicepconfig.json`.
   - Versioning strategy and module immutability.
   - [Read Guide](./references/avm_and_registry_standards.md)

2. **User-Defined Types & Functions in Bicep**:
   - Defining custom types, union types, sealed objects, and array constraints.
   - Decorators: `@description()`, `@allowed()`, `@minLength()`, `@maxLength()`, `@minValue()`, `@maxValue()`.
   - Creating pure User-Defined Functions (`func`).
   - [Read Guide](./references/user_defined_types_and_functions.md)

3. **Modern Parameters with `.bicepparam`**:
   - The `.bicepparam` specification and structure.
   - Environment separation (`dev.bicepparam`, `prod.bicepparam`).
   - Environment variable reading and runtime Key Vault references.
   - [Read Guide](./references/bicepparam_and_configuration.md)

---

## Blueprint Example: Modular Multi-Tier Infrastructure

### 1. User-Defined Type Contract & User-Defined Function (`main.bicep`)

```bicep
metadata name = 'Modern Multi-Tier Cloud Application'
metadata description = 'Deploys hardened network, identity, and containerized compute using modular Bicep.'

targetScope = 'resourceGroup'

// User-Defined Types
@description('Environment classification tier.')
type EnvironmentTier = 'dev' | 'staging' | 'prod'

@description('Subnet configuration contract.')
type SubnetDefinition = {
  name: string
  addressPrefix: string
}

@description('Resource tagging taxonomy.')
type ResourceTags = {
  Environment: string
  Workload: string
  ManagedBy: string
  *: string
}

// User-Defined Function for deterministic naming
func formatName(prefix string, workload string, env string, service string) string =>
  toLower('${prefix}-${workload}-${env}-${service}')

// Parameters
@description('Primary Azure deployment region.')
param location string = resourceGroup().location

@description('Deployment environment tier.')
param environment EnvironmentTier

@description('Organization prefix for resource naming.')
@minLength(2)
@maxLength(6)
param orgPrefix string

@description('Application workload name.')
param workloadName string

@description('Subnets to provision in the virtual network.')
param subnets SubnetDefinition[]

@description('Resource tagging taxonomy.')
param tags ResourceTags = {
  Environment: environment
  Workload: workloadName
  ManagedBy: 'Bicep'
}

// Variables
var vnetName = formatName(orgPrefix, workloadName, environment, 'vnet')
var identityName = formatName(orgPrefix, workloadName, environment, 'id')
var appEnvName = formatName(orgPrefix, workloadName, environment, 'cae')
var appName = formatName(orgPrefix, workloadName, environment, 'app')

// 1. User-Assigned Managed Identity
resource resIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30' = {
  name: identityName
  location: location
  tags: tags
}

// 2. Network Module
module modNetwork 'modules/network/vnet.bicep' = {
  name: 'deploy-network-${environment}'
  params: {
    location: location
    vnetName: vnetName
    addressPrefix: '10.0.0.0/16'
    subnets: subnets
    tags: tags
  }
}

// 3. Compute Module (Container App)
module modCompute 'modules/compute/container_app.bicep' = {
  name: 'deploy-compute-${environment}'
  params: {
    location: location
    environmentName: appEnvName
    appName: appName
    subnetId: modNetwork.outputs.subnetIds[0]
    userAssignedIdentityId: resIdentity.id
    tags: tags
  }
}

// Outputs
@description('Resource ID of the provisioned Virtual Network.')
output vnetId string = modNetwork.outputs.vnetId

@description('Principal ID of the User-Assigned Managed Identity.')
output identityPrincipalId string = resIdentity.properties.principalId

@description('Fully Qualified Domain Name of the deployed application.')
output appFqdn string = modCompute.outputs.appFqdn
```

### 2. Parameters File (`main.bicepparam`)

```bicep
using 'main.bicep'

param environment = 'prod'
param orgPrefix = 'hlc'
param workloadName = 'billing'

param subnets = [
  {
    name: 'snet-infra'
    addressPrefix: '10.0.1.0/24'
  }
  {
    name: 'snet-compute'
    addressPrefix: '10.0.2.0/24'
  }
]
```
