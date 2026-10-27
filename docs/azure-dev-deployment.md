# NovaCart Azure development deployment — DEVOPS-009

## Status and scope

This is the deployment procedure for the DEVOPS-008 Terraform baseline. **Deployment and live API verification completed on 2026-10-26 (Asia/Kolkata).** The lab resources have since been deleted to control cost; the endpoint and results below are historical, not a currently running deployment. The recorded endpoint and results below are the evidence for DEVOPS-009. Terraform validation alone is not evidence of a live deployment.

## Architecture

- Azure Container Registry (ACR) stores `novacart-backend` and `novacart-frontend` images.
- Azure Container Apps runs the FastAPI backend on port 8080 with internal ingress and the Nginx frontend on port 80 with external ingress.
- The frontend Nginx template proxies `/api/*` to the backend Container App's internal FQDN. The browser uses the same-origin `/api` path; it does not need a public backend URL.
- Azure Database for PostgreSQL Flexible Server hosts the `novacart` database. The backend connects using `DATABASE_URL` with TLS (`sslmode=require`).
- Log Analytics receives Container Apps environment logs.
- A user-assigned managed identity pulls images from ACR. ACR admin credentials are disabled.

## Prerequisites

Terraform and Docker installed; Azure CLI logged in; an active subscription; permission to create resource groups, ACR, Container Apps, role assignments, and PostgreSQL; unique ACR and PostgreSQL names; and a reviewed cost estimate. Never commit passwords or `terraform.tfvars`.

Set credentials in the current PowerShell session:
```powershell
$env:TF_VAR_subscription_id = "<active-subscription-id>"
$env:TF_VAR_db_admin_password = "<unique-strong-password>"
```
Use a password with at least 16 characters. Terraform state contains the generated database connection secret and must be protected.

## Two-phase deployment

Terraform creates the registry and platform first with `deploy_application=false`. Images must exist in ACR before Container Apps can start.

```powershell
Set-Location .\infra\azure
terraform fmt -recursive
terraform init -backend=false
terraform validate
terraform plan -out baseline.tfplan
```

Review the plan and estimated cost before applying. Apply only after confirming the subscription and spend:
```powershell
terraform apply baseline.tfplan
```

Build and push images from the repository root (replace the ACR name with the Terraform output `container_registry_login_server` host):
```powershell
Set-Location ..\..
$acrHost = "<acr-name>.azurecr.io"
az acr login --name "<acr-name>"
docker build -t "$acrHost/novacart-backend:devops-009" .\novacart\backend
docker build -t "$acrHost/novacart-frontend:devops-009" .\novacart\frontend
docker push "$acrHost/novacart-backend:devops-009"
docker push "$acrHost/novacart-frontend:devops-009-fix2"
```

Then enable the application resources and apply:
```powershell
$env:TF_VAR_deploy_application = "true"
Set-Location .\infra\azure
terraform plan -out apps.tfplan
# Inspect the plan before applying.
terraform apply apps.tfplan
terraform output frontend_url
terraform output backend_internal_fqdn
```

The frontend image uses `nginx-azure.conf.template`; the Nginx official image entrypoint substitutes `BACKEND_FQDN` at startup. The local Compose config remains separate and continues to use the `backend` service name.

## Verification checklist

After a successful real deployment, record actual results and timestamp:
```powershell
$url = terraform output -raw frontend_url
Invoke-WebRequest "$url" -UseBasicParsing
Invoke-RestMethod "$url/api/health"
Invoke-RestMethod "$url/api/ready"
Invoke-RestMethod "$url/api/products"
Invoke-RestMethod "$url/api/runtime"
```
Also place a test order through the UI and confirm it appears in order history. The backend's `/ready` endpoint checks database connectivity. **Current DEVOPS-009 development compromise:** the deployed PostgreSQL server uses `allow-azure-services-dev` (`0.0.0.0` to `0.0.0.0`) because Container Apps has many possible outbound IPs. This permits Azure services—including services in other customers' subscriptions—to attempt connections. It is broader than the source-IP allowlist originally designed and is not appropriate for production. DEVOPS-011 must remove public PostgreSQL exposure and verify the private path. The old `backend_egress` loop that attempted hundreds of individual rules has been removed from the current configuration.

## Recorded deployment verification — 2026-10-26

- **Status:** Terraform apply succeeded; frontend and backend Container Apps are deployed.
- **Region / resource group:** Central India / `rg-novacart-dev`.
- **Public frontend:** https://ca-novacart-dev-frontend.purplemeadow-6a1a6da7.centralindia.azurecontainerapps.io
- **Internal backend FQDN:** `ca-novacart-dev-backend.internal.purplemeadow-6a1a6da7.centralindia.azurecontainerapps.io`
- **PostgreSQL FQDN:** `pg-novacart-asif-20261022.postgres.database.azure.com`; database `novacart`.
- **Images:** backend `novacart-backend:devops-009`; frontend `novacart-frontend:devops-009-fix2`.
- **Terraform:** `fmt` and `validate` passed. The final image deployment apply reported `0 added, 2 changed, 0 destroyed`; no mass firewall rule creation was included.
- **Runtime checks:** frontend HTTP 200; `/api/health` returned `status=ok`; `/api/ready` returned `status=ready`; `/api/products` returned three seeded products; `/api/runtime` reported `database_configured=true`; `/api/orders?limit=5` returned a saved order record.
- **Verification timestamp:** health endpoint reported `2026-10-26T20:39:20+05:30` (India Standard Time). All five API checks passed in the subsequent PowerShell test run.
- **Persistence clarification:** catalog products are seeded database data, not user-created products. Cart contents are browser-side demo state and are not expected to survive a browser refresh; persisted orders are stored through the backend/database.

## Expected endpoint

The expected public endpoint is the Terraform output `frontend_url`. The backend is internal-only and is not intended to be called directly from a public browser. Browser requests to `/api/...` are proxied by Nginx to the backend.

## Evidence status

- Repository configuration and Terraform validation: record results after local checks.
- Azure resource creation, public URL, API behavior, database persistence, and browser verification: **not verified until performed against an active subscription**.
- Cost: estimate with the Azure Pricing Calculator and confirm subscription budget before applying. Budget alerts are not spending caps.

## Cleanup

Review the destroy plan carefully before deleting resources. Export any data needed first. Do not destroy shared resources or a database containing data you need.