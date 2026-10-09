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

@description('Resource tagging taxonomy.')
type ResourceTags = {
  *: string
}

@description('Resource tags.')
param tags ResourceTags = {}

// Key Vault Secrets User built-in role GUID
var keyVaultSecretsUserRoleId = '4633458b-17de-408a-b874-0445c86b69e6'

// 1. Hardened Key Vault
resource resKeyVault 'Microsoft.KeyVault/vaults@2024-11-01' = {
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
resource resPrivateEndpoint 'Microsoft.Network/privateEndpoints@2025-01-01' = {
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
resource resDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2025-01-01' = {
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
