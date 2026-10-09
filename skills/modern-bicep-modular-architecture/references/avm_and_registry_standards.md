# Azure Verified Modules (AVM) & Bicep Registry Standards

This reference guide establishes engineering standards for authoring Azure Verified Modules (AVM) and publishing/consuming modules via private and public Bicep registries.

---

## 1. Azure Verified Modules (AVM) Specification

The **Azure Verified Modules (AVM)** initiative is Microsoft's official standard for reusable Infrastructure-as-Code modules across Bicep and Terraform. Aligning with AVM ensures consistency, reliability, security, and effortless composition across enterprise cloud teams.

### Standard Module Interface Contract

Every AVM-compliant Bicep module MUST follow a strict parameter and output contract:

| Element | Type | Requirement | Description / Rule |
| :--- | :--- | :--- | :--- |
| `name` | `string` | **Mandatory** | The name of the primary resource being deployed. Never hardcode resource names inside modules. |
| `location` | `string` | **Optional** | Default to `resourceGroup().location`. Never hardcode static regions like `'eastus'`. |
| `tags` | `object` | **Optional** | Default to `{}`. Tags passed to the module must merge or apply to all taggable child resources. |
| `enableTelemetry` | `bool` | **Optional** | Default to `true`. Embeds a customer usage attribution GUID (PID) to track module usage. |
| `diagnosticSettings` | `DiagnosticSettingType[]` | **Optional** | Allows callers to pipe diagnostic logs and metrics to a Log Analytics Workspace. |
| `roleAssignments` | `RoleAssignmentType[]` | **Optional** | Allows callers to declare RBAC role assignments directly as part of module invocation. |
| `privateEndpoints` | `PrivateEndpointType[]` | **Optional** | Exposes standardized private endpoint configuration. |

### Standard Module Outputs

- **Resource Identity**: Always output the primary resource `id` (`output resourceId string = resInstance.id`) and name (`output name string = resInstance.name`).
- **Resource Object Reference**: Expose the symbolic reference where useful, but never expose sensitive keys or passwords.
- **Strict Prohibition on Secret Outputs**: Never emit storage keys, connection strings, admin passwords, or private certificates in outputs. Instead, consumers must access secrets via Azure Key Vault or use Managed Identity tokens.

---

## 2. Bicep Registry Architecture

Modules should never be copied and pasted across repositories. Instead, leverage versioned Bicep registries.

### Public Registry (`br/public:`)

Microsoft maintains a rich catalog of verified modules on the Microsoft Container Registry (MCR). Consume them via the `br/public:` alias:

```bicep
// Example: Consuming official Key Vault AVM from public registry
module modKeyVault 'br/public:avm/res/key-vault/vault:0.11.0' = {
  name: 'deploy-kv'
  params: {
    name: 'kv-prod-eastus-01'
    location: resourceGroup().location
    enableRbacAuthorization: true
    enablePurgeProtection: true
    tags: tags
  }
}
```

### Private Enterprise Registry (Azure Container Registry - ACR)

Enterprise platforms must maintain an internal Azure Container Registry to publish and govern internal modules.

#### 1. Configuring Registry Aliases (`bicepconfig.json`)

To avoid hardcoding full registry FQDNs across all Bicep files, define module aliases in `bicepconfig.json`:

```json
{
  "moduleAliases": {
    "br": {
      "enterprise": {
        "registry": "acrmodulesprod.azurecr.io",
        "modulePath": "bicep/modules"
      }
    }
  }
}
```

#### 2. Consuming Private Modules via Alias

```bicep
// Clean, short syntax using the configured alias
module modVnet 'br/enterprise:network/virtual-network:1.4.0' = {
  name: 'deploy-vnet'
  params: {
    name: 'vnet-core-prod'
    addressPrefix: '10.0.0.0/16'
  }
}
```

---

## 3. Publishing Modules to ACR

Use the Azure CLI to validate, build, and publish Bicep modules as OCI artifacts:

```bash
# 1. Lint and compile before publishing
az bicep build --file modules/network/vnet.bicep

# 2. Publish with immutable semantic version
az bicep publish \
  --file modules/network/vnet.bicep \
  --target "br:acrmodulesprod.azurecr.io/bicep/modules/network/virtual-network:1.4.0" \
  --documentationUri "https://github.com/my-org/bicep-modules/tree/main/modules/network"

# 3. Restore external modules locally for offline caching / verification
az bicep restore --file main.bicep
```

### Module Versioning Discipline

- Follow **Semantic Versioning 2.0.0** (`MAJOR.MINOR.PATCH`).
  - `PATCH`: Backward-compatible bug fixes or API version bumps without interface changes.
  - `MINOR`: New optional parameters, additional child resources, backward-compatible additions.
  - `MAJOR`: Breaking changes (removed/renamed parameters, changed default values, altered output names).
- **Absolute Ban on `:latest` in Production**: Never use mutable tags. Always pin exact versions to guarantee deterministic infrastructure builds.
