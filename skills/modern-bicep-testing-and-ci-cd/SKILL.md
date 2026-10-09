---
name: modern-bicep-testing-and-ci-cd
description: >-
  Use this skill when implementing automated validation, testing, and CI/CD pipelines for Azure Bicep:
  bicepconfig.json linter enforcement, PSRule for Azure Well-Architected Framework (WAF) static analysis,
  passwordless OIDC Workload Identity Federation (GitHub Actions and Azure DevOps), automated PR What-If diff commenting,
  and the mandatory living README.md runbook documentation discipline.
---

# Modern Azure Bicep Testing, Quality Gates & CI/CD Pipelines

This skill provides comprehensive architectural guidelines, testing practices, and pipeline recipes for building robust, passwordless, multi-gate CI/CD pipelines for Azure Bicep.

---

## Core Principles

1. **Shift-Left Quality Gate Pyramid**:
   - Validate infrastructure code across four progressive quality gates before deploying to production:
     ```text
     ┌────────────────────────────────────────────────────────┐
     │ Gate 4: Deployment Stack Apply (Atomic rollout & deny) │
     ├────────────────────────────────────────────────────────┤
     │ Gate 3: Pre-Flight What-If & Automated PR Diff Review  │
     ├────────────────────────────────────────────────────────┤
     │ Gate 2: PSRule for Azure (WAF Compliance & Security)   │
     ├────────────────────────────────────────────────────────┤
     │ Gate 1: Bicep Format & Strict Linter (bicepconfig.json)│
     └────────────────────────────────────────────────────────┘
     ```

2. **Strict Bicep Linter Configuration (`bicepconfig.json`)**:
   - Every Bicep repository MUST maintain a root `bicepconfig.json` file.
   - Enforce zero tolerance for linter warnings in CI/CD by configuring critical analyzer rules as `error` or running `az bicep build` with strict warning handling:
     - `no-hardcoded-env-urls`
     - `no-unused-params`, `no-unused-vars`
     - `secure-parameter-default`
     - `use-recent-api-versions`
     - `use-resource-id-functions`
   - Enforce code formatting with `az bicep format`.

3. **PSRule for Azure (Well-Architected Framework Compliance)**:
   - Run **PSRule for Azure** in automated pipelines to assert adherence to Microsoft's Well-Architected Framework (WAF).
   - Catch insecure defaults before deployment: missing diagnostic settings, unencrypted disks, public PaaS endpoints, missing tags, or non-zone-redundant SKUs.
   - Output SARIF results directly into GitHub Advanced Security or pipeline test tabs.

4. **Passwordless OIDC Workload Identity Federation**:
   - Abolish static service principal client secrets (`AZURE_CREDENTIALS` JSON with secret passwords).
   - Configure **OpenID Connect (OIDC)** federated credentials in Microsoft Entra ID linked directly to GitHub Actions repository branches/environments or Azure DevOps service connections.
   - Authenticate with short-lived tokens using `azure/login@v2` with `client-id`, `tenant-id`, and `subscription-id`.

5. **Automated Pull Request What-If Diff Commenting**:
   - In PR workflows, pipelines must execute What-If analysis and format the output into clean markdown.
   - Automatically post or update the What-If summary as a comment on the active Pull Request, enabling peer reviewers to inspect the exact predicted Azure mutations prior to merging.

6. **Mandatory Dedicated Living `README.md` Runbook**:
   - Every directory or repository housing Bicep infrastructure code MUST maintain a dedicated, up-to-date `README.md` living runbook.
   - Any pull request or commit that introduces, alters, or removes Bicep templates, modules, parameters, or deployment procedures MUST synchronize this `README.md` in the exact same commit.

---

## Detailed Topic Guides

1. **Bicep Linting & Analyzer Rules (`bicepconfig.json`)**:
   - Analyzer rules reference and severity levels (`error`, `warning`, `off`).
   - Formatting standards with `az bicep format`.
   - [Read Guide](./references/bicep_linting_and_analyzer_rules.md)

2. **Static Analysis with PSRule for Azure**:
   - Integrating PSRule in GitHub Actions and Azure DevOps.
   - WAF alignment (Security, Reliability, Cost, Operational Excellence).
   - Suppressions and baseline configurations.
   - [Read Guide](./references/static_analysis_psrule_and_arm_ttk.md)

3. **CI/CD Pipelines with OIDC & Workload Identity Federation**:
   - Entra ID app registration federated credentials setup.
   - GitHub Actions workflow blueprint with What-If PR commenting.
   - Azure DevOps YAML pipeline blueprint.
   - [Read Guide](./references/cicd_pipelines_and_oidc.md)

4. **IaC Living Runbook Documentation Mandate**:
   - Standard runbook structure and operational sections.
   - Atomic PR synchronization checklist.
   - [Read Guide](./references/iac_living_readme_runbook.md)

---

## Blueprint Example: GitHub Actions Pipeline with OIDC & What-If

```yaml
name: "Bicep Infrastructure Pipeline"

on:
  pull_request:
    branches: [main]
    paths:
      - "infra/**"
  push:
    branches: [main]
    paths:
      - "infra/**"

permissions:
  id-token: write
  contents: read
  pull-requests: write

jobs:
  validate:
    name: "Lint & Validate"
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: "Azure CLI Login via OIDC"
        uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - name: "Lint Bicep Templates"
        run: |
          az bicep build --file infra/main.bicep

      - name: "Run PSRule for Azure"
        uses: microsoft/ps-rule@v2.9.0
        with:
          modules: "PSRule.Rules.Azure"
          inputType: "repository"

      - name: "What-If Analysis"
        id: whatif
        run: |
          OUTPUT=$(az stack group create \
            --name stack-billing-prod \
            --resource-group rg-billing-prod \
            --template-file infra/main.bicep \
            --parameters infra/main.bicepparam \
            --action-on-unmanage "deleteResources" \
            --deny-settings-mode "denyWriteAndDelete" \
            --what-if \
            --no-pretty-print)
          echo "whatif_output<<EOF" >> $GITHUB_OUTPUT
          echo "$OUTPUT" >> $GITHUB_OUTPUT
          echo "EOF" >> $GITHUB_OUTPUT

      - name: "Comment What-If on PR"
        if: github.event_name == 'pull_request'
        uses: actions/github-script@v7
        with:
          script: |
            const output = `### 🔍 Bicep What-If Deployment Preview\n\`\`\`text\n${{ steps.whatif.outputs.whatif_output }}\n\`\`\``;
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: output
            });
```
