---
name: modern-bicep-container-apps-and-jobs
description: >-
  Use this skill when designing, authoring, or refactoring Azure Container Apps and Container Apps Jobs in Bicep:
  microservice topologies, background worker isolation (ShedLock), scheduled cron jobs (Schedule trigger),
  manual triggered migration jobs (Manual trigger), VNet internal ingress with IP security restrictions (ipSecurityRestrictions for APIM subnet),
  partner mock server choreography (scale-to-zero in uat/prod), dynamic Key Vault secretRef wiring, and container resource quotas.
---

# Modern Azure Container Apps & Container Apps Jobs

This skill provides comprehensive architectural guidelines, security controls, and declarative Bicep patterns for deploying resilient, secure microservices using Azure Container Apps (`Microsoft.App/containerApps`) and Azure Container Apps Jobs (`Microsoft.App/jobs`).

---

## Core Principles

1. **Decouple Continuous Services from Ephemeral Workloads**:
   - Continuous HTTP endpoints must be modeled as **Container Apps** (`Microsoft.App/containerApps`) with auto-scaling rules based on HTTP concurrency, CPU, and memory.
   - Long-running scheduled tasks (e.g. batch chunk processing) must NEVER run continuously as idle services. Model them as **Container Apps Scheduled Jobs** (`triggerType: 'Schedule'`) with cron schedules (e.g. `*/5 * * * *`), spinning up replicas on-demand and scaling to zero upon task completion.
   - One-time operational tasks (database schema migrations, seed jobs) must be modeled as **Container Apps Manual Jobs** (`triggerType: 'Manual'`) with zero retries (`replicaRetryLimit: 0`) and dedicated timeouts (`replicaTimeout: 300`).

2. **Ingress Isolation & IP Restrictions for API Services**:
   - In private microservice topologies, never expose Container Apps directly to the public internet without an API Gateway (APIM).
   - When deploying to an internal Container Apps Environment (`internal: true`), configure `ingress.external: true` (which exposes the app within the CAE cluster/VNet only) and enforce strict `ipSecurityRestrictions`:
     ```bicep
     ipSecurityRestrictions: [
       {
         name: 'Allow-APIM-Subnet-Only'
         action: 'Allow'
         ipAddressRange: apimSubnetPrefix
         description: 'Restricts inbound access strictly to the dedicated APIM subnet, blocking all other intra-VNet and external access'
       }
     ]
     ```
   - Enforce `allowInsecure: false` to require HTTPS on `targetPort: 8080`.

3. **Background Worker Isolation (ShedLock & Async Schedulers)**:
   - Microservice background schedulers (e.g., token renewal, async submission/polling, status checkers) must have ingress completely disabled (omit `ingress` from `configuration`).
   - Pin replicas to fixed bounds `minReplicas: 1, maxReplicas: 1` when paired with distributed locking frameworks (like ShedLock) to prevent redundant scheduling threads and lock contention.
   - Launch workers with profile segregation (e.g., Spring Boot `PropertiesLauncher` with specific active scheduling profiles) to prevent binding HTTP endpoints on background worker pods.

4. **Dynamic Key Vault Secret Resolution (`secretRef`)**:
   - Absolute ban on baking cleartext credentials into container environment variables.
   - Register secret definitions in the Container App's `configuration.secrets` linking directly to Azure Key Vault URLs using User-Assigned Managed Identity:
     ```bicep
     secrets: [
       {
         name: 'mongodb-uri'
         keyVaultUrl: '${keyVaultUri}secrets/mongodb-uri'
         identity: managedIdentityId
       }
     ]
     ```
   - In container `env` arrays, reference the secret by name using `secretRef: 'mongodb-uri'`.

5. **Internal Partner Mock Server Choreography & Scale-to-Zero**:
   - For integration testing, provide a companion mock container (e.g. WireMock) with internal ingress (`external: false`, `targetPort: 8080`).
   - Support zero idle cost in non-dev environments by declaratively binding replicas:
     - Development (`dev`): `mockMinReplicas: 2` (active mock server).
     - Staging/Production (`uat`/`prod`): `mockMinReplicas: 0` (dormant / scaled-to-zero).
   - In Bicep variables, use conditional resolution to point dependent services to the internal mock URL when partner URLs are empty:
     ```bicep
     var resolvedProcobApiBaseUrl = !empty(procobApiBaseUrl) ? procobApiBaseUrl : internalMockUrl
     ```

6. **JVM & Distributed Telemetry Wiring**:
   - Inject Application Insights Java Agent via `JAVA_TOOL_OPTIONS: '-javaagent:/app/applicationinsights-agent.jar'`.
   - Assign unique `APPLICATIONINSIGHTS_ROLE_NAME` to each container (`<workload>-api`, `<workload>-scheduling`, `<workload>-batch`) to ensure clean separation on the Azure Application Map.

---

## Detailed Topic Guides

1. **Container Apps & Container Apps Jobs Architecture Patterns**:
   - Continuous apps vs. scheduled jobs vs. manual migration jobs.
   - Job trigger configuration (`scheduleTriggerConfig`, cron expressions, parallelism, completion count).
   - [Read Guide](./references/container_apps_and_jobs_patterns.md)

2. **Ingress Security & Network Restrictions**:
   - CAE internal VNet mode, DNS resolution, and IP filtering.
   - Restricting API ingress strictly to the dedicated APIM subnet prefix.
   - [Read Guide](./references/ingress_and_network_security.md)

3. **Dynamic Secret References & Environment Variables Wiring**:
   - Key Vault secret resolution with Managed Identities.
   - Composing environment variable arrays using Bicep `concat()`.
   - [Read Guide](./references/secret_refs_and_environment_wiring.md)

---

## Blueprint Example: Microservice Architecture with API, Scheduler, Batch Job & Migration

See [`examples/microservice_aca_apps.bicep`](./examples/microservice_aca_apps.bicep) for a complete, production-grade template implementing these patterns.
