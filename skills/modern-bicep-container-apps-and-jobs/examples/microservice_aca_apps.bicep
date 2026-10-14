@description('The Azure region where Container Apps resources will be deployed.')
param location string = resourceGroup().location

@description('Deployment environment name (e.g. dev, uat, prod).')
param environmentName string = 'dev'

@description('Project or workload name used to compose resource names.')
param projectName string = 'my-service'

@description('Resource ID of the Container Apps Managed Environment.')
param acaEnvironmentId string

@description('Resource ID of the User-Assigned Managed Identity.')
param managedIdentityId string

@description('URI of the Key Vault for secret resolution.')
param keyVaultUri string

@description('Login server for Azure Container Registry.')
param acrLoginServer string = ''

@description('Container image tag for application workloads.')
param applicationImageTag string = 'latest'

@description('Container image tag for database migrations.')
param migrationImageTag string = 'latest'

@description('Container image tag for partner mock server.')
param mockImageTag string = 'latest'

@description('Address prefix of the APIM subnet for ingress IP restriction.')
param apimSubnetPrefix string = '10.0.3.0/24'

@description('Parallelism for the Scheduled Batch Job.')
param batchJobParallelism int = 1

@description('Minimum replicas for mock server (0 = scale-to-zero in uat/prod, >=1 in dev).')
param mockMinReplicas int = 0

@description('Resource tags applied to all resources.')
param tags object = {}

var resolvedContainerImage = empty(acrLoginServer)
  ? 'mcr.microsoft.com/k8se/quickstart:latest'
  : '${acrLoginServer}/${projectName}:${applicationImageTag}'

var resolvedMigrationContainerImage = empty(acrLoginServer)
  ? 'mcr.microsoft.com/k8se/quickstart:latest'
  : '${acrLoginServer}/db-migration:${migrationImageTag}'

var resolvedMockContainerImage = empty(acrLoginServer)
  ? 'mcr.microsoft.com/k8se/quickstart:latest'
  : '${acrLoginServer}/mock-server:${mockImageTag}'

var acrRegistries = !empty(acrLoginServer) ? [
  {
    server: acrLoginServer
    identity: managedIdentityId
  }
] : []

var appSecrets = [
  {
    name: 'mongodb-uri'
    keyVaultUrl: '${keyVaultUri}secrets/mongodb-uri'
    identity: managedIdentityId
  }
  {
    name: 'partner-api-key'
    keyVaultUrl: '${keyVaultUri}secrets/partner-api-key'
    identity: managedIdentityId
  }
]

var commonEnvVars = [
  {
    name: 'SPRING_MONGODB_URI'
    secretRef: 'mongodb-uri'
  }
  {
    name: 'SPRING_MONGODB_DATABASE'
    value: 'app_db'
  }
  {
    name: 'TZ'
    value: 'UTC'
  }
]

var apiEnvVars = concat(commonEnvVars, [
  {
    name: 'APPLICATIONINSIGHTS_ROLE_NAME'
    value: '${projectName}-api'
  }
])

var schedEnvVars = concat(commonEnvVars, [
  {
    name: 'APPLICATIONINSIGHTS_ROLE_NAME'
    value: '${projectName}-sched'
  }
])

var batchEnvVars = concat(commonEnvVars, [
  {
    name: 'APPLICATIONINSIGHTS_ROLE_NAME'
    value: '${projectName}-batch'
  }
])

// ================================================================================================
// 1. API Container App (Ingress restricted strictly to APIM subnet)
// ================================================================================================
resource apiApp 'Microsoft.App/containerApps@2025-01-01' = {
  name: 'aca-api-${projectName}-${environmentName}'
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityId}': {}
    }
  }
  properties: {
    managedEnvironmentId: acaEnvironmentId
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        targetPort: 8080
        transport: 'auto'
        allowInsecure: false
        ipSecurityRestrictions: [
          {
            name: 'Allow-APIM-Subnet-Only'
            action: 'Allow'
            ipAddressRange: apimSubnetPrefix
            description: 'Restricts inbound access strictly to the dedicated APIM subnet'
          }
        ]
      }
      registries: acrRegistries
      secrets: appSecrets
    }
    template: {
      containers: [
        {
          name: 'api'
          image: resolvedContainerImage
          args: [
            '-jar'
            '/app/app.jar'
            '--spring.profiles.active=api'
          ]
          resources: {
            cpu: json('0.5')
            memory: '1.0Gi'
          }
          env: apiEnvVars
        }
      ]
      scale: {
        minReplicas: environmentName == 'prod' ? 2 : 1
        maxReplicas: 10
        rules: [
          {
            name: 'http-rule'
            http: {
              metadata: {
                concurrentRequests: '100'
              }
            }
          }
        ]
      }
    }
  }
}

// ================================================================================================
// 2. Scheduling Worker Container App (No Ingress, Single Instance ShedLock)
// ================================================================================================
resource schedulingWorkerApp 'Microsoft.App/containerApps@2025-01-01' = {
  name: 'aca-sched-${projectName}-${environmentName}'
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityId}': {}
    }
  }
  properties: {
    managedEnvironmentId: acaEnvironmentId
    configuration: {
      activeRevisionsMode: 'Single'
      registries: acrRegistries
      secrets: appSecrets
    }
    template: {
      containers: [
        {
          name: 'scheduling-worker'
          image: resolvedContainerImage
          args: [
            '-jar'
            '/app/app.jar'
            '--spring.profiles.active=scheduling'
          ]
          resources: {
            cpu: json('0.5')
            memory: '1.0Gi'
          }
          env: schedEnvVars
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
    }
  }
}

// ================================================================================================
// 3. Batch Worker Container Apps Job (Scheduled Cron Job)
// ================================================================================================
resource batchWorkerJob 'Microsoft.App/jobs@2025-01-01' = {
  name: 'aca-batch-${projectName}-${environmentName}'
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityId}': {}
    }
  }
  properties: {
    environmentId: acaEnvironmentId
    configuration: {
      triggerType: 'Schedule'
      replicaTimeout: 1800
      replicaRetryLimit: 1
      scheduleTriggerConfig: {
        cronExpression: '*/5 * * * *'
        parallelism: batchJobParallelism
        replicaCompletionCount: batchJobParallelism
      }
      registries: acrRegistries
      secrets: appSecrets
    }
    template: {
      containers: [
        {
          name: 'batch-worker'
          image: resolvedContainerImage
          args: [
            '-jar'
            '/app/app.jar'
            '--spring.profiles.active=batch'
          ]
          resources: {
            cpu: json('1.0')
            memory: '2.0Gi'
          }
          env: batchEnvVars
        }
      ]
    }
  }
}

// ================================================================================================
// 4. Database Migration Container Apps Job (Manual Triggered Ephemeral Job)
// ================================================================================================
resource migrationJob 'Microsoft.App/jobs@2025-01-01' = {
  name: 'aca-migration-${projectName}-${environmentName}'
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityId}': {}
    }
  }
  properties: {
    environmentId: acaEnvironmentId
    configuration: {
      triggerType: 'Manual'
      replicaTimeout: 300
      replicaRetryLimit: 0
      registries: acrRegistries
      secrets: appSecrets
    }
    template: {
      containers: [
        {
          name: 'db-migration'
          image: resolvedMigrationContainerImage
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
          env: [
            {
              name: 'SPRING_MONGODB_URI'
              secretRef: 'mongodb-uri'
            }
          ]
        }
      ]
    }
  }
}

// ================================================================================================
// 5. Partner Mock Server (WireMock, Internal Only, Scale-to-Zero in UAT/Prod)
// ================================================================================================
resource mockApp 'Microsoft.App/containerApps@2025-01-01' = if (mockMinReplicas > 0) {
  name: 'aca-mock-${projectName}-${environmentName}'
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityId}': {}
    }
  }
  properties: {
    managedEnvironmentId: acaEnvironmentId
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: false
        targetPort: 8080
      }
      registries: acrRegistries
    }
    template: {
      containers: [
        {
          name: 'mock'
          image: resolvedMockContainerImage
          resources: {
            cpu: json('0.5')
            memory: '1.0Gi'
          }
        }
      ]
      scale: {
        minReplicas: mockMinReplicas
        maxReplicas: 5
      }
    }
  }
}

// ================================================================================================
// Outputs
// ================================================================================================
@description('Resource ID of the API Container App.')
output apiAppId string = apiApp.id

@description('Internal FQDN of the API Container App.')
output apiAppFqdn string = apiApp.properties.configuration.ingress.fqdn

@description('Resource ID of the Scheduling Worker Container App.')
output schedulingWorkerAppId string = schedulingWorkerApp.id

@description('Resource ID of the Batch Worker Job.')
output batchWorkerJobId string = batchWorkerJob.id

@description('Resource ID of the Database Migration Job.')
output migrationJobId string = migrationJob.id

@description('Resource ID of the Partner Mock Server (empty if scaled to zero).')
output mockAppId string = mockMinReplicas > 0 ? mockApp.id : ''
