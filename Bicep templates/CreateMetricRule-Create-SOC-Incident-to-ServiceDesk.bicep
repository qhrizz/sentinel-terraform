param metricAlerts_Create_SOC_Incident_to_ServiceDesk_name string = 'Create-SOC-Incident-to-ServiceDesk'
param actionGroupName string = 'Alert-SOC'
param subscriptionID string = subscription().subscriptionId
param resourceGroupname string = resourceGroup().name
param location string = resourceGroup().location
param customerName string = 'Contoso AB'
param workflows_Create_SOC_Incident_to_ServiceDesk_externalid string = '/subscriptions/${subscriptionID}/resourceGroups/${resourceGroupname}/providers/Microsoft.Logic/workflows/${metricAlerts_Create_SOC_Incident_to_ServiceDesk_name}'
param actiongroups_qdsverige_siem_qdc_playbook_failures_externalid string = '/subscriptions/${subscriptionID}/resourceGroups/${resourceGroupname}/providers/microsoft.insights/actiongroups/${actionGroupName}'

resource customerName_metricAlerts_Create_SOC_Incident_to_ServiceDesk_name 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: '${customerName} - ${metricAlerts_Create_SOC_Incident_to_ServiceDesk_name}'
  location: 'global'
  properties: {
    severity: 2
    enabled: true
    scopes: [
      workflows_Create_SOC_Incident_to_ServiceDesk_externalid
    ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      allOf: [
        {
          threshold: 0
          name: 'Metric1'
          metricNamespace: 'Microsoft.Logic/workflows'
          metricName: 'RunsFailed'
          operator: 'GreaterThan'
          timeAggregation: 'Total'
          skipMetricValidation: false
          criterionType: 'StaticThresholdCriterion'
        }
      ]
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
    }
    autoMitigate: true
    targetResourceType: 'Microsoft.Logic/workflows'
    targetResourceRegion: location
    actions: [
      {
        actionGroupId: actiongroups_qdsverige_siem_qdc_playbook_failures_externalid
        webHookProperties: {}
      }
    ]
  }
}