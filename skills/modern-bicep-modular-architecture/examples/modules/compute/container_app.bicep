@description('Container App Environment and Container App module with Managed Identity.')

metadata name = 'Container App Module'
metadata description = 'Provisions a managed Container App environment and secure container application.'

@description('Azure region for deployment.')
param location string = resourceGroup().location

@description('Name of the Container App Environment.')
param environmentName string

@description('Name of the Container App.')
param appName string

@description('Resource ID of the subnet for infrastructure.')
param subnetId string

@description('Resource ID of the User-Assigned Managed Identity.')
param userAssignedIdentityId string

@description('Container image to deploy.')
param containerImage string = 'mcr.microsoft.com/azuredocs/aci-helloworld:latest'

@description('Resource tags.')
param tags object = {}

// Container App Managed Environment
resource resEnvironment 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: environmentName
  location: location
  tags: tags
  properties: {
    vnetConfiguration: {
      infrastructureSubnetId: subnetId
      internal: true
    }
    workloadProfiles: [
      {
        name: 'Consumption'
        workloadProfileType: 'Consumption'
      }
    ]
  }
}

// Container App with User-Assigned Identity
resource resApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: appName
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentityId}': {}
    }
  }
  properties: {
    managedEnvironmentId: resEnvironment.id
    workloadProfileName: 'Consumption'
    configuration: {
      ingress: {
        external: false
        targetPort: 80
        transport: 'auto'
        allowInsecure: false
      }
    }
    template: {
      containers: [
        {
          name: appName
          image: containerImage
          resources: {
            cpu: json('0.5')
            memory: '1.0Gi'
          }
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 5
      }
    }
  }
}

@description('Resource ID of the provisioned Container App.')
output appId string = resApp.id

@description('Fully Qualified Domain Name of the application.')
output appFqdn string = resApp.properties.configuration.ingress.fqdn
