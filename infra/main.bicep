targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@description('provide a 2-13 character prefix for all resources.')
param ResourcePrefix string = 'zedy03'

@minLength(1)
@description('Primary location for all resources')
param location string

@description('Name of App Service plan')
param HostingPlanName string = '${ResourcePrefix}-hosting-plan'

@description('The pricing tier for the App Service plan')
@allowed([
  'F1'
  'D1'
  'B1'
  'B2'
  'B3'
  'S1'
  'S2'
  'S3'
  'P1'
  'P2'
  'P3'
  'P4'
])
param HostingPlanSku string = 'B3'

@description('Name of Web App')
param WebsiteName string = '${ResourcePrefix}-website'

@description('Name of Application Insights')
param ApplicationInsightsName string = '${ResourcePrefix}-appinsights'

@description('Use semantic search')
param AzureSearchUseSemanticSearch string = 'false'

@description('Semantic search config')
param AzureSearchSemanticSearchConfig string = 'default'

@description('Is the index prechunked')
param AzureSearchIndexIsPrechunked string = 'false'

@description('Top K results')
param AzureSearchTopK string = '5'

@description('Enable in domain')
param AzureSearchEnableInDomain string = 'false'

@description('Content columns')
param AzureSearchContentColumns string = 'content'

@description('Filename column')
param AzureSearchFilenameColumn string = 'filename'

@description('Title column')
param AzureSearchTitleColumn string = 'title'

@description('Url column')
param AzureSearchUrlColumn string = 'url'

@description('Name of Azure OpenAI Resource')
param AzureOpenAIResource string = 'zedyopenai02'

@description('Azure OpenAI Model Deployment Name')
param AzureOpenAIModel string = 'gpt-35-turbo'

@description('Azure OpenAI Model Name')
param AzureOpenAIModelName string = 'gpt-35-turbo'

@description('Azure OpenAI Key')
param AzureOpenAIKey string = '5deacafac21744c6990d3fe2aa5c0067'

@description('Orchestration strategy: openai_function or langchain str. If you use a old version of turbo (0301), plese select langchain')
@allowed([
  'openai_function'
  'langchain'
])
param OrchestrationStrategy string = 'langchain'

@description('Azure OpenAI Temperature')
param AzureOpenAITemperature string = '0'

@description('Azure OpenAI Top P')
param AzureOpenAITopP string = '1'

@description('Azure OpenAI Max Tokens')
param AzureOpenAIMaxTokens string = '1000'

@description('Azure OpenAI Stop Sequence')
param AzureOpenAIStopSequence string = '\n'

@description('Azure OpenAI System Message')
param AzureOpenAISystemMessage string = 'You are an AI assistant that helps people find information.'

@description('Azure OpenAI Api Version')
param AzureOpenAIApiVersion string = '2023-07-01-preview'

@description('Whether or not to stream responses from Azure OpenAI')
param AzureOpenAIStream string = 'true'

@description('Azure OpenAI Embedding Model')
param AzureOpenAIEmbeddingModel string = 'text-embedding-ada-002'

@description('Azure Cognitive Search Resource')
param AzureCognitiveSearch string = '${ResourcePrefix}-search'

@description('The SKU of the search service you want to create. E.g. free or standard')
@allowed([
  'free'
  'basic'
  'standard'
  'standard2'
  'standard3'
])
param AzureCognitiveSearchSku string = 'standard'

@description('Azure Cognitive Search Index')
param AzureSearchIndex string = '${ResourcePrefix}-index'

@description('Azure Cognitive Search Conversation Log Index')
param AzureSearchConversationLogIndex string = 'conversations'

@description('Name of Storage Account')
param StorageAccountName string = '${ResourcePrefix}str'

@description('Name of Function App for Batch document processing')
param FunctionName string = '${ResourcePrefix}-backend'

@description('Azure Form Recognizer Name')
param FormRecognizerName string = '${ResourcePrefix}-formrecog'

@description('Azure Content Safety Name')
param ContentSafetyName string = '${ResourcePrefix}-contentsafety'

param newGuidString string = newGuid()

var BlobContainerName = 'documents'
var QueueName = 'doc-processing'
var ClientKey = '${uniqueString(guid(deployment().name))}${newGuidString}'
var EventGridSystemTopicName = 'doc-processing'
var tags = { 'azd-env-name': environmentName }

// Organize resources in a resource group
resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'rg-${environmentName}'
  location: location
  tags: tags
}

module searchService 'core/search/search-services.bicep' = {
  name: 'search-service'
  scope: resourceGroup
  params: {
    name: AzureCognitiveSearch
    location: location
    tags: {
      deployment : 'chatwithyourdata-sa'
    }
    sku: {
      name: AzureCognitiveSearchSku
    }
  }
}

module formRecognizer 'core/ai/cognitiveservices.bicep' = {
  name: FormRecognizerName
  scope: resourceGroup
  params: {
    name: FormRecognizerName
    location: location
    sku: {
      name: 'S0'
    }
    kind: 'FormRecognizer'
  }
}

module contentSafety './core/ai/cognitiveservices.bicep' = {
  name: ContentSafetyName
  scope: resourceGroup
  params: {
    name: ContentSafetyName
    location: location
    sku: {
      name: 'S0'
    }
  }
}

// Create an App Service Plan to group applications under the same payment plan and SKU
module appServicePlan 'core/host/appserviceplan.bicep' = {
  name: HostingPlanName
  scope: resourceGroup
  params: {
    name: HostingPlanName
    location: location
    sku: {
      name: HostingPlanSku
      capacity: 1
    }
    kind: 'linux'
  }
}

module Website './app/websiteapi.bicep' = {
  name: WebsiteName
  scope: resourceGroup
  params: {
    name: WebsiteName
    location: location
    tags: { 'azd-service-name': 'Website' }
    appServicePlanId: appServicePlan.outputs.id
    storageAccountName: StorageAccountName
    appSettings: [
      { name: 'APPINSIGHTS_CONNECTION_STRING', value: monitoring.outputs.applicationInsightsConnectionString}
      { name: 'AZURE_SEARCH_SERVICE', value: 'https://${AzureCognitiveSearch}.search.windows.net'}
      { name: 'AZURE_SEARCH_INDEX', value: AzureSearchIndex}
      { name: 'AZURE_SEARCH_CONVERSATIONS_LOG_INDEX', value: AzureSearchConversationLogIndex}
      { name: 'AZURE_SEARCH_KEY', value: listAdminKeys('Microsoft.Search/searchServices/${AzureCognitiveSearch}', '2021-04-01-preview').primaryKey}
      { name: 'AZURE_SEARCH_SEMANTIC_SEARCH_CONFIG', value: AzureSearchSemanticSearchConfig}
      { name: 'AZURE_SEARCH_INDEX_IS_PRECHUNKED', value: AzureSearchIndexIsPrechunked}
      { name: 'AZURE_SEARCH_TOP_K', value: AzureSearchTopK}
      { name: 'AZURE_SEARCH_ENABLE_IN_DOMAIN', value: AzureSearchEnableInDomain}
      { name: 'AZURE_SEARCH_CONTENT_COLUMNS', value: AzureSearchContentColumns}
      { name: 'AZURE_SEARCH_FILENAME_COLUMN', value: AzureSearchFilenameColumn}
      { name: 'AZURE_SEARCH_TITLE_COLUMN', value: AzureSearchTitleColumn}
      { name: 'AZURE_SEARCH_URL_COLUMN', value: AzureSearchUrlColumn}
      { name: 'AZURE_OPENAI_RESOURCE', value: AzureOpenAIResource}
      { name: 'AZURE_OPENAI_KEY', value: AzureOpenAIKey}
      { name: 'AZURE_OPENAI_MODEL', value: AzureOpenAIModel}
      { name: 'AZURE_OPENAI_MODEL_NAME', value: AzureOpenAIModelName}
      { name: 'AZURE_OPENAI_TEMPERATURE', value: AzureOpenAITemperature}
      { name: 'AZURE_OPENAI_TOP_P', value: AzureOpenAITopP}
      { name: 'AZURE_OPENAI_MAX_TOKENS', value: AzureOpenAIMaxTokens}
      { name: 'AZURE_OPENAI_STOP_SEQUENCE', value: AzureOpenAIStopSequence}
      { name: 'AZURE_OPENAI_SYSTEM_MESSAGE', value: AzureOpenAISystemMessage}
      { name: 'AZURE_OPENAI_API_VERSION', value: AzureOpenAIApiVersion}
      { name: 'AZURE_OPENAI_STREAM', value: AzureOpenAIStream}
      { name: 'AZURE_OPENAI_EMBEDDING_MODEL', value: AzureOpenAIEmbeddingModel}
      { name: 'AZURE_FORM_RECOGNIZER_ENDPOINT', value: 'https://${location}.api.cognitive.microsoft.com/'}
      { name: 'AZURE_FORM_RECOGNIZER_KEY', value: listKeys('Microsoft.CognitiveServices/accounts/${FormRecognizerName}', '2023-05-01').key1}
      { name: 'AZURE_BLOB_ACCOUNT_NAME', value: StorageAccountName}
      { name: 'AZURE_BLOB_CONTAINER_NAME', value: BlobContainerName}
      { name: 'ORCHESTRATION_STRATEGY', value: OrchestrationStrategy}
      { name: 'AZURE_CONTENT_SAFETY_ENDPOINT', value: ContentSafetyName}
      { name: 'AZURE_CONTENT_SAFETY_KEY', value: listKeys('Microsoft.CognitiveServices/accounts/${ContentSafetyName}', '2023-05-01').key1}
    ]
  }
  dependsOn:[
    appServicePlan
  ]
}

module WebsiteName_admin './app/websiteadmin.bicep' = {
  name: '${WebsiteName}-admin'
  scope: resourceGroup
  params: {
    name: '${WebsiteName}-admin'
    location: location
    tags: { 'azd-service-name': 'WebsiteName_admin' }
    appServicePlanId: appServicePlan.outputs.id
    storageAccountName: StorageAccountName
    appSettings: [
      { name: 'APPINSIGHTS_INSTRUMENTATIONKEY', value: monitoring.outputs.applicationInsightsInstrumentationKey }
      { name: 'AZURE_SEARCH_SERVICE', value: 'https://${AzureCognitiveSearch}.search.windows.net' }
      { name: 'AZURE_SEARCH_KEY', value: listAdminKeys('Microsoft.Search/searchServices/${AzureCognitiveSearch}', '2021-04-01-preview').primaryKey }
      { name: 'AZURE_SEARCH_INDEX', value: AzureSearchIndex }
      { name: 'AZURE_SEARCH_USE_SEMANTIC_SEARCH', value: AzureSearchUseSemanticSearch }
      { name: 'AZURE_SEARCH_SEMANTIC_SEARCH_CONFIG', value: AzureSearchSemanticSearchConfig }
      { name: 'AZURE_SEARCH_INDEX_IS_PRECHUNKED', value: AzureSearchIndexIsPrechunked }
      { name: 'AZURE_SEARCH_TOP_K', value: AzureSearchTopK }
      { name: 'AZURE_SEARCH_ENABLE_IN_DOMAIN', value: AzureSearchEnableInDomain }
      { name: 'AZURE_SEARCH_CONTENT_COLUMNS', value: AzureSearchContentColumns}
      { name: 'AZURE_SEARCH_FILENAME_COLUMN', value: AzureSearchFilenameColumn }
      { name: 'AZURE_SEARCH_TITLE_COLUMN', value: AzureSearchTitleColumn}
      { name: 'AZURE_SEARCH_URL_COLUMN', value: AzureSearchUrlColumn }
      { name: 'AZURE_OPENAI_RESOURCE', value: AzureOpenAIResource}
      { name: 'AZURE_OPENAI_KEY', value: AzureOpenAIKey}
      { name: 'AZURE_OPENAI_MODEL', value: AzureOpenAIModel }
      { name: 'AZURE_OPENAI_MODEL_NAME', value: AzureOpenAIModelName }
      { name: 'AZURE_OPENAI_TEMPERATURE', value: AzureOpenAITemperature }
      { name: 'AZURE_OPENAI_TOP_P', value: AzureOpenAITopP }
      { name: 'AZURE_OPENAI_MAX_TOKENS', value: AzureOpenAIMaxTokens }
      { name: 'AZURE_OPENAI_STOP_SEQUENCE', value: AzureOpenAIStopSequence }
      { name: 'AZURE_OPENAI_SYSTEM_MESSAGE', value: AzureOpenAISystemMessage }
      { name: 'AZURE_OPENAI_API_VERSION', value: AzureOpenAIApiVersion }
      { name: 'AZURE_OPENAI_STREAM', value: AzureOpenAIStream }
      { name: 'AZURE_OPENAI_EMBEDDING_MODEL', value: AzureOpenAIEmbeddingModel }
      { name: 'AZURE_FORM_RECOGNIZER_ENDPOINT', value: 'https://${location}.api.cognitive.microsoft.com/' }
      { name: 'AZURE_FORM_RECOGNIZER_KEY', value: listKeys('Microsoft.CognitiveServices/accounts/${FormRecognizerName}', '2023-05-01').key1 }
      { name: 'AZURE_BLOB_ACCOUNT_NAME', value: StorageAccountName }
      { name: 'AZURE_BLOB_CONTAINER_NAME', value: BlobContainerName }
      { name: 'DOCUMENT_PROCESSING_QUEUE_NAME', value: QueueName}
      { name: 'BACKEND_URL', value: 'https://${FunctionName}.azurewebsites.net'}
      { name: 'FUNCTION_KEY', value: ClientKey}
      { name: 'ORCHESTRATION_STRATEGY', value: OrchestrationStrategy}
      { name: 'AZURE_CONTENT_SAFETY_ENDPOINT', value: ContentSafetyName}
      { name: 'AZURE_CONTENT_SAFETY_KEY', value: listKeys('Microsoft.CognitiveServices/accounts/${ContentSafetyName}', '2023-05-01').key1}
    ]
  }
  dependsOn:[
    appServicePlan
  ]
}

module storage 'app/storage.bicep' = {
  name: StorageAccountName
  scope: resourceGroup
  params: {
    StorageAccountName: StorageAccountName
    location: location
    BlobContainerName: BlobContainerName
  }
}

// Monitor application with Azure Monitor
module monitoring './core/monitor/monitoring.bicep' = {
  name: 'monitoring'
  scope: resourceGroup
  params: {
    location: location
    tags: {
      'hidden-link:${resourceId('Microsoft.Web/sites', ApplicationInsightsName)}': 'Resource'
    }
    applicationInsightsName: ApplicationInsightsName
    applicationInsightsDashboardName: '${ResourcePrefix}-dash-appinsights'
    logAnalyticsName: '${ResourcePrefix}-loganalytics'
  }
}

module Function './app/function.bicep' = {
  name: FunctionName
  scope: resourceGroup
  params:{
    name: FunctionName
    location: location
    tags: union(tags, { 'azd-service-name': 'Function' })
    appServicePlanId: appServicePlan.outputs.id
    runtimeName:'python'
    runtimeVersion:'3.11'
    storageAccountName: StorageAccountName
    ClientKey: ClientKey
    appSettings: [
      { name: 'FUNCTIONS_EXTENSION_VERSION', value: '~4'}
      { name: 'WEBSITES_ENABLE_APP_SERVICE_STORAGE', value: 'false'}
      { name: 'APPINSIGHTS_INSTRUMENTATIONKEY', value: monitoring.outputs.applicationInsightsInstrumentationKey}
      { name: 'AZURE_OPENAI_MODEL', value: AzureOpenAIModel}
      { name: 'AZURE_OPENAI_EMBEDDING_MODEL', value: AzureOpenAIEmbeddingModel}
      { name: 'AZURE_OPENAI_RESOURCE', value: AzureOpenAIResource}
      { name: 'AZURE_OPENAI_KEY', value: AzureOpenAIKey}
      { name: 'AZURE_BLOB_ACCOUNT_NAME', value: StorageAccountName}
      { name: 'AZURE_BLOB_CONTAINER_NAME', value: BlobContainerName}
      { name: 'AZURE_FORM_RECOGNIZER_ENDPOINT', value: 'https://${location}.api.cognitive.microsoft.com/'}
      { name: 'AZURE_FORM_RECOGNIZER_KEY', value: listKeys('Microsoft.CognitiveServices/accounts/${FormRecognizerName}', '2023-05-01').key1}
      { name: 'AZURE_SEARCH_SERVICE', value: 'https://${AzureCognitiveSearch}.search.windows.net'}
      { name: 'AZURE_SEARCH_KEY', value: listAdminKeys('Microsoft.Search/searchServices/${AzureCognitiveSearch}', '2021-04-01-preview').primaryKey}
      { name: 'DOCUMENT_PROCESSING_QUEUE_NAME', value: QueueName}
      { name: 'AZURE_OPENAI_API_VERSION', value: AzureOpenAIApiVersion}
      { name: 'AZURE_SEARCH_INDEX', value: AzureSearchIndex}
      { name: 'ORCHESTRATION_STRATEGY', value: OrchestrationStrategy}
      { name: 'AZURE_CONTENT_SAFETY_ENDPOINT', value: ContentSafetyName}
      { name: 'AZURE_CONTENT_SAFETY_KEY', value: listKeys('Microsoft.CognitiveServices/accounts/${ContentSafetyName}', '2023-05-01').key1}
    ]
  }
}

module eventgrid './app/eventgrid.bicep' = {
  name: '${ResourcePrefix}-eventgrid'
  scope: resourceGroup
  params:{
    EventGridSystemTopicName: EventGridSystemTopicName
    location: location
    StorageAccountId: storage.outputs.StorageAccountId
    StorageAccountName_default_doc_processing_name: storage.outputs.StorageAccountName_default_doc_processing_name
    BlobContainerName: BlobContainerName
  }
}


