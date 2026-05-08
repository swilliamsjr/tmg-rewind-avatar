@description('Grant the user-assigned managed identity the roles it needs against the deployed dependencies.')
param managedIdentityPrincipalId string
param foundryAccountName string
param speechAccountName string
param keyVaultName string
param storageAccountName string

// ── Built-in role definition IDs ────────────────────────────────────────────
//   Cognitive Services User           — a97b65f3-24c7-4388-baec-2e87135dc908
//   Cognitive Services Speech User    — f2dc8367-1007-4938-bd23-fe263f013447
//   Cognitive Services OpenAI User    — 5e0bd9bd-7b93-4f28-af87-19fc36ad61bd
//   Key Vault Secrets User            — 4633458b-17de-408a-b874-0445c86b69e6
//   Storage Blob Data Reader          — 2a2b9908-6ea1-4ae2-8e65-a410df84e7d1
// ────────────────────────────────────────────────────────────────────────────

resource foundry 'Microsoft.CognitiveServices/accounts@2024-10-01' existing = {
  name: foundryAccountName
}

resource speech 'Microsoft.CognitiveServices/accounts@2024-10-01' existing = {
  name: speechAccountName
}

resource kv 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageAccountName
}

// Foundry — Cognitive Services User (broad Voice Live access)
resource roleFoundryUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: foundry
  name: guid(foundry.id, managedIdentityPrincipalId, 'a97b65f3-24c7-4388-baec-2e87135dc908')
  properties: {
    principalId: managedIdentityPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'a97b65f3-24c7-4388-baec-2e87135dc908')
  }
}

// Foundry — Cognitive Services OpenAI User (realtime model invocation)
resource roleFoundryOpenAi 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: foundry
  name: guid(foundry.id, managedIdentityPrincipalId, '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd')
  properties: {
    principalId: managedIdentityPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd')
  }
}

// Speech — Cognitive Services Speech User
resource roleSpeechUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: speech
  name: guid(speech.id, managedIdentityPrincipalId, 'f2dc8367-1007-4938-bd23-fe263f013447')
  properties: {
    principalId: managedIdentityPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'f2dc8367-1007-4938-bd23-fe263f013447')
  }
}

// Key Vault — Secrets User
resource roleKvSecretsUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: kv
  name: guid(kv.id, managedIdentityPrincipalId, '4633458b-17de-408a-b874-0445c86b69e6')
  properties: {
    principalId: managedIdentityPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')
  }
}

// Storage — Blob Data Reader (read background images uploaded by the SE)
resource roleStorageBlobReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storage
  name: guid(storage.id, managedIdentityPrincipalId, '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1')
  properties: {
    principalId: managedIdentityPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1')
  }
}
