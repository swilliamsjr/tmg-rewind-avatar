@description('Container App running the tmg-rewind-avatar image.')
param name string
param location string
param environmentId string
param managedIdentityResourceId string
param managedIdentityClientId string
param image string
@minValue(0)
@maxValue(10)
param minReplicas int
@minValue(1)
@maxValue(30)
param maxReplicas int
param foundryEndpoint string
param appInsightsConnectionString string
param voiceLiveModel string
param defaultVoice string
param defaultAvatarCharacter string
param defaultBackgroundImageUrl string
param defaultSystemPrompt string
param tags object

resource app 'Microsoft.App/containerApps@2024-03-01' = {
  name: name
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityResourceId}': {}
    }
  }
  properties: {
    environmentId: environmentId
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        targetPort: 3000
        transport: 'auto'
        allowInsecure: false
        traffic: [
          {
            latestRevision: true
            weight: 100
          }
        ]
        corsPolicy: {
          allowedOrigins: ['*']
          allowedMethods: ['GET', 'POST', 'OPTIONS']
          allowedHeaders: ['*']
          allowCredentials: false
        }
      }
    }
    template: {
      containers: [
        {
          name: 'app'
          image: image
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
          env: [
            { name: 'AZURE_CLIENT_ID',                          value: managedIdentityClientId }
            { name: 'AZURE_VOICELIVE_ENDPOINT',                 value: foundryEndpoint }
            { name: 'VOICELIVE_MODEL',                          value: voiceLiveModel }
            { name: 'VOICELIVE_VOICE',                          value: defaultVoice }
            { name: 'VOICELIVE_VOICE_TYPE',                     value: 'standard' }
            { name: 'VOICELIVE_INSTRUCTIONS',                   value: defaultSystemPrompt }
            { name: 'VOICELIVE_AVATAR_ENABLED',                 value: 'true' }
            { name: 'VOICELIVE_AVATAR_CHARACTER',               value: defaultAvatarCharacter }
            { name: 'VOICELIVE_AVATAR_OUTPUT_MODE',             value: 'webrtc' }
            { name: 'VOICELIVE_IS_PHOTO_AVATAR',                value: 'false' }
            { name: 'VOICELIVE_IS_CUSTOM_AVATAR',               value: 'false' }
            { name: 'VOICELIVE_AVATAR_BG_URL',                  value: defaultBackgroundImageUrl }
            { name: 'APPLICATIONINSIGHTS_CONNECTION_STRING',    value: appInsightsConnectionString }
          ]
          probes: [
            {
              type: 'Liveness'
              httpGet: {
                path: '/health'
                port: 3000
              }
              initialDelaySeconds: 15
              periodSeconds: 30
              failureThreshold: 3
            }
            {
              type: 'Readiness'
              httpGet: {
                path: '/health'
                port: 3000
              }
              initialDelaySeconds: 5
              periodSeconds: 10
              failureThreshold: 3
            }
          ]
        }
      ]
      scale: {
        minReplicas: minReplicas
        maxReplicas: maxReplicas
        rules: [
          {
            name: 'http-concurrency'
            http: {
              metadata: {
                concurrentRequests: '30'
              }
            }
          }
        ]
      }
    }
  }
}

output name string = app.name
output fqdn string = app.properties.configuration.ingress.fqdn
output resourceId string = app.id
