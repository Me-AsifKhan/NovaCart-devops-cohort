# NovaCart — DevOps Cohort Project

NovaCart is a small commerce demo used to practise the full DevOps delivery path: container packaging, local orchestration, CI checks, Terraform, Azure deployment, security, and operations.

## Architecture

- **Frontend:** static storefront served by Nginx.
- **Backend:** FastAPI API on port 8080.
- **Local database:** PostgreSQL via Docker Compose, with a named persistent volume.
- **Azure development:** Azure Container Apps for frontend/backend, Azure Container Registry for images, Azure Database for PostgreSQL Flexible Server, Log Analytics, and Terraform-managed resources.
- **Traffic:** browser → public frontend → internal backend → PostgreSQL. The browser calls same-origin `/api/*` routes; it does not connect directly to the backend or database.

The Azure environment was live-tested on **2026-10-26**. See [the DEVOPS-009 deployment record](docs/azure-dev-deployment.md) for the endpoint and test evidence. Azure resources may be stopped or deleted after the lab to control cost.

## Local quick start

**Before running any Docker command, open Docker Desktop and wait until its Linux engine is running.**

Run from the repository root in PowerShell:

```powershell
docker compose config --quiet
docker compose up --build -d
docker compose ps
```

Open `http://localhost:8081` in a browser. The following endpoints are useful for verification:

```powershell
Invoke-RestMethod "http://localhost:8081/api/health"
Invoke-RestMethod "http://localhost:8081/api/ready"
Invoke-RestMethod "http://localhost:8081/api/products"
Invoke-RestMethod "http://localhost:8081/api/orders?limit=5"
```

Stop the local stack with `docker compose down`. The named PostgreSQL volume remains, so data survives ordinary container removal. Use `docker compose down -v` only when you deliberately want to delete the local database volume and its data.

## Repository guide

| Path | Purpose |
|---|---|
| `novacart/` | Application source, Dockerfiles, and backend tests |
| `docker-compose.yml` | Local frontend/backend/PostgreSQL stack |
| `.github/workflows/ci.yml` | Pull-request tests and container build checks |
| `infra/azure/` | Terraform for Azure development infrastructure |
| `docs/application-discovery.md` | Application behaviour and runtime assumptions |
| `docs/runtime-packaging.md` | Separate frontend/backend image workflow |
| `docs/git-strategy.md` | Collaboration and merge controls |
| `docs/azure-architecture.md` | Azure architecture decision record |
| `docs/azure-dev-deployment.md` | DEVOPS-009 deployment procedure and recorded verification |
| `docs/terraform-reproducibility.md` | Terraform inputs, validation, and safe review |
| `docs/private-database-connectivity.md` | DEVOPS-011 private database design and verification plan |
| `tickets/` | Acceptance criteria and scope boundaries for DEVOPS-001 through DEVOPS-016 |

## Safe working rules

- Never commit `terraform.tfvars`, `.tfstate`, saved plan files, `.env` files, passwords, tokens, or connection strings.
- Use `terraform plan` and review all replacements, deletions, network changes, identity permissions, and cost before applying.
- The Azure DEV PostgreSQL firewall currently uses a **temporary, broad Azure-services rule** to keep DEVOPS-009 functional. It is not a production security boundary; DEVOPS-011 must remove public database exposure and verify private connectivity.
- The current Terraform backend is local. Before GitHub Actions manages shared infrastructure, DEVOPS-013 must provide a protected remote state backend, locking/recovery, and secure OIDC-based Azure authentication.
- Document actual verification results separately from planned controls. A successful Terraform validation does not prove a live cloud deployment.
