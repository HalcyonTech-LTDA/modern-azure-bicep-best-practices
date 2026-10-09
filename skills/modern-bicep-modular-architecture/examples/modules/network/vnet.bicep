@description('Virtual Network module with declarative subnets and Network Security Group.')

metadata name = 'Virtual Network Module'
metadata description = 'Provisions an Azure Virtual Network with associated subnets and NSGs.'

@description('Subnet definition contract.')
type SubnetDefinition = {
  @description('Name of the subnet.')
  name: string
  @description('CIDR address range.')
  addressPrefix: string
}

@description('Azure region for deployment.')
param location string = resourceGroup().location

@description('Name of the Virtual Network.')
param vnetName string

@description('Address space prefix for the Virtual Network.')
param addressPrefix string = '10.0.0.0/16'

@description('List of subnets to create.')
param subnets SubnetDefinition[]

@description('Resource tags.')
param tags object = {}

// Network Security Group for subnets
resource resNsg 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: 'nsg-${vnetName}'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'DenyAllInbound'
        properties: {
          priority: 4096
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

// Virtual Network
resource resVnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefix
      ]
    }
    subnets: [
      for subnet in subnets: {
        name: subnet.name
        properties: {
          addressPrefix: subnet.addressPrefix
          networkSecurityGroup: {
            id: resNsg.id
          }
        }
      }
    ]
  }
}

@description('Resource ID of the created Virtual Network.')
output vnetId string = resVnet.id

@description('Resource IDs of the created subnets.')
output subnetIds string[] = [
  for (subnet, i) in subnets: resVnet.properties.subnets[i].id
]
