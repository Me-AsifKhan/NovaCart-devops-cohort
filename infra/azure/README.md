# NovaCart Azure infrastructure

This Terraform configuration evolves through DEVOPS-008 (platform baseline), DEVOPS-009 (application containers), DEVOPS-010 (Terraform maintainability), and DEVOPS-011 (private PostgreSQL connectivity).

## File layout

All `.tf` files in this folder are one Terraform root module:

- `versions.tf`, `providers.tf`: version constraints and Azure provider.
- `variables.tf`, `outputs.tf`: reusable inputs and useful non-secret outputs.
- `main.tf`: resource group, logging, ACR, identity, role assignment, and Container Apps environment.
- `postgresql.tf`: database and development firewall configuration.
- `networking.tf`: optional VNet, delegated subnets, and private DNS for DEVOPS-011.
- `container_apps.tf`: frontend and backend Container Apps.
- `terraform.tfvars.example`: safe example values only.
- `.terraform.lock.hcl`: reviewed provider selection/checksums.

The files are not separate state/modules: resource addresses remain stable when moving blocks between files in this same directory.

## Prerequisites and secrets

Use Terraform >= 1.5.0, the pinned AzureRM provider, Azure CLI, an active subscription, and permissions for the requested resources and role assignments. Docker Desktop is required only when building/pushing container images. Provide `TF_VAR_subscription_id` and `TF_VAR_db_admin_password` through secure environment variables. Never commit credentials, real tfvars, state, or saved plans.

## Recommended workflow

From the repository root:
```powershell
terraform -chdir=infra/azure fmt -check -recursive
terraform -chdir=infra/azure init -backend=false
terraform -chdir=infra/azure validate
terraform -chdir=infra/azure plan -input=false -out=review.tfplan
terraform -chdir=infra/azure show review.tfplan
```

Review region/SKU costs, the exact active subscription, and every deletion/replacement, identity change, network rule, and database access change before apply. Remove the local plan file after review. Local validation does not prove cloud API permissions, quotas, regional availability, image availability, or live application health.

The two-phase deployment and runtime tests are in [`docs/azure-dev-deployment.md`](../../docs/azure-dev-deployment.md). Review [`docs/terraform-reproducibility.md`](../../docs/terraform-reproducibility.md) before extending the configuration and [`docs/private-database-connectivity.md`](../../docs/private-database-connectivity.md) before enabling private DB mode.

## Security and cost

ACR admin access is disabled; Container Apps use a user-assigned managed identity for image pulls; the backend database connection uses TLS. The current DEV environment uses PostgreSQL's `allow-azure-services-dev` firewall exception as a **temporary broad development compromise**; it allows attempts from Azure services across subscriptions and is not a production security boundary. DEVOPS-011 must remove public DB exposure and verify the private path. Do not add the old outbound-IP loop that generated hundreds of rules.

Terraform currently uses local state. Before CI manages shared infrastructure, DEVOPS-013 must establish protected remote state with locking/recovery and secure OIDC-based Azure authentication. Review the Azure Pricing Calculator and actual plan before applying. Clean up the development resource group after the lab to avoid ongoing charges.
