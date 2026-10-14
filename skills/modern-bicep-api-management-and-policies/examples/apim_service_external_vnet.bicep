@description('The Azure region where API Management will be deployed.')
param location string = resourceGroup().location

@description('Deployment environment name (e.g. dev, uat, prod).')
param environmentName string = 'dev'

@description('Project or workload name used to compose resource names.')
param projectName string = 'my-workload'

@description('Name of the API Management service instance.')
param apimName string = 'apim-${projectName}-${environmentName}'

@description('Publisher organization email address for APIM notifications.')
param publisherEmail string = 'admin@example.com'

@description('Publisher organization name.')
param publisherName string = 'Example Organization'

@description('Subnet Resource ID dedicated for Azure API Management (snet-apim).')
param apimSubnetId string

@description('Internal FQDN of the Container Apps API application.')
param apiAppFqdn string

@description('The pricing tier of the APIM service.')
param apimSkuName string = 'Developer'

@description('The instance capacity of the APIM service.')
param apimSkuCapacity int = 1

@description('Resource tags.')
param tags object = {}

// ================================================================================================
// Azure API Management Service (External VNet Mode)
// ================================================================================================
resource apim 'Microsoft.ApiManagement/service@2024-05-01' = {
  name: apimName
  location: location
  tags: tags
  sku: {
    name: apimSkuName
    capacity: apimSkuCapacity
  }
  properties: {
    publisherEmail: publisherEmail
    publisherName: publisherName
    virtualNetworkType: 'External'
    virtualNetworkConfiguration: {
      subnetResourceId: apimSubnetId
    }
    customProperties: {
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls10': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls11': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls12': 'True'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls10': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls11': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls12': 'True'
    }
  }
}

// ================================================================================================
// APIM Backend: Routes traffic internally to ACA API via HTTPS
// ================================================================================================
resource apiBackend 'Microsoft.ApiManagement/service/backends@2024-05-01' = {
  parent: apim
  name: 'aca-api-backend'
  properties: {
    description: 'Internal backend target pointing to Azure Container Apps REST API'
    protocol: 'http'
    url: 'https://${apiAppFqdn}'
    tls: {
      validateCertificateChain: false
      validateCertificateName: false
    }
  }
}

// ================================================================================================
// Outputs
// ================================================================================================
@description('Resource ID of the API Management service.')
output apimId string = apim.id

@description('Name of the API Management service.')
output apimName string = apim.name

@description('Public Gateway URL of the API Management service.')
output gatewayUrl string = apim.properties.gatewayUrl

@description('Identifier name of the configured internal ACA backend.')
output backendId string = apiBackend.name
