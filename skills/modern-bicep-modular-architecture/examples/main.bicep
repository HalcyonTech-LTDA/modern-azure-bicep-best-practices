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
