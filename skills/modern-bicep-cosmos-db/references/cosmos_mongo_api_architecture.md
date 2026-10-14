# Cosmos DB MongoDB API Architecture

This guide covers architecture, configuration flags, and network topology for Azure Cosmos DB with MongoDB API.

---

## 1. Resource Declaration (`Microsoft.DocumentDB/databaseAccounts@2024-11-15`)

When declaring a Cosmos DB account for MongoDB workloads:
1. `kind`: Set to `'MongoDB'`.
2. `capabilities`: Include `{ name: 'EnableMongo' }`.
3. `apiProperties.serverVersion`: Specify `'7.0'` (or `'4.2'` if legacy compatibility is required). Server version 7.0 provides support for modern aggregation operators, compound wildcard indexes, and ACID multi-document transactions.
4. `databaseAccountOfferType`: Always `'Standard'`.
5. `publicNetworkAccess`: Always `'Disabled'`.

```bicep
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
```

---

## 2. Consistency Level Selection

Cosmos DB supports 5 consistency levels: Strong, Bounded Staleness, Session, Consistent Prefix, and Eventual.
- For MongoDB applications, **Session Consistency** (`Session`) is the recommended default. It provides monotonic reads, monotonic writes, read-your-writes, and write-follows-reads guarantees within a single client session, matching the operational model of MongoDB replica sets while minimizing RU costs.

---

## 3. High Availability & Zone Redundancy

In production environments, enable Availability Zone redundancy:
```bicep
locations: [
  {
    locationName: location
    failoverPriority: 0
    isZoneRedundant: isZoneRedundant // true in prod, false in dev/uat
  }
]
```
Zone redundancy replicates data across three physically separated availability zones within the primary region without requiring multi-region data replication charges.

---

## 4. Diagnostic Settings for FinOps & Telemetry

To calculate FinOps metrics (like Cosmos DB RUs consumed per 1,000 transactions) in Azure Monitor Workbooks, Cosmos DB must stream its platform metrics to the centralized Log Analytics Workspace:

```bicep
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
```
This populates the `AzureMetrics` table with metric `TotalRequestUnits`, enabling continuous FinOps unit economic analysis.
