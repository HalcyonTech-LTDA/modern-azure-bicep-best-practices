# Azure Built-In RBAC Roles Cheatsheet

A curated reference of Azure Built-in Role Definition IDs commonly used when implementing declarative least-privilege security in Bicep.

---

## 1. Role Definition GUID Matrix

| Role Name | Role Definition ID (GUID) | Typical Use Case |
| :--- | :--- | :--- |
| **Key Vault Secrets User** | `4633458b-17de-408a-b874-0445c86b69e6` | Grants read access to secret contents without admin rights. Ideal for application managed identities. |
| **Key Vault Crypto User** | `12338081-198d-4476-aa5f-447c423ea692` | Perform cryptographic operations using Key Vault keys. Required for Customer-Managed Keys (CMK). |
| **Key Vault Secrets Officer** | `b86a8fe4-44ce-4948-aee5-ecc2b00b1d24` | Create, read, and delete Key Vault secrets. Ideal for CI/CD secret deployment pipelines. |
| **Key Vault Administrator** | `00482a5a-887f-4fb3-b363-3b7fe8e74483` | Full control over all Key Vault data-plane assets (keys, secrets, certificates). Reserved for Security Admins. |
| **Storage Blob Data Reader** | `2a2b9908-6ea1-4ae2-8e65-a410df84e7d1` | Read access to Azure Blob storage containers and blobs. |
| **Storage Blob Data Contributor**| `ba92f5b4-2d11-453d-a403-e96b0029c9fe`| Read, write, and delete access to Azure Blob storage containers and blobs. Standard for backend services. |
| **Storage Queue Data Contributor**| `974c5e8b-45b9-4653-a493-f0af8b307488`| Read, write, and delete access to Azure storage queues. Standard for worker queue processors. |
| **AcrPull** | `7f951dda-4ed3-4680-a7ca-43fe172d538d` | Pull container images from Azure Container Registry. Standard for AKS, Container Apps, App Service. |
| **AcrPush** | `8311e382-0749-4cb8-b61a-30fbab166057` | Push container images to Azure Container Registry. Standard for CI/CD container build agents. |
| **Azure Service Bus Data Receiver**| `4f6d3b9b-027b-4f4c-9142-0e5a2a2247e0`| Receive messages from Service Bus queues and subscriptions. |
| **Azure Service Bus Data Sender**  | `69a216fc-b8fb-44d8-bc22-1f3c2cd27a39`| Send messages to Service Bus queues and topics. |
| **App Configuration Data Reader**  | `516239f1-63e1-4378-a4b6-670fc9e69f76`| Read key-values from Azure App Configuration store. |
| **Monitoring Metrics Publisher**   | `3913510d-42f4-4e42-8a64-420c390055eb`| Publish custom metrics to Azure Monitor. |
| **Reader** | `acdd72a7-3385-48ef-bd42-f606fba81ae7` | View management-plane resources, without modifications. Standard for read-only auditor service principals. |
| **Contributor** | `b24988ac-6180-42a0-ab88-20f7382dd24c` | Full management access, excluding role assignments. Prohibited for narrow workload identities. |

---

## 2. Bicep Role Definition Helper Example

```bicep
// Central dictionary of standard roles
var roleDefinitions = {
  keyVaultSecretsUser: '4633458b-17de-408a-b874-0445c86b69e6'
  storageBlobDataContributor: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
  acrPull: '7f951dda-4ed3-4680-a7ca-43fe172d538d'
}

// Constructing resource ID
var roleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitions.keyVaultSecretsUser)
```
