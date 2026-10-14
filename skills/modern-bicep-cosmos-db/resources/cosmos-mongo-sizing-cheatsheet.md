# Cosmos DB (MongoDB API) Sizing & Best Practices Cheatsheet

## Autoscale RU/s Budget & Sizing Cheatsheet

| Workload Tier | Collection Purpose | Max Throughput (`maxThroughput`) | Scaled Floor (10%) | Est. Monthly Peak Cost (USD) |
| :--- | :--- | :--- | :--- | :--- |
| **Dev / Sandbox** | All Collections | 1,000 RU/s | 100 RU/s | ~$12 - $30 / mo |
| **UAT / Staging** | Core Collection | 4,000 RU/s | 400 RU/s | ~$48 - $120 / mo |
| **Prod Standard** | Secondary (Batches/Outbox) | 4,000 RU/s | 400 RU/s | ~$48 - $120 / mo |
| **Prod High-Load**| Primary (Customer/Data) | 10,000 RU/s | 1,000 RU/s | ~$120 - $300 / mo |
| **Prod Enterprise**| Ultra High-Volume Ingestion | 50,000 RU/s | 5,000 RU/s | ~$600 - $1,500 / mo |

---

## Indexing & Query Guardrails for MongoDB API

1. **Avoid COLLSCAN**:
   - Every read query MUST be backed by an index. A single COLLSCAN on a 1M document collection can consume 1,000+ RUs in a single query and trigger 429 (RequestRateTooLarge) throttling.
2. **Compound Indexes & Order**:
   - Create compound indexes that follow the Equality, Sort, Range (ESR) rule.
3. **Compound Wildcard Indexes (Server 7.0)**:
   - Server version 7.0 supports wildcard compound indexes on dynamic attribute maps: `db.collection.createIndex({ "data.$**": 1 })`.
4. **Decoupled Throughput Management**:
   - Manage schema/indexes via application migration files (e.g., `migrate-mongo`).
   - Manage RU/s caps and autoscale policy exclusively via Bicep `throughputSettings`.
