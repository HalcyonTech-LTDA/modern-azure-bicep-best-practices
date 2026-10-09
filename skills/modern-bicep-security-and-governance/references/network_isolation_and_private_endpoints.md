# Network Isolation & Private Endpoints Architecture in Bicep

This guide details best practices for securing Azure PaaS resources behind Virtual Networks using Azure Private Link, Private Endpoints, and Private DNS Zones.

---

## 1. Network Perimeter Security Fundamentals

Exposing PaaS endpoints (e.g., `*.blob.core.windows.net`, `*.vaultcore.azure.net`) to the public internet introduces severe threat vectors. 

### Modern Baseline Requirements:
1. **Disable Public Network Access**: Set `publicNetworkAccess: 'Disabled'` on all production PaaS services.
2. **Private Endpoint Injection**: Connect PaaS resources to dedicated subnets inside the application Virtual Network.
3. **Private DNS Zone Integration**: Register the private IP of the Private Endpoint in an Azure Private DNS Zone so applications resolve the resource's FQDN to a private IP within the VNet.

---

## 2. Declarative Private Endpoint in Bicep

A Private Endpoint is provisioned via `Microsoft.Network/privateEndpoints`:

```bicep
resource resPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-11-01' = {
  name: 'pe-${resourceName}'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: subnetId // Subnet dedicated to private endpoints
    }
    privateLinkServiceConnections: [
      {
        name: 'plsc-${resourceName}'
        properties: {
          privateLinkServiceId: targetResource.id // ID of the PaaS resource (Key Vault, Storage, etc.)
          groupIds: [
            groupId // 'vault' for Key Vault, 'blob' for Blob Storage, 'sqlServer' for SQL
          ]
        }
      }
    ]
  }
}
```

---

## 3. Private DNS Zone Group Automation

Without a Private DNS Zone Group, DNS resolution will continue returning the public IP (which will now reject traffic).

Always declare the `privateDnsZoneGroups` child resource to automatically create the required DNS A-record upon endpoint creation:

```bicep
resource resDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-11-01' = {
  parent: resPrivateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink-config'
        properties: {
          privateDnsZoneId: privateDnsZoneId
        }
      }
    ]
  }
}
```

---

## 4. Subnet Configuration Requirement

In modern Azure networking, subnets containing Private Endpoints must have network policies disabled for private endpoints to allow Network Security Groups (NSGs) to govern traffic:

```bicep
resource resSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' = {
  parent: resVnet
  name: 'snet-private-endpoints'
  properties: {
    addressPrefix: '10.0.3.0/24'
    privateEndpointNetworkPolicies: 'Disabled'
  }
}
```

---

## 5. Common Private Link Group IDs & Private DNS Zone Names

| Service | Group ID (`groupIds`) | Target Private DNS Zone Name |
| :--- | :--- | :--- |
| **Azure Key Vault** | `'vault'` | `privatelink.vaultcore.azure.net` |
| **Storage Account (Blob)** | `'blob'` | `privatelink.blob.core.windows.net` |
| **Storage Account (Queue)** | `'queue'` | `privatelink.queue.core.windows.net` |
| **Azure SQL Database** | `'sqlServer'` | `privatelink.database.windows.net` |
| **Azure Cosmos DB (SQL API)** | `'Sql'` | `privatelink.documents.azure.com` |
| **Azure Container Registry** | `'registry'` | `privatelink.azurecr.io` |
| **Azure Service Bus** | `'namespace'` | `privatelink.servicebus.windows.net` |
| **Azure App Service / Function** | `'sites'` | `privatelink.azurewebsites.net` |
