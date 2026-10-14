---
description: >-
  Automatically enforces modern Azure Bicep engineering standards: Azure Verified Modules (AVM),
  User-Defined Types (UDT), .bicepparam parameter files, zero-secrets security with Managed Identities and Key Vault,
  granular least-privilege RBAC, Container Apps & Jobs, Cosmos DB MongoDB API, APIM & XML policies,
  Azure Monitor Workbooks, Azure Deployment Stacks lifecycle & drift governance, and living README.md runbooks.
trigger: model_decision
---

# Modern Azure Bicep Engineering Guardrails & Skill Router

When authoring, reviewing, refactoring, or deploying Azure infrastructure using Bicep, strictly adhere to Modern Azure Bicep Engineering Standards and the corresponding specialized skills:

| When working on... | Consult & Activate Skill | Key Focus Areas |
| :--- | :--- | :--- |
| **Modular Architecture & Contracts** | `modern-bicep-modular-architecture` | AVM compliance, User-Defined Types (`type`), `.bicepparam` parameter files, registry distribution, and deterministic scopes. |
| **Security, Identity & Governance** | `modern-bicep-security-and-governance` | Zero plain-text secrets, `@secure()` discipline, Managed Identities, deterministic RBAC `guid()`, and network isolation. |
| **Container Apps & Ephemeral Jobs** | `modern-bicep-container-apps-and-jobs` | Ingress IP restrictions (`snet-apim`), background ShedLock workers, scheduled/manual Jobs, scale-to-zero mocks, and secretRef wiring. |
| **Cosmos DB & Data Governance** | `modern-bicep-cosmos-db` | MongoDB API 7.0, session consistency, decoupled collection autoscale `throughputSettings` (RU/s), backup policies, and private DNS. |
| **API Management & XML Policies** | `modern-bicep-api-management-and-policies` | External VNet mode, ACA backends, W3C diagnostics, `<rate-limit-by-key>`, Entra ID `<validate-jwt>`, RFC 6648 idempotency, and timeouts. |
| **Workbooks & Observability** | `modern-bicep-workbooks-and-observability` | Deterministic GUID names, declarative `serializedData` objects, hybrid KQL (`union isfuzzy=true`), RED metrics, and FinOps unit economics. |
| **Deployment Stacks & Lifecycle** | `modern-bicep-deployment-stacks-and-lifecycle` | Azure Deployment Stacks (`az stack`), deny settings (`denyWriteAndDelete`), cleanup via `actionOnUnmanage`, and What-If analysis. |
| **Testing, Quality Gates & CI/CD** | `modern-bicep-testing-and-ci-cd` | Strict linter (`bicepconfig.json`), PSRule WAF gates, passwordless OIDC authentication, and living `README.md` runbooks. |

---

## Non-Negotiable Guardrails (Absolute Invariants)

1. **Mandatory Native `.bicepparam` & User-Defined Types (UDT)**: Prohibit legacy JSON parameter files (`*.parameters.json`) and weakly typed `object`/`array` parameters. Define explicit compile-time schemas via User-Defined Types (`type`).
2. **Azure Verified Modules (AVM) & Version Pinning**: Reusable modules must adhere to AVM specifications and be published to/consumed from private or public Bicep registries with immutable semantic version tags.
3. **Zero Plain-Text Secrets & State Leakage**: Never hardcode credentials in templates or parameters; annotate sensitive parameters with `@secure()` and eliminate outputting secrets. Authenticate services exclusively via Managed Identities and Key Vault references.
4. **Least-Privilege RBAC & Network Isolation by Default**: Scope role assignments narrowly using deterministic `guid()` seeds. Production PaaS services must disable public network access (`publicNetworkAccess: 'Disabled'`) in favor of Private Endpoints and Private DNS Zones.
5. **Microservice Ingress Restrictions & Worker Decoupling**: Container Apps REST APIs in internal CAE must restrict ingress strictly to the dedicated APIM subnet via `ipSecurityRestrictions`. Schedulers must omit ingress and pin single replicas (`minReplicas: 1, maxReplicas: 1`), while batch pipelines and migrations run as ephemeral Container Apps Jobs (`Microsoft.App/jobs`), and partner mocks scale to zero in non-dev environments.
6. **Decoupled Cosmos DB Throughput Governance**: For Cosmos DB MongoDB API (`kind: 'MongoDB'`), govern collection autoscale RU/s caps via dedicated `throughputSettings` extension resources decoupled from application migrations, stream platform metrics to Log Analytics via diagnostic settings for FinOps telemetry, and define explicit backup policies (`Continuous` or `Periodic`).
7. **APIM Route-Based Rate Limiting & RFC 6648 Idempotency**: Protect mutation APIs with mandatory `Idempotency-Key` headers, 24h caching returning `Idempotent-Replayed: true`, and tiered `<rate-limit-by-key>` dynamic expressions; bypass health probes (`/actuator/health`) from auth/rate limiting.
8. **Deterministic GUID Naming & Hybrid KQL for Workbooks**: `Microsoft.Insights/workbooks` resource names must strictly be valid GUIDs generated via `guid()`, with `serializedData` dashboard specs and `union isfuzzy=true` cold-start resilient KQL queries.
9. **Atomic Lifecycle via Azure Deployment Stacks**: Prohibit loose unmanaged ARM/Bicep deployments in production. Mandate Azure Deployment Stacks configured with tampering prevention (`denySettingsMode`) and clean resource cleanup (`actionOnUnmanage`).
10. **Deterministic Quality Gates & Living Documentation**: Automated pipelines must enforce strict linter rules, PSRule for Azure WAF validation, passwordless OIDC credentials, and pre-flight What-If checks. Maintain and synchronize a dedicated living `README.md` in every atomic infrastructure commit.

Consult the corresponding specialized skills for comprehensive architectural patterns, code blueprints, configuration templates, and testing runbooks.
