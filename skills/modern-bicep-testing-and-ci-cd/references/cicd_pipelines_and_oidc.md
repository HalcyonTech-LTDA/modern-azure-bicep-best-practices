# CI/CD Pipelines & Passwordless OIDC Authentication

This guide covers setting up modern, passwordless Continuous Integration and Continuous Deployment (CI/CD) pipelines for Azure Bicep using GitHub Actions and Azure DevOps via OpenID Connect (OIDC) Workload Identity Federation.

---

## 1. Why Passwordless OIDC?

Historically, CI/CD pipelines authenticated to Azure using a Service Principal with a client secret (password) stored in repository secrets.

### Vulnerabilities of Client Secrets:
- Secret rotation is painful, leading to expired keys halting production pipelines.
- Secrets can be printed accidentally in pipeline debug logs.
- Anyone with repository admin rights could exfiltrate the secret.

### The OIDC Solution:
With OpenID Connect (OIDC) Workload Identity Federation:
- No passwords or secrets are stored in GitHub or Azure DevOps.
- The pipeline requests a short-lived OIDC JSON Web Token (JWT) from GitHub/Azure DevOps.
- Azure Entra ID validates the token's claims (`sub`, `iss`, `aud`) against a pre-configured federated credential.
- Entra ID returns a temporary Azure access token valid only for that pipeline job.

---

## 2. Setting Up Federated Credentials in Microsoft Entra ID

### Using Azure CLI:

```bash
# 1. Create App Registration
APP_ID=$(az ad app create --display-name "github-actions-bicep-prod" --query appId -o tsv)

# 2. Create Service Principal
az ad sp create --id "${APP_ID}"

# 3. Add Federated Credential for GitHub Actions (Main Branch)
az ad app federated-credential create \
  --id "${APP_ID}" \
  --parameters '{
    "name": "gh-actions-main-branch",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:my-org/my-bicep-repo:ref:refs/heads/main",
    "description": "Deployment from main branch",
    "audiences": ["api://AzureADTokenExchange"]
  }'

# 4. Add Federated Credential for Pull Requests
az ad app federated-credential create \
  --id "${APP_ID}" \
  --parameters '{
    "name": "gh-actions-pull-request",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:my-org/my-bicep-repo:pull_request",
    "description": "Validation on pull requests",
    "audiences": ["api://AzureADTokenExchange"]
  }'
```

---

## 3. GitHub Actions Authentication Recipe

```yaml
permissions:
  id-token: write # Required for requesting OIDC token
  contents: read

steps:
  - name: "Azure Login via OIDC"
    uses: azure/login@v2
    with:
      client-id: ${{ vars.AZURE_CLIENT_ID }}
      tenant-id: ${{ vars.AZURE_TENANT_ID }}
      subscription-id: ${{ vars.AZURE_SUBSCRIPTION_ID }}
```

---

## 4. Azure DevOps Workload Identity Federation

In Azure DevOps:
1. Go to **Project Settings** -> **Service connections**.
2. Select **Azure Resource Manager** -> **Workload Identity federation (automatic)**.
3. Azure DevOps configures the Entra ID application registration and federated credential automatically.
4. Consume in YAML pipelines using the `AzureCLI@2` task:

```yaml
steps:
  - task: AzureCLI@2
    inputs:
      azureSubscription: 'sc-azure-prod-federated'
      scriptType: 'bash'
      scriptLocation: 'inlineScript'
      inlineScript: |
        az stack group create ...
```
