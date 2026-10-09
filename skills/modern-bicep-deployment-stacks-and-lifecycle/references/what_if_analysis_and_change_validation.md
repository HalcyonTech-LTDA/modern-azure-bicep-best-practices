# What-If Analysis & Pre-Flight Change Validation

This guide covers pre-flight change validation using ARM/Bicep What-If analysis, interpreting change operations, eliminating noise, and automating diff reporting in CI/CD.

---

## 1. What-If Execution Mechanics

The What-If operation evaluates the difference between the desired state in Bicep templates and the current state in Azure, without altering any resources.

### Command Invocations

```bash
# Standard Resource Group deployment What-If
az deployment group what-if \
  --resource-group rg-billing-prod \
  --template-file main.bicep \
  --parameters main.bicepparam

# Subscription-level What-If
az deployment sub what-if \
  --location eastus \
  --template-file landing-zone.bicep \
  --parameters landing-zone.bicepparam

# Deployment Stack What-If (including action-on-unmanage predictions!)
az stack group create \
  --name stack-billing \
  --resource-group rg-billing-prod \
  --template-file main.bicep \
  --parameters main.bicepparam \
  --action-on-unmanage "deleteResources" \
  --deny-settings-mode "denyWriteAndDelete" \
  --what-if
```

---

## 2. Interpreting Change Operations

What-If classifies predicted actions into 6 distinct operation types:

| Symbol / Type | Meaning | Risk Level |
| :--- | :--- | :--- |
| **`+ Create`** | Resource will be created as a new Azure resource. | Low |
| **`- Delete`** | Resource will be removed from Azure. | **High** (Review carefully for data loss) |
| **`~ Modify`** | Existing resource properties will be updated in-place. | Medium |
| **`* Deploy`** | Resource will be deployed, but changes cannot be determined. | Medium |
| **`x NoChange`** | Resource matches template exactly. No modification will occur. | None |
| **`! Ignore`** | Resource is not supported for What-If evaluation. | Low |

---

## 3. Filtering Noise & False Positives

Sometimes What-If reports false positives for properties managed dynamically by Azure (e.g., default tags or read-only metrics).

To suppress noise in automated scripts:
- Pass `--exclude-change-types Unsupported` to omit resources that do not support What-If evaluation.
- Output JSON format (`--result-format FullResourcePayloads` or `--output json`) for programmatic parsing in GitHub Actions or Azure DevOps pipelines.
