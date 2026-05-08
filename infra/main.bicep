// ─────────────────────────────────────────────────────────────────────────────
// tmg-rewind-avatar — main.bicep
//
// Resource-group-scoped one-click deploy of the Project Rewind avatar
// experience. Provisions:
//   • Log Analytics + Application Insights
//   • User-assigned Managed Identity
//   • Key Vault (RBAC, soft-delete)            ← scaffolding for SE secrets
//   • Storage Account + 'backgrounds' container
//   • AI Foundry (AIServices) + Project + realtime model deployment
//   • Speech Services account                  ← scaffolding for non-Foundry voices
//   • Container Apps Environment
//   • Container App pulling tmg-rewind-avatar image (default: GHCR public)
//   • Role assignments: UAMI → Foundry Cognitive Services User,
//                       UAMI → KV Secrets User,
//                       UAMI → Storage Blob Data Reader
//
// Requires the deploying principal to have BOTH Contributor and User Access
// Administrator on the target resource group (or Owner). Most TMG sandbox
// subscriptions grant this by default.
// ─────────────────────────────────────────────────────────────────────────────

targetScope = 'resourceGroup'

// ── Parameters ───────────────────────────────────────────────────────────────

@description('Azure region. Restricted to regions that currently host Voice Live realtime models.')
@allowed([
  'eastus2'
  'swedencentral'
  'japaneast'
])
param location string = 'eastus2'

@description('Lowercase 3–10 char prefix used in resource names. Must be globally unique-friendly.')
@minLength(3)
@maxLength(10)
param resourcePrefix string = 'tmgrewind'

@description('Environment tag (e.g. demo, dev, henry-review).')
param environmentName string = 'demo'

@description('Voice Live realtime model deployment name. Default `gpt-realtime` is the current GA model.')
@allowed([
  'gpt-realtime'
  'gpt-4o-mini-realtime'
  'gpt-4o-realtime-preview'
  'gpt-4o-mini-realtime-preview'
])
param voiceLiveModel string = 'gpt-realtime'

@description('Realtime model version. Pair with voiceLiveModel: gpt-realtime → 2025-08-28, gpt-4o-realtime-preview → 2024-12-17.')
param voiceLiveModelVersion string = '2025-08-28'

@description('Realtime model capacity in thousands of tokens per minute (TPM). Default 1 (=1K TPM) is the minimum for a single-user demo. Bump to 5+ for sustained use; quota in shared subscriptions is tight (default ceiling is often 10).')
@minValue(1)
@maxValue(100)
param voiceLiveModelCapacity int = 1

@description('Default TTS voice for the avatar. See Microsoft Speech voices list.')
param defaultVoice string = 'en-US-AvaMultilingualNeural'

@description('Default avatar character (lisa, harry, layla, etc.).')
param defaultAvatarCharacter string = 'lisa'

@description('Default background image URL for the avatar. Empty string falls back to the bundled background.png shipped in the container.')
param defaultBackgroundImageUrl string = ''

@description('Default system prompt / instructions for the realtime agent.')
param defaultSystemPrompt string = 'You are MAX, a friendly content guide for a TV streaming service. Help the viewer find a movie or show for tonight. Keep replies short, warm, and conversational.'

@description('Container Apps workload profile.')
@allowed([
  'Consumption'
  'Dedicated-D4'
  'Dedicated-D8'
])
param skuTier string = 'Consumption'

@description('Container image to deploy. Default: anonymously-pullable GHCR image published from this repo.')
param containerImage string = 'ghcr.io/swilliamsjr/tmg-rewind-avatar:latest'

@description('Min replicas for the Container App. 0 = scale-to-zero (cold start ~10s); 1 = always-warm.')
@minValue(0)
@maxValue(10)
param minReplicas int = 0

@description('Max replicas for the Container App.')
@minValue(1)
@maxValue(30)
param maxReplicas int = 3

@description('Tags applied to every resource.')
param tags object = {
  'azd-env-name': environmentName
  workload: 'tmg-rewind-avatar'
  owner: 'TMG-SE'
}

// ── Naming ───────────────────────────────────────────────────────────────────

var uniq = uniqueString(resourceGroup().id, resourcePrefix)
var nameSuffix = substring(uniq, 0, 6)

var names = {
  identity: 'uami-${resourcePrefix}-${nameSuffix}'
  logAnalytics: 'log-${resourcePrefix}-${nameSuffix}'
  appInsights: 'appi-${resourcePrefix}-${nameSuffix}'
  keyVault: 'kv-${resourcePrefix}-${nameSuffix}'
  storage: toLower('st${resourcePrefix}${nameSuffix}')
  foundry: 'ai-${resourcePrefix}-${nameSuffix}'
  foundryProject: '${resourcePrefix}-project'
  speech: 'speech-${resourcePrefix}-${nameSuffix}'
  containerAppEnv: 'cae-${resourcePrefix}-${nameSuffix}'
  containerApp: 'ca-${resourcePrefix}-${nameSuffix}'
}

// ── Modules ──────────────────────────────────────────────────────────────────

module identity 'modules/identity.bicep' = {
  name: 'identity'
  params: {
    name: names.identity
    location: location
    tags: tags
  }
}

module monitoring 'modules/monitoring.bicep' = {
  name: 'monitoring'
  params: {
    logAnalyticsName: names.logAnalytics
    appInsightsName: names.appInsights
    location: location
    tags: tags
  }
}

module keyVault 'modules/keyVault.bicep' = {
  name: 'keyVault'
  params: {
    name: names.keyVault
    location: location
    tags: tags
  }
}

module storage 'modules/storage.bicep' = {
  name: 'storage'
  params: {
    name: names.storage
    location: location
    tags: tags
  }
}

module foundry 'modules/foundry.bicep' = {
  name: 'foundry'
  params: {
    accountName: names.foundry
    projectName: names.foundryProject
    location: location
    modelDeploymentName: voiceLiveModel
    modelName: voiceLiveModel
    modelVersion: voiceLiveModelVersion
    modelCapacity: voiceLiveModelCapacity
    tags: tags
  }
}

module speech 'modules/speech.bicep' = {
  name: 'speech'
  params: {
    name: names.speech
    location: location
    tags: tags
  }
}

module containerAppEnv 'modules/containerAppEnv.bicep' = {
  name: 'containerAppEnv'
  params: {
    name: names.containerAppEnv
    location: location
    logAnalyticsCustomerId: monitoring.outputs.logAnalyticsCustomerId
    logAnalyticsSharedKey: monitoring.outputs.logAnalyticsSharedKey
    skuTier: skuTier
    tags: tags
  }
}

module roles 'modules/roleAssignments.bicep' = {
  name: 'roleAssignments'
  params: {
    managedIdentityPrincipalId: identity.outputs.principalId
    foundryAccountName: foundry.outputs.accountName
    speechAccountName: speech.outputs.name
    keyVaultName: keyVault.outputs.name
    storageAccountName: storage.outputs.name
  }
}

module containerApp 'modules/containerApp.bicep' = {
  name: 'containerApp'
  params: {
    name: names.containerApp
    location: location
    environmentId: containerAppEnv.outputs.environmentId
    managedIdentityResourceId: identity.outputs.resourceId
    managedIdentityClientId: identity.outputs.clientId
    image: containerImage
    minReplicas: minReplicas
    maxReplicas: maxReplicas
    foundryEndpoint: foundry.outputs.endpoint
    appInsightsConnectionString: monitoring.outputs.appInsightsConnectionString
    voiceLiveModel: voiceLiveModel
    defaultVoice: defaultVoice
    defaultAvatarCharacter: defaultAvatarCharacter
    defaultBackgroundImageUrl: defaultBackgroundImageUrl
    defaultSystemPrompt: defaultSystemPrompt
    tags: tags
  }
  dependsOn: [
    roles
  ]
}

// ── Outputs ──────────────────────────────────────────────────────────────────

@description('Public HTTPS URL of the deployed avatar app.')
output appUrl string = 'https://${containerApp.outputs.fqdn}'

@description('AI Foundry endpoint — copy into AZURE_VOICELIVE_ENDPOINT for local dev.')
output foundryEndpoint string = foundry.outputs.endpoint

@description('Storage account to upload background images into the `backgrounds` container.')
output storageAccountName string = storage.outputs.name

@description('User-assigned managed identity used by the Container App.')
output managedIdentityClientId string = identity.outputs.clientId

@description('Key Vault for any secrets the SE wants to add post-deploy.')
output keyVaultName string = keyVault.outputs.name

@description('Container App resource name (for `az containerapp update` rollouts).')
output containerAppName string = containerApp.outputs.name
