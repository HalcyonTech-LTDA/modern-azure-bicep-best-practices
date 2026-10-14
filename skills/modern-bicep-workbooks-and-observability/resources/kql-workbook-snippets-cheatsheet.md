# KQL & Workbook Snippets Cheatsheet

## 1. Top Visualization Types in Workbook Items

| Visualization (`visualization`) | Ideal Content Type | Description |
| :--- | :--- | :--- |
| `'tiles'` | Executive KPI Cards | Shows big numeric values with delta comparisons and subtitles |
| `'linechart'` | Time-Series Trends | Requests per minute, latency over time, CPU/memory percentage |
| `'barchart'` | Categorical Comparisons | Errors per dependency, status code distribution |
| `'grid'` | Detailed Tables | Multi-column table with column sorting, filtering, and threshold heatmaps |
| `'piechart'` | Proportional Shares | Success vs client error vs server error distribution |

---

## 2. Common KQL Snippets for Microservices

### Dependency Failure Breakdown
```kql
dependencies
| where timestamp {TimeRange}
| where success == false
| summarize Failures = count() by target, resultCode
| order by Failures desc
```

### High Latency Route Detection (P99)
```kql
requests
| where timestamp {TimeRange}
| summarize
    Calls = count(),
    P50_Ms = round(percentile(duration, 50), 1),
    P95_Ms = round(percentile(duration, 95), 1),
    P99_Ms = round(percentile(duration, 99), 1)
  by name
| where Calls > 10
| order by P99_Ms desc
```

### Cosmos DB RU Consumption by Operation
```kql
AzureDiagnostics
| where TimeGenerated {TimeRange}
| where ResourceProvider == "MICROSOFT.DOCUMENTDB"
| where Category == "DataPlaneRequests"
| summarize TotalRUs = sum(todouble(requestCharge_s)) by OperationName, bin(TimeGenerated, 1h)
```
