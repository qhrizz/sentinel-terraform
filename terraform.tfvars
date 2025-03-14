// This is the name of the AD Groups created and delegated 
Sentinel-OwnerGroupName = "Sentinel - Owner"
Sentinel-ContributorGroupName = "Sentinel - Contributor"
// Name of the managed identity
managed-identity-name = "managed-SPN-MDE-SIEM"
// RG group, region, name of the LA and the alert email for failed logic app runs
resource-group = "rg-sentinel"
azure-region = "Sweden Central"
log-analytics-workspace-name = "log-sentinel-swedencentral-prod-01"
alertEmail = "email@email.com"
// Set Days of retention
retention-in-days = "90"
// Name of the customer, used in some logic apps and alert action group
customerName = "CustomerName"
//Subscription ID 
subscriptionId = "00000000-0000-0000-0000-000000000000"