---
name: modern-bicep-security-and-governance
description: >-
  Use this skill when implementing security, identity, access control, and compliance in Azure Bicep:
  zero plain-text secrets, @secure() decorator discipline, Azure Key Vault integration,
  Managed Identities (User-Assigned & System-Assigned), granular RBAC with deterministic guid() role assignments,
  network isolation (Private Endpoints, Private DNS Zones, disabling public network access),
  Customer-Managed Keys (CMK), and Azure Policy as Code.
---

# Modern Azure Bicep Security, Identity & Governance

This skill provides comprehensive architectural guidelines, security controls, and governance patterns for designing zero-trust, compliant Azure infrastructure with Bicep.

---

## Core Principles

1. **Zero Secrets in Source Code & State**:
   - Absolute ban on storing passwords, API keys, client secrets, connection strings, or storage keys in Bicep files or `.bicepparam` files.
   - All secret parameters MUST be decorated with `@secure()`.
   - Never output `@secure()` parameters or runtime secrets in Bicep `output` declarations.
   - Downstream consumers must resolve credentials at runtime via Azure Key Vault or, preferably, eliminate credentials entirely through Azure AD / Entra ID token authentication.

2. **Azure RBAC Authorization over Legacy Access Policies & Shared Keys**:
   - For Azure Key Vault, always set `enableRbacAuthorization: true`. Deprecate legacy Key Vault vault access policies (`accessPolicies`), which do not support granular least-privilege scoping or PIM.
   - For Azure Storage Accounts, disable local shared access keys by setting `allowSharedKeyAccess: false` and mandate Azure AD role-based access control.

3. **Managed Identities over Service Principal Secrets**:
   - Workloads running in Azure (Container Apps, App Services, Functions, VMs, AKS) must authenticate using **Azure Managed Identities**.
   - Prefer **User-Assigned Managed Identities** for workloads where identity lifecycle spans multiple resources or where identity pre-creation is necessary to assign RBAC roles prior to resource instantiation.
   - Eliminate connection strings in code by leveraging SDK identity mechanisms (such as `DefaultAzureCredential`).

4. **Granular RBAC with Deterministic, Idempotent GUIDs**:
   - Declarative role assignments (`Microsoft.Authorization/roleAssignments`) require a unique GUID for their name.
   - Always generate role assignment names deterministically using the `guid()` function seeded by the target scope, principal ID, and role definition ID:
     ```bicep
     resource resRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
       name: guid(resTarget.id, principalId, roleDefinitionId)
       scope: resTarget
       properties: {
         roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionId)
         principalId: principalId
         principalType: 'ServicePrincipal'
       }
     }
     ```
   - Always scope role assignments to specific resources or resource groups, avoiding wide subscription-level grants.

5. **Network Isolation by Default (Private Endpoints & No Public Access)**:
   - Modern enterprise PaaS resources (Key Vault, Storage Accounts, Azure SQL, Cosmos DB, ACR) must explicitly disable public internet ingress:
     `publicNetworkAccess: 'Disabled'`
   - Private connectivity MUST be established using Azure Private Endpoints (`Microsoft.Network/privateEndpoints`) linked to dedicated Private DNS Zones (`privatelink.*`).

6. **Infrastructure Encryption & Minimum TLS**:
   - Enforce minimum TLS version 1.2 across all PaaS services (e.g. `minimumTlsVersion: '1.2'`).
   - Enable infrastructure encryption / double encryption on Storage Accounts.
   - Configure Customer-Managed Keys (CMK) when regulatory compliance demands tenant-governed key lifecycles.

7. **Azure Policy as Code**:
   - Enforce regulatory standards and guardrails by deploying Azure Policy definitions (`Microsoft.Authorization/policyDefinitions`) and assignments (`Microsoft.Authorization/policyAssignments`) at subscription or management group scopes using Bicep.

---

## Detailed Topic Guides

1. **Secrets Hygiene & Managed Identity Best Practices**:
   - `@secure()` decorator rules, Key Vault runtime reference syntax, preventing secret leakages in outputs.
   - Managed identity patterns (System-Assigned vs User-Assigned).
   - Eliminating connection strings with `DefaultAzureCredential`.
   - [Read Guide](./references/secrets_and_identity_hygiene.md)

2. **Granular RBAC & Least-Privilege Architecture**:
   - Declarative `roleAssignments` with deterministic `guid()` seeds.
   - Standard built-in Azure role definitions vs custom roles.
   - Scoping assignments to specific resources or resource groups.
   - [Read Guide](./references/rbac_and_least_privilege.md)

3. **Network Isolation, Private Endpoints & Private DNS**:
   - Disabling public network access on PaaS services.
   - Designing Private Endpoints and Private DNS Zone groups.
   - Subnet requirements (`privateEndpointNetworkPolicies: 'Disabled'`).
   - [Read Guide](./references/network_isolation_and_private_endpoints.md)

4. **Customer-Managed Keys (CMK) & Encryption**:
   - Key Vault key provisioning and rotation.
   - Storage Account and SQL CMK integration.
   - [Read Guide](./references/customer_managed_keys_and_encryption.md)

---

## Blueprint Example: Hardened Key Vault with RBAC & Private Endpoint

```bicep
metadata name = 'Hardened Key Vault with Private Endpoint'
metadata description = 'Deploys an Azure Key Vault with Azure RBAC authorization, disabled public access, and a Private Endpoint.'

@description('Azure region for deployment.')
param location string = resourceGroup().location

@description('Name of the Key Vault.')
param keyVaultName string

@description('Subnet ID where the Private Endpoint will be created.')
param subnetId string

@description('Resource ID of the Private DNS Zone for Key Vault.')
param privateDnsZoneId string

@description('Principal ID of the workload identity granted Secrets User access.')
param workloadPrincipalId string

@description('Resource tags.')
param tags object = {}

// Key Vault Secrets User built-in role GUID
var keyVaultSecretsUserRoleId = '4633458b-17de-408a-b874-0445c86b69e6'

// 1. Hardened Key Vault
resource resKeyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    enablePurgeProtection: true
    publicNetworkAccess: 'Disabled'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
    }
  }
}

// 2. Deterministic RBAC Role Assignment
resource resRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resKeyVault.id, workloadPrincipalId, keyVaultSecretsUserRoleId)
  scope: resKeyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultSecretsUserRoleId)
    principalId: workloadPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// 3. Private Endpoint
resource resPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-11-01' = {
  name: 'pe-${keyVaultName}'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: subnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'plsc-${keyVaultName}'
        properties: {
          privateLinkServiceId: resKeyVault.id
          groupIds: [
            'vault'
          ]
        }
      }
    ]
  }
}

// 4. Private DNS Zone Group Integration
resource resDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-11-01' = {
  parent: resPrivateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink-vaultcore-azure-net'
        properties: {
          privateDnsZoneId: privateDnsZoneId
        }
      }
    ]
  }
}

@description('Resource ID of the hardened Key Vault.')
output keyVaultId string = resKeyVault.id
```
