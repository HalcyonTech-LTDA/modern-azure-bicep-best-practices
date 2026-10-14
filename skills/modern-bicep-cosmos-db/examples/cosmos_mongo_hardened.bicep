@description('The Azure region where Cosmos DB resources will be deployed.')
param location string = resourceGroup().location

@description('Deployment environment name (e.g. dev, uat, prod).')
param environmentName string = 'dev'

@description('Workload or project name.')
param projectName string = 'my-workload'

@description('Globally unique Cosmos DB account name.')
param cosmosAccountName string = 'cosmos-${projectName}-${environmentName}-${take(uniqueString(resourceGroup().id), 6)}'

@description('Resource ID of the Virtual Network for Private DNS Zone linking.')
param vnetId string

@description('Resource ID of the snet-pe subnet for the Private Endpoint.')
param subnetId string

@description('Resource ID of Log Analytics Workspace for streaming platform metrics (TotalRequestUnits) to AzureMetrics.')
param logAnalyticsWorkspaceId string = ''

@description('Maximum autoscale throughput (RU/s) for the primary collection.')
param primaryCollectionMaxThroughput int = 10000

@description('Whether to enable zone redundancy.')
param isZoneRedundant bool = false

@description('Cosmos DB backup policy type (Periodic or Continuous).')
@allowed([
  'Periodic'
  'Continuous'
])
param backupPolicyType string = 'Periodic'

@description('Resource tags.')
param tags object = {}

var privateDnsZoneName = 'privatelink.mongo.cosmos.azure.com'
var vnetName = last(split(vnetId, '/'))

// ================================================================================================
// Cosmos DB Account (MongoDB API 7.0, Public Access Disabled)
// ================================================================================================
resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2024-11-15' = {
  name: cosmosAccountName
  location: location
  tags: tags
  kind: 'MongoDB'
  properties: {
    databaseAccountOfferType: 'Standard'
    publicNetworkAccess: 'Disabled'
    enableAutomaticFailover: false
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    backupPolicy: backupPolicyType == 'Continuous' ? {
      type: 'Continuous'
      continuousModeProperties: {
        tier: 'Continuous30Days'
      }
    } : {
      type: 'Periodic'
      periodicModeProperties: {
        backupIntervalInMinutes: 240
        backupRetentionIntervalInHours: 8
        backupStorageRedundancy: 'Geo'
      }
    }
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: isZoneRedundant
      }
    ]
    capabilities: [
      {
        name: 'EnableMongo'
      }
    ]
    apiProperties: {
      serverVersion: '7.0'
    }
  }
}

// ================================================================================================
// Diagnostic Settings: Stream Platform Metrics (TotalRequestUnits) to Log Analytics Workspace
// ================================================================================================
#disable-next-line use-recent-api-versions
resource cosmosDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(logAnalyticsWorkspaceId)) {
  name: 'ds-cosmos-to-log'
  scope: cosmosAccount
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

// ================================================================================================
// Private Endpoint in snet-pe
// ================================================================================================
resource cosmosPrivateEndpoint 'Microsoft.Network/privateEndpoints@2025-01-01' = {
  name: 'pe-cosmos-${environmentName}'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: subnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'plsc-cosmos-${environmentName}'
        properties: {
          privateLinkServiceId: cosmosAccount.id
          groupIds: [
            'MongoDB'
          ]
        }
      }
    ]
  }
}

// ================================================================================================
// Private DNS Zone & VNet Link
// ================================================================================================
resource cosmosPrivateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: privateDnsZoneName
  location: 'global'
  tags: tags
}

resource cosmosPrivateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: cosmosPrivateDnsZone
  name: 'link-${vnetName}'
  location: 'global'
  tags: tags
  properties: {
    virtualNetwork: {
      id: vnetId
    }
    registrationEnabled: false
  }
}

resource cosmosPrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2025-01-01' = {
  parent: cosmosPrivateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink-mongo-cosmos-azure-com'
        properties: {
          privateDnsZoneId: cosmosPrivateDnsZone.id
        }
      }
    ]
  }
}

// ================================================================================================
// Decoupled Autoscale Throughput Settings on Application Collection
// ================================================================================================
resource primaryCollectionThroughput 'Microsoft.DocumentDB/databaseAccounts/mongodbDatabases/collections/throughputSettings@2024-11-15' = {
  name: '${cosmosAccount.name}/app_db/primary_collection/default'
  properties: {
    resource: {
      autoscaleSettings: {
        maxThroughput: primaryCollectionMaxThroughput
      }
    }
  }
}

// ================================================================================================
// Outputs
// ================================================================================================
@description('Cosmos DB Account ID.')
output cosmosAccountId string = cosmosAccount.id

@description('Cosmos DB Account Name.')
output cosmosAccountName string = cosmosAccount.name

@description('Cosmos DB Document Endpoint.')
output cosmosEndpoint string = cosmosAccount.properties.documentEndpoint

@secure()
@description('Primary MongoDB Connection String.')
output cosmosConnectionString string = cosmosAccount.listConnectionStrings().connectionStrings[0].connectionString
