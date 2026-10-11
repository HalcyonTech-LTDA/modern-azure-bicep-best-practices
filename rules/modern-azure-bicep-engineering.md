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
| **Modular Architecture & Contracts** | `modern-bicep-modular-architecture` | AVM compliance, User-Defined Types (`type`), `.bicepparam` parameter files, registry distribution, and deterministic scopes. |
| **Security, Identity & Governance** | `modern-bicep-security-and-governance` | Zero plain-text secrets, `@secure()` discipline, Managed Identities, deterministic RBAC `guid()`, and network isolation. |
| **Deployment Stacks & Lifecycle** | `modern-bicep-deployment-stacks-and-lifecycle` | Azure Deployment Stacks (`az stack`), deny settings (`denyWriteAndDelete`), cleanup via `actionOnUnmanage`, and What-If analysis. |
| **Testing, Quality Gates & CI/CD** | `modern-bicep-testing-and-ci-cd` | Strict linter (`bicepconfig.json`), PSRule WAF gates, passwordless OIDC authentication, and living `README.md` runbooks. |

---

## Non-Negotiable Guardrails (Absolute Invariants)

1. **Mandatory Native `.bicepparam` & User-Defined Types (UDT)**: Prohibit legacy JSON parameter files (`*.parameters.json`) and weakly typed `object`/`array` parameters. Define explicit compile-time schemas via User-Defined Types (`type`).
2. **Azure Verified Modules (AVM) & Version Pinning**: Reusable modules must adhere to AVM specifications and be published to/consumed from private or public Bicep registries with immutable semantic version tags.
3. **Zero Plain-Text Secrets & State Leakage**: Never hardcode credentials in templates or parameters; annotate sensitive parameters with `@secure()` and eliminate outputting secrets. Authenticate services exclusively via Managed Identities and Key Vault references.
4. **Least-Privilege RBAC & Network Isolation by Default**: Scope role assignments narrowly using deterministic `guid()` seeds. Production PaaS services must disable public network access (`publicNetworkAccess: 'Disabled'`) in favor of Private Endpoints and Private DNS Zones.
5. **Atomic Lifecycle via Azure Deployment Stacks**: Prohibit loose unmanaged ARM/Bicep deployments in production. Mandate Azure Deployment Stacks configured with tampering prevention (`denySettingsMode`) and clean resource cleanup (`actionOnUnmanage`).
6. **Deterministic Quality Gates & Living Documentation**: Automated pipelines must enforce strict linter rules, PSRule for Azure WAF validation, passwordless OIDC credentials, and pre-flight What-If checks. Maintain and synchronize a dedicated living `README.md` in every atomic infrastructure commit.

Consult the corresponding specialized skills for comprehensive architectural patterns, code blueprints, configuration templates, and testing runbooks.
