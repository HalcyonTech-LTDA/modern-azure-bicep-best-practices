metadata name = 'Storage Account RBAC Role Assignment'
metadata description = 'Deploys a Storage Account with shared keys disabled, and assigns Storage Blob Data Contributor to a Managed Identity.'

@description('Azure region for deployment.')
param location string = resourceGroup().location

@description('Name of the Storage Account.')
@minLength(3)
@maxLength(24)
param storageAccountName string

@description('Name of the User-Assigned Managed Identity.')
param identityName string

@description('Resource tagging taxonomy.')
type ResourceTags = {
  *: string
}

@description('Resource tags.')
param tags ResourceTags = {}

// Built-in Storage Blob Data Contributor role definition ID
var storageBlobDataContributorRoleId = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'

// 1. User-Assigned Managed Identity
resource resIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30' = {
  name: identityName
  location: location
  tags: tags
}

// 2. Storage Account with Modern Security Hardening
resource resStorage 'Microsoft.Storage/storageAccounts@2025-01-01' = {
  name: storageAccountName
  location: location
  tags: tags
  sku: {
    name: 'Standard_GRS'
  }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false // Mandatory: Disables storage keys, enforcing Azure AD RBAC exclusively
    publicNetworkAccess: 'Disabled'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
    }
  }
}

// 3. Deterministic RBAC Role Assignment
resource resRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resStorage.id, resIdentity.id, storageBlobDataContributorRoleId)
  scope: resStorage
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      storageBlobDataContributorRoleId
    )
    principalId: resIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

@description('Resource ID of the Storage Account.')
output storageAccountId string = resStorage.id

@description('Principal ID of the Managed Identity.')
output identityPrincipalId string = resIdentity.properties.principalId
