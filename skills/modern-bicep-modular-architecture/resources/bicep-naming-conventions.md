# Azure Cloud Adoption Framework (CAF) Resource Naming Standards

Adhering to consistent resource naming prevents confusion, eases cost management, and enforces governance across enterprise Azure subscriptions.

---

## 1. The Standard Naming Formula

```text
<resource-type>-<workload/app>-<environment>-<region-short>-<instance>
```

### Components

1. **Resource Type Prefix**: 2–5 letter standardized abbreviation (e.g., `vnet`, `kv`, `st`, `cae`, `app`).
2. **Workload / Application**: Short name of the system or capability (e.g., `billing`, `identity`, `core`).
3. **Environment**: `dev`, `test`, `qa`, `staging`, `prod`.
4. **Region Shortcode**: Abbreviated Azure region (e.g., `eus` for East US, `weu` for West Europe, `bra` for Brazil South).
5. **Instance**: 2-digit zero-padded index (`01`, `02`).

---

## 2. Resource Abbreviation Matrix

| Azure Resource | Resource Type Abbreviation | Example Name | Rules / Constraints |
| :--- | :--- | :--- | :--- |
| **Resource Group** | `rg-` | `rg-billing-prod-eus-01` | 1–90 chars, alphanumeric + hyphens |
| **Virtual Network** | `vnet-` | `vnet-core-prod-eus-01` | 2–64 chars, alphanumeric + hyphens |
| **Subnet** | `snet-` | `snet-compute-01` | 1–80 chars |
| **Network Security Group** | `nsg-` | `nsg-compute-prod-eus-01` | 1–80 chars |
| **Storage Account** | `st` (no hyphens) | `stbillingprodeus01` | 3–24 chars, lowercase alphanumeric ONLY |
| **Key Vault** | `kv-` | `kv-billing-prod-eus-01` | 3–24 chars, alphanumeric + hyphens |
| **Container App Environment** | `cae-` | `cae-billing-prod-eus-01` | 1–64 chars |
| **Container App** | `ca-` | `ca-billing-api-prod-01` | 1–32 chars, lowercase alphanumeric + hyphens |
| **User-Assigned Identity** | `id-` | `id-billing-worker-prod-01`| 3–128 chars |
| **Log Analytics Workspace** | `log-` | `log-ops-prod-eus-01` | 4–63 chars |
| **Application Insights** | `appi-` | `appi-billing-prod-eus-01` | 1–260 chars |
| **Azure Cosmos DB** | `cosmos-` | `cosmos-billing-prod-01` | 3–44 chars, lowercase |
| **Azure SQL Database Server** | `sql-` | `sql-billing-prod-eus-01` | 1–63 chars, lowercase |
| **Private Endpoint** | `pe-` | `pe-kv-billing-prod-01` | 2–80 chars |
| **Private DNS Zone** | `pdnsz-` | `privatelink.vaultcore.azure.net` | Standard FQDN |
