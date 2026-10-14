# Autoscale Throughput Governance & Decoupled Collections

This guide explains how to govern Cosmos DB Request Unit (RU/s) limits declaratively in Bicep while decoupling infrastructure from application-managed database collections.

---

## 1. The Migration Dilemma vs Bicep Declarations

When teams adopt database migration frameworks (e.g. `migrate-mongo` in Node.js/Docker or Flyway/Liquibase), collections and indexes are created, altered, and validated imperatively by code:
- If Bicep attempts to declare the same `mongodbCollections` resource, ARM deployments can conflict with migration scripts or overwrite indexes and validator schemas.
- If Bicep completely ignores collections, infrastructure engineers lose declarative governance over autoscale throughput caps, risking unexpected billing spikes.

### The Decoupled Solution: `throughputSettings` Extension Resource

Cosmos DB provides a dedicated ARM resource type:
`Microsoft.DocumentDB/databaseAccounts/mongodbDatabases/collections/throughputSettings@2024-11-15`

This resource targets existing collections created by migrations, applying autoscale limits without managing the collection schema:

```bicep
param bureauDataMaxThroughput int = 10000

resource bureauDataThroughput 'Microsoft.DocumentDB/databaseAccounts/mongodbDatabases/collections/throughputSettings@2024-11-15' = {
  name: '${cosmosAccount.name}/atendas_bureau/bureau_data/default'
  properties: {
    resource: {
      autoscaleSettings: {
        maxThroughput: bureauDataMaxThroughput
      }
    }
  }
}
```

---

## 2. Autoscale Dynamics & Sizing Rules

Cosmos DB Autoscale dynamically scales throughput based on current workload demand:
- **Scaling Range**: Scaled instantaneously between **10% of maxThroughput** and **100% of maxThroughput**.
  - Example: `maxThroughput: 10000 RU/s` scales between `1000 RU/s` (idle) and `10000 RU/s` (peak).
- **Billing**: Billed per hour based on the maximum RU/s consumed in that hour.
- **Storage Tier Allocation**: Cosmos DB provisions 100 GB of storage per 10,000 RU/s max throughput tier.

### Recommended Sizing Tiers

| Workload Volume | Maximum Throughput (`maxThroughput`) | Scaled Floor (10%) | Typical Scenario |
| :--- | :--- | :--- | :--- |
| **Low / Dev** | 1,000 - 4,000 RU/s | 100 - 400 RU/s | Development, unit testing, integration tests |
| **Medium / UAT** | 4,000 - 10,000 RU/s | 400 - 1,000 RU/s | Staging, QA validation, secondary collections |
| **High / Production** | 10,000 - 50,000+ RU/s | 1,000 - 5,000+ RU/s | Core transactional collections, batch pipelines |
