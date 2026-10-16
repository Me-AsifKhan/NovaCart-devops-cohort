# Terraform reproducibility and maintenance — DEVOPS-010

## Structure

- `versions.tf`: Terraform/provider version constraints.
- `providers.tf`: AzureRM provider configuration and subscription selection.
- `variables.tf`: configurable region, unique names, credentials, sizing, image tags, and deployment/network feature flags.
- `main.tf`: Azure resources and dependencies.
- `outputs.tf`: useful resource identifiers and application endpoints.
- `terraform.tfvars.example`: non-secret example values only.
- `.terraform.lock.hcl`: provider selections and checksums; commit it.

## Values to configure per environment

| Value | Per-environment guidance |
|---|---|
| `subscription_id` | Required; provide via `TF_VAR_subscription_id` |
| `location` | Choose a supported region and check service/SKU availability |
| `acr_name` | Globally unique alphanumeric name |
| `postgres_server_name` | Globally unique lowercase name meeting Azure naming rules |
| `db_admin_password` | Unique secret, via `TF_VAR_db_admin_password`; never commit |
| `postgres_sku_name`, `postgres_storage_mb` | Choose after capacity, availability, and price review |
| `log_retention_days` | Set to operational and compliance requirements |
| `deploy_application` | Keep false for the initial base apply; set true after images are pushed |
| `backend_image_tag`, `frontend_image_tag` | Pin to a known image tag; avoid mutable `latest` in shared environments |
| `enable_private_database` | DEVOPS-011 networking mode; review replacement and data-migration implications first |

Stable conventions: resource names derive from `name_prefix`; common tags identify application, environment, manager, and ticket. Provider version constraints and lock file should change only through a reviewed provider-upgrade workflow.

## Checks before every apply

Run from `infra/azure`:
```powershell
terraform fmt -recursive
terraform init -backend=false
terraform validate
terraform plan -out review.tfplan
terraform show review.tfplan
```
For a shared deployment, configure a secure remote backend with access control, locking, versioning/recovery, and documented ownership before applying. Do not treat a local state file or saved plan as safe to share; both may contain sensitive values. Keep state, plans, `.terraform/`, and secret tfvars out of Git.

Review every replacement/deletion, public network change, role assignment, firewall rule, SKU, region, and estimated cost. Confirm the active subscription and permissions before apply. Local validation does not prove cloud API permissions, quotas, regional availability, image availability, or live application health.

## Safe extension conventions

1. Add an input variable with type, description, validation where useful, and a safe default only when a default is genuinely appropriate.
2. Use locals for repeated naming or expressions; avoid hard-coded environment-specific IDs.
3. Use managed identity instead of registry admin credentials.
4. Keep secrets out of source control and outputs; use a protected secret store for shared production deployments.
5. Add outputs only for useful, non-secret operational values.
6. Update the relevant deployment documentation and verification evidence with every infrastructure change.
7. Review the plan and run policy/security checks before apply.

## Relationship to other tickets

See [Azure development deployment](azure-dev-deployment.md) for image build/push, two-phase deployment, endpoint configuration, and runtime verification. This document defines the repeatable Terraform authoring and review workflow; it intentionally does not duplicate the full deployment procedure.

See [Private database connectivity](private-database-connectivity.md) for the DEVOPS-011 network design and migration warnings.