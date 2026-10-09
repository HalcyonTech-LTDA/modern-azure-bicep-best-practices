using 'subscription_stack_orchestrator.bicep'

param location = 'eastus'
param environment = 'prod'
param workloadName = 'core'

param tags = {
  Environment: 'prod'
  Workload: 'core'
  ManagedBy: 'DeploymentStack'
}
