param name string
param location string = 'eastus2'
param appServicePlanId string 
param storageAccountName string 
param tags object = {}

param appSettings array = []
param serviceName string = 'Function'
param runtimeName string
param runtimeVersion string
param ClientKey string


module Function '../core/host/functions.bicep' = {
  name: name
  params: {
    name: name
    location: location
    tags: union(tags, { 'azd-service-name': serviceName })
    appServicePlanId: appServicePlanId
    storageAccountName: storageAccountName
    runtimeName: runtimeName
    runtimeVersion: runtimeVersion
    appSettings: union(toObject(appSettings, entry => entry.name, entry => entry.value), {
      AZURE_BLOB_ACCOUNT_KEY: storage.listKeys().keys[0].value
    })
    
  }
}

resource FunctionName_default_clientKey 'Microsoft.Web/sites/host/functionKeys@2018-11-01' = {
  name: '${name}/default/clientKey'
  properties: {
    name: 'ClientKey'
    value: ClientKey
  }
  dependsOn: [
    Function
    WaitFunctionDeploymentSection
  ]
}

resource WaitFunctionDeploymentSection 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  kind: 'AzurePowerShell'
  name: 'WaitFunctionDeploymentSection'
  location: location
  properties: {
    azPowerShellVersion: '3.0'
    scriptContent: 'start-sleep -Seconds 300'
    cleanupPreference: 'Always'
    retentionInterval: 'PT1H'
  }
  dependsOn: [
    Function
  ]
}

resource storage 'Microsoft.Storage/storageAccounts@2021-08-01' existing = {
  name: storageAccountName
}

output SERVICE_API_NAME string = Function.outputs.name
output SERVICE_API_URI string = Function.outputs.uri

