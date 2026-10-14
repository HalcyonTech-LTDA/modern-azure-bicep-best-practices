# Ingress & Network Security in Azure Container Apps

This guide covers network security, private ingress isolation, and IP security restrictions for Azure Container Apps in zero-trust architectures.

---

## 1. Network Topology: Internal CAE + APIM Ingress

In enterprise microservice architectures, Container Apps must not have public IP addresses. Instead:
- Deploy the Container Apps Environment (`Microsoft.App/managedEnvironments`) in internal mode (`internal: true`) bound to a dedicated subnet (`snet-aca`).
- External traffic enters through an Azure API Management gateway deployed in its own subnet (`snet-apim`).
- Container Apps API instances configure VNet-accessible ingress, but strictly restrict incoming requests to the APIM subnet prefix via `ipSecurityRestrictions`.

```txt
  Internet ──> Azure APIM (snet-apim: 10.0.3.0/24)
                     │
                     │ Internal HTTPS (Port 8080)
                     ▼
          Azure Container Apps API (snet-aca: 10.0.0.0/23)
          [ipSecurityRestrictions: Allow 10.0.3.0/24 only]
```

---

## 2. Ingress Configuration & IP Security Restrictions

```bicep
@description('Address prefix of the dedicated APIM subnet for ingress IP restriction.')
param apimSubnetPrefix string = '10.0.3.0/24'

resource apiApp 'Microsoft.App/containerApps@2025-01-01' = {
  name: 'aca-api-${projectName}-${environmentName}'
  location: location
  tags: tags
  properties: {
    managedEnvironmentId: acaEnvironmentId
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: true          // Exposes the app to other subnets in the VNet/cluster
        targetPort: 8080        // Target port in the container
        transport: 'auto'
        allowInsecure: false    // Enforce HTTPS
        ipSecurityRestrictions: [
          {
            name: 'Allow-APIM-Subnet-Only'
            action: 'Allow'
            ipAddressRange: apimSubnetPrefix
            description: 'Restricts inbound access strictly to the dedicated APIM subnet, blocking all other VNet/internal access'
          }
        ]
      }
      registries: acrRegistries
      secrets: appSecrets
    }
    template: {
      containers: [
        {
          name: 'api'
          image: resolvedContainerImage
          resources: {
            cpu: json('0.5')
            memory: '1.0Gi'
          }
          env: apiEnvVars
        }
      ]
      scale: {
        minReplicas: 2
        maxReplicas: 10
        rules: [
          {
            name: 'http-rule'
            http: {
              metadata: {
                concurrentRequests: '100'
              }
            }
          }
          {
            name: 'cpu-rule'
            custom: {
              type: 'cpu'
              metadata: {
                type: 'Utilization'
                value: '75'
              }
            }
          }
        ]
      }
    }
  }
}
```

---

## 3. Internal Partner Mock Server Pattern

When simulating third-party partner APIs (e.g. WireMock server for external bureaus), deploy a mock Container App with `external: false` (accessible only within the CAE cluster):

```bicep
resource mockApp 'Microsoft.App/containerApps@2025-01-01' = if (deployApps) {
  name: 'aca-mock-${projectName}-${environmentName}'
  location: location
  tags: tags
  properties: {
    managedEnvironmentId: acaEnvironmentId
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: false        // Cluster-internal only
        targetPort: 8080
      }
      registries: acrRegistries
    }
    template: {
      containers: [
        {
          name: 'mock'
          image: resolvedMockImage
          resources: {
            cpu: json('1.0')
            memory: '2.0Gi'
          }
        }
      ]
      scale: {
        minReplicas: mockMinReplicas  // 2 in dev, 0 in uat/prod (dormant scale-to-zero)
        maxReplicas: mockMaxReplicas
      }
    }
  }
}
```
