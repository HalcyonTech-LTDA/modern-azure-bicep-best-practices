# RED Metrics & FinOps Analytics in Azure Workbooks

This guide covers implementing standard RED metrics (Rate, Errors, Duration) and calculating FinOps unit economics in Azure Monitor Workbooks.

---

## 1. The RED Method (Rate, Errors, Duration)

The RED method provides an essential health summary for microservices and their external dependencies:

### KQL RED Metrics Implementation

```kql
let rawDeps = union isfuzzy=true
    (
        dependencies
        | project
            timestamp,
            target = tostring(target),
            type = tostring(type),
            success = tobool(success),
            duration = todouble(duration)
    ),
    (
        AppDependencies
        | project
            timestamp = TimeGenerated,
            target = tostring(Target),
            type = tostring(DependencyType),
            success = tobool(Success),
            duration = todouble(DurationMs)
    );
rawDeps
| where timestamp {TimeRange}
| summarize
    // 1. Rate: Requests per interval
    TotalCalls = count(),
    // 2. Errors: Failed call count and error percentage
    FailedCalls = countif(success == false),
    ErrorRatePct = round(100.0 * countif(success == false) / count(), 2),
    // 3. Duration: Latency percentiles (P50, P95, P99)
    P50_Ms = round(percentile(duration, 50), 1),
    P95_Ms = round(percentile(duration, 95), 1),
    P99_Ms = round(percentile(duration, 99), 1)
  by target
| order by TotalCalls desc
```

---

## 2. FinOps Unit Economics Analytics

Tracking raw Azure spend (e.g. total monthly Cosmos DB bill) fails to explain whether cost increases are due to healthy business growth or architectural regressions (such as N+1 query loops).

### Unit Metric: Cosmos DB RU/s per 1,000 Transactions

Correlate database dependency metrics with business operation counts:

```kql
let rawDeps = union isfuzzy=true
    (dependencies | project timestamp, type = tostring(type), target = tostring(target), success = tobool(success)),
    (AppDependencies | project timestamp = TimeGenerated, type = tostring(DependencyType), target = tostring(Target), success = tobool(Success));
let cosmosOps = rawDeps
| where timestamp {TimeRange}
| where target has 'cosmos' or type has 'Cosmos' or type has 'MongoDB'
| summarize TotalCosmosOps = count() by bin(timestamp, 1h);
let businessTransactions = rawDeps
| where timestamp {TimeRange}
| where target !has 'cosmos' and (success == true)
| summarize TotalProcessed = count() by bin(timestamp, 1h);
cosmosOps
| join kind=inner businessTransactions on timestamp
| project
    timestamp,
    TotalCosmosOps,
    TotalProcessed,
    OpsPerTransaction = round(todouble(TotalCosmosOps) / todouble(TotalProcessed), 2),
    EstimatedRUsPer1000 = round((todouble(TotalCosmosOps) * 2.5) / (todouble(TotalProcessed) / 1000.0), 2)
```

Visualizing this ratio in a `linechart` allows engineering teams to immediately detect database query regressions during performance and load testing.
