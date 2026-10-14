# Cosmos DB Backup Policies & Disaster Recovery

This guide covers configuring backup policies and disaster recovery options in Azure Cosmos DB Bicep templates.

---

## 1. Periodic vs Continuous Backup Comparison

| Capability | Periodic Backup (`Periodic`) | Continuous Backup (`Continuous`) |
| :--- | :--- | :--- |
| **Restore Model** | Restore from discrete snapshot intervals | Point-In-Time Restore (PITR) to any second |
| **Recovery Point Objective (RPO)** | Bounded by backup interval (e.g. 4 hours) | < 1 second |
| **Retention Window** | Configured in hours (e.g. 8h to 720h) | 7 days or 30 days (`Continuous30Days`) |
| **Cost** | 2 copies free, additional copies billed | Billed per GB storage per month |
| **Recommended Scope** | Dev, QA, cost-sensitive workloads | Production mission-critical databases |

---

## 2. Declarative Bicep Configuration

Support both modes seamlessly via parameter conditionals:

```bicep
@description('Cosmos DB backup policy type (Periodic or Continuous).')
@allowed([
  'Periodic'
  'Continuous'
])
param backupPolicyType string = 'Periodic'

@description('Cosmos DB backup interval in minutes for periodic mode (e.g. 240 = 4h).')
param backupIntervalInMinutes int = 240

@description('Cosmos DB backup retention interval in hours for periodic mode (e.g. 8 = 2 copies).')
param backupRetentionIntervalInHours int = 8

@description('Cosmos DB backup storage redundancy for periodic mode (Geo, Local, Zone).')
@allowed([
  'Geo'
  'Local'
  'Zone'
])
param backupStorageRedundancy string = 'Geo'

resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2024-11-15' = {
  name: cosmosAccountName
  location: location
  properties: {
    backupPolicy: backupPolicyType == 'Continuous' ? {
      type: 'Continuous'
      continuousModeProperties: {
        tier: 'Continuous30Days'
      }
    } : {
      type: 'Periodic'
      periodicModeProperties: {
        backupIntervalInMinutes: backupIntervalInMinutes
        backupRetentionIntervalInHours: backupRetentionIntervalInHours
        backupStorageRedundancy: backupStorageRedundancy
      }
    }
  }
}
```
