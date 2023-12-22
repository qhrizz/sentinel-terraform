# sentinel-terraform
Repository for setting up Microsoft Sentinel using Terraform. One thing that this does is creating and delegating permission on a **user managed idenity** which makes it so much easier to work with and maintain playbooks since the app credentials does not need to be renewed. 

This terraform script will 

- Create a resource group
- Deploy Log analytics workspace
- Add the Security Insights solution
  - Pay as you go
- Set Log analytics diagnostic setting for query logging for auditing purpose (LAQuery table)
- Add the Security Insights App to the role Microsoft Sentinel Automation Contributor so that playbooks can be run by Sentinel
- Create a User assigned managed identity (this will be used in playbooks)
  - The identity is assigned the role Microsoft Sentinel Responder
  - The API permissions SecurityAlert.Read.All, Machine.Isolate and Alert.ReadWrite.All (Microsoft Defender XDR API) is added
- Creating Entra Id Groups for delegation (Owner and Contributor but this can easily be expanded upon)
  - Delegating the permissions to these groups on the Log analytics workspace
- Importing playbooks (Lots of these have been stripped from information, somewhat empty shells but should be enough to get you started)
- Creates an action group to send an email to a specified email address (Ties together with the item below)
- Sets diagnostic settings on some of the playbooks to alert to an email when they fail to run
- Deploy automation rules to automatically trigger the playbooks based on conditions

## Pre flight checklist
- Azure cli
- Terraform
- An Azure subscription
- Permissions to deploy resources
- Go through the terraform.tfvars file and edit the variables to your liking


## Deployment
- Intialize with `terraform init`
- Validate the terraform files `terraform validate`
- Plan with `terraform plan`
- If everything looks OK, deploy with `terraform apply`

## Post deployment
Some things to note

- The Automation rules conditions may have to be changed depending on your environment so make sure the conditions are correct for your use


## Bicep
The Bicep templates for the playbooks and Metric rules are included in the Bicep Template folder, might be easier to edit these and then just convert these into ARM templates and then deploy them via Terraform. 