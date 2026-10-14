# Container Apps & Container Apps Jobs Architecture Patterns

This guide details best practices for structuring microservice compute workloads using Azure Container Apps (`Microsoft.App/containerApps@2025-01-01`) and Azure Container Apps Jobs (`Microsoft.App/jobs@2025-01-01`).

---

## 1. Workload Categorization Matrix

| Workload Type | Azure Resource Type | Trigger Model | Scaling / Lifecycle | Typical Use Cases |
| :--- | :--- | :--- | :--- | :--- |
| **REST / HTTP Services** | `Microsoft.App/containerApps` | Ingress (HTTP) | Dynamic scale (minReplicas to maxReplicas) | Web APIs, BFF gateways, Webhook listeners |
| **Continuous Background Workers** | `Microsoft.App/containerApps` | None (No Ingress) | Fixed replicas (min: 1, max: 1) | ShedLock schedulers, queue consumers, token managers |
| **Scheduled Batch Pipelines** | `Microsoft.App/jobs` | Schedule (Cron) | Ephemeral execution (scale-to-zero upon completion) | Spring Batch jobs, nightly ETL, periodic synchronization |
| **Manual / CI/CD Operations** | `Microsoft.App/jobs` | Manual | On-demand single execution (scale-to-zero) | Database migrations (`migrate-mongo`, Flyway, Liquibase) |

---

## 2. Container Apps Jobs Specification

### Scheduled Cron Job Pattern

Scheduled jobs run periodically based on a standard cron expression. Once all chunks/items are processed, the container process terminates cleanly (exit code 0) and ACA releases all CPU and memory resources.

```bicep
resource batchJob 'Microsoft.App/jobs@2025-01-01' = {
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
      replicaTimeout: 1800            // Maximum execution time in seconds (e.g. 30 minutes)
      replicaRetryLimit: 1            // Number of retries before marking execution as failed
      scheduleTriggerConfig: {
        cronExpression: '*/5 * * * *' // Runs every 5 minutes
        parallelism: batchJobParallelism // Number of parallel replica containers
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
            '-cp'
            '/app/app.jar'
            '-Dloader.main=com.example.BatchWorkerApplication'
            'org.springframework.boot.loader.launch.PropertiesLauncher'
            '--spring.profiles.active=batch'
          ]
          resources: {
            cpu: json(batchCpu)
            memory: batchMemory
          }
          env: batchEnvVars
        }
      ]
    }
  }
}
```

### Manual Triggered Migration Job Pattern

Database migrations must run in an isolated job prior to deploying new revisions of application containers. This guarantees schema compatibility and avoids race conditions across multiple application replicas.

```bicep
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
      replicaTimeout: 300             // 5 minutes timeout
      replicaRetryLimit: 0            // Zero retries: schema failure must fail fast
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
```

---

## 3. Continuous Scheduling Worker with Distributed Locks

When running recurring distributed schedulers using libraries like ShedLock or Quartz:
1. Omit the `ingress` block completely from `configuration`.
2. Set `minReplicas: 1` and `maxReplicas: 1`. Multiple replicas with distributed locking waste compute resources as redundant replicas remain idle waiting on lock acquisition.
3. Configure health probes (readiness and liveness probes) to ensure unhealthy workers restart automatically.

```bicep
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
            '-cp'
            '/app/app.jar'
            '-Dloader.main=com.example.SchedulingWorkerApplication'
            'org.springframework.boot.loader.launch.PropertiesLauncher'
            '--spring.profiles.active=scheduling,scheduling-worker'
          ]
          resources: {
            cpu: json(schedulingCpu)
            memory: schedulingMemory
          }
          env: schedulingEnvVars
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
    }
  }
}
```
