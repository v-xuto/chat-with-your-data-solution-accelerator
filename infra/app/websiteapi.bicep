param name string
param location string = resourceGroup().location
param tags object = {}

param appServicePlanId string
param storageAccountName string

param appSettings array = []
param serviceName string = 'Website'

module Website '../core/host/appservice.bicep' = {
  name: '${name}-app-module'
  params: {
    name: name
    location: location
    tags: union(tags, { 'azd-service-name': serviceName })
    appServicePlanId: appServicePlanId
    appSettings: union(toObject(appSettings, entry => entry.name, entry => entry.value), {
      AZURE_BLOB_ACCOUNT_KEY: storage.listKeys().keys[0].value
    })
    runtimeName: 'python'
    runtimeVersion: '3.10'
  }
}

resource storage 'Microsoft.Storage/storageAccounts@2021-08-01' existing = {
  name: storageAccountName
}

output FRONTEND_API_IDENTITY_PRINCIPAL_ID string = Website.outputs.identityPrincipalId
output FRONTEND_API_NAME string = Website.outputs.name
output SFRONTEND_API_URI string = Website.outputs.uri
