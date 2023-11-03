param name string
param location string = resourceGroup().location
param tags object = {}

param appServicePlanId string
param storageAccountName string
param appCommandLine string = 'python -m streamlit run Admin.py --server.port 8000 --server.address 0.0.0.0'

param appSettings array = []
param serviceName string = 'websiteadmin'

module websiteadmin '../core/host/appservice.bicep' = {
  name: '${name}-app-module'
  params: {
    name: name
    location: location
    tags: union(tags, { 'azd-service-name': serviceName })
    appServicePlanId: appServicePlanId
    appCommandLine: appCommandLine
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

output WEBSITE_ADMIN_IDENTITY_PRINCIPAL_ID string = websiteadmin.outputs.identityPrincipalId
output WEBSITE_ADMIN_NAME string = websiteadmin.outputs.name
output WEBSITE_ADMIN_URI string = websiteadmin.outputs.uri
