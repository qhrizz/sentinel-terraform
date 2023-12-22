@description('Name of the logic app')
param logicAppName string = 'Create-SOC-MDE-Incident-to-ServiceDesk'

@description('Name of the connector being displayed inside the logic app')
param apiName string = 'Microsoft-Sentinel-API-Connector'

@description('Get subscription Id')
param subscriptionID string = subscription().subscriptionId

@description('Get resource group location')
param location string = resourceGroup().location

@description('Name of the managed Identity to be used when connecting to the api connector')
param managedIdentityName string = 'managed-SPN-MDE-SIEM'

@description('Set resource group name')
param resourceGroupname string = resourceGroup().name
// Connection name for AzureSentinel API connection. DO NOT CHANGE
var ConnectionName = 'azuresentinel'

resource Connection 'Microsoft.Web/connections@2018-07-01-preview' = {
  name: ConnectionName
  location: location
  properties: {
    displayName: apiName
    parameterValueType: 'Alternative'
    api: {
      id: '/subscriptions/${subscriptionID}/providers/Microsoft.Web/locations/${location}/managedApis/${ConnectionName}'
      type: 'Microsoft.Web/locations/managedApis'
    }
  }
}

resource logicApp 'Microsoft.Logic/workflows@2017-07-01' = {
  name: logicAppName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '/subscriptions/${subscriptionID}/resourceGroups/${resourceGroupname}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/${managedIdentityName}': {}
    }
  }
  properties: {
    state: 'Enabled'
    definition: {
      '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
      contentVersion: '1.0.0.0'
      parameters: {
        '$connections': {
          defaultValue: {}
          type: 'Object'
        }
      }
      triggers: {
        Microsoft_Sentinel_incident: {
          type: 'ApiConnectionWebhook'
          inputs: {
            body: {
              callback_url: '@{listCallbackUrl()}'
            }
            host: {
              connection: {
                name: '@parameters(\'$connections\')[\'azuresentinel\'][\'connectionId\']'
              }
            }
            path: '/incident-creation'
          }
        }
      }
      actions: {
        'Entities_-_Get_Hosts': {
          runAfter: {
            Get_incident: [
              'Succeeded'
            ]
          }
          type: 'ApiConnection'
          inputs: {
            body: '@triggerBody()?[\'object\']?[\'properties\']?[\'relatedEntities\']'
            host: {
              connection: {
                name: '@parameters(\'$connections\')[\'azuresentinel\'][\'connectionId\']'
              }
            }
            method: 'post'
            path: '/entities/host'
          }
        }
        For_each: {
          foreach: '@body(\'Entities_-_Get_Hosts\')?[\'Hosts\']'
          actions: {
            'Add_comment_to_incident_(V3)': {
              runAfter: {
                Post_to_Webhook: [
                  'Succeeded'
                ]
              }
              type: 'ApiConnection'
              inputs: {
                body: {
                  incidentArmId: '@body(\'Get_incident\')?[\'id\']'
                  message: '<p>Incidentnumber created: @{body(\'Post_to_Webhook\')}</p>'
                }
                host: {
                  connection: {
                    name: '@parameters(\'$connections\')[\'azuresentinel\'][\'connectionId\']'
                  }
                }
                method: 'post'
                path: '/Incidents/Comment'
              }
            }
            Post_to_Webhook: {
              runAfter: {}
              type: 'Http'
              inputs: {
                body: {
                  Text: 'Insert json body or whatever'
                }
                headers: {
                  'Content-Type': 'application/json'
                }
                method: 'POST'
                uri: 'https://myapi.cloud.com/api/v2'
              }
            }
          }
          runAfter: {
            'Entities_-_Get_Hosts': [
              'Succeeded'
            ]
          }
          type: 'Foreach'
        }
        Get_incident: {
          runAfter: {}
          type: 'ApiConnection'
          inputs: {
            body: {
              incidentArmId: '@triggerBody()?[\'object\']?[\'id\']'
            }
            host: {
              connection: {
                name: '@parameters(\'$connections\')[\'azuresentinel\'][\'connectionId\']'
              }
            }
            method: 'post'
            path: '/Incidents'
          }
        }
      }
      outputs: {}
    }
    parameters: {
      '$connections': {
        value: {
          azuresentinel: {
            connectionId: Connection.id
            connectionName: ConnectionName
            // This is where we allow the managed identity to use the API connection we created.             
            connectionProperties: {
              authentication: {
                type: 'ManagedServiceIdentity'
                identity: '/subscriptions/${subscriptionID}/resourceGroups/${resourceGroupname}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/${managedIdentityName}'
              }
            }
            id: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Web/locations/${location}/managedApis/${ConnectionName}'
          }
        }
      }
    }
  }
}
