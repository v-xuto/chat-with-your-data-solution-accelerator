param EventGridSystemTopicName string
param location string
param StorageAccountId string
param StorageAccountName_default_doc_processing_name string
param BlobContainerName string

resource EventGridSystemTopic 'Microsoft.EventGrid/systemTopics@2021-12-01' = {
  name: EventGridSystemTopicName
  location: location
  properties: {
    source: StorageAccountId
    topicType: 'Microsoft.Storage.StorageAccounts'
  }
}

resource EventGridSystemTopicName_BlobEvents 'Microsoft.EventGrid/systemTopics/eventSubscriptions@2021-12-01' = {
  parent: EventGridSystemTopic
  name: 'BlobEvents'
  properties: {
    destination: {
      endpointType: 'StorageQueue'
      properties: {
        queueMessageTimeToLiveInSeconds: -1
        queueName: StorageAccountName_default_doc_processing_name
        resourceId: StorageAccountId
      }
    }
    filter: {
      includedEventTypes: [
        'Microsoft.Storage.BlobCreated'
        'Microsoft.Storage.BlobDeleted'
      ]
      enableAdvancedFilteringOnArrays: true
      subjectBeginsWith: '/blobServices/default/containers/${BlobContainerName}/blobs/'
    }
    labels: []
    eventDeliverySchema: 'EventGridSchema'
    retryPolicy: {
      maxDeliveryAttempts: 30
      eventTimeToLiveInMinutes: 1440
    }
  }
}
