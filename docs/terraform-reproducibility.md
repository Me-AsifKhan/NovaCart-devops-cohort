# Terraform reproducibility and maintenance — DEVOPS-010

## File layout

All files under `infra/azure/` remain in **one Terraform root module**. Splitting resources across files is only for readability; it does not create child modules or change Terraform resource addresses.

- `versions.tf`: Terraform and AzureRM provider version constraints.
- ackend.tf: partial Azure Blob Storage backend declaration for DEVOPS-013; backend storage must exist before standard 	erraform init can succeed.
- `providers.tf`: AzureRM provider configuration and subscription selection.
- `variables.tf`: inputs, descriptions, types, validation, and safe defaults.
- `main.tf`: resource group, Log Analytics, ACR, identity, role assignment, Container Apps environment, PostgreSQL server/database, and development firewall rules.

- `network.tf`: optional VNet, delegated subnets, private DNS zone, and VNet link for DEVOPS-011.
- `apps.tf`: optional frontend and backend Container Apps.
- `outputs.tf`: useful, non-secret IDs, hostnames, region, and application URL.
- `terraform.tfvars.example`: example non-secret settings; copy locally to `terraform.tfvars` and replace placeholders before use.
- `.terraform.lock.hcl`: selected provider versions/checksums; commit this file and change it only through a reviewed provider update.

These files all share the same variables, provider, locals, and state. Do not add modules, separate environment directories, or a remote backend as part of this ticket unless the team explicitly needs them; those are separate design decisions.

## Environment-specific versus stable values

| Value | Guidance |
|---|---|
| `subscription_id` | Required. Set as `TF_VAR_subscription_id` for the target subscription. |
| `location` | Set per environment and verify service/SKU availability. Current DEV default is `centralindia`. |
| `acr_name`, `postgres_server_name` | Must be unique in Azure and satisfy the input validations. |
| `db_admin_password` | Sensitive input via `TF_VAR_db_admin_password`; never place a real value in Git or share Terraform state. |
| `postgres_sku_name`, `postgres_storage_mb`, `log_retention_days` | Choose according to region, required capacity, retention, and reviewed cost. |
| `backend_image_tag`, `frontend_image_tag` | Must match images already pushed to ACR. Use clear versioned tags; avoid `latest` for repeatable deployments. |
| `deploy_application` | `false` for the platform-only phase; `true` when the required images exist. |
| `enable_private_database` | DEVOPS-011 feature flag. A mode change can replace networking and PostgreSQL resources; never toggle it without inspecting the plan and protecting data. |
| `name_prefix`, `database_name`, `app_environment`, `tags` | Prefer stable, reviewed naming conventions. Change only when the intended environment or resource identity changes. |
| PostgreSQL zone and resource names | Currently defined in Terraform as design defaults; review region/SKU support before changing them. |

The example file contains placeholders and no real subscription ID, password, state, or plan. Do not commit the real local `terraform.tfvars`, `.tfstate`, saved plan, `.env`, tokens, or passwords.

## Repeatable validation workflow

Run from the repository root in PowerShell. Docker Desktop is **not required** for Terraform formatting or validation.

```powershell
terraform -chdir=infra/azure fmt -check -recursive
terraform -chdir=infra/azure init -backend=false
terraform -chdir=infra/azure validate
terraform -chdir=infra/azure plan -input=false -out=review.tfplan
terraform -chdir=infra/azure show review.tfplan
```

Set required variables securely in the current shell before planning. If a plan uses local Terraform state, it must be protected just like a saved plan because sensitive values may be present. Remove the local plan file after review when it is no longer needed:
```powershell
Remove-Item .\infra\azure\review.tfplan -Force -ErrorAction SilentlyContinue
```

Review the complete plan before applying. Specifically check:
- active subscription, region, image tags, resource names, and estimated spend;
- every replacement/deletion, especially PostgreSQL and the Container Apps environment;
- public/private database access, firewall changes, subnet/DNS changes, and identity role assignments;
- that the plan does not create hundreds of individual firewall rules or expose secrets in outputs/logs.

Apply only a reviewed plan, and record the outcome. `validate` proves configuration structure, not that Azure permissions, quotas, regional availability, images, network connectivity, or application endpoints will work.

## Conventions for future changes

1. Add inputs with types and descriptions; add validation for values with clear constraints.
2. Use stable names and common tags; avoid hard-coded environment-specific IDs and secrets.
3. Keep resources grouped by responsibility in files within this root module. Preserve existing resource addresses unless a reviewed state migration is intentional.
4. Keep outputs useful and non-sensitive.
5. Use managed identity for ACR pulls; do not enable ACR admin credentials for convenience.
6. Keep the Terraform lock file committed.
7. Update this document when Terraform structure/conventions change, and update the deployment runbook only when deployment behaviour or verification changes.
8. Keep cloud changes and costs separate from local validation. Do not run `apply` without review and explicit approval.

## Related documentation

- [Azure development deployment — DEVOPS-009](azure-dev-deployment.md) explains how the environment is assembled, deployed, and live-tested.
- [Private database connectivity — DEVOPS-011](private-database-connectivity.md) explains the target private-network design and its migration/verification requirements.

This document describes Terraform structure and safe reuse. It intentionally does not repeat the DEVOPS-009 deployment walkthrough.

## Repository layout alignment

The local Compose file lives at `novacart/compose.yaml`; run Compose commands from that directory. Terraform files remain a single root module under `infra/azure/`; changing file names does not change resource addresses. Use `terraform init -backend=false` for local static validation. CI will provide remote-backend settings only after the Azure state storage account and container are bootstrapped. Never commit `*.tfplan`, Terraform state, real tfvars, or credentials.