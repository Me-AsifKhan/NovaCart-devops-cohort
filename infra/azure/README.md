# NovaCart Azure Terraform

This directory contains the current Terraform **root module** for the NovaCart Azure DEV design.

## Current status

The configuration files remain in source control, but Azure lab resources and the remote state Storage Account were intentionally deleted on 2026-10-29 to control cost. No Azure infrastructure is currently managed by this directory. Do not run `terraform apply` until an approved backend/state approach has been rebuilt and the full plan has been reviewed.

The old backend used Resource Group `rg-novacart-tfstate`, Storage Account `stnovacarttf1027`, container `tfstate`, and key `novacart-dev.tfstate`. Those resources do not exist now. The previous state was downloaded before teardown; keep it private and do not assume an archived state describes current Azure resources.

## Current file layout

- `main.tf`: shared platform, ACR, identity, Container Apps environment, PostgreSQL, and development firewall configuration
- `apps.tf`: optional frontend and backend Container Apps
- `network.tf`: optional VNet, delegated subnets, and PostgreSQL private DNS
- `variables.tf`: typed variables and validation
- `outputs.tf`: non-secret IDs, hostnames, and conditional endpoints
- `providers.tf`, `versions.tf`: provider and version constraints
- `backend.tf`: AzureRM backend declaration, which requires a provisioned backend to initialize remotely
- `terraform.tfvars.example`: example settings only; never commit real credentials

All `.tf` files in this directory belong to the same root module. The files are grouped by concern but are not child modules.

## Local static validation

From the repository root in PowerShell:

```powershell
terraform -chdir=infra/azure fmt -check -recursive
terraform -chdir=infra/azure init -backend=false
terraform -chdir=infra/azure validate
```

These checks require no Azure deployment and do not prove that resources can be created successfully.

## Future direction

The mentor's suggested `modules/` plus `environments/dev` / `environments/prd` layout is not implemented yet. See [Terraform reproducibility and structure guidance](../../docs/terraform-reproducibility.md) for a comparison and a staged migration plan.

Keep real `terraform.tfvars`, state files, saved plans, passwords and tokens out of Git. A real remote backend must be bootstrapped separately before OIDC backend and plan workflows can be used again.
