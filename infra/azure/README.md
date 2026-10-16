# NovaCart Azure development baseline — DEVOPS-008

This directory defines the Azure development platform only. It does not deploy
the NovaCart frontend or backend application containers.

## Resources

- Resource group and Log Analytics workspace
- Azure Container Registry with admin access disabled
- User-assigned managed identity and ACR pull role assignment
- Azure Container Apps environment
- Public-network Azure Database for PostgreSQL Flexible Server and database
- Optional single-IP PostgreSQL firewall rule

## Prerequisites

- Terraform >= 1.5.0
- Azure CLI authenticated to the intended tenant
- An active Azure subscription with permission to create resources and role assignments
- Globally unique ACR and PostgreSQL server names

## Configure credentials securely

Supply the subscription ID and database administrator password through
environment variables, not committed files:

PowerShell example (use your own values):

    $env:TF_VAR_subscription_id = "<subscription-id>"
    $env:TF_VAR_db_admin_password = "<unique-strong-password>"

Do not paste credentials into tickets, source files, shell transcripts, or Git.
Unset the variables when finished:

    Remove-Item Env:TF_VAR_subscription_id -ErrorAction SilentlyContinue
    Remove-Item Env:TF_VAR_db_admin_password -ErrorAction SilentlyContinue

## Validate locally

From this directory:

    terraform fmt -recursive
    terraform init -backend=false
    terraform validate

A successful local validation does not prove that Azure resources can be
created. A subscription, permissions, unique names, regional SKU availability,
and service-specific policies must be checked before deployment.

## Cost and security notes

- Review the Azure Pricing Calculator and subscription budget before applying.
- PostgreSQL public network access is enabled for the development baseline.
  No broad firewall rule is created. Set dev_client_ip only for an approved
  single client IP; later application connectivity requires a separately
  verified, narrowly scoped approach.
- The database administrator password is marked sensitive.
  Never output it or commit it. Treat Terraform state and saved plans as
  sensitive too.
- No remote backend is configured here. Before a shared deployment, configure
  a secured remote backend with access control, state locking and recovery
  safeguards.
- DEVOPS-009 is responsible for deploying the application containers.
