# Customer-Managed Keys (CMK) & Encryption at Rest in Bicep

This reference guide establishes implementation patterns for Customer-Managed Keys (CMK), double encryption, and transport-layer security standards in Bicep.

---

## 1. Encryption Standards

Azure provides default encryption at rest using platform-managed keys (Microsoft-managed). However, regulatory standards (HIPAA, PCI-DSS, SOC 2, ISO 27001) often mandate Customer-Managed Keys (CMK) where keys are stored in dedicated Azure Key Vault instances managed by the tenant.

### Core Architectural Invariants:
1. **Key Vault Configuration**: The Key Vault hosting the CMK must have `enablePurgeProtection: true` and `enableSoftDelete: true`.
2. **Key Rotation Policy**: Keys must define automated rotation policies via `rotationPolicy`.
3. **Identity Assignment**: The target service must access Key Vault using a User-Assigned Managed Identity granted the `Key Vault Crypto User` role (`12338081-198d-4476-aa5f-447c423ea692`).

---

## 2. Key Vault Key with Automated Rotation

```bicep
resource resKeyVaultKey 'Microsoft.KeyVault/vaults/keys@2024-11-01' = {
  parent: resKeyVault
  name: 'cmk-storage-encryption'
  properties: {
    kty: 'RSA'
    keySize: 4096
    rotationPolicy: {
      attributes: {
        expiryTime: 'P1Y' // 1 year expiry
      }
      lifetimeActions: [
        {
          trigger: {
            timeBeforeExpiry: 'P30D' // Rotate 30 days before expiry
          }
          action: {
            type: 'Rotate'
          }
        }
      ]
    }
  }
}
```

---

## 3. Storage Account CMK with User-Assigned Identity

```bicep
resource resStorageAccount 'Microsoft.Storage/storageAccounts@2025-01-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_GRS'
  }
  kind: 'StorageV2'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${resIdentity.id}': {}
    }
  }
  properties: {
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    encryption: {
      requireInfrastructureEncryption: true // Double encryption
      keySource: 'Microsoft.Keyvault'
      keyvaultproperties: {
        keyname: resKeyVaultKey.name
        keyvaulturi: resKeyVault.properties.vaultUri
        identity: resIdentity.id
      }
      services: {
        blob: {
          enabled: true
          keyType: 'Account'
        }
      }
    }
  }
}
```

---

## 4. Minimum TLS Enforcement across PaaS Services

Ensure all PaaS resource declarations explicitly enforce modern TLS versions:

- **Storage Accounts**: `minimumTlsVersion: 'TLS1_2'`
- **Azure App Service / Function Apps**: `siteConfig: { minTlsVersion: '1.2', ftpsState: 'Disabled' }`
- **Azure SQL Database Server**: `minimalTlsVersion: '1.2'`
- **Azure Redis Cache**: `minimumTlsVersion: '1.2'`
