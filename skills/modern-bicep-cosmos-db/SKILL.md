---
name: modern-bicep-cosmos-db
description: >-
  Use this skill when designing, authoring, or refactoring Azure Cosmos DB (especially MongoDB API) in Bicep:
  MongoDB API kind ('MongoDB'), server version 7.0, session consistency, autoscale collection throughput settings (throughputSettings RU/s)
  decoupled from collection provisioning, periodic vs continuous backup policies, private endpoints with privatelink.mongo.cosmos.azure.com DNS,
  and secure connection string export via @secure() and listConnectionStrings().
---

# Modern Azure Cosmos DB (MongoDB API) with Bicep

This skill provides comprehensive architectural guidelines, security hardening, and declarative Bicep patterns for provisioning and governing Azure Cosmos DB accounts configured with the MongoDB API.

---

## Core Principles

1. **MongoDB API Account Specification**:
   - Explicitly configure `kind: 'MongoDB'`.
   - Set capabilities: `capabilities: [{ name: 'EnableMongo' }]`.
   - Pin server version explicitly to current standards: `apiProperties: { serverVersion: '7.0' }`.
   - Default consistency level should match application session requirements: `consistencyPolicy: { defaultConsistencyLevel: 'Session' }`.
   - Always disable public internet ingress: `publicNetworkAccess: 'Disabled'`.

2. **Decoupled Autoscale Throughput Governance**:
   - In modern architectures, schema evolution and collection/index creation are managed by database migration tools (e.g. `migrate-mongo`).
   - Do NOT tightly couple collection schemas inside Bicep templates if migrations manage them.
   - Instead, govern throughput declaratively using dedicated `throughputSettings` extension resources referencing target collections:
     ```bicep
     resource collectionThroughput 'Microsoft.DocumentDB/databaseAccounts/mongodbDatabases/collections/throughputSettings@2024-11-15' = {
       name: '${cosmosAccount.name}/${databaseName}/${collectionName}/default'
       properties: {
         resource: {
           autoscaleSettings: {
             maxThroughput: maxThroughputRuPerSec // e.g. 10000 RU/s
           }
         }
       }
     }
     ```
   - This prevents deployment-time conflicts with migration scripts while enforcing FinOps budget caps and autoscale limits.

3. **Backup Policies & Disaster Recovery**:
   - Explicitly define `backupPolicy` rather than relying on silent defaults.
   - Support parameterized backup policies:
     - `Periodic`: Default with configurable `backupIntervalInMinutes` (e.g. 240 min = 4h), `backupRetentionIntervalInHours` (e.g. 8h = 2 copies), and `backupStorageRedundancy` (`Geo`, `Zone`, `Local`).
     - `Continuous`: For production systems requiring Point-in-Time Restore (PITR) with `continuousModeProperties: { tier: 'Continuous30Days' }`.

4. **Network Isolation via Private Endpoint & Private DNS**:
   - Deploy a dedicated Private Endpoint in the private endpoints subnet (`snet-pe`).
   - Group ID MUST be strictly set to `['MongoDB']`.
   - Provision the Private DNS Zone `privatelink.mongo.cosmos.azure.com`.
   - Link the zone to the VNet (`Microsoft.Network/privateDnsZones/virtualNetworkLinks`) with `registrationEnabled: false`.
   - Create a Private DNS Zone Group (`privateDnsZoneGroups`) to register the private IP automatically.

5. **Secure Connection String Propagation**:
   - Extract connection strings dynamically using `cosmosAccount.listConnectionStrings().connectionStrings[0].connectionString`.
   - The output MUST be decorated with `@secure()` in Bicep:
     ```bicep
     @secure()
     @description('Primary MongoDB connection string for the Cosmos DB account.')
     output cosmosConnectionString string = cosmosAccount.listConnectionStrings().connectionStrings[0].connectionString
     ```
   - Feed this output directly into an Azure Key Vault secret resource (`Microsoft.KeyVault/vaults/secrets`), ensuring zero plain-text storage in parameter files or CI/CD logs.

6. **Diagnostic Settings & FinOps Telemetry Streaming**:
   - Stream platform metrics (`AllMetrics`, specifically `TotalRequestUnits`) to the central Log Analytics Workspace using `Microsoft.Insights/diagnosticSettings`.
   - This feeds `AzureMetrics` for automated FinOps unit economics in Azure Monitor Workbooks (e.g. measuring RUs consumed per 1,000 processed transactions).

---

## Detailed Topic Guides

1. **Cosmos DB MongoDB API Architecture**:
   - Server version pinning, session consistency, capabilities, zone redundancy.
   - [Read Guide](./references/cosmos_mongo_api_architecture.md)

2. **Autoscale Throughput Governance**:
   - Decoupled `throughputSettings` pattern vs embedded collection definitions.
   - Sizing autoscale RU/s and FinOps budget management.
   - [Read Guide](./references/autoscale_throughput_governance.md)

3. **Backup Policies & Disaster Recovery**:
   - Continuous 30-day PITR vs Periodic backup strategies.
   - [Read Guide](./references/backup_and_disaster_recovery.md)

---

## Blueprint Example: Hardened Cosmos DB MongoDB API Module

See [`examples/cosmos_mongo_hardened.bicep`](./examples/cosmos_mongo_hardened.bicep) for a complete, production-grade template implementing these patterns.
