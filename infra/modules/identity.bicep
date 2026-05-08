@description('User-assigned managed identity used by the Container App.')
param name string
param location string
param tags object

resource uami 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: name
  location: location
  tags: tags
}

output resourceId string = uami.id
output clientId string = uami.properties.clientId
output principalId string = uami.properties.principalId
output name string = uami.name
