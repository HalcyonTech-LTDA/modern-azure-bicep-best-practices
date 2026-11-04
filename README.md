<div align="center">

<a href="https://www.halcyontech.com.br/" target="_blank" rel="noopener noreferrer">
  <img src="assets/halcyon-horizontal-cor.svg" alt="Halcyon Tech" height="60">
</a>

# Modern Azure Bicep Best Practices Plugin
### Enterprise Infrastructure as Code Engineering & Azure Architecture Standards

[![Antigravity Plugin](https://img.shields.io/badge/Antigravity-Plugin%20v1.0.0-4F46E5.svg)](https://antigravity.google)
[![License: MIT](https://img.shields.io/badge/License-MIT-10B981.svg)](./LICENSE)
[![Website](https://img.shields.io/badge/Website-halcyontech.com.br-008080.svg)](https://www.halcyontech.com.br/)
[![Organization](https://img.shields.io/badge/Organization-HalcyonTech--LTDA-black.svg)](https://github.com/HalcyonTech-LTDA)

<p align="center">
  <b>Professional modern Azure Bicep engineering best practices covering modular architecture & AVM, User-Defined Types (UDT) and .bicepparam parameter files, zero-secrets security & Managed Identity RBAC, Container Apps & Jobs microservice topologies, Cosmos DB MongoDB API autoscale throughput governance, API Management external VNet & XML policies (rate limiting, Entra ID JWT, RFC 6648 idempotency), Azure Monitor Workbooks & FinOps telemetry, Azure Deployment Stacks lifecycle & drift governance, multi-gate CI/CD with OIDC, PSRule/linter validation, and mandatory living README.md runbook documentation discipline.</b>
</p>

</div>

---

## Installation & Verification

### Antigravity CLI (`agy`)

Install directly into your Antigravity environment via the CLI:

```bash
agy plugin install https://github.com/HalcyonTech-LTDA/modern-azure-bicep-best-practices
```

Verify that the plugin is active and adheres to the strict official schema:

```bash
agy plugin list
agy plugin validate --strict ./modern-azure-bicep-best-practices
```

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

---

## What's Included (Component Catalog)

### Contextual Rules (`rules/`)
Automatically loaded to govern and protect project contexts:
- **[`modern-azure-bicep-engineering.md`](rules/modern-azure-bicep-engineering.md)**: >-

### Procedural Skills (`skills/`)
On-demand actionable workflows and runbooks:
- **[`/modern-bicep-api-management-and-policies`](skills/modern-bicep-api-management-and-policies/SKILL.md)**: Use this skill when designing, authoring, or refactoring Azure API Management (APIM) and XML Policy Engine in Bicep: external VNet injection, internal Container Apps backends, Products, APIs, typed Operations, W3C distributed tracing (App Insights loggers & diagnostics), and XML policies: route-based rate limiting (<rate-limit-by-key>), Entra ID OAuth JWT validation (<validate-jwt>), RFC 6648 idempotency validation & response caching (<cache-lookup-value>/<cache-store-value>), backend timeouts (<forward-request>), URI rewrites, and health probe bypassing.
- **[`/modern-bicep-container-apps-and-jobs`](skills/modern-bicep-container-apps-and-jobs/SKILL.md)**: Use this skill when designing, authoring, or refactoring Azure Container Apps and Container Apps Jobs in Bicep: microservice topologies, background worker isolation (ShedLock), scheduled cron jobs (Schedule trigger), manual triggered migration jobs (Manual trigger), VNet internal ingress with IP security restrictions (ipSecurityRestrictions for APIM subnet), partner mock server choreography (scale-to-zero in uat/prod), dynamic Key Vault secretRef wiring, and container resource quotas.
- **[`/modern-bicep-cosmos-db`](skills/modern-bicep-cosmos-db/SKILL.md)**: Use this skill when designing, authoring, or refactoring Azure Cosmos DB (especially MongoDB API) in Bicep: MongoDB API kind ('MongoDB'), server version 7.0, session consistency, autoscale collection throughput settings (throughputSettings RU/s) decoupled from collection provisioning, periodic vs continuous backup policies, private endpoints with privatelink.mongo.cosmos.azure.com DNS, and secure connection string export via @secure() and listConnectionStrings().
- **[`/modern-bicep-deployment-stacks-and-lifecycle`](skills/modern-bicep-deployment-stacks-and-lifecycle/SKILL.md)**: Use this skill when managing cloud infrastructure lifecycles and governance with Azure Deployment Stacks: atomic stack lifecycle management, drift & tampering prevention with Deny Settings (denyWriteAndDelete, denyWrite), orphaned resource elimination with Action on Unmanage (delete vs detach), What-If pre-flight validation, multi-scope orchestration (Management Group, Subscription, Resource Group), and dependency graph optimization.
- **[`/modern-bicep-modular-architecture`](skills/modern-bicep-modular-architecture/SKILL.md)**: Use this skill when designing, authoring, or refactoring modular Azure Bicep codebases: Azure Verified Modules (AVM) compliance, User-Defined Types (UDT with type keyword), User-Defined Functions (func keyword), native .bicepparam parameter files, private/public Bicep Registries (ACR/MCR), multi-scope deployments (Tenant, Management Group, Subscription, Resource Group), child/extension resources, and deterministic loops.
- **[`/modern-bicep-security-and-governance`](skills/modern-bicep-security-and-governance/SKILL.md)**: Use this skill when implementing security, identity, access control, and compliance in Azure Bicep: zero plain-text secrets, @secure() decorator discipline, Azure Key Vault integration, Managed Identities (User-Assigned & System-Assigned), granular RBAC with deterministic guid() role assignments, network isolation (Private Endpoints, Private DNS Zones, disabling public network access), Customer-Managed Keys (CMK), and Azure Policy as Code.
- **[`/modern-bicep-testing-and-ci-cd`](skills/modern-bicep-testing-and-ci-cd/SKILL.md)**: Use this skill when implementing automated validation, testing, and CI/CD pipelines for Azure Bicep: bicepconfig.json linter enforcement, PSRule for Azure Well-Architected Framework (WAF) static analysis, passwordless OIDC Workload Identity Federation (GitHub Actions and Azure DevOps), automated PR What-If diff commenting, and the mandatory living README.md runbook documentation discipline.
- **[`/modern-bicep-workbooks-and-observability`](skills/modern-bicep-workbooks-and-observability/SKILL.md)**: Use this skill when designing, authoring, or refactoring Azure Monitor Workbooks and Observability in Bicep: Microsoft.Insights/workbooks resource modeling, deterministic GUID resource naming with guid(), hybrid KQL queries (union isfuzzy=true across Application Insights and Log Analytics Workspace), serialized JSON dashboard specification (string(workbookContent)), timeContext parameterization, RED metrics (Rate, Errors, Duration) panels, and FinOps unit economics (Cosmos RU/s per 1,000 requests).

---

## Directory Hierarchy

```text
modern-azure-bicep-best-practices/
├── plugin.json              # Official Antigravity manifest (schema v1)
├── LICENSE                  # MIT License (Copyright 2026 HalcyonTech LTDA)
├── .gitignore               # System ignores & installed_version.json exclusions
├── .gitattributes           # Deterministic line endings (* text=auto eol=lf)
├── README.md                # Golden Standard documentation & runbook
├── assets/
│   ├── logo.svg             # Antigravity marketplace square icon
│   └── halcyon-horizontal-cor.svg # Official Halcyon Tech brand logo (white background)             # Official Halcyon Tech corporate vector symbol
├── rules/                   # Contextual rules discovered automatically
│   └── modern-azure-bicep-engineering.md
├── skills/                  # Actionable procedural skills (Progressive Disclosure)
│   └── modern-bicep-api-management-and-policies/
│       └── SKILL.md
│   └── modern-bicep-container-apps-and-jobs/
│       └── SKILL.md
│   └── modern-bicep-cosmos-db/
│       └── SKILL.md
│   └── modern-bicep-deployment-stacks-and-lifecycle/
│       └── SKILL.md
│   └── modern-bicep-modular-architecture/
│       └── SKILL.md
│   └── modern-bicep-security-and-governance/
│       └── SKILL.md
│   └── modern-bicep-testing-and-ci-cd/
│       └── SKILL.md
│   └── modern-bicep-workbooks-and-observability/
│       └── SKILL.md
```

---

## 💡 Prompt Recipes & Use Cases

```markdown
- "Refactor this Azure Bicep module to follow modern IaC conventions"
- "Validate security parameters, tagging, and resource naming in Bicep"
- "Generate automated deployment and parameter files for Azure Bicep"
```

---

## 📄 License & Corporate Governance

Distributed under the **MIT License**. Copyright (c) 2026 **HalcyonTech LTDA**.  
Engineered with precision and excellence by [Halcyon Tech](https://www.halcyontech.com.br/) &mdash; [GitHub Organization](https://github.com/HalcyonTech-LTDA).
