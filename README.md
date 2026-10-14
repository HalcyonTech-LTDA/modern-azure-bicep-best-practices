# Modern Azure Bicep Best Practices Plugin

An Antigravity plugin providing automated engineering guardrails, architectural patterns, security controls, and procedural skills for modern Azure Bicep engineering: Azure Verified Modules (AVM), User-Defined Types (UDT), `.bicepparam` parameters, zero-secrets security with Managed Identities and Azure RBAC, Azure Container Apps & Jobs, Cosmos DB MongoDB API autoscale governance, API Management & XML Policy choreography, Azure Monitor Workbooks with hybrid KQL and FinOps unit economics, Azure Deployment Stacks lifecycle & drift governance, multi-gate CI/CD with OIDC, and the mandatory living `README.md` runbook documentation discipline.

---

## Installation

### Antigravity

Install directly in Antigravity via the CLI:

```bash
agy plugin install https://github.com/HalcyonTech-LTDA/modern-azure-bicep-best-practices
```

Verify that the plugin is installed and ready:

```bash
agy plugin list
```

### Claude Code

Add the Halcyon Tech marketplace once, then install the plugin:

```text
/plugin marketplace add HalcyonTech-LTDA/halcyon-plugins
/plugin install modern-azure-bicep-best-practices@halcyon-plugins
```

Skills are namespaced by plugin in Claude Code (`/modern-azure-bicep-best-practices:<skill-name>`). The guardrails in `rules/` load through the skills in `claude/skills/`.

---

## Overview

Modern cloud engineering demands infrastructure as code that is deterministic, type-safe, drift-resistant, and free of secret leakages. Without strict architectural discipline, Azure infrastructure codebases frequently suffer from critical enterprise failure modes:

- **The Legacy JSON Parameters Trap**: Maintaining verbose, brittle `parameters.json` files that lack compile-time validation, type checking, or environment variable resolution.
- **Untyped "God" Objects**: Passing untyped `object` and `array` configurations to modules, hiding schema requirements and deferring syntax errors to runtime deployment crashes.
- **Secret & Connection String Sprawl**: Baking database passwords, storage keys, and connection strings into Bicep templates or deployment state rather than using Managed Identities and Azure RBAC.
- **Microservice Perimeter Leaks & Idle Compute**: Exposing internal container apps directly to public ingress or running continuous background services for workloads that should scale to zero as ephemeral scheduled jobs.
- **Uncontrolled Cloud Database Spending**: Over-provisioning static database throughput or neglecting to set declarative autoscale caps on collections created by migration scripts.
- **Gateway Policy Sprawl & Starvation**: Hardcoding XML policies without dynamic caller identity or failing to bypass health probe endpoints from rate limiting and authentication checks.
- **Orphaned Resources & Cost Leaks**: Running loose ARM deployments (`az deployment group create`) that fail to clean up deleted resources, leaving costly orphaned disks, VMs, and subnets running indefinitely.
- **Out-of-Band Cloud Drift**: Allowing operators or automated scripts to mutate cloud resources directly, drifting away from source control definitions.
- **Long-Lived CI/CD Credentials**: Storing static service principal passwords in CI/CD secret stores, creating major supply-chain exposure risks.

This plugin establishes modern, production-grade engineering standards for Azure Bicep across eight comprehensive pillars:

1. **Modular Architecture & Contracts (`modern-bicep-modular-architecture`)**: Azure Verified Modules (AVM) compliance, compile-time type safety with User-Defined Types (`type`), User-Defined Functions (`func`), native `.bicepparam` parameter files, registry distribution (Public MCR and Private ACR), and cross-scope orchestration.
2. **Security, Identity & Governance (`modern-bicep-security-and-governance`)**: Zero secrets in source code, `@secure()` decorator rules, Azure RBAC authorization over legacy access policies, User-Assigned Managed Identity lifecycles, deterministic role assignment GUIDs with `guid()`, network isolation with Private Endpoints, and Customer-Managed Keys (CMK).
3. **Container Apps & Ephemeral Jobs (`modern-bicep-container-apps-and-jobs`)**: Microservice compute topology segregation, internal CAE ingress with `ipSecurityRestrictions` allowing APIM subnet only, background ShedLock worker isolation, scheduled cron jobs (`Microsoft.App/jobs`), manual migration jobs, scale-to-zero mock servers, and dynamic `secretRef` Key Vault resolution.
4. **Cosmos DB & Data Governance (`modern-bicep-cosmos-db`)**: MongoDB API 7.0 specification, session consistency, decoupled collection-level autoscale throughput settings (`throughputSettings` RU/s), periodic vs continuous 30-day backup policies, private DNS wiring (`privatelink.mongo.cosmos.azure.com`), and secure connection string export via `@secure()`.
5. **API Management & XML Policies (`modern-bicep-api-management-and-policies`)**: External VNet injection, internal ACA backends, Products, APIs, typed Operations, W3C distributed tracing diagnostics, route-based rate limiting (`<rate-limit-by-key>`), Entra ID OAuth 2.0 JWT validation (`<validate-jwt>`), RFC 6648 idempotency validation & response caching, URI rewrites, and probe bypassing.
6. **Workbooks & Observability (`modern-bicep-workbooks-and-observability`)**: Azure Monitor Workbooks (`Microsoft.Insights/workbooks`), mandatory deterministic GUID resource naming via `guid()`, declarative `serializedData` dashboard composition, cold-start resilient hybrid KQL queries (`union isfuzzy=true`), RED metrics (Rate, Errors, Duration), and FinOps unit economics (RU/s per 1,000 transactions).
7. **Deployment Stacks & Lifecycle Governance (`modern-bicep-deployment-stacks-and-lifecycle`)**: Treating infrastructure as an atomic unit using **Azure Deployment Stacks**, enforcing drift protection via Deny Assignments (`denyWriteAndDelete`), automated resource cleanup with `actionOnUnmanage`, What-If pre-flight verification, and dependency DAG optimization.
8. **Testing, Quality Gates & CI/CD Pipelines (`modern-bicep-testing-and-ci-cd`)**: Shift-left multi-gate validation, Bicep linter enforcement (`bicepconfig.json`), static analysis against the Microsoft Well-Architected Framework using PSRule for Azure, passwordless OIDC Workload Identity Federation in GitHub Actions and Azure DevOps, PR What-If diff commenting, and the mandatory living `README.md` runbook mandate.

---

## What's Included

### 1. Automatic Guardrails (`rules/modern-azure-bicep-engineering.md`)
Automatically enforced across all projects utilizing Azure Bicep:
- **Mandatory `.bicepparam` over Deprecated JSON Parameters**: Absolute ban on `.parameters.json` for new projects; mandate `.bicepparam` with `using 'main.bicep'`.
- **Strict Compile-Time Typing with User-Defined Types (UDT)**: Ban on untyped `object` parameters for complex contracts. Mandate `type` declarations with tagged unions, nullable markers, and `@sealed()` decorators.
- **Azure Verified Modules (AVM) Alignment**: Standardize on AVM specifications, parameter contracts, outputs, tags, and private ACR registries.
- **Zero Hardcoded Secrets & State Leakage**: Absolute ban on inline passwords, client secrets, connection strings, or storage keys. Mandate `@secure()`, Azure Key Vault runtime references, and zero output of secrets.
- **Mandatory Managed Identity & Elimination of Service Credentials**: All Azure services must authenticate via Managed Identities (User-Assigned or System-Assigned); ban storing service principal credentials in infrastructure code.
- **Granular RBAC with Deterministic GUIDs**: Mandate `Microsoft.Authorization/roleAssignments` with deterministic `guid()` seeds and built-in role definition IDs over custom roles.
- **Network Isolation by Default on PaaS Services**: Public network access must be explicitly disabled (`publicNetworkAccess: 'Disabled'`) on PaaS services with Private Endpoints and Private DNS Zones configured.
- **Microservice Ingress Restrictions & Worker Decoupling**: Container Apps REST APIs in internal CAE must restrict ingress strictly to the dedicated APIM subnet via `ipSecurityRestrictions`. Schedulers must omit ingress and pin single replicas (`minReplicas: 1, maxReplicas: 1`), while batch pipelines and migrations run as ephemeral Container Apps Jobs (`Microsoft.App/jobs`), and partner mocks scale to zero in non-dev environments.
- **Decoupled Cosmos DB Throughput Governance**: For Cosmos DB MongoDB API (`kind: 'MongoDB'`), govern collection autoscale RU/s caps via dedicated `throughputSettings` extension resources decoupled from application migrations, stream platform metrics to Log Analytics via diagnostic settings for FinOps telemetry, and define explicit backup policies (`Continuous` or `Periodic`).
- **APIM Route-Based Rate Limiting & RFC 6648 Idempotency**: Protect mutation APIs with mandatory `Idempotency-Key` headers, 24h caching returning `Idempotent-Replayed: true`, and tiered `<rate-limit-by-key>` dynamic expressions; bypass health probes (`/actuator/health`) from auth/rate limiting.
- **Deterministic GUID Naming & Hybrid KQL for Workbooks**: `Microsoft.Insights/workbooks` resource names must strictly be valid GUIDs generated via `guid()`, with `serializedData` dashboard specs and `union isfuzzy=true` cold-start resilient KQL queries.
- **Mandatory Azure Deployment Stacks over Loose Deployments**: Use Azure Deployment Stacks (`az stack group create` or `az stack sub create`) with explicit `denySettingsMode` (`denyWriteAndDelete` or `denyWrite`) and clean `actionOnUnmanage` (`deleteResources`).
- **Mandatory Pre-Flight What-If Execution in CI/CD**: Never run imperative deployments without automated `what-if` execution and noise-free diff reporting.
- **Passwordless CI/CD Authentication with OIDC / Workload Identity Federation**: Pipelines must use OpenID Connect (OIDC) with Azure Entra ID federated credentials; ban long-lived `AZURE_CREDENTIALS` client secrets in CI secrets stores.
- **Deterministic Static Analysis Quality Gates (Linter & PSRule)**: Enforce strict linter rules via `bicepconfig.json` paired with PSRule for Azure Well-Architected Framework compliance.
- **Mandatory Dedicated Living `README.md` Runbook**: Any directory or repository housing Bicep infrastructure code must maintain an up-to-date living `README.md` documenting architecture, parameter contracts, stack commands, role assignments, and disaster recovery.

---

### 2. Specialized Skills (`skills/`)

#### 🧱 `modern-bicep-modular-architecture`
Guides modular composition, Azure Verified Modules (AVM) patterns, compile-time typing, and parameter files:
- **References**:
  - `references/avm_and_registry_standards.md`: AVM specifications, standard parameter/output contracts, private ACR module distribution, and semantic version pinning.
  - `references/user_defined_types_and_functions.md`: User-Defined Types (`type`), tagged unions, nullable types, sealed objects, User-Defined Functions (`func`), and validation decorators.
  - `references/bicepparam_and_configuration.md`: The `.bicepparam` standard, `using` declarations, environment decoupling, reading environment variables, and Key Vault secret references.
- **Examples**:
  - `examples/main.bicep`: Multi-tier root orchestrator using modules, UDTs, and user-defined functions.
  - `examples/main.bicepparam`: Native `.bicepparam` parameter file.
  - `examples/modules/network/vnet.bicep`: Modular network definition with typed subnets and NSGs.
  - `examples/modules/compute/container_app.bicep`: Hardened Container App module with Managed Identity.
- **Resources**:
  - `resources/bicep-naming-conventions.md`: Azure Cloud Adoption Framework (CAF) abbreviation guide and standard naming patterns.

#### 🛡️ `modern-bicep-security-and-governance`
Guides zero-trust architecture, Key Vault integration, identity lifecycle, and RBAC:
- **References**:
  - `references/secrets_and_identity_hygiene.md`: Zero plain-text secrets, `@secure()` decorator rules, preventing secret leakages in outputs, and Managed Identity SDK integration (`DefaultAzureCredential`).
  - `references/rbac_and_least_privilege.md`: Declarative `roleAssignments`, deterministic GUID calculation with `guid()`, avoiding BCP120 compiler traps, and resource-level scoping.
  - `references/network_isolation_and_private_endpoints.md`: Disabling public access on PaaS services, Private Endpoint architecture, and automated Private DNS Zone group wiring.
  - `references/customer_managed_keys_and_encryption.md`: Customer-Managed Keys (CMK) with automated key rotation, double encryption, and minimum TLS enforcement.
- **Examples**:
  - `examples/keyvault_hardened.bicep`: Hardened Key Vault with RBAC, soft-delete, purge protection, disabled public access, and private endpoint.
  - `examples/rbac_storage_role_assignment.bicep`: User-Assigned Managed Identity granted "Storage Blob Data Contributor" role on a Storage Account with deterministic GUID.
- **Resources**:
  - `resources/azure-builtin-roles-cheatsheet.md`: Standard Azure Built-In Role Definition GUIDs cheatsheet (Key Vault Secrets User, Storage Blob Data Contributor, AcrPull, etc.).

#### 📦 `modern-bicep-container-apps-and-jobs`
Guides microservice container topologies, background ShedLock workers, scheduled/manual jobs, and ingress security:
- **References**:
  - `references/container_apps_and_jobs_patterns.md`: Continuous apps vs scheduled jobs vs manual migration jobs, cron configurations, parallelism, and retry limits.
  - `references/ingress_and_network_security.md`: Internal CAE mode, ingress port mapping, and strict `ipSecurityRestrictions` for APIM subnet delegation.
  - `references/secret_refs_and_environment_wiring.md`: Managed Identity Key Vault secret resolution, array concatenation for environment variables (`concat()`), avoiding circular dependencies.
- **Examples**:
  - `examples/microservice_aca_apps.bicep`: Complete multi-workload module modeling API (restricted ingress), single-replica ShedLock scheduler, scheduled batch job, and manual migration job.
- **Resources**:
  - `resources/container-apps-sizing-cheatsheet.md`: CPU/Memory combination matrix, replica sizing guidelines, and autoscaling triggers.

#### 🍃 `modern-bicep-cosmos-db`
Guides Azure Cosmos DB (MongoDB API) architecture, decoupled collection throughput, backup policies, and private networking:
- **References**:
  - `references/cosmos_mongo_api_architecture.md`: MongoDB API 7.0 specification, session consistency, capabilities, and availability zone redundancy.
  - `references/autoscale_throughput_governance.md`: Decoupled `throughputSettings` extension resource pattern, autoscale scaling range (10% to 100%), and FinOps budget management.
  - `references/backup_and_disaster_recovery.md`: Continuous 30-day Point-in-Time Restore (PITR) vs Periodic backup strategies and storage redundancy.
- **Examples**:
  - `examples/cosmos_mongo_hardened.bicep`: Complete production Cosmos DB MongoDB API module with private endpoint, DNS zone, backup policy, autoscale collection throughput settings, and connection string export.
- **Resources**:
  - `resources/cosmos-mongo-sizing-cheatsheet.md`: Collection sizing cheatsheet, autoscale RU/s budget tiers, and indexing guardrails (COLLSCAN prevention).

#### 🌐 `modern-bicep-api-management-and-policies`
Guides API Management service deployment in External VNet mode and authoring enterprise XML policies:
- **References**:
  - `references/apim_vnet_and_backend_architecture.md`: External VNet mode, mandatory NSG rules (port 3443), internal ACA backend target wiring, and TLS hardening.
  - `references/apim_xml_policy_engine_mastery.md`: Deep dive on APIM XML policy elements, rate limiting by key with C# context expressions, Entra ID JWT validation, URL rewriting, and timeouts.
  - `references/idempotency_and_distributed_tracing.md`: RFC 6648 idempotency validation & response caching, W3C correlation (`traceparent`/`tracestate`), and Application Insights diagnostics.
- **Examples**:
  - `examples/apim_service_external_vnet.bicep`: Core APIM service provisioning with External VNet injection and ACA backend.
  - `examples/apim_api_and_xml_policies.bicep`: Complete API definition with Products, typed Operations, App Insights Diagnostics, and enterprise XML policy suite.
- **Resources**:
  - `resources/apim-policy-snippets-cheatsheet.md`: Copy-pasteable APIM policy snippets (rate limiting, JWT, idempotency, header manipulation, error handling).

#### 📈 `modern-bicep-workbooks-and-observability`
Guides Azure Monitor Workbooks (`Microsoft.Insights/workbooks`), hybrid KQL queries, and FinOps unit economics:
- **References**:
  - `references/workbook_resource_architecture.md`: ARM workbook specification, mandatory deterministic GUID naming (`guid()`), `serializedData` JSON structure, and sourceId binding.
  - `references/hybrid_kql_query_patterns.md`: Hybrid KQL queries resilient to schema differences between App Insights and Log Analytics, `union isfuzzy=true`, and `{TimeRange}` macro token.
  - `references/red_metrics_and_finops_analytics.md`: Constructing RED dashboards (Rate, Errors, Duration) and calculating FinOps unit economics (RU/s per 1,000 transactions).
- **Examples**:
  - `examples/operational_finops_workbook.bicep`: Complete production Azure Workbook template with parameter controls, KPI cards, RED dependency charts, and Cosmos DB FinOps analytics.
- **Resources**:
  - `resources/kql-workbook-snippets-cheatsheet.md`: Reusable KQL queries and workbook visualization items (tiles, charts, grids, thresholds).

#### 🚀 `modern-bicep-deployment-stacks-and-lifecycle`
Guides atomic lifecycle management, drift prevention, and cleanup with Azure Deployment Stacks:
- **References**:
  - `references/deployment_stacks_architecture.md`: In-depth breakdown of Azure Deployment Stacks, comparing with classic ARM deployments, deny assignments, and break-glass workflows.
  - `references/action_on_unmanage_and_cleanup.md`: Safe cleanup strategies, `actionOnUnmanage` matrix, resource deletion vs detaching, and safeguarding stateful resources.
  - `references/what_if_analysis_and_change_validation.md`: What-If change operations (`Create`, `Delete`, `Modify`, `Deploy`, `NoChange`), noise filtering, and CI/CD validation gates.
  - `references/dependency_graph_and_idempotency.md`: Symbolic reference dependencies, ARM engine DAG calculation, eliminating unnecessary explicit `dependsOn`, and deployment idempotency.
- **Examples**:
  - `examples/deployment-stack-workflow.sh`: Hardened bash script demonstrating `az stack group create` with deny settings, what-if validation, and lifecycle cleanup.
  - `examples/subscription_stack_orchestrator.bicep`: Subscription-scoped Bicep file (`targetScope = 'subscription'`) creating foundation resource groups.
- **Resources**:
  - `resources/deployment-stacks-cli-cheatsheet.md`: Operational Azure CLI and PowerShell cheat sheet for Deployment Stacks across all scopes.

#### 🚦 `modern-bicep-testing-and-ci-cd`
Guides automated multi-gate pipelines, linting, WAF static analysis, OIDC, and living runbooks:
- **References**:
  - `references/bicep_linting_and_analyzer_rules.md`: Bicep compiler linter configuration (`bicepconfig.json`), core rules, warning vs error levels, and code formatting.
  - `references/static_analysis_psrule_and_arm_ttk.md`: Running PSRule for Azure, WAF compliance rules, SARIF reporting, and ARM-TTK checks.
  - `references/cicd_pipelines_and_oidc.md`: Passwordless OIDC Workload Identity Federation setup, GitHub Actions workflows, and Azure DevOps YAML pipelines.
  - `references/iac_living_readme_runbook.md`: Mandatory living documentation standard for Bicep repositories, architecture diagrams, parameter matrices, and PR synchronization checklists.
- **Examples**:
  - `examples/github-actions-bicep-pipeline.yml`: Production GitHub Actions workflow with OIDC login, Bicep lint, PSRule, What-If PR commenting, and Deployment Stack apply.
  - `examples/azure-pipelines-bicep.yml`: Production Azure DevOps YAML pipeline using federated service connection.
- **Resources**:
  - `resources/bicepconfig.json`: Enterprise-grade Bicep configuration with strict analyzer rules and module registry aliases.
  - `resources/iac-living-runbook-template.md`: Complete living runbook markdown template for infrastructure codebases.

---

## Directory Layout

```text
modern-azure-bicep-best-practices/
├── .gitattributes
├── .gitignore
├── LICENSE
├── README.md
├── bicepconfig.json
├── plugin.json
├── rules/
│   └── modern-azure-bicep-engineering.md
└── skills/
    ├── modern-bicep-modular-architecture/
    │   ├── SKILL.md
    │   ├── examples/
    │   ├── references/
    │   └── resources/
    ├── modern-bicep-security-and-governance/
    │   ├── SKILL.md
    │   ├── examples/
    │   ├── references/
    │   └── resources/
    ├── modern-bicep-container-apps-and-jobs/
    │   ├── SKILL.md
    │   ├── examples/
    │   │   └── microservice_aca_apps.bicep
    │   ├── references/
    │   │   ├── container_apps_and_jobs_patterns.md
    │   │   ├── ingress_and_network_security.md
    │   │   └── secret_refs_and_environment_wiring.md
    │   └── resources/
    │       └── container-apps-sizing-cheatsheet.md
    ├── modern-bicep-cosmos-db/
    │   ├── SKILL.md
    │   ├── examples/
    │   │   └── cosmos_mongo_hardened.bicep
    │   ├── references/
    │   │   ├── autoscale_throughput_governance.md
    │   │   ├── backup_and_disaster_recovery.md
    │   │   └── cosmos_mongo_api_architecture.md
    │   └── resources/
    │       └── cosmos-mongo-sizing-cheatsheet.md
    ├── modern-bicep-api-management-and-policies/
    │   ├── SKILL.md
    │   ├── examples/
    │   │   ├── apim_api_and_xml_policies.bicep
    │   │   └── apim_service_external_vnet.bicep
    │   ├── references/
    │   │   ├── apim_vnet_and_backend_architecture.md
    │   │   ├── apim_xml_policy_engine_mastery.md
    │   │   └── idempotency_and_distributed_tracing.md
    │   └── resources/
    │       └── apim-policy-snippets-cheatsheet.md
    ├── modern-bicep-workbooks-and-observability/
    │   ├── SKILL.md
    │   ├── examples/
    │   │   └── operational_finops_workbook.bicep
    │   ├── references/
    │   │   ├── hybrid_kql_query_patterns.md
    │   │   ├── red_metrics_and_finops_analytics.md
    │   │   └── workbook_resource_architecture.md
    │   └── resources/
    │       └── kql-workbook-snippets-cheatsheet.md
    ├── modern-bicep-deployment-stacks-and-lifecycle/
    │   ├── SKILL.md
    │   ├── examples/
    │   ├── references/
    │   └── resources/
    └── modern-bicep-testing-and-ci-cd/
        ├── SKILL.md
        ├── examples/
        ├── references/
        └── resources/
```
