variable "resource-group" {
  type        = string
  description = "Name of the resource group to be created"
  default     = "rg-sentinel-westeurope"
}
variable "azure-region" {
  type        = string
  description = "Set the region where the resource will be created"
  default     = "West Europe"
}
variable "log-analytics-workspace-name" {
  type        = string
  description = "Define name of the log analytics workspace"
  default = "log-sentinel-westeurope-prod-01"
}
variable "retention-in-days" {
  type        = string
  description = "Set how many days to retain logs"
  default = 180
}
variable "Sentinel-OwnerGroupName" {
  type        = string
  description = "Define the name of the Entra ID Group with delegated Owner permissions"
  default = "Sentinel - Owner"
}
variable "Sentinel-ContributorGroupName" {
  type        = string
  description = "Define the name of the Entra ID Group with delegated Contributor permissions"
  default = "Sentinel - Contributor"
}
variable "managed-identity-name" {
  type        = string
  description = "Define the name of the User Assigned Managed Identity"
  default = "managed-SPN-MDE-SIEM"
}
variable "customerName" {
  type        = string
  description = "Set customerName, like Contoso AB, used in Playbooks"
  default = "Ankeborg AB"
}
variable "alertEmail" {
  type        = string
  description = "Set alertEmail for the ActionGroup"
  default = "myEmail@domain.com"
}
