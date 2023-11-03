param name string
param location string = 'eastus2'
param tags object = {}

param appSettings array = []
param serviceName string = 'frontend'


module frontend '../core/host/staticwebapp.bicep' = {
  name: '${name}-app-module'
  params: {
    name: name
    location: location
    tags: union(tags, { 'azd-service-name': serviceName })
    appSettings: toObject(appSettings, entry => entry.name, entry => entry.value)
  }
}

output SERVICE_API_NAME string = frontend.outputs.name
output SERVICE_API_URI string = frontend.outputs.uri

