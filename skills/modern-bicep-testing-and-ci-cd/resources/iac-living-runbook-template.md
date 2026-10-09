# Infrastructure Living Runbook: [Workload Name]

This runbook documents the architecture, parameters, deployment procedures, and recovery operations for the **[Workload Name]** Azure infrastructure.

---

## 1. System Under Management & Architecture

### Topology Overview
Brief description of the workload, network topology, and deployed services:
- **Networking**: Hub-Spoke VNet (`10.0.0.0/16`) with private endpoints.
- **Compute**: Azure Container Apps environment with User-Assigned Managed Identity.
- **Security**: Hardened Azure Key Vault with RBAC and private DNS zones.

### Architecture Diagram
```text
[ Internet / Clients ]
       │
       ▼ (Private VNet Ingress)
┌────────────────────────────────────────────────────────┐
│ Virtual Network: vnet-[workload]-[env]                │
│                                                        │
│  ┌────────────────────┐      ┌──────────────────────┐  │
│  │ snet-compute       │      │ snet-infra           │  │
│  │  [Container App]   │─────▶│  [Private Endpoints] │  │
│  └────────────────────┘      └──────────┬───────────┘  │
└─────────────────────────────────────────┼──────────────┘
                                          ▼
                            ┌────────────────────────┐
                            │ Azure Key Vault (PaaS) │
                            │  (No Public Access)    │
                            └────────────────────────┘
```

---

## 2. Directory Architecture Tree

```text
infra/
├── bicepconfig.json            # Compiler linter rules and module aliases
├── README.md                   # THIS living runbook (synchronized in every PR)
├── main.bicep                  # Root orchestrator
├── env/
│   ├── dev.bicepparam          # Development tier parameters
│   ├── staging.bicepparam      # Staging tier parameters
│   └── prod.bicepparam         # Production tier parameters
└── modules/
    ├── network/                # Modular network and NSG definitions
    └── compute/                # Container App and compute definitions
```

---

## 3. Environment & Parameter Contracts Matrix

| Parameter | Type | Required | Dev Value | Prod Value | Source / Notes |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `environment` | `string` | **Yes** | `'dev'` | `'prod'` | Allowed: `dev`, `staging`, `prod` |
| `orgPrefix` | `string` | **Yes** | `'hlc'` | `'hlc'` | 2–6 characters |
| `workloadName`| `string` | **Yes** | `'billing'` | `'billing'` | Resource naming key |
| `subnets` | `SubnetSpec[]` | **Yes** | `10.0.1.0/24`... | `10.0.1.0/24`... | Strongly typed array |

---

## 4. Execution Runbook

### Prerequisites
- Azure CLI `>= 2.60.0`
- Bicep CLI `>= 0.30.0`
- Active Azure Login with target subscription selected:
  ```bash
  az account set --subscription "<subscription-id>"
  ```

### Step 1: Local Linting & Formatting
```bash
# Format code
az bicep format --file main.bicep

# Compile and lint
az bicep build --file main.bicep
```

### Step 2: Pre-Flight What-If Verification
```bash
az stack group create \
  --name "stack-[workload]-[env]" \
  --resource-group "rg-[workload]-[env]" \
  --template-file "main.bicep" \
  --parameters "env/[env].bicepparam" \
  --action-on-unmanage "deleteResources" \
  --deny-settings-mode "denyWriteAndDelete" \
  --what-if
```

### Step 3: Production Deployment
```bash
az stack group create \
  --name "stack-[workload]-[env]" \
  --resource-group "rg-[workload]-[env]" \
  --template-file "main.bicep" \
  --parameters "env/[env].bicepparam" \
  --action-on-unmanage "deleteResources" \
  --deny-settings-mode "denyWriteAndDelete" \
  --yes
```

---

## 5. Emergency Break-Glass & Teardown

If manual intervention is strictly required during an outage:
1. Use an identity listed in `denySettingsExcludedPrincipals`.
2. To unlock resources temporarily:
   ```bash
   az stack group create \
     --name "stack-[workload]-[env]" \
     --resource-group "rg-[workload]-[env]" \
     --template-file "main.bicep" \
     --parameters "env/[env].bicepparam" \
     --deny-settings-mode "none" \
     --yes
   ```
