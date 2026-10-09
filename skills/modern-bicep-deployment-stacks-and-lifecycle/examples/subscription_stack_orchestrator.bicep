metadata name = 'Subscription Landing Zone Stack Orchestrator'
metadata description = 'Provisions foundation resource groups and delegates to modules at subscription scope.'

targetScope = 'subscription'

@description('Deployment region for resource groups.')
param location string = 'eastus'

@description('Environment name.')
@allowed([
  'dev'
  'staging'
  'prod'
])
param environment string

@description('Workload name.')
param workloadName string

@description('Resource tagging taxonomy.')
type ResourceTags = {
  Environment: string
  Workload: string
  ManagedBy: string
  *: string
}

@description('Resource tags.')
param tags ResourceTags = {
  Environment: environment
  Workload: workloadName
  ManagedBy: 'DeploymentStack'
}

var coreRgName = 'rg-${workloadName}-core-${environment}'
var appRgName = 'rg-${workloadName}-app-${environment}'

// 1. Core Shared Resource Group
resource resCoreRg 'Microsoft.Resources/resourceGroups@2024-11-01' = {
  name: coreRgName
  location: location
  tags: tags
}

// 2. Application Resource Group
resource resAppRg 'Microsoft.Resources/resourceGroups@2024-11-01' = {
  name: appRgName
  location: location
  tags: tags
}

@description('Resource ID of the core resource group.')
output coreResourceGroupId string = resCoreRg.id

@description('Resource ID of the application resource group.')
output appResourceGroupId string = resAppRg.id
