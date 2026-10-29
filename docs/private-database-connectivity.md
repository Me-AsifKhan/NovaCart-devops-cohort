# Private database connectivity — DEVOPS-011

## Current state — 2026-10-29

The private networking configuration is present in Terraform, but the private PostgreSQL path was not live-verified. The NovaCart Azure lab resources, including the application runtime and database, were intentionally deleted on 2026-10-29 to control cost. This guide describes the intended implementation and the checks required during a future approved rebuild; it does not claim that a private database is currently running.

## Goal and traffic path

Keep the existing app path unchanged:

```text
Browser -- HTTPS --> public Frontend Container App (Nginx)
                         |
                         | /api/* via internal backend FQDN
                         v
                  Backend Container App (FastAPI)
                         |
                         | PostgreSQL TCP 5432 + TLS
                         v
                  Private PostgreSQL Flexible Server
```

Only the database path becomes private. The storefront must remain publicly reachable and the backend must remain internal to the Container Apps environment.

## Terraform network resources

When `enable_private_database=true`, Terraform configures:

- VNet `10.42.0.0/16`.
- Dedicated Container Apps environment subnet `10.42.0.0/23`, delegated to `Microsoft.App/environments`.
- Dedicated PostgreSQL subnet `10.42.2.0/28`, delegated to `Microsoft.DBforPostgreSQL/flexibleServers`.
- Private DNS zone `private.postgres.database.azure.com` linked to the VNet.
- PostgreSQL Flexible Server attached to its delegated subnet and private DNS zone, with public network access disabled.
- Container Apps environment attached to its delegated VNet subnet, but with `internal_load_balancer_enabled=false` so the environment retains its external/public endpoint. The frontend Container App keeps external ingress; the backend Container App keeps internal ingress.
- No public PostgreSQL firewall rules in private mode.

Azure Container Apps distinguishes environment accessibility from per-app ingress. An internal environment has no public endpoint; setting the environment internal would prevent public visitors from reaching this storefront. Therefore the environment must remain **external**, while the backend app remains internal. See [Microsoft's Container Apps networking guidance](https://learn.microsoft.com/azure/container-apps/networking) and [custom VNet integration](https://learn.microsoft.com/azure/container-apps/vnet-custom).

## DNS and application connection

The backend continues using the PostgreSQL FQDN (not a hard-coded private IP) and TLS through its existing `DATABASE_URL`. Azure Private DNS resolves the PostgreSQL hostname over the linked VNet. The frontend continues proxying same-origin `/api/*` requests to the backend's internal FQDN. No application feature or route changes are needed.

## Migration warning — read before applying

Switching the existing public PostgreSQL server to delegated-subnet private access and attaching the current Container Apps environment to a VNet can force resource replacement. PostgreSQL replacement can lose the current database and test orders; environment replacement can restart both apps and change the public frontend URL.

Before applying to an environment with data:
1. Export/backup the database if any current orders or records must be retained, and verify the backup is usable.
2. Set `$env:TF_VAR_enable_private_database = "true"` only in the shell used for this deployment.
3. Run `terraform plan -out private-db.tfplan` and `terraform show private-db.tfplan`.
4. Confirm the plan disables PostgreSQL public access, attaches the private subnets/DNS, keeps the frontend environment external, and does not contain unrelated changes. Treat any PostgreSQL/environment replacement as a planned migration, not a routine update.
5. Apply only after accepting any planned database loss/downtime and cost. If the plan proposes the Container Apps environment as internal, do not apply.

For this disposable dev lab, rebuilding seeded products and making a fresh test order after replacement is acceptable only if you do not need existing test-order history.

## Deployment configuration

Run from `infra/azure` after the change is reviewed:

```powershell
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
terraform plan -out private-db.tfplan -var="deploy_application=true" -var="enable_private_database=true"
terraform show private-db.tfplan
# Apply only after reviewing the full replacement and deletion plan:
terraform apply private-db.tfplan
```

Do not reopen PostgreSQL public access or add `0.0.0.0` firewall rules as a workaround.

## Verification after a real deployment

Confirm the Azure control plane first:

```powershell
az postgres flexible-server show --resource-group "rg-novacart-dev" --name "pg-novacart-asif-20261022" --query "{publicNetworkAccess:network.publicNetworkAccess,delegatedSubnet:network.delegatedSubnetResourceId,privateDnsZone:network.privateDnsZoneArmResourceId}" -o json
az containerapp env show --name "cae-novacart-dev" --resource-group "rg-novacart-dev" --query "{provisioningState:properties.provisioningState,internal:properties.vnetConfiguration.internal,subnet:properties.vnetConfiguration.infrastructureSubnetId}" -o json
```

Expected:
- PostgreSQL `publicNetworkAccess` is `Disabled`.
- PostgreSQL has a delegated subnet and private DNS zone resource ID.
- Container Apps environment is provisioned, integrated with the VNet, and `internal` is `false` (external endpoint retained).

Then test the public frontend and backend-to-database path:

```powershell
$url = (terraform output -raw frontend_url).Trim()
(Invoke-WebRequest "$url" -UseBasicParsing -TimeoutSec 30).StatusCode
Invoke-RestMethod "$url/api/health"
Invoke-RestMethod "$url/api/ready"
Invoke-RestMethod "$url/api/products"
Invoke-RestMethod "$url/api/runtime"
Invoke-RestMethod "$url/api/orders?limit=5"
```

The frontend should return HTTP 200, health should return `ok`, readiness should return `ready`, and products/orders should return JSON. Because `/ready` tests DB connectivity, it is the quick end-to-end check that the backend can reach PostgreSQL through its private path. Place a new test order and verify it appears in order history.

Record the deployment date, new frontend URL if it changed, resource IDs, command results, and test order reference here. Until those live checks pass, describe the design as configured—not verified.

## Rollback

Do not simply reopen public PostgreSQL access. Review the rollback plan, restore/migrate the database deliberately if needed, confirm the public frontend path, and obtain approval before changing network mode again.
