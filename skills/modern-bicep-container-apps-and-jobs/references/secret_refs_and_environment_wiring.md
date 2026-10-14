# Secret References & Environment Variables Wiring

This guide details best practices for managing container secrets via Key Vault references and composing complex environment variable sets cleanly in Azure Bicep.

---

## 1. Zero-Trust Key Vault Secret References (`secretRef`)

Never expose secret values (database passwords, tokens, API keys) in plain text in container environment variables. Container Apps provides native secret resolution backed by Azure Key Vault.

### Step 1: Declare App Secrets with Managed Identity

```bicep
var appSecrets = [
  {
    name: 'mongodb-uri'
    keyVaultUrl: '${keyVaultUri}secrets/mongodb-uri'
    identity: managedIdentityId
  }
  {
    name: 'partner-api-key'
    keyVaultUrl: '${keyVaultUri}secrets/partner-api-key'
    identity: managedIdentityId
  }
]
```

### Step 2: Reference Secrets by Name in Container Env Arrays

```bicep
var containerEnv = [
  {
    name: 'SPRING_MONGODB_URI'
    secretRef: 'mongodb-uri'
  }
  {
    name: 'PARTNER_API_KEY'
    secretRef: 'partner-api-key'
  }
  {
    name: 'SPRING_MONGODB_DATABASE'
    value: 'app_db'
  }
]
```

---

## 2. Dynamic Environment Variable Composition (`concat()`)

In multi-application topologies (API, scheduling worker, batch worker), services often share common configurations (database URI, timeouts, logging) while requiring container-specific variables (Spring profiles, Application Insights role names, job chunk sizes).

Use Bicep's native `concat()` function to build layered, DRY configurations:

```bicep
// Base environment variables shared across all workloads
var commonEnvVars = [
  {
    name: 'SPRING_MONGODB_URI'
    secretRef: 'mongodb-uri'
  }
  {
    name: 'SPRING_MONGODB_DATABASE'
    value: 'app_db'
  }
  {
    name: 'TZ'
    value: 'UTC'
  }
  {
    name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
    value: appInsightsConnectionString
  }
  {
    name: 'JAVA_TOOL_OPTIONS'
    value: '-javaagent:/app/applicationinsights-agent.jar -XX:InitialRAMPercentage=75.0 -XX:MaxRAMPercentage=75.0 -XX:+UseG1GC'
  }
]

// API-specific environment variables
var apiEnvVars = concat(commonEnvVars, [
  {
    name: 'APPLICATIONINSIGHTS_ROLE_NAME'
    value: 'my-service-api'
  }
  {
    name: 'SERVER_PORT'
    value: '8080'
  }
])

// Batch Worker-specific environment variables
var batchEnvVars = concat(commonEnvVars, [
  {
    name: 'APPLICATIONINSIGHTS_ROLE_NAME'
    value: 'my-service-batch'
  }
  {
    name: 'BATCH_PENDING_CHUNK_SIZE'
    value: '50'
  }
  {
    name: 'BATCH_LEASE_DURATION'
    value: 'PT5M'
  }
])
```
