@description('The Azure region where the workbook resource will be deployed.')
param location string = resourceGroup().location

@description('Display name of the Azure Workbook in Azure Monitor.')
param workbookDisplayName string = 'Microservice Observability & FinOps Dashboard'

@description('Deterministic unique identifier (GUID) for the Workbook resource.')
param workbookName string = guid(resourceGroup().id, workbookDisplayName)

@description('Resource ID of the Application Insights component.')
param appInsightsId string = ''

@description('Resource ID of the Log Analytics Workspace backing Application Insights.')
param logAnalyticsWorkspaceId string = ''

@description('Resource tags.')
param tags object = {}

var targetResourceId = !empty(appInsightsId) ? appInsightsId : logAnalyticsWorkspaceId
var targetResourceType = !empty(appInsightsId) ? 'microsoft.insights/components' : 'microsoft.operationalinsights/workspaces'
var cosmosTargetResourceId = !empty(logAnalyticsWorkspaceId) ? logAnalyticsWorkspaceId : targetResourceId
var cosmosTargetResourceType = !empty(logAnalyticsWorkspaceId) ? 'microsoft.operationalinsights/workspaces' : targetResourceType

// ================================================================================================
// Hybrid KQL Queries (App Insights & Log Analytics)
// ================================================================================================
var kqlRequestsSummary = '''
let rawRequests = union isfuzzy=true
    (requests | project timestamp, name = tostring(name), success = tobool(success), duration = todouble(duration), resultCode = tostring(resultCode)),
    (AppRequests | project timestamp = TimeGenerated, name = tostring(Name), success = tobool(Success), duration = todouble(DurationMs), resultCode = tostring(ResultCode)),
    (print timestamp = datetime(null), name = '', success = bool(null), duration = real(null), resultCode = '' | where false);
rawRequests
| where timestamp {TimeRange}
| summarize
    TotalRequests = count(),
    SuccessCount = countif(success == true),
    ErrorCount = countif(success == false),
    P95DurationMs = round(percentile(duration, 95), 1)
| extend SuccessRatePct = iff(TotalRequests > 0, round(100.0 * SuccessCount / TotalRequests, 2), 100.0)
| project-away SuccessCount
'''

var kqlDependenciesRed = '''
let rawDeps = union isfuzzy=true
    (dependencies | project timestamp, target = tostring(target), type = tostring(type), success = tobool(success), duration = todouble(duration)),
    (AppDependencies | project timestamp = TimeGenerated, target = tostring(Target), type = tostring(DependencyType), success = tobool(Success), duration = todouble(DurationMs)),
    (print timestamp = datetime(null), target = '', type = '', success = bool(null), duration = real(null) | where false);
rawDeps
| where timestamp {TimeRange}
| summarize
    TotalCalls = count(),
    FailedCalls = countif(success == false),
    ErrorRatePct = round(100.0 * countif(success == false) / count(), 2),
    P50_Ms = round(percentile(duration, 50), 1),
    P95_Ms = round(percentile(duration, 95), 1),
    P99_Ms = round(percentile(duration, 99), 1)
  by target
| order by TotalCalls desc
'''

var kqlCosmosFinOpsKpi = '''
let rawDependencies = union isfuzzy=true
    (
        dependencies
        | project timestamp, type = tostring(type), target = tostring(target), duration = todouble(duration), success = tobool(success)
    ),
    (
        AppDependencies
        | project timestamp = TimeGenerated, type = tostring(DependencyType), target = tostring(Target), duration = todouble(DurationMs), success = tobool(Success)
    ),
    (
        print timestamp = datetime(null), type = '', target = '', duration = real(null), success = bool(null)
        | where false
    );
let rawRequests = union isfuzzy=true
    (requests | project timestamp, name = tostring(name)),
    (AppRequests | project timestamp = TimeGenerated, name = tostring(Name)),
    (print timestamp = datetime(null), name = '' | where false);
let cosmosRUs = union isfuzzy=true
    (
        AzureMetrics
        | where TimeGenerated {TimeRange}
        | where ResourceProvider has 'DOCUMENTDB'
        | where MetricName == 'TotalRequestUnits'
        | summarize TotalRUs = sum(todouble(Total))
    ),
    (
        print TotalRUs = real(0.0)
        | where false
    );
let dbCalls = rawDependencies
| where timestamp {TimeRange}
| where type =~ 'mongodb' or target has 'cosmos' or target has 'documents.azure.com'
| summarize TotalOps = count(), P95Latency = round(percentile(duration, 95), 1), SuccessOps = countif(success == true);
let requestCount = rawRequests
| where timestamp {TimeRange}
| summarize Requests = count();
let cleanRUs = toscalar(cosmosRUs | summarize TotalRUs = sum(TotalRUs) | project coalesce(TotalRUs, 0.0));
let cleanOps = toscalar(dbCalls | project coalesce(TotalOps, 0));
let cleanP95 = toscalar(dbCalls | project coalesce(P95Latency, 0.0));
let cleanSuccess = toscalar(dbCalls | project coalesce(SuccessOps, 0));
let cleanReqs = toscalar(requestCount | project coalesce(Requests, 0));
let ruPer1k = iff(cleanReqs > 0, round((cleanRUs / toreal(cleanReqs)) * 1000.0, 1), 0.0);
let opsPerReq = iff(cleanReqs > 0, round(toreal(cleanOps) / toreal(cleanReqs), 2), 0.0);
let dbSuccessRate = iff(cleanOps > 0, round(100.0 * cleanSuccess / cleanOps, 2), 100.0);
union
    (print MetricName = 'RUs por 1.000 Requisições', MetricValue = todouble(ruPer1k), SubTitle = 'Eficiência FinOps (AzureMetrics / 1k Reqs)'),
    (print MetricName = 'Total RUs Medidas', MetricValue = round(cleanRUs, 0), SubTitle = 'Request Units Reais (AzureMetrics)'),
    (print MetricName = 'Operações BD / Requisição', MetricValue = todouble(opsPerReq), SubTitle = 'Média Chamadas Cosmos / Req'),
    (print MetricName = 'Latência P95 Banco', MetricValue = todouble(cleanP95), SubTitle = 'ms (Percentil 95)'),
    (print MetricName = 'Taxa Sucesso Banco', MetricValue = todouble(dbSuccessRate), SubTitle = '% Operações Bem-Sucedidas')
'''

// ================================================================================================
// Dashboard JSON Specification Object
// ================================================================================================
var workbookContent = {
  version: 'Notebook/1.0'
  items: [
    {
      type: 9
      content: {
        version: 'KqlParameterItem/1.0'
        parameters: [
          {
            id: 'time-range-param'
            version: 'KqlParameterItem/1.0'
            name: 'TimeRange'
            type: 4
            isRequired: true
            value: {
              durationMs: 86400000
            }
            typeSettings: {
              selectableValues: [
                {
                  durationMs: 3600000
                  displayName: '1 hour'
                }
                {
                  durationMs: 14400000
                  displayName: '4 hours'
                }
                {
                  durationMs: 86400000
                  displayName: '24 hours'
                }
                {
                  durationMs: 604800000
                  displayName: '7 days'
                }
              ]
            }
          }
        ]
      }
    }
    {
      type: 1
      content: {
        json: '# 📊 Operational Health & RED Metrics\nExecutive observability dashboard for microservice ingress and dependencies.'
      }
    }
    {
      type: 3
      content: {
        version: 'KqlItem/1.0'
        query: kqlRequestsSummary
        size: 3
        title: 'Inbound Request Volume & Success Rate'
        timeContext: {
          durationMs: 86400000
        }
        timeContextFromParameter: 'TimeRange'
        queryType: 0
        resourceType: targetResourceType
        crossComponentResources: [
          targetResourceId
        ]
        visualization: 'tiles'
      }
    }
    {
      type: 1
      content: {
        json: '### External Dependencies RED Metrics (Rate, Errors, Duration)'
      }
    }
    {
      type: 3
      content: {
        version: 'KqlItem/1.0'
        query: kqlDependenciesRed
        size: 0
        title: 'Dependencies Breakdown'
        timeContext: {
          durationMs: 86400000
        }
        timeContextFromParameter: 'TimeRange'
        queryType: 0
        resourceType: targetResourceType
        crossComponentResources: [
          targetResourceId
        ]
        visualization: 'grid'
      }
    }
    {
      type: 1
      content: {
        json: '### 💰 Cosmos DB FinOps Unit Economics (AzureMetrics & Request Units)'
      }
    }
    {
      type: 3
      content: {
        version: 'KqlItem/1.0'
        query: kqlCosmosFinOpsKpi
        size: 3
        title: 'Cosmos DB FinOps Unit Economics'
        timeContext: {
          durationMs: 86400000
        }
        timeContextFromParameter: 'TimeRange'
        queryType: 0
        resourceType: cosmosTargetResourceType
        crossComponentResources: [
          cosmosTargetResourceId
        ]
        visualization: 'tiles'
      }
    }
  ]
  isLocked: false
  fallbackResourceIds: [
    targetResourceId
  ]
}

// ================================================================================================
// Azure Resource Definition
// ================================================================================================
resource workbook 'Microsoft.Insights/workbooks@2023-06-01' = {
  name: workbookName
  location: location
  tags: tags
  kind: 'shared'
  properties: {
    displayName: workbookDisplayName
    serializedData: string(workbookContent)
    sourceId: targetResourceId
    category: 'workbook'
  }
}

// ================================================================================================
// Outputs
// ================================================================================================
@description('Resource ID of the provisioned Azure Workbook.')
output workbookId string = workbook.id

@description('The deterministic GUID name of the Azure Workbook.')
output workbookName string = workbook.name
