# NovaCart — DevOps Cohort Project

NovaCart is a small commerce demo for practising containerization, local orchestration, CI, Terraform, Azure, identity/security, observability, and operational recovery.

## Current project status — checked 2026-10-29

**The Azure lab is intentionally torn down to control cost.** The Azure CLI inventory after cleanup showed no resource groups or resources in the selected subscription. The previous NovaCart Azure deployment was genuinely live-tested on **2026-10-26**; its recorded endpoint and verification evidence are historical, not a currently available demo. See [the deployment record](docs/azure-dev-deployment.md).

The Terraform configuration, deployment workflow, OIDC workflow, application source, and documentation remain in GitHub. However:

- The Terraform remote-state resource group and Storage Account were deleted on 2026-10-29. The last remote state was backed up locally before deletion. Keep that backup private; never commit it.
- The OIDC backend-test and Terraform plan workflows depend on that backend and will not currently complete. Recreate and verify the backend before using them again.
- The Azure deployment workflow expects an existing development resource group, registry, and Container Apps. It does not provision those resources, so it cannot deploy until the environment is deliberately rebuilt.
- The private PostgreSQL networking design is present in Terraform, but it was not live-verified after enabling private mode.

This is a cost-controlled learning repository, not a claim that a live Azure environment is currently running.

## Architecture

- **Frontend:** static storefront served by Nginx.
- **Backend:** FastAPI API on port 8080.
- **Local database:** PostgreSQL through Docker Compose with a named persistent volume.
- **Intended Azure DEV architecture:** Azure Container Apps, Azure Container Registry (ACR), PostgreSQL Flexible Server, Log Analytics, and Terraform.
- **Traffic flow:** browser → public frontend → internal backend → PostgreSQL. The browser does not connect directly to the backend or database.

## Run locally

Start Docker Desktop and wait for its Linux engine to be ready. Run these commands from the repository root:

```powershell
Set-Location .\novacart
docker compose -f compose.yaml config --quiet
docker compose -f compose.yaml up --build -d
docker compose -f compose.yaml ps
```

Open `http://localhost:8081` and verify the API paths:

```powershell
Invoke-RestMethod "http://localhost:8081/api/health"
Invoke-RestMethod "http://localhost:8081/api/ready"
Invoke-RestMethod "http://localhost:8081/api/products"
Invoke-RestMethod "http://localhost:8081/api/orders?limit=5"
```

Stop the stack with `docker compose -f compose.yaml down`. The named PostgreSQL volume remains. Use `docker compose -f compose.yaml down -v` only when you deliberately want to delete the local database volume and its data.

## Repository layout

| Path | Purpose |
|---|---|
| `novacart/` | Application source and local Compose stack |
| `novacart/compose.yaml` | Frontend, backend, and PostgreSQL services |
| `.github/workflows/ci.yml` | Pull-request tests, validation, and container builds |
| `.github/workflows/terraform-azure-infra.yml` | Terraform static validation on relevant pull requests |
| `.github/workflows/terraform-azure-oidc-test.yml` | Manual OIDC and remote-state connectivity test; currently blocked by the deleted backend |
| `.github/workflows/terraform-azure-plan.yml` | Manual Terraform plan-only workflow; currently blocked by the deleted backend |
| `.github/workflows/azure-dev-deploy.yml` | Image publish/deploy workflow; requires existing Azure DEV resources |
| `infra/azure/` | Current Terraform configuration, in one root module |
| `docs/` | Architecture, deployment evidence, reproducibility, security, observability, and operating guides |
| `tickets/` | Ticket definitions; see the ticket audit for missing/unverified items |
| `ONBOARDING.md` | Cohort setup guidance |

## Terraform structure

The current configuration does **not** yet match the mentor's proposed module/environment layout. Files such as `main.tf`, `network.tf`, and `apps.tf` are separate files in the same `infra/azure/` directory, so they are all part of one root module. There is no `modules/` directory or `environments/dev` / `environments/prd` root yet. See [Terraform structure and migration guidance](docs/terraform-reproducibility.md).

That layout is valid for a small configuration. Moving resources into reusable child modules and separate environment roots is a future maintainability improvement, not something to do casually with a populated state. The current remote backend has been deleted, and an older archived local state must not be restored blindly.

## Verified evidence versus current availability

- **Historical Azure deployment:** recorded successful frontend, health/readiness, product, runtime, and order checks on 2026-10-26 in [the deployment record](docs/azure-dev-deployment.md).
- **Current Azure deployment:** none; lab resources were intentionally removed on 2026-10-29.
- **Private database mode:** Terraform configuration and documentation are merged; live private-path acceptance remains unverified.
- **CI:** inspect the latest run in [GitHub Actions](https://github.com/Me-AsifKhan/NovaCart-devops-cohort/actions). A local validation or a successful CI run is not proof of a live Azure deployment.

## Safe working rules

- Never commit `.env`, real `terraform.tfvars`, Terraform state, saved `*.tfplan` files, passwords, tokens, or connection strings.
- Commit `terraform.tfvars.example`; keep real `terraform.tfvars` local and ignored by Git.
- `terraform init -backend=false` is for local static validation. It is not a replacement for the shared remote state backend.
- Do not run `terraform apply` until the backend is intentionally restored or a deliberate isolated local-state exercise is approved, the complete plan is reviewed, costs are estimated, and any destructive/replacement changes are understood.
- Keep historical test evidence, current configuration, and currently deployed infrastructure clearly distinguished.

## Ticket status

See [DEVOPS ticket audit 007–020](docs/ticket-status-007-020.md). It distinguishes code/documentation delivered from cloud acceptance criteria that still require live evidence. The supplied DEVOPS-019 definition and implementation are in review; DEVOPS-020 is defined, with its rollback runbook still to be completed and live rollback evidence pending. See [the capacity and availability review](docs/production-capacity-and-availability-review.md), [the safe deployment guide](docs/safe-production-deployment.md), and [the ticket audit](docs/ticket-status-007-020.md).
