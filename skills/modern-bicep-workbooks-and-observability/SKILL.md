---
name: modern-bicep-workbooks-and-observability
description: >-
  Use this skill when designing, authoring, or refactoring Azure Monitor Workbooks and Observability in Bicep:
  Microsoft.Insights/workbooks resource modeling, deterministic GUID resource naming with guid(),
  hybrid KQL queries (union isfuzzy=true across Application Insights and Log Analytics Workspace),
  serialized JSON dashboard specification (string(workbookContent)), timeContext parameterization,
  RED metrics (Rate, Errors, Duration) panels, and FinOps unit economics (Cosmos RU/s per 1,000 requests).
---

# Modern Azure Monitor Workbooks & Observability with Bicep

This skill provides comprehensive architectural guidelines, declarative Bicep patterns, and robust KQL query conventions for provisioning interactive, production-grade Azure Monitor Workbooks (`Microsoft.Insights/workbooks`).

---

## Core Principles

1. **Workbook Resource Modeling & Mandatory GUID Naming**:
   - Workbooks are declared as `Microsoft.Insights/workbooks@2023-06-01`.
   - **Crucial Rule**: The resource `name` MUST be a valid GUID string. String names will fail deployment.
   - Use Bicep's `guid()` function to generate a deterministic, idempotent GUID seeded by the resource group ID and workbook display name:
     ```bicep
     param workbookDisplayName string = 'Microservice Observability & FinOps'
     param workbookName string = guid(resourceGroup().id, workbookDisplayName)

     resource workbook 'Microsoft.Insights/workbooks@2023-06-01' = {
       name: workbookName
       location: location
       kind: 'shared'
       properties: {
         displayName: workbookDisplayName
         serializedData: string(workbookContent)
         sourceId: targetResourceId
         category: 'workbook'
       }
     }
     ```

2. **Declarative Dashboard Construction (`serializedData: string(...)`)**:
   - Do not store unmaintainable, raw escaped JSON strings for the dashboard layout.
   - Author the workbook dashboard structure as a first-class, typed Bicep object (`var workbookContent = { ... }`) and serialize it natively using `string(workbookContent)`.
   - Structure includes `version: 'Notebook/1.0'`, `items: [...]`, parameters (e.g. `TimeRange`), markdown headers, KPI scorecards (`tiles`), time series graphs (`linechart`), and tables (`grid`).

3. **Cold-Start Resilient Hybrid KQL (`union isfuzzy=true`)**:
   - Azure Monitor deployments vary: telemetry might route to classic Application Insights tables (`requests`, `dependencies`, `customMetrics`) or to Log Analytics workspace-based tables (`AppRequests`, `AppDependencies`, `AppMetrics`).
   - Use hybrid KQL queries with `union isfuzzy=true` across both schemas. This ensures queries execute seamlessly regardless of workspace ingestion modes.
   - Include dummy zero-matching branches (e.g. `| where false`) so queries compile cleanly even when one of the tables has received zero events (preventing broken tiles on cold starts).

4. **RED Metrics Architecture (Rate, Errors, Duration)**:
   - Organize technical observability around the standard RED method:
     - **Rate**: Throughput / requests per minute (`summarize count() by bin(timestamp, 5m)`).
     - **Errors**: HTTP 5xx failures, dependency exceptions, and business errors (`bin(timestamp, 5m), success == false`).
     - **Duration**: Latency percentiles P50, P95, and P99 (`percentiles(duration, 50, 95, 99)`).

5. **FinOps Unit Economics Analytics**:
   - Correlate infrastructure consumption metrics directly with business throughput:
     - Cosmos DB Request Units (RUs) consumed per 1,000 processed records.
     - Database operations executed per transaction.
   - This provides real-time visibility into cost per transaction, detecting N+1 query regressions and billing anomalies before monthly invoices arrive.

---

## Detailed Topic Guides

1. **Workbook Resource Architecture**:
   - Resource model, GUID naming, `serializedData` compilation, source ID binding.
   - [Read Guide](./references/workbook_resource_architecture.md)

2. **Hybrid KQL Query Patterns**:
   - Schema differences between Application Insights and Log Analytics.
   - `union isfuzzy=true` patterns, time context filtering `{TimeRange}`, and zero-data resilience.
   - [Read Guide](./references/hybrid_kql_query_patterns.md)

3. **RED Metrics & FinOps Analytics**:
   - Constructing RED operational tiles and calculating unit cost economics.
   - [Read Guide](./references/red_metrics_and_finops_analytics.md)

---

## Blueprint Example: Complete Observability & FinOps Workbook

See [`examples/operational_finops_workbook.bicep`](./examples/operational_finops_workbook.bicep) for a complete, production-grade template implementing these patterns.
