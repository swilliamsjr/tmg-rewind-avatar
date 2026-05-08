@description('Storage account hosting a `backgrounds` blob container for avatar background images.')
param name string
param location string
param tags object

resource sa 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: name
  location: location
  tags: tags
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: true
    supportsHttpsTrafficOnly: true
    accessTier: 'Hot'
    publicNetworkAccess: 'Enabled'
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: sa
  name: 'default'
  properties: {
    cors: {
      corsRules: [
        {
          allowedOrigins: ['*']
          allowedMethods: ['GET', 'HEAD']
          allowedHeaders: ['*']
          exposedHeaders: ['*']
          maxAgeInSeconds: 3600
        }
      ]
    }
  }
}

resource backgroundsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobService
  name: 'backgrounds'
  properties: {
    publicAccess: 'Blob'
  }
}

output name string = sa.name
output id string = sa.id
output blobEndpoint string = sa.properties.primaryEndpoints.blob
output backgroundsContainerUrl string = '${sa.properties.primaryEndpoints.blob}backgrounds'
