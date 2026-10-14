# Workbook Resource Architecture in Bicep

This guide details ARM workbook resource modeling (`Microsoft.Insights/workbooks@2023-06-01`), GUID requirements, and dashboard schema composition.

---

## 1. The Resource Name GUID Invariant

Unlike most Azure resources that permit alphanumeric names with hyphens, Azure Monitor Workbooks **strictly enforce that the ARM resource name MUST be a valid UUID/GUID**. Passing a human-readable name like `workbook-my-service` will cause an ARM deployment validation error:
`InvalidResourceName: The resource name 'workbook-my-service' is not a valid GUID.`

### The Solution: Deterministic `guid()` Generation

Use Bicep's built-in `guid()` function seeded by the resource group ID and the workbook display name:

```bicep
param workbookDisplayName string = 'Service Observability & FinOps Dashboard'
param workbookName string = guid(resourceGroup().id, workbookDisplayName)

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
```
This guarantees an idempotent, reproducible GUID across deployments.

---

## 2. Declarative Workbook Schema (`workbookContent`)

Rather than escaping JSON quotes inside a massive string, model the workbook as a clean Bicep object:

```bicep
var workbookContent = {
  version: 'Notebook/1.0'
  items: [
    // 1. TimeRange parameter control
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
              durationMs: 86400000 // Default: 24h
            }
            typeSettings: {
              selectableValues: [
                { durationMs: 3600000, displayName: '1h' }
                { durationMs: 14400000, displayName: '4h' }
                { durationMs: 86400000, displayName: '24h' }
                { durationMs: 604800000, displayName: '7d' }
                { durationMs: 2592000000, displayName: '30d' }
              ]
            }
          }
        ]
      }
    }
    // 2. Markdown Header
    {
      type: 1
      content: {
        json: '## Service Health Overview'
      }
    }
    // 3. KQL Query Item (Tiles / Charts / Grids)
    {
      type: 3
      content: {
        version: 'KqlItem/1.0'
        query: kqlRequestsSummary
        size: 3
        title: 'Total Inbound Requests'
        timeContext: { durationMs: 86400000 }
        timeContextFromParameter: 'TimeRange'
        queryType: 0
        resourceType: targetResourceType
        crossComponentResources: [ targetResourceId ]
        visualization: 'tiles'
      }
    }
  ]
  isLocked: false
  fallbackResourceIds: [ targetResourceId ]
}
```
