---
name: modern-azure-bicep-engineering
description: "Automatically enforces modern Azure Bicep engineering standards: Azure Verified Modules (AVM), User-Defined Types (UDT), .bicepparam parameter files, zero-secrets security with Managed Identities and Key Vault, granular least-privilege RBAC, Azure Deployment Stacks lifecycle & drift governance, What-If pre-flight verification, PSRule & bicepconfig linter quality gates, and mandatory living README.md runbook documentation."
---

# Modern Azure Bicep Engineering Guardrails & Skill Router

Entry point for this plugin's guardrails in Claude Code. Before acting, read the full standard:

`${CLAUDE_PLUGIN_ROOT}/rules/modern-azure-bicep-engineering.md`

It routes each kind of task to the specialized skill of this plugin and lists the non-negotiable rules.
In Claude Code those skills are namespaced: invoke `modern-azure-bicep-best-practices:<skill-name>`.

> Generated from `rules/modern-azure-bicep-engineering.md`, which is also the Antigravity rule. Edit the rule, not this file.
