@description('Container Apps Environment wired to Log Analytics.')
param name string
param location string
param logAnalyticsCustomerId string
@secure()
param logAnalyticsSharedKey string
@allowed([
  'Consumption'
  'Dedicated-D4'
  'Dedicated-D8'
])
param skuTier string
param tags object

var workloadProfileName = skuTier == 'Consumption' ? 'Consumption' : 'D4-General'
var workloadProfileType = skuTier == 'Consumption' ? 'Consumption' : (skuTier == 'Dedicated-D4' ? 'D4' : 'D8')

resource env 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsCustomerId
        sharedKey: logAnalyticsSharedKey
      }
    }
    workloadProfiles: [
      {
        name: workloadProfileName
        workloadProfileType: workloadProfileType
        minimumCount: skuTier == 'Consumption' ? null : 1
        maximumCount: skuTier == 'Consumption' ? null : 3
      }
    ]
  }
}

output environmentId string = env.id
output defaultDomain string = env.properties.defaultDomain
output workloadProfileName string = workloadProfileName
