targetScope = 'subscription'

param location string
param environmentName string
param resourceGroupName string 

param tags object

param msiName string = ''
param appServicePlanName string = ''
param appServiceName string = ''
param botServiceName string = ''
param cosmosName string = ''

param sqlServerName string = ''
param sqlDBName string = ''
param searchName string = ''
param storageName string = ''
param documentIntelligenceName string = ''
@description('Deploy SQL Database? (required for SQL Plugin demo)')
param deploySQL bool
@description('Deploy Search service? (required for Search Plugin demo)')
param deploySearch bool
@description('Deploy Document Intelligence service? (required for Upload Plugin demo)')
param deployDocIntel bool 

param publicNetworkAccess string = 'Enabled'

@description('Name of your existing open ai resource')
param openaiName string

var abbrs = loadJsonContent('abbreviations.json')

var uniqueSuffix = substring(uniqueString(subscription().id, resourceGroup.id), 1, 3) 

// Organize resources in a resource group
resource resourceGroup 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: !empty(resourceGroupName) ? resourceGroupName : '${abbrs.resourcesResourceGroups}${environmentName}'
  location: location
  tags: tags
}

module m_msi 'modules/msi.bicep' = {
  name: 'deploy_msi'
  scope: resourceGroup
  params: {
    location: location
    msiName: !empty(msiName) ? msiName : '${abbrs.managedIdentityUserAssignedIdentities}${environmentName}-${uniqueSuffix}'
    tags: tags
  }
}

resource existing_openai 'Microsoft.CognitiveServices/accounts@2023-05-01' existing = {
  name: openaiName
  scope: az.resourceGroup('rg-hol-aoai')
}

module m_openai 'modules/openai.bicep' = {
  name: 'deploy_openai'
  scope: resourceGroup
  params: {
    msiPrincipalID: m_msi.outputs.msiPrincipalID
    openaiId: existing_openai.id
  }
}

module m_docs 'modules/documentIntelligence.bicep' = if (deployDocIntel) {
  name: 'deploy_docs'
  scope: resourceGroup
  params: {
    location: location
    documentIntelligenceName: !empty(documentIntelligenceName) ? documentIntelligenceName : '${abbrs.cognitiveServicesFormRecognizer}${environmentName}-${uniqueSuffix}'
    msiPrincipalID: m_msi.outputs.msiPrincipalID
    publicNetworkAccess: publicNetworkAccess
    tags: tags
  }
}

module m_search 'modules/searchService.bicep' = if (deploySearch) {
  name: 'deploy_search'
  scope: resourceGroup
  params: {
    location: location
    searchName: !empty(searchName) ? searchName : '${abbrs.searchSearchServices}${environmentName}-${uniqueSuffix}'
    msiPrincipalID: m_msi.outputs.msiPrincipalID
    publicNetworkAccess: publicNetworkAccess
    tags: tags
  }
}


module m_storage 'modules/storage.bicep' = {
  name: 'deploy_storage'
  scope: resourceGroup
  params: {
    location: location
    storageName: !empty(storageName) ? storageName : '${abbrs.storageStorageAccounts}${replace(replace(environmentName,'-',''),'_','')}${uniqueSuffix}'
    msiPrincipalID: m_msi.outputs.msiPrincipalID
    publicNetworkAccess: publicNetworkAccess
    tags: tags
  }
}

module m_sql 'modules/sql.bicep' = if (deploySQL) {
  name: 'deploy_sql'
  scope: resourceGroup
  params: {
    location: location
    sqlServerName: !empty(sqlServerName) ? sqlServerName : '${abbrs.sqlServers}${environmentName}-${uniqueSuffix}'
    sqlDBName: !empty(sqlDBName) ? sqlDBName : '${abbrs.sqlServersDatabases}${environmentName}-${uniqueSuffix}'
    msiPrincipalID: m_msi.outputs.msiPrincipalID
    msiClientID: m_msi.outputs.msiClientID
    publicNetworkAccess: publicNetworkAccess
    tags: tags
  }
}

module m_cosmos 'modules/cosmos.bicep' = {
  name: 'deploy_cosmos'
  scope: resourceGroup
  params: {
    location: location
    cosmosName: !empty(cosmosName) ? cosmosName : '${abbrs.documentDBDatabaseAccounts}${environmentName}-${uniqueSuffix}'
    msiPrincipalID: m_msi.outputs.msiPrincipalID
    publicNetworkAccess: publicNetworkAccess
    tags: tags
  }
}


module m_app 'modules/appservice.bicep' = {
  name: 'deploy_app'
  scope: resourceGroup
  params: {
    location: location
    appServicePlanName: !empty(appServicePlanName) ? appServicePlanName : '${abbrs.webServerFarms}${environmentName}-${uniqueSuffix}'
    appServiceName: !empty(appServiceName) ? appServiceName : '${abbrs.webSitesAppService}${environmentName}-${uniqueSuffix}'
    tags: tags
    msiID: m_msi.outputs.msiID
    msiClientID: m_msi.outputs.msiClientID
    openaiName: openaiName 
    openaiEndpoint: 'https://${openaiName}.openai.azure.com/'
    openaiGPTModel: 'gpt-4'
    openaiEmbeddingsModel: 'text-embedding-ada-002'
    openaiDALLEModel: 'dall-e-3'
    documentIntelligenceName: deployDocIntel ? m_docs.outputs.documentIntelligenceName : ''
    documentIntelligenceEndpoint: deployDocIntel ? m_docs.outputs.documentIntelligenceEndpoint : ''
    searchName: deploySearch ? m_search.outputs.searchName : ''
    searchEndpoint: deploySearch ? m_search.outputs.searchEndpoint : ''
    cosmosEndpoint: m_cosmos.outputs.cosmosEndpoint
    sqlConnectionString: deploySQL ? m_sql.outputs.sqlConnectionString : ''
    storageName: m_storage.outputs.storageName
  }
}

module m_bot 'modules/botservice.bicep' = {
  name: 'deploy_bot'
  scope: resourceGroup
  params: {
    location: 'global'
    botServiceName: !empty(botServiceName) ? botServiceName : '${abbrs.cognitiveServicesBot}${environmentName}-${uniqueSuffix}'
    tags: tags
    endpoint: 'https://${m_app.outputs.hostName}/api/messages'
    msiClientID: m_msi.outputs.msiClientID
    msiID: m_msi.outputs.msiID
    publicNetworkAccess: publicNetworkAccess
  }
}

output AZURE_SEARCH_ENDPOINT string = deploySearch ? m_search.outputs.searchEndpoint : ''
output AZURE_SEARCH_NAME string = deploySearch ? m_search.outputs.searchName : ''
output AZURE_RESOURCE_GROUP_ID string = resourceGroup.id
output AZURE_RESOURCE_GROUP_NAME string = resourceGroup.name
