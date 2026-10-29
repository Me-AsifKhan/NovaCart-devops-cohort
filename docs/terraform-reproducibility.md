# Terraform reproducibility and maintenance — DEVOPS-010

## Status as of 2026-10-29

The Terraform configuration remains in GitHub and is locally inspectable. Azure lab resources and the Azure Storage remote-state backend were intentionally deleted on 2026-10-29 to control cost. The last remote state blob was downloaded before deletion; preserve that file privately and do not commit it.

The historical OIDC/backend test succeeded before teardown, but the remote backend is **not available now**. A normal remote-backend `terraform init`, the OIDC backend workflow, and the Terraform plan workflow will fail until a new backend is provisioned and the backend configuration/RBAC are verified.

Local syntax and configuration checks that deliberately disable the backend can still be run without creating Azure resources:

```powershell
terraform -chdir=infra/azure fmt -check -recursive
terraform -chdir=infra/azure init -backend=false
terraform -chdir=infra/azure validate
```

These commands do not prove that Azure resources can be created or that a live application works.

## Current Terraform structure

The repository currently uses **one root module** in `infra/azure/`. Terraform loads all `.tf` files in that directory as a single configuration and state. Splitting resources among files improves readability; it does not, by itself, create reusable child modules.

Current key files:

| File | Responsibility |
|---|---|
| `main.tf` | Resource Group, Log Analytics workspace, ACR, managed identity/ACR role assignment, Container Apps environment, PostgreSQL server/database, and development firewall configuration |
| `network.tf` | Optional VNet, delegated subnets, private DNS zone, and VNet link for DEVOPS-011 |
| `apps.tf` | Optional frontend and backend Container Apps |
| `variables.tf` | Typed inputs, validation, and defaults |
| `outputs.tf` | Resource IDs, registry host, database hostname, and conditional app endpoints |
| `providers.tf` | AzureRM provider/subscription selection |
| `versions.tf` | Terraform and provider constraints |
| `backend.tf` | Empty `azurerm` backend block whose settings were passed at initialization time |
| `terraform.tfvars.example` | Example non-secret settings; actual `terraform.tfvars` must remain local/ignored |
| `.terraform.lock.hcl` | Provider selections and checksums |

The app resources default to `deploy_application = false`; private database mode defaults to `enable_private_database = false`. Those are source defaults, not proof of the deployed environment's state. The current cloud environment has been deleted.

## Comparison with the mentor's suggested structure

**They are different.** The mentor's structure separates reusable infrastructure modules from environment-specific root configurations:

```text
infra/azure/
├── modules/
│   ├── networking/
│   ├── container-registry/
│   ├── container-apps/
│   ├── postgresql/
│   ├── key-vault/
│   └── monitoring/
└── environments/
    ├── dev/
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── terraform.tfvars.example
    │   ├── backend.tf
    │   ├── providers.tf
    │   ├── versions.tf
    │   └── outputs.tf
    └── prd/
        ├── main.tf
        ├── variables.tf
        ├── terraform.tfvars.example
        ├── backend.tf
        ├── providers.tf
        ├── versions.tf
        └── outputs.tf
```

| Concern | Current repository | Mentor's suggested structure |
|---|---|---|
| Root configuration | One root at `infra/azure/` | Separate environment roots under `environments/dev` and `environments/prd` |
| Reuse | Resources are in shared files within one module | Environment roots call child modules under `modules/` |
| Environment isolation | One variables/defaults set and one intended state key | Independent configuration and state boundary per environment |
| Monitoring | Log Analytics is declared inside current `main.tf` | A separate monitoring module can own monitoring resources |
| Key Vault | No Key Vault module or integration currently exists | A Key Vault module is a future design/build task, not something already implemented |
| Backend | `backend.tf` points to a backend configured by CLI/workflow; the Storage Account is currently deleted | Each environment's backend configuration assumes a state backend has been bootstrapped and protected |

This does **not** mean the existing Terraform is invalid. DEVOPS-010 focused on maintainability, input validation, outputs, review, and reproducibility; grouping resources into files is a reasonable first step. The mentor's layout is a useful future improvement for reuse and environment separation.

HashiCorp's [standard module structure guidance](https://developer.hashicorp.com/terraform/language/modules/develop/structure) describes modules as separate configurations with inputs and outputs. Microsoft's [Azure remote-state guide](https://learn.microsoft.com/en-us/azure/developer/terraform/store-state-in-azure-storage) explains why a remote backend with locking is suitable for collaborative infrastructure work.

## Recommended refactor approach

Make this a focused Terraform-maintenance branch before rebuilding Azure, not a surprise deployment change:

1. Keep the current single-root configuration as a reference and preserve a private copy of the current files. Do not restore an older state file blindly.
2. Extract one logical module at a time: `container-registry`, `postgresql`, `networking`, `container-apps`, and `monitoring`. Add `key-vault` only when implementing and testing that capability.
3. Each child module should expose clear inputs and outputs. Keep provider configuration and backend configuration in the environment root unless there is a strong reason otherwise.
4. Have `environments/dev/main.tf` compose module calls and provide environment-specific values. Treat `prd` as a future environment: do not pretend it is implemented or use it without production requirements, approval, independent state, and stronger access controls.
5. Commit `terraform.tfvars.example`, not a real `terraform.tfvars`. The repository's `.gitignore` already ignores real `terraform.tfvars` files. Never commit passwords, state, saved plans, or tokens.
6. Run `terraform fmt -check -recursive`, `terraform init -backend=false`, and `terraform validate` from each environment root. Review resource/module addresses and the full plan before any apply.

Moving existing resources into modules changes their Terraform addresses unless the migration is handled deliberately. If any live state exists at refactor time, use reviewed `moved` blocks or a planned state migration and validate the plan. The previously archived local state is not automatically authoritative: the current Azure subscription is empty, the current remote state backend was removed, and old state may describe resources that no longer exist.

## Environment-specific inputs and safe defaults

| Value | Guidance |
|---|---|
| `subscription_id` | Supply for the intended subscription; never copy IDs between environments without review |
| `location` | Choose per environment and confirm service/SKU availability; current code defaults to `centralindia` |
| `acr_name`, `postgres_server_name` | Globally unique and compliant with Azure naming rules |
| `db_admin_password` | Sensitive; pass securely through an environment variable or protected secret input, not a committed tfvars file |
| `postgres_sku_name`, `postgres_storage_mb`, `log_retention_days` | Choose after checking current prices, availability, retention needs, and budget |
| `backend_image_tag`, `frontend_image_tag` | Must match images already present in ACR; deployment workflow uses image digests for rollouts |
| `deploy_application` | Keep false for a platform-only plan; enable only when images and costs are ready |
| `enable_private_database` | Private-networking feature flag; changes can replace resources, so examine every replacement/deletion |
| `name_prefix`, `database_name`, `tags` | Keep stable within an environment |

## Backend lifecycle after the teardown

The old backend was:

- Resource Group: `rg-novacart-tfstate`
- Storage Account: `stnovacarttf1027`
- Container: `tfstate`
- Key: `novacart-dev.tfstate`

Those Azure resources were deleted on 2026-10-29. Do not run the existing OIDC backend or Terraform plan workflow and expect it to pass. When resuming Azure automation:

1. Decide if cloud usage is approved and estimate storage/transaction charges.
2. Bootstrap the state Storage Account and container through a separately controlled process.
3. Configure identity federation and grant Blob data-plane access at the intended container scope.
4. Update/review the backend values in workflows if the resource names change.
5. Prove backend access and locking, then run a read-only plan and inspect it before considering any apply.

Do not run `terraform init -backend=false` and then apply against a shared cloud environment as if it were the deleted remote state. That would be a different local state and can lead Terraform to propose creating resources that already exist.

## Validation before apply

Run local checks first:

```powershell
terraform -chdir=infra/azure fmt -check -recursive
terraform -chdir=infra/azure init -backend=false
terraform -chdir=infra/azure validate
```

Once a remote backend and permissions have been re-established, use the approved remote-backend plan workflow and review the entire plan. Check the selected subscription, region, image tags, role assignments, public/private database settings, and all additions, changes, replacements, and deletions. Estimate cost before applying. `validate` only validates configuration; it does not prove Azure quota, permissions, image availability, network connectivity, or live application health.

## Related documentation

- [Azure development deployment record and procedure — DEVOPS-009](azure-dev-deployment.md)
- [Private database connectivity design — DEVOPS-011](private-database-connectivity.md)
- [Automated Azure infrastructure status — DEVOPS-013](automated-azure-infrastructure.md)
- [DEVOPS ticket audit 007–020](ticket-status-007-020.md)
