---
description: >-
  Automatically enforces modern Azure Bicep engineering standards: Azure Verified Modules (AVM),
  User-Defined Types (UDT), .bicepparam parameter files, zero-secrets security with Managed Identities and Key Vault,
  granular least-privilege RBAC, Azure Deployment Stacks lifecycle & drift governance, What-If pre-flight verification,
  PSRule & bicepconfig linter quality gates, and mandatory living README.md runbook documentation.
trigger: model_decision
---

# Modern Azure Bicep Engineering Guardrails & Skill Router

When authoring, reviewing, refactoring, or deploying Azure infrastructure using Bicep, strictly adhere to Modern Azure Bicep Engineering Standards and the corresponding specialized skills:

| When working on... | Consult & Activate Skill | Key Focus Areas |
| :--- | :--- | :--- |
| **Modular Architecture & Contracts** | `modern-bicep-modular-architecture` | Azure Verified Modules (AVM), User-Defined Types (`type`), User-Defined Functions (`func`), `.bicepparam` parameter files, registry distribution (Public MCR & Private ACR), scoping, and child/extension resources. |
| **Security, Identity & Governance** | `modern-bicep-security-and-governance` | Zero plain-text secrets, `@secure()` decorator discipline, Azure Key Vault references, Managed Identities (User-Assigned vs System-Assigned), granular RBAC with deterministic `guid()`, network isolation (Private Endpoints & disabled public access), and CMK encryption. |
| **Deployment Stacks & Lifecycle** | `modern-bicep-deployment-stacks-and-lifecycle` | Azure Deployment Stacks (`az stack`), deny settings (`denySettingsMode: denyWriteAndDelete` / `denyWrite`), cleanup with `actionOnUnmanage`, What-If pre-flight analysis, multi-scope governance, and implicit dependency optimization. |
| **Testing, Quality Gates & CI/CD** | `modern-bicep-testing-and-ci-cd` | Strict linter rules (`bicepconfig.json`), PSRule for Azure Well-Architected Framework compliance, ARM-TTK, passwordless OIDC Workload Identity Federation in GitHub Actions and Azure DevOps, PR What-If diff commenting, and mandatory living `README.md` runbooks. |

---

## Non-Negotiable Guardrails (Absolute Invariants)

1. **Mandatory `.bicepparam` over Deprecated JSON Parameter Files**:
   - Never generate or use legacy ARM JSON parameter files (`*.parameters.json`) for new Bicep templates.
   - Mandate native Bicep parameters files (`.bicepparam`) using the `using '<template>.bicep'` declaration.
   - Leverage native Bicep expressions, environment variables via `readEnvironmentVariable()`, and secure Key Vault references inside `.bicepparam`.

2. **Strict Compile-Time Typing with User-Defined Types (UDT)**:
   - Absolute ban on weakly typed `object` or `array` parameters without schema definitions when passing structured configurations.
   - Define formal User-Defined Types using the `type` statement with tagged unions, string literal unions, nullable modifiers (`?`), and property-level `@description()` decorators.
   - Leverage `@sealed()` on object types where unexpected extra properties must be rejected at compile time.

3. **Azure Verified Modules (AVM) Alignment & Registry Distribution**:
   - Reusable infrastructure modules MUST conform to Azure Verified Modules (AVM) specifications (standardized parameter names like `name`, `location`, `tags`, output contracts, and telemetry toggles).
   - In enterprise repositories, publish and consume modules via versioned Bicep Registries (Azure Container Registry: `br:<acr-name>.azurecr.io/bicep/modules/<module>:<version>` or public MCR: `br/public:avm/...`).
   - Pin immutable semantic version tags for all remote modules; never consume floating or untracked module versions.

4. **Absolute Ban on Hardcoded Secrets & State Leakage**:
   - Never commit passwords, client secrets, connection strings, certificates, or storage keys into Bicep templates, `.bicepparam` files, or source control.
   - All sensitive parameters MUST be decorated with `@secure()`.
   - Never output `@secure()` parameters or sensitive connection strings in template `output` blocks.
   - Pass secrets to downstream services via direct Azure Key Vault references (`getSecret` in `.bicepparam` or Key Vault secret resource IDs) or eliminate them entirely using Managed Identity.

5. **Mandatory Managed Identity & Elimination of Service Credentials**:
   - Services deployed to Azure MUST authenticate to other Azure services (Key Vault, Storage, Cosmos DB, Service Bus, Azure SQL) via Azure Managed Identities (prefer User-Assigned Managed Identity for deterministic lifecycles across resources).
   - Eliminate shared keys, SAS tokens, and database passwords from infrastructure definitions in favor of Entra ID token-based authentication.

6. **Granular Least-Privilege RBAC with Deterministic GUIDs**:
   - Declarative role assignments (`Microsoft.Authorization/roleAssignments`) MUST use deterministic, collision-resistant GUIDs generated via the `guid()` function (e.g., `guid(resourceGroup().id, principalId, roleDefinitionId)`).
   - Scope role assignments to the narrowest possible resource boundary (resource level or resource group level; never root subscription unless managing policies or management groups).
   - Reference built-in Azure RBAC roles using standard role definition GUIDs rather than creating broad `Contributor` or `Owner` assignments.

7. **Network Isolation by Default on PaaS Services**:
   - Production PaaS resources (Key Vault, Storage Accounts, Azure SQL, Cosmos DB, ACR) MUST explicitly set `publicNetworkAccess: 'Disabled'`.
   - Integrate workloads into Azure Virtual Networks using Private Endpoints (`Microsoft.Network/privateEndpoints`) and Private DNS Zones (`Microsoft.Network/privateEndpoints/privateDnsZoneGroups`).
   - Restrict Network Security Groups (NSGs) with default-deny inbound rules and allow only explicit application ports.

8. **Mandatory Azure Deployment Stacks over Loose Deployments**:
   - Do NOT run loose, unmanaged ARM/Bicep deployments (`az deployment group create`) in production environments.
   - Mandate **Azure Deployment Stacks** (`az stack group create` or `az stack sub create`) to treat infrastructure as an atomically managed unit.
   - Enforce drift and tampering protection using `denySettingsMode: 'denyWriteAndDelete'` or `'denyWrite'`.
   - Configure clean resource lifecycle cleanup via `actionOnUnmanage: { resources: 'delete', resourceGroups: 'delete' }` to prevent orphaned, lingering resources.

9. **Mandatory Pre-Flight What-If Execution in CI/CD**:
   - Every automated pipeline MUST execute What-If analysis (`az deployment group what-if` or `az stack group create --action-on-unmanage ... --what-if`) before applying any infrastructure changes.
   - In Pull Request workflows, pipe the formatted What-If change summary directly as a PR comment to guarantee transparent peer review before merge.
   - Zero deployments may proceed without automated verification of predicted resource creations, modifications, and deletions.

10. **Passwordless CI/CD Authentication with OIDC / Workload Identity Federation**:
    - CI/CD pipelines (GitHub Actions, Azure DevOps) MUST authenticate to Azure using OpenID Connect (OIDC) federated credentials.
    - Absolute ban on storing long-lived service principal client secrets (`AZURE_CREDENTIALS` JSON blobs with secret passwords) in repository secrets or pipeline variable groups.

11. **Deterministic Static Analysis Quality Gates (Linter & PSRule)**:
    - Infrastructure codebases MUST include a root `bicepconfig.json` configuring Bicep analyzer rules with strict quality levels (warnings treated as errors in CI).
    - Validate Bicep templates against the Microsoft Well-Architected Framework (WAF) using PSRule for Azure before deploying.
    - Format all Bicep templates using `az bicep format` to ensure deterministic syntax indentation and style.

12. **Mandatory Dedicated Living `README.md` Runbook**:
    - Every directory or repository housing Bicep infrastructure code MUST maintain a dedicated, up-to-date `README.md` living runbook.
    - Any pull request or commit that introduces, alters, or removes Bicep templates, modules, parameters, or deployment procedures MUST synchronize this `README.md` in the exact same commit.
    - The runbook must document architecture topologies, parameter contracts, Deployment Stack commands, RBAC matrices, and disaster recovery procedures.

---

Consult the corresponding specialized skills for comprehensive architectural patterns, code blueprints, configuration templates, and testing runbooks.
