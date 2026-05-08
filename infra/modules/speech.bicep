@description('Standalone Speech Services account; scaffolding for SE customizations (custom voice, batch transcription) that do not flow through Foundry.')
param name string
param location string
param tags object

resource speech 'Microsoft.CognitiveServices/accounts@2024-10-01' = {
  name: name
  location: location
  tags: tags
  kind: 'SpeechServices'
  sku: {
    name: 'S0'
  }
  properties: {
    customSubDomainName: name
    publicNetworkAccess: 'Enabled'
  }
}

output name string = speech.name
output endpoint string = speech.properties.endpoint
output resourceId string = speech.id
