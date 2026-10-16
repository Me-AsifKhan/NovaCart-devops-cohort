# NovaCart Azure infrastructure

This Terraform configuration evolves through DEVOPS-008 (platform baseline), DEVOPS-009 (application containers), DEVOPS-010 (reproducibility), and DEVOPS-011 (private PostgreSQL connectivity).

## Prerequisites and secrets

Use Terraform >= 1.5.0, the pinned AzureRM provider, Docker, Azure CLI, an active subscription, and permissions for the requested resources and role assignments. Provide `TF_VAR_subscription_id` and `TF_VAR_db_admin_password` through environment variables. Never commit credentials, secret tfvars, state, or saved plans.

## Recommended workflow

1. Set non-secret environment values in a reviewed `terraform.tfvars` created from the example.
2. Run `terraform fmt -recursive`, `terraform init -backend=false`, `terraform validate`, and inspect `terraform plan`.
3. Keep `deploy_application=false` for the first apply so Terraform can create the resource group, ACR, identity, Container Apps environment, logging, and database.
4. Build and push the frontend/backend images to ACR.
5. Set `TF_VAR_deploy_application=true`, review the second plan, and apply to create the Container Apps.
6. Follow `docs/azure-dev-deployment.md` for the detailed deployment and live verification procedure.
7. Review `docs/terraform-reproducibility.md` before extending the module.
8. Review `docs/private-database-connectivity.md` before setting `enable_private_database=true`; private mode can replace networking and PostgreSQL resources and requires a migration plan.

## Security and cost

ACR admin access is disabled; Container Apps use managed identity for image pulls. PostgreSQL uses TLS in the application connection string. Public development mode permits only explicitly created single-IP firewall rules, including backend egress addresses. Private mode disables public database access and uses VNet/private DNS. Terraform state still contains sensitive values and needs protected remote storage for team use.

Review regional SKU availability, Azure Pricing Calculator estimates, quotas, role permissions, and the full Terraform plan before applying. Budget alerts are not spending caps. No cloud deployment or live verification is claimed by local Terraform validation alone.