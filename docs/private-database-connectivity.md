# Private database connectivity — DEVOPS-011

## Target architecture

When `enable_private_database=true`, the Terraform configuration provisions:
- a VNet (`10.42.0.0/16`);
- a dedicated Container Apps infrastructure subnet (`10.42.0.0/23`) delegated to `Microsoft.App/environments`;
- a separate PostgreSQL Flexible Server subnet (`10.42.2.0/28`) delegated to `Microsoft.DBforPostgreSQL/flexibleServers`;
- the `private.postgres.database.azure.com` private DNS zone and a VNet link;
- PostgreSQL Flexible Server with the delegated subnet and private DNS zone, and public network access disabled;
- a VNet-integrated Container Apps environment so the backend can resolve and route to the private database FQDN.

The frontend remains externally reachable through the Container Apps ingress. Its `/api/` requests are proxied to the internal backend ingress. The backend reaches PostgreSQL using the server FQDN and TLS; private DNS resolves that hostname to the private network path. No public PostgreSQL firewall rule is created in private mode.

## Important migration warning

Switching an already-created public PostgreSQL Flexible Server to delegated-subnet private access, or adding/changing Container Apps environment infrastructure subnet configuration, can require resource replacement. This is not a zero-downtime in-place toggle. Before enabling private mode on an environment containing data:
1. take and verify a database backup/export;
2. review `terraform plan` for PostgreSQL and Container Apps environment replacement;
3. plan data restore/migration, DNS cutover, application restart, and rollback;
4. apply only in a maintenance window after approval.

For disposable development resources, recreation may be acceptable after confirming no data needs to be retained. Do not enable this flag blindly on a shared or production environment.

## Configuration

Set the feature flag in a reviewed environment-specific tfvars file or the current PowerShell session:
```powershell
$env:TF_VAR_enable_private_database = "true"
```
Run `terraform fmt -recursive`, `terraform validate`, then save and inspect a plan. Confirm the plan disables public PostgreSQL access and does not leave any broad firewall rule.

## Verification after deployment

The following checks require an active Azure subscription and a successful apply:
1. Confirm `publicNetworkAccess` is disabled for the PostgreSQL Flexible Server.
2. Confirm the server is attached to the delegated PostgreSQL subnet and the private DNS zone is linked to the VNet.
3. From the backend Container App, verify the PostgreSQL FQDN resolves privately and TCP/TLS connectivity succeeds. Use an approved diagnostic/exec method for the deployed Container Apps environment; do not publish database credentials in logs.
4. Call the public frontend URL's `/api/ready` endpoint. It must return HTTP 200 with `{"status":"ready"}`.
5. Load products and place a test order; verify persistence in PostgreSQL.
6. Confirm the public PostgreSQL endpoint cannot be reached from an external client.

Record command outputs, timestamps, and deployment revision in the ticket. Until those live checks are run, private connectivity remains **implemented in configuration but not cloud-verified**.

## Rollback

Rollback is not simply reopening the public firewall. Restore or migrate the database deliberately, review the Terraform plan, and obtain approval before changing the network mode. Never add `0.0.0.0` as a shortcut.