# APIM VNet & Backend Architecture

This guide details network integration, NSG rules, and backend routing for Azure API Management (APIM).

---

## 1. External VNet Mode & Subnet Requirements

In External VNet mode, APIM is assigned a public IP address for inbound client requests, while its gateway engine is injected into a private VNet subnet (`snet-apim`). This enables APIM to resolve and route directly to private VNet backends (e.g., Azure Container Apps in `snet-aca`).

### Resource Definition: `Microsoft.ApiManagement/service`

```bicep
resource apim 'Microsoft.ApiManagement/service@2024-05-01' = {
  name: apimName
  location: location
  tags: tags
  sku: {
    name: apimSkuName       // Developer for dev/uat, Premium for prod
    capacity: apimSkuCapacity // 1 for dev/uat, 2+ for prod HA
  }
  properties: {
    publisherEmail: publisherEmail
    publisherName: publisherName
    virtualNetworkType: 'External'
    virtualNetworkConfiguration: {
      subnetResourceId: apimSubnetId
    }
    customProperties: {
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls10': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls11': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls12': 'True'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls10': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls11': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls12': 'True'
    }
  }
}
```

---

## 2. Mandatory NSG Inbound & Outbound Rules for APIM

The subnet delegated to APIM (`snet-apim`) MUST have an associated Network Security Group (NSG) configured with the following mandatory rules. Failure to configure these rules will cause APIM deployment or updates to fail:

### Inbound Rules

1. **Port 3443 (Management Endpoint)**:
   - Source: `ApiManagement`
   - Destination: Any (`*`)
   - Protocol: `Tcp`
   - Purpose: Azure portal and management connectivity.
2. **Ports 80 & 443 (Client Communication)**:
   - Source: `Internet`
   - Destination: Any (`*`)
   - Protocol: `Tcp`
   - Purpose: Inbound API caller traffic.
3. **AzureLoadBalancer**:
   - Source: `AzureLoadBalancer`
   - Destination: Any (`*`)
   - Protocol: `*`
   - Purpose: Health probe monitoring.

### Outbound Rules

1. **Storage (Port 443)**: Outbound to `Storage` service tag for logging and telemetry.
2. **Azure SQL (Port 1433)**: Outbound to `Sql` service tag for internal configuration storage.
3. **Azure Key Vault (Port 443)**: Outbound to `AzureKeyVault` service tag for certificate and named value resolution.
4. **Azure Monitor**: Outbound to `AzureMonitor` service tag for metric publication.

---

## 3. APIM Backend Declaration

Declare downstream targets as first-class `backends`:

```bicep
resource apiBackend 'Microsoft.ApiManagement/service/backends@2024-05-01' = {
  parent: apim
  name: 'aca-api-backend'
  properties: {
    description: 'Internal backend target pointing to Azure Container Apps REST API'
    protocol: 'http'
    url: 'https://${apiAppFqdn}'
    tls: {
      validateCertificateChain: false
      validateCertificateName: false
    }
  }
}
```
In policy files, bind the request dynamically using `<set-backend-service backend-id="aca-api-backend" />`.
