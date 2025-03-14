# Define providers for this terraform project
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=4.23.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.1.0"
    }
  }
}

# Configure the Microsoft Azure Provider
# Required to even work, but not neccesary to configure anything more than this
# Dunno why (shrugman)
provider "azurerm" {
  features {}
  subscription_id = var.subscriptionId
}

# Get Subscription data, used for example scope and such
data "azurerm_subscription" "primary" {
}

# Create a resource group
# Terraform location mapping list: https://github.com/claranet/terraform-azurerm-regions/blob/master/REGIONS.md
resource "azurerm_resource_group" "resourceGroup" {
  name     = var.resource-group
  location = var.azure-region
}

# Create a log analytics workspace
resource "azurerm_log_analytics_workspace" "logAnalyticsWorkspace" {
  name                = var.log-analytics-workspace-name
  location            = azurerm_resource_group.resourceGroup.location
  resource_group_name = azurerm_resource_group.resourceGroup.name
  sku                 = "PerGB2018"
  retention_in_days   = var.retention-in-days
  depends_on = [
    azurerm_resource_group.resourceGroup
 ]
}

# Onboard Sentinel to log analytics workspace 
resource "azurerm_sentinel_log_analytics_workspace_onboarding" "logAnalyticsWorkspace" {
  workspace_id                 = azurerm_log_analytics_workspace.logAnalyticsWorkspace.id
  customer_managed_key_enabled = false
}

# Assign Azure Security Insights App to be able to run playbooks
data "azuread_service_principal" "security_insight" {
  display_name = "Azure Security Insights"
}

// Set diagnostic settings for the log analytics workspace. Adds a table for LA Search queries auditing. enabled_log will show red since the intellisense module isnt up to date
resource "azurerm_monitor_diagnostic_setting" "diagnostic-settings-logAnalyticsWorkspace" {
  name               = "QueryLogs"
  target_resource_id = azurerm_log_analytics_workspace.logAnalyticsWorkspace.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.logAnalyticsWorkspace.id
  enabled_log {
    category_group = "allLogs"
  }
  metric {
    category = "AllMetrics"
  }
  depends_on = [
   azurerm_log_analytics_workspace.logAnalyticsWorkspace
 ]
}

resource "azurerm_role_assignment" "sentinel_automation_contributor" {
  scope                = data.azurerm_subscription.primary.id
  role_definition_name = "Microsoft Sentinel Automation Contributor"
  principal_id         = data.azuread_service_principal.security_insight.object_id
}

# Create SPN managed-SPN-MDE-SIEM
# Required permissions Application.ReadWrite.OwnedBy or Application.ReadWrite.All
resource "azurerm_user_assigned_identity" "managed-SPN-MDE-SIEM" {
  name                = var.managed-identity-name
  location            = var.azure-region
  resource_group_name = azurerm_resource_group.resourceGroup.name
}

# Get Azure configuration for use with the managed identity managed-SPN-MDE-SIEM
data "azurerm_client_config" "managed-SPN-MDE-SIEM" {
}

# Assign Microsoft Sentinel Responder to managed Identity managed-SPN-MDE-SIEM
resource "azurerm_role_assignment" "managed-SPN-MDE-SIEM" {
  scope                = data.azurerm_subscription.primary.id
  role_definition_name = "Microsoft Sentinel Responder"
  principal_id         = azurerm_user_assigned_identity.managed-SPN-MDE-SIEM.principal_id
}

# Get all published Apps Ids
data "azuread_application_published_app_ids" "well_known" {}
# Can be used to print which published app ids there are
/*
output "published_app_ids" {
  value = data.azuread_application_published_app_ids.well_known.result
}
*/

# This gets the MS Graph app id  which is used when assigning SecurityAlert.Read.All
resource "azuread_service_principal" "msgraph" {
  client_id = data.azuread_application_published_app_ids.well_known.result.MicrosoftGraph
  use_existing   = true
}

# azuread_app_role_assignment may fail on the first run because of replication lags in Azure, simply re-running terraform apply will add the permissions correctly.
# Assign SecurityAlert.Read Permissions
resource "azuread_app_role_assignment" "managed-SPN-MDE-SIEM-Graph-Permissions" {
  app_role_id         = azuread_service_principal.msgraph.app_role_ids["SecurityAlert.Read.All"]
  principal_object_id = azurerm_user_assigned_identity.managed-SPN-MDE-SIEM.principal_id
  resource_object_id  = azuread_service_principal.msgraph.object_id
  // Depends on that the managed Identity exists
  depends_on = [
    azurerm_user_assigned_identity.managed-SPN-MDE-SIEM,
    azurerm_role_assignment.managed-SPN-MDE-SIEM
 ]
}

# Get Windows Defender ATP AppId for use when assigning permissions in the WDATP API
resource "azuread_service_principal" "wdatp" {
  client_id = data.azuread_application_published_app_ids.well_known.result.WindowsDefenderAtp
  use_existing   = true
}

# Assign Machine.Isolate Permissions
resource "azuread_app_role_assignment" "managed-SPN-MDE-SIEM-Isolate-Permissions" {
  app_role_id         = azuread_service_principal.wdatp.app_role_ids["Machine.Isolate"]
  principal_object_id = azurerm_user_assigned_identity.managed-SPN-MDE-SIEM.principal_id
  resource_object_id  = azuread_service_principal.wdatp.object_id
  // Depends on that the managed Identity exists
  depends_on = [
    azurerm_user_assigned_identity.managed-SPN-MDE-SIEM,
    azurerm_role_assignment.managed-SPN-MDE-SIEM
 ]
}

# Assign ReadWrite Permissions on Alerts from Defender
resource "azuread_app_role_assignment" "managed-SPN-MDE-SIEM-Alert-Permissions" {
  app_role_id         = azuread_service_principal.wdatp.app_role_ids["Alert.ReadWrite.All"]
  principal_object_id = azurerm_user_assigned_identity.managed-SPN-MDE-SIEM.principal_id
  resource_object_id  = azuread_service_principal.wdatp.object_id
  // Depends on that the managed Identity exists
  depends_on = [
    azurerm_user_assigned_identity.managed-SPN-MDE-SIEM,
    azurerm_role_assignment.managed-SPN-MDE-SIEM
 ]
}

# Create Owner Group, can edit everything, including permissions
resource "azuread_group" "Sentinel_Owner" {
  display_name     = var.Sentinel-OwnerGroupName
  security_enabled = true
}
  
# Assign Owner role to group
resource "azurerm_role_assignment" "Sentinel_Owner" {
  scope                = data.azurerm_subscription.primary.id
  role_definition_name = "Owner"
  principal_id         = azuread_group.Sentinel_Owner.object_id
}
  
# Create Contributor Group, can edit dataconnectors and stuff
resource "azuread_group" "Sentinel_Contributor" {
  display_name     = var.Sentinel-ContributorGroupName
  security_enabled = true
}

# Assign Contributor role to group
resource "azurerm_role_assignment" "Sentinel_Contributor" {
  scope                = data.azurerm_subscription.primary.id
  role_definition_name = "Contributor"
  principal_id         = azuread_group.Sentinel_Contributor.object_id
}

// Read data from an ARM template to be deployed
data "local_file" "Create-SOC-Incident-to-ServiceDesk" {
  filename = "Create-SOC-Incident-to-ServiceDesk.json"
}
resource "azurerm_resource_group_template_deployment" "Create-SOC-Incident-to-ServiceDesk" {
  name                = data.local_file.Create-SOC-Incident-to-ServiceDesk.filename
  resource_group_name = azurerm_resource_group.resourceGroup.name
  deployment_mode     = "Incremental"
  template_content = data.local_file.Create-SOC-Incident-to-ServiceDesk.content
  depends_on = [
    azurerm_user_assigned_identity.managed-SPN-MDE-SIEM,
    azurerm_role_assignment.managed-SPN-MDE-SIEM
 ]
}

data "local_file" "Create-SOC-MDE-Incident-to-ServiceDesk" {
  filename = "Create-SOC-MDE-Incident-to-ServiceDesk.json"
}
resource "azurerm_resource_group_template_deployment" "Create-SOC-MDE-Incident-to-ServiceDesk" {
  name                = data.local_file.Create-SOC-MDE-Incident-to-ServiceDesk.filename
  resource_group_name = azurerm_resource_group.resourceGroup.name
  deployment_mode     = "Incremental"
  template_content = data.local_file.Create-SOC-MDE-Incident-to-ServiceDesk.content
  depends_on = [
    azurerm_user_assigned_identity.managed-SPN-MDE-SIEM,
    azurerm_role_assignment.managed-SPN-MDE-SIEM
 ]
}

// Deploy Playbook to isolate Defender machines
data "local_file" "Isolate-MDEMachine" {
  filename = "Isolate-MDEMachine.json"
}
resource "azurerm_resource_group_template_deployment" "Isolate-MDEMachine" {
  name                = data.local_file.Isolate-MDEMachine.filename
  resource_group_name = azurerm_resource_group.resourceGroup.name
  deployment_mode     = "Incremental"
  template_content = data.local_file.Isolate-MDEMachine.content
  depends_on = [
    azurerm_user_assigned_identity.managed-SPN-MDE-SIEM,
    azurerm_role_assignment.managed-SPN-MDE-SIEM
 ]
}

// Create Local variable to make the string for the resourceid when applying diagnostic settings to work.
locals {
  resourceId = "/subscriptions/${data.azurerm_subscription.primary.subscription_id}/resourceGroups/${var.resource-group}/providers/Microsoft.Logic/workflows/Isolate-MDEMachine"
}
// Set Isolate-MDEMachine Diagnostic Settings
resource "azurerm_monitor_diagnostic_setting" "diagnostic-isolate-mdemachine" {
  name               = "Send-Logs-to-LA"
  target_resource_id = local.resourceId
  log_analytics_workspace_id = azurerm_log_analytics_workspace.logAnalyticsWorkspace.id
  enabled_log {
    category_group = "allLogs"
  }  
  metric {
    category = "AllMetrics"
  }
  depends_on = [
    azurerm_resource_group_template_deployment.Isolate-MDEMachine
 ]
}

// Deploy automation rules
data "local_file" "Deploy-Automation-Rules" {
  filename = "Deploy-Automation-Rules.json"
}
resource "azurerm_resource_group_template_deployment" "Deploy-Automation-Rules" {
  name                = data.local_file.Deploy-Automation-Rules.filename
  resource_group_name = azurerm_resource_group.resourceGroup.name
  deployment_mode     = "Incremental"
  template_content = data.local_file.Deploy-Automation-Rules.content
  parameters_content = jsonencode({
    "workspaceName" = {
      value = azurerm_log_analytics_workspace.logAnalyticsWorkspace.name
    }
  })
  // Creation depends on the playbooks actually existing
  depends_on = [
    azurerm_resource_group_template_deployment.Isolate-MDEMachine,
    azurerm_resource_group_template_deployment.Create-SOC-MDE-Incident-to-ServiceDesk,
    azurerm_resource_group_template_deployment.Create-SOC-Incident-to-ServiceDesk
 ]
}

// Create Monitor Action Group
data "local_file" "Deploy-ActionGroup" {
  filename = "Create-ActionGroup-Send-Mail-to-SOC.json"
}
resource "azurerm_resource_group_template_deployment" "Deploy-ActionGroup" {
  name                = data.local_file.Deploy-ActionGroup.filename
  resource_group_name = azurerm_resource_group.resourceGroup.name
  deployment_mode     = "Incremental"
  template_content = data.local_file.Deploy-ActionGroup.content
  parameters_content = jsonencode({
    "alertEmail" = {
      value = var.alertEmail
    }
  })
  // Creation depends on the playbooks actually existing
  depends_on = [
    azurerm_resource_group_template_deployment.Create-SOC-MDE-Incident-to-ServiceDesk,
    azurerm_resource_group_template_deployment.Create-SOC-Incident-to-ServiceDesk
 ]
}

// Create Alert Rule
data "local_file" "CreateMetricRule-Create-SOC-Incident-to-ServiceDesk" {
  filename = "CreateMetricRule-Create-SOC-Incident-to-ServiceDesk.json"
}
resource "azurerm_resource_group_template_deployment" "CreateMetricRule-Create-SOC-Incident-to-ServiceDesk" {
  name                = data.local_file.CreateMetricRule-Create-SOC-Incident-to-ServiceDesk.filename
  resource_group_name = azurerm_resource_group.resourceGroup.name
  deployment_mode     = "Incremental"
  template_content = data.local_file.CreateMetricRule-Create-SOC-Incident-to-ServiceDesk.content
  parameters_content = jsonencode({
    "customerName" = {
      value = var.customerName
    }
  })
  depends_on = [
    azurerm_resource_group_template_deployment.Deploy-ActionGroup
 ]
}
data "local_file" "CreateMetricRule-Create-SOC-MDE-Incident-to-ServiceDesk" {
  filename = "CreateMetricRule-Create-SOC-MDE-Incident-to-ServiceDesk.json"
}
resource "azurerm_resource_group_template_deployment" "CreateMetricRule-Create-SOC-MDE-Incident-to-ServiceDesk" {
  name                = data.local_file.CreateMetricRule-Create-SOC-MDE-Incident-to-ServiceDesk.filename
  resource_group_name = azurerm_resource_group.resourceGroup.name
  deployment_mode     = "Incremental"
  template_content = data.local_file.CreateMetricRule-Create-SOC-MDE-Incident-to-ServiceDesk.content
  parameters_content = jsonencode({
    "customerName" = {
      value = var.customerName
    }
  })
  // Creation depends on the playbooks actually existing
  depends_on = [
    azurerm_resource_group_template_deployment.Deploy-ActionGroup
 ]
}