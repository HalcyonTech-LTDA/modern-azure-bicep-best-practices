# Hybrid KQL Query Patterns for Azure Monitor Workbooks

This guide explains how to author KQL queries that run reliably against both Application Insights components and Log Analytics Workspaces.

---

## 1. Schema Differences: Application Insights vs Log Analytics

Depending on whether an Azure Workbook targets an Application Insights component (`microsoft.insights/components`) or a Log Analytics Workspace (`microsoft.operationalinsights/workspaces`), telemetry table and column names differ:

| Concept | Classic App Insights Table & Fields | Log Analytics Workspace Table & Fields |
| :--- | :--- | :--- |
| **Inbound Requests** | `requests` (`timestamp`, `name`, `duration`, `success`, `resultCode`) | `AppRequests` (`TimeGenerated`, `Name`, `DurationMs`, `Success`, `ResultCode`) |
| **External Dependencies** | `dependencies` (`timestamp`, `target`, `type`, `data`, `duration`) | `AppDependencies` (`TimeGenerated`, `Target`, `DependencyType`, `Data`, `DurationMs`) |
| **Custom Metrics** | `customMetrics` (`timestamp`, `name`, `valueCount`, `customDimensions`) | `AppMetrics` (`TimeGenerated`, `Name`, `ItemCount`, `Properties`) |
| **Traces / Logs** | `traces` (`timestamp`, `message`, `severityLevel`, `customDimensions`) | `AppTraces` (`TimeGenerated`, `Message`, `SeverityLevel`, `Properties`) |

---

## 2. The `union isfuzzy=true` Normalization Pattern

To write queries that execute seamlessly in either context (or in hybrid transition environments), use the `union isfuzzy=true` pattern to project common column names, along with a false-predicate dummy branch to prevent query parser errors on newly created workspaces:

```kql
let rawRequests = union isfuzzy=true
    (
        requests
        | project
            timestamp,
            name = tostring(name),
            success = tobool(success),
            resultCode = tostring(resultCode),
            duration = todouble(duration)
    ),
    (
        AppRequests
        | project
            timestamp = TimeGenerated,
            name = tostring(Name),
            success = tobool(Success),
            resultCode = tostring(ResultCode),
            duration = todouble(DurationMs)
    ),
    (
        print timestamp = datetime(null), name = '', success = bool(null), resultCode = '', duration = real(null)
        | where false
    );
```

---

## 3. Dynamic Time Filtering with `{TimeRange}`

In Azure Monitor Workbooks, time ranges are parameterized by the user via interactive dropdowns.
In KQL queries, reference the parameter using the `{TimeRange}` macro token:

```kql
rawRequests
| where timestamp {TimeRange}
| summarize
    TotalRequests = count(),
    SuccessfulRequests = countif(success == true),
    FailedRequests = countif(success == false),
    P95DurationMs = round(percentile(duration, 95), 2)
  by bin(timestamp, 5m)
```
When executed in the workbook, Azure Monitor substitutes `{TimeRange}` with the selected duration filter (e.g. `| where timestamp >= ago(24h)`).
