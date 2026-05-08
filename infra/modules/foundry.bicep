@description('Azure AI Foundry (AIServices) account with a project and a realtime model deployment for Voice Live.')
param accountName string
param projectName string
param location string
param modelDeploymentName string
param modelName string
param modelVersion string
@minValue(1)
@maxValue(100)
param modelCapacity int
param tags object

resource account 'Microsoft.CognitiveServices/accounts@2025-09-01' = {
  name: accountName
  location: location
  tags: tags
  kind: 'AIServices'
  sku: {
    name: 'S0'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    customSubDomainName: accountName
    publicNetworkAccess: 'Enabled'
    disableLocalAuth: false
    allowProjectManagement: true
  }
}

resource project 'Microsoft.CognitiveServices/accounts/projects@2025-04-01-preview' = {
  parent: account
  name: projectName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    description: 'TMG Rewind Avatar — Voice Live demo project'
    displayName: projectName
  }
}

resource modelDeployment 'Microsoft.CognitiveServices/accounts/deployments@2025-09-01' = {
  parent: account
  name: modelDeploymentName
  sku: {
    name: 'GlobalStandard'
    capacity: modelCapacity
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: modelName
      version: modelVersion
    }
    raiPolicyName: 'Microsoft.DefaultV2'
    versionUpgradeOption: 'OnceCurrentVersionExpired'
  }
}

output accountName string = account.name
output endpoint string = account.properties.endpoint
output projectName string = project.name
output deploymentName string = modelDeployment.name
output resourceId string = account.id
