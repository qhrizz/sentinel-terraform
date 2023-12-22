@description('Name of the Alert group, must NOT exceed 12 characters')
param actionGroups_LA_to_Soc_name string = 'Alert-SOC'
param alertEmail string = 'myEmail@domain.com'

resource actionGroups_LA_to_Soc_name_resource 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: actionGroups_LA_to_Soc_name
  location: 'Global'
  properties: {
    groupShortName: actionGroups_LA_to_Soc_name
    enabled: true
    emailReceivers: [
      {
        name: 'support_-EmailAction-'
        emailAddress: alertEmail
        useCommonAlertSchema: false
      }
    ]
    smsReceivers: []
    webhookReceivers: []
    eventHubReceivers: []
    itsmReceivers: []
    azureAppPushReceivers: []
    automationRunbookReceivers: []
    voiceReceivers: []
    logicAppReceivers: []
    azureFunctionReceivers: []
    armRoleReceivers: []
  }
}
