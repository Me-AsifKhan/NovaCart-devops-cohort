# NovaCart — DevOps Cohort Project

NovaCart is a small commerce demo for practising containerization, local orchestration, CI, Terraform, Azure, security, and operations.

## Architecture

- Frontend: static storefront served by Nginx.
- Backend: FastAPI API on port 8080.
- Local database: PostgreSQL via Compose with a named persistent volume.
- Intended Azure development architecture: Azure Container Apps, ACR, PostgreSQL Flexible Server, Log Analytics, and Terraform.
- Traffic path: browser → public frontend → internal backend → PostgreSQL. The browser does not connect directly to the backend or database.

The Azure development deployment was previously live-tested, but the lab resources have since been deleted. Any endpoints recorded in `docs/azure-dev-deployment.md` are historical, not active URLs.

## Run locally

Open Docker Desktop and wait until its Linux engine is running before running Docker commands.

```powershell
Set-Location .\novacart
docker compose -f compose.yaml config --quiet
docker compose -f compose.yaml up --build -d
docker compose -f compose.yaml ps
```

Open `http://localhost:8081`. Verify:

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
| `.github/workflows/ci.yml` | Pull-request checks, tests, and container builds |
| `.github/workflows/terraform-azure-infra.yml` | DEVOPS-013 infrastructure workflow (add during that ticket) |
| `infra/azure/` | Terraform root module for Azure development infrastructure |
| `docs/` | Application, architecture, operations, and engineering reviews |
| `tickets/` | DEVOPS-001 through DEVOPS-016 acceptance criteria |
| `ONBOARDING.md` | Cohort setup guidance |

## Safe working rules

- Never commit `.env`, real `terraform.tfvars`, Terraform state, saved `*.tfplan` files, passwords, tokens, or connection strings.
- Use `terraform plan` and review every replacement/deletion, network change, identity permission, and cost before apply.
- DEVOPS-011's private networking design is merged but has not been live-verified. Do not claim private DB acceptance until deployed and tested.
- Before CI manages shared infrastructure, DEVOPS-013 must provide protected remote state, locking/recovery safeguards, and OIDC-based Azure authentication.
- Record actual verification separately from planned controls. Local validation is not proof of a live cloud deployment.