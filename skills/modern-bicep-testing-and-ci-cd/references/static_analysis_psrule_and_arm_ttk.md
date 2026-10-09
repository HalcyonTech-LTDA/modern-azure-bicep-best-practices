# Static Analysis with PSRule for Azure & ARM-TTK

This guide details running PSRule for Azure and ARM Template Test Toolkit (ARM-TTK) to validate infrastructure against the Microsoft Well-Architected Framework (WAF).

---

## 1. What is PSRule for Azure?

**PSRule for Azure** is a static analysis engine that reads compiled ARM templates or Bicep source files and evaluates them against 400+ pre-configured Well-Architected Framework (WAF) best practice rules covering:
- **Security**: Disabling public endpoints, requiring TLS 1.2+, enforcing disk encryption.
- **Reliability**: Validating availability zone deployments, replica counts.
- **Cost Optimization**: Flagging oversized development SKUs.
- **Operational Excellence**: Validating diagnostic logging settings and tags.

---

## 2. Running PSRule Locally

```bash
# Install PSRule for Azure via PowerShell
Install-Module -Name PSRule.Rules.Azure -Scope CurrentUser

# Run analysis against Bicep files
Assert-PSRule -Module PSRule.Rules.Azure -InputPath ./infra
```

---

## 3. Configuring Baseline & Suppressions (`ps-rule.yaml`)

Create a `ps-rule.yaml` file in the repository root to configure company baselines or documented exceptions:

```yaml
# ps-rule.yaml
version: 1

binding:
  targetType:
    - type

execution:
  notProcessedWarning: false

configuration:
  # Enforce company standard tags
  AZURE_RESOURCE_TAGS:
    Environment:
      - dev
      - staging
      - prod
    ManagedBy:
      - Bicep
      - DeploymentStack

# Documented exceptions
rule:
  suppress:
    # Allow non-zone redundant storage account in dev environments
    Azure.Storage.UseReplication:
      - stdev*
```

---

## 4. ARM-TTK (ARM Template Test Toolkit)

The ARM Template Test Toolkit verifies foundational ARM engine compliance:
- Validates that parameters have descriptions.
- Ensures API versions are not preview versions in production.
- Verifies that secure parameters have no default values.

Run ARM-TTK in PowerShell:
```powershell
Import-Module ./arm-ttk/arm-ttk.psd1
Test-AzTemplate -TemplatePath ./infra/main.json
```
