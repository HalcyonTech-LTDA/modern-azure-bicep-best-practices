using 'main.bicep'

param environment = 'prod'
param orgPrefix = 'hlc'
param workloadName = 'billing'

param subnets = [
  {
    name: 'snet-infra'
    addressPrefix: '10.0.1.0/24'
  }
  {
    name: 'snet-compute'
    addressPrefix: '10.0.2.0/24'
  }
]
