# Secrets Hygiene & Managed Identity Best Practices in Bicep

This reference guide establishes strict engineering standards for eliminating secrets from Infrastructure-as-Code and enforcing modern Azure Managed Identity authentication.

---

## 1. Zero Secrets Discipline

### The Problem with Secrets in IaC
Hardcoding secrets, passwords, or connection strings in Bicep files or `.bicepparam` files creates major vulnerabilities:
- Secrets are leaked into source control history.
- Secrets are exposed in deployment history (`az deployment group show`) and Azure Portal deployment blades.
- Rotation is complex and error-prone.

### Guardrail Requirements

1. **Mandatory `@secure()` Decorator**:
   Any parameter accepting a sensitive value (password, client secret, SSL certificate private key) MUST be decorated with `@secure()`:
   ```bicep
   @description('Administrator password for the SQL Server.')
   @secure()
   param administratorLoginPassword string
   ```
   The `@secure()` decorator prevents the value from being logged in deployment outputs or execution logs.

2. **Absolute Ban on Secret Outputs**:
   Never define an `output` block returning a secure parameter or connection string:
   ```bicep
   // CRITICAL SECURITY VIOLATION:
   output dbSecret string = administratorLoginPassword // PROHIBITED
   ```

3. **Key Vault Reference Syntax in `.bicepparam`**:
   When a secret is required by a legacy service that cannot use Managed Identity, inject it directly from an existing Azure Key Vault at deployment time:
   ```bicep
   using 'main.bicep'

   param sqlAdminPassword = getSecret(
     'sub-id',
     'rg-security-prod',
     'kv-prod-core',
     'SqlAdminPassword'
   )
   ```

---

## 2. Managed Identity Architecture

Modern cloud applications should never use credentials or connection strings. Azure Managed Identities allow resources to obtain Entra ID access tokens automatically without managing secrets.

### System-Assigned vs. User-Assigned Managed Identity

| Feature | System-Assigned Identity | User-Assigned Identity |
| :--- | :--- | :--- |
| **Lifecycle** | Tied 1:1 to resource lifecycle. Deleted when resource is deleted. | Independent lifecycle. Created and managed as a standalone Azure resource. |
| **Sharing** | Cannot be shared across multiple resources. | Can be shared across multiple resources (e.g., frontend + worker apps). |
| **Bicep Dependency Order** | Identity exists only *after* resource is created; RBAC cannot be assigned before creation. | Identity can be created first, RBAC granted, and then attached to the workload. |
| **Enterprise Standard** | Simple single-resource workloads. | **Recommended standard** for production multi-tier microservices and zero-trust architectures. |

### Provisioning a User-Assigned Managed Identity

```bicep
resource resIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30' = {
  name: 'id-billing-worker-prod-01'
  location: resourceGroup().location
  tags: tags
}

output identityId string = resIdentity.id
output principalId string = resIdentity.properties.principalId
output clientId string = resIdentity.properties.clientId
```

### Attaching to Compute Resources

```bicep
resource resContainerApp 'Microsoft.App/containerApps@2025-01-01' = {
  name: 'ca-billing-worker'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${resIdentity.id}': {}
    }
  }
  // Application code inside the container uses DefaultAzureCredential(managedIdentityClientId: resIdentity.properties.clientId)
}
```

### Eliminating Connection Strings in Application Code

Instead of passing connection strings like `DefaultEndpointsProtocol=https;AccountName=...;AccountKey=...`:
1. Grant the User-Assigned Identity **Storage Blob Data Contributor** RBAC role.
2. Pass only the Storage Account endpoint URL (e.g. `https://stbillingprod.blob.core.windows.net`) to the application configuration.
3. The application SDK automatically negotiates an OAuth token with Entra ID.
