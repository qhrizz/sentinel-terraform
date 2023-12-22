param logicAppName string = 'Isolate-MDEMachine'
param apiName string = 'Microsoft-Sentinel-API-Connector'
param apiNameWDATP string = 'Microsoft-WDATP-API-Connector'
param subscriptionID string = subscription().subscriptionId
param location string = resourceGroup().location
param resourceGroupname string = resourceGroup().name
param managedIdentityName string = 'managed-SPN-MDE-SIEM'
//Api names to connect to - DO NOT CHANGE
var ConnectionName = 'azuresentinel'
var ConnectionApiNameWDATP_var = 'wdatp'

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

resource ConnectionApiNameWDATP 'Microsoft.Web/connections@2018-07-01-preview' = {
  name: ConnectionApiNameWDATP_var
  location: location
  properties: {
    displayName: apiNameWDATP
    parameterValueType: 'Alternative'
    api: {
      id: '/subscriptions/${subscriptionID}/providers/Microsoft.Web/locations/${location}/managedApis/${ConnectionApiNameWDATP_var}'
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
          runAfter: {}
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
            Condition: {
              actions: {
                'Actions_-_Isolate_machine': {
                  runAfter: {}
                  type: 'ApiConnection'
                  inputs: {
                    body: {
                      Comment: 'Isolated from playbook for Azure Sentinel Incident:  @{triggerBody()?[\'object\']?[\'properties\']?[\'incidentNumber\']} - @{triggerBody()?[\'object\']?[\'properties\']?[\'title\']}'
                      IsolationType: 'Full'
                    }
                    host: {
                      connection: {
                        name: '@parameters(\'$connections\')[\'wdatp\'][\'connectionId\']'
                      }
                    }
                    method: 'post'
                    path: '/api/machines/@{encodeURIComponent(items(\'For_each\')?[\'additionalData\']?[\'MdatpDeviceId\'])}/isolate'
                  }
                }
                'Add_comment_to_incident_(V3)': {
                  runAfter: {
                    'Actions_-_Isolate_machine': [
                      'Succeeded'
                    ]
                  }
                  type: 'ApiConnection'
                  inputs: {
                    body: {
                      incidentArmId: '@triggerBody()?[\'object\']?[\'id\']'
                      message: '<p>@{items(\'For_each\')?[\'HostName\']} was isolated in MDE and the status was @{body(\'Actions_-_Isolate_machine\')?[\'status\']}</p>'
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
              }
              runAfter: {}
              else: {
                actions: {
                  'Add_comment_to_incident_(V3)_2': {
                    runAfter: {}
                    type: 'ApiConnection'
                    inputs: {
                      body: {
                        incidentArmId: '@triggerBody()?[\'object\']?[\'id\']'
                        message: '<p>@{items(\'For_each\')?[\'HostName\']} does not have MDEDeviceID in the Entities list. &nbsp;It was not isolated.&nbsp;</p>'
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
                }
              }
              expression: {
                or: [
                  {
                    equals: [
                      '@triggerBody()?[\'object\']?[\'properties\']?[\'severity\']'
                      'High'
                    ]
                  }
                  {
                    equals: [
                      '@triggerBody()?[\'object\']?[\'properties\']?[\'severity\']'
                      'Medium'
                    ]
                  }
                  {
                    equals: [
                      '@triggerBody()?[\'object\']?[\'properties\']?[\'severity\']'
                      'Low'
                    ]
                  }
                ]
              }
              type: 'If'
            }
          }
          runAfter: {
            'Entities_-_Get_Hosts': [
              'Succeeded'
            ]
          }
          type: 'Foreach'
        }
      }
      outputs: {}
    }
    parameters: {
      '$connections': {
        value: {
          azuresentinel: {
            connectionId: Connection.id
            connectionName: 'azuresentinel'
            connectionProperties: {
              authentication: {
                type: 'ManagedServiceIdentity'
                identity: '/subscriptions/${subscriptionID}/resourceGroups/${resourceGroupname}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/${managedIdentityName}'
              }
            }
            id: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Web/locations/${location}/managedApis/${ConnectionName}'
          }
          wdatp: {
            connectionId: ConnectionApiNameWDATP.id
            connectionName: 'wdatp'
            connectionProperties: {
              authentication: {
                type: 'ManagedServiceIdentity'
                identity: '/subscriptions/${subscriptionID}/resourceGroups/${resourceGroupname}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/${managedIdentityName}'
              }
            }
            id: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Web/locations/${location}/managedApis/wdatp'
          }
        }
      }
    }
  }
}
