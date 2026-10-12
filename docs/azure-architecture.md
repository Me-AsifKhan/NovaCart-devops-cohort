# DEVOPS-007 — NovaCart Azure Architecture Decision Record

**Status:** Proposed — design only; this ticket creates no Azure resources or Terraform.
**Scope:** Initial development environment. Private database networking is explicitly out of scope.

## 1. Architecture decisions

- Azure Container Apps (ACA) runs the Nginx frontend and FastAPI backend.
- Azure Container Registry (ACR) stores separate frontend/backend images.
- Azure Database for PostgreSQL Flexible Server stores persistent data.
- Log Analytics receives basic Container Apps logs.
- Terraform provisions and manages the Azure environment.
- Only the frontend has public application ingress. The backend uses internal ingress. PostgreSQL is never accessed directly by the browser.
- The initial development database uses public access with restrictive firewall rules. Production networking must be reviewed separately.

## 2. Expected Azure resources

| Resource | Purpose |
|---|---|
| Resource group | Lifecycle boundary for development resources. |
| Log Analytics workspace | Central log destination and retention configuration. |
| Container Apps environment | Shared runtime boundary for both apps, integrated with Log Analytics. |
| Frontend Container App | Nginx static site; external ingress, target port 80. |
| Backend Container App | FastAPI/Uvicorn API; internal ingress, target port 8080. |
| Azure Container Registry | Private image registry for frontend and backend. |
| User-assigned managed identity | Runtime identity for Container Apps image pulls; grant pull-only registry permission. |
| PostgreSQL Flexible Server | Managed PostgreSQL service, initially public access with firewall restrictions. |
| PostgreSQL database and app role | Dedicated application database and least-privilege role. |
| PostgreSQL firewall rules | Allow only approved development source addresses; do not use broad “all Azure services” access as a shortcut. |
| GitHub Actions federated identity (recommended) | OIDC-based CI authentication for pushing images to ACR without long-lived client secrets; separate from runtime pull identity. |

Region, naming, SKUs, budget, retention, availability requirements, and subscription are not yet specified.

## 3. Traffic flow

```text
GitHub Actions -- OIDC identity with push permission --> Azure Container Registry
                                                           ^
                                                           | image pull using managed identity
                                                           |
Browser -- HTTPS --> Frontend Container App (Nginx :80)
                           |
                           | /api/* reverse proxy inside ACA environment
                           v
                    Backend Container App (internal, :8080)
                           |
                           | PostgreSQL over TLS, TCP 5432
                           v
                    PostgreSQL Flexible Server
                    (dev public endpoint + restricted firewall)

Container Apps system/console logs --> Log Analytics workspace
```

The browser calls the frontend's same-origin relative paths such as `/api/products`. Nginx proxies these requests to the backend internal ingress endpoint. The browser must not know the backend hostname, registry endpoint, or database connection string.

## 4. Endpoint contract

Real Azure FQDNs are assigned during provisioning; placeholders below are not live endpoints.

| Caller | Destination | Protocol / port | Purpose |
|---|---|---|---|
| Browser | `https://<frontend-app-fqdn>/` | HTTPS / 443 | Load frontend assets through external ACA ingress. |
| Browser | `https://<frontend-app-fqdn>/api/...` | HTTPS / 443 | Same-origin API calls. |
| Frontend Nginx | `http://<backend-internal-fqdn>:8080` | Internal ACA traffic / 8080 | Reverse-proxy API requests to FastAPI. Verify the exact internal FQDN and DNS after environment creation. |
| ACA runtime | `<registry-name>.azurecr.io` | HTTPS / 443 | Pull image manifests/layers from ACR using managed identity. |
| Backend | `<server>.postgres.database.azure.com:5432` | PostgreSQL TLS / TCP 5432 | Reach PostgreSQL using its FQDN, not a hard-coded IP. |
| Container Apps environment | Log Analytics workspace | Azure platform integration | Centralize system and console logs. |

### Hostname, port, and configuration assumptions

- Frontend ACA ingress is external; its container target port is **80** (Nginx).
- Backend ACA ingress is internal; its container target port is **8080** (FastAPI/Uvicorn).
- The backend process must bind to `0.0.0.0:8080`, not only loopback.
- The frontend JavaScript uses relative paths like `/api/products`, not localhost or a hard-coded public backend URL.
- Azure Nginx config must proxy `/api/*` to the backend internal ingress FQDN and port 8080. Preserve the intended API path; test for accidental stripping or duplication of `/api/`.
- The repository's local Compose target `backend:8080` and Docker Desktop target `host.docker.internal:8080` are not the Azure endpoint. An Azure-specific upstream is required.
- Prefer a configurable Nginx upstream injected at startup/deployment over baking environment-specific hostnames into a reusable image.
- Use the HTTPS frontend FQDN for development. Custom DNS and a custom certificate require a separate decision.
- Use PostgreSQL's FQDN and port 5432 with TLS and certificate/hostname verification once driver and trust settings are validated.

## 5. Frontend-to-backend communication

1. Browser loads the frontend from its public HTTPS FQDN.
2. JavaScript calls same-origin relative paths such as `/api/products`.
3. ACA routes the request to Nginx on port 80.
4. Nginx reverse-proxies the request to the backend's internal ACA endpoint on port 8080.
5. The response returns through Nginx to the browser.

This keeps the backend off the public application ingress and normally avoids browser CORS configuration. Confirm the exact internal FQDN and DNS behavior once the ACA environment exists.

The application currently documents `/health` and `/ready` health endpoints. Confirm their semantics before configuring ACA startup, liveness, or readiness probes. Readiness should reflect the app's ability to serve traffic and should not expose secrets.

## 6. Backend-to-PostgreSQL connectivity

- The backend reads `DATABASE_URL`; credentials must not be committed or baked into images.
- Connection string shape (illustrative only):

  `postgresql://<app-user>:<url-encoded-password>@<server>.postgres.database.azure.com:5432/<database>?sslmode=require`

- Keep TLS enabled. Prefer `sslmode=verify-full` after confirming the Python driver, trusted CA, and hostname validation setup. Do not disable TLS to bypass errors.
- Store the connection value as a Container Apps secret and reference it in backend environment configuration. Evaluate Key Vault and Microsoft Entra database authentication for production if supported by the chosen driver and deployment model.
- Use a dedicated database and least-privilege app role, not the server administrator account for normal queries.
- The frontend must never receive database credentials or `DATABASE_URL`.

### Initial development database placement

PostgreSQL Flexible Server is a separate managed PaaS service. For this development design, choose public access with firewall restrictions; private VNet integration is not designed in this ticket.

The endpoint is not automatically open. Before implementation, verify the Container Apps environment's actual outbound IP behavior and how the required addresses will be kept current. Allow only the narrow approved source addresses. If stable, narrow egress cannot be established, agree on a supported development connectivity approach instead of opening access to all Azure services. Revisit private networking and public exposure for production.

## 7. ACR image publishing and pulling

Use separate repositories and immutable tags, for example:

- `<registry-name>.azurecr.io/novacart-frontend:<commit-sha>`
- `<registry-name>.azurecr.io/novacart-backend:<commit-sha>`

Avoid `latest` for predictable releases; record the image digest or immutable tag used for each deployment.

**CI push path**
1. GitHub Actions builds and tests both images.
2. CI authenticates to Azure using OIDC/workload federation (recommended), not a long-lived client secret.
3. The CI identity gets only the registry push permission needed. This may be `AcrPush` under classic registry RBAC or an equivalent repository-writer role for ABAC-enabled registries.
4. CI pushes the tagged images to ACR.

**Container Apps pull path**
1. Assign a user-assigned managed identity to the Container Apps that need the images.
2. Grant pull-only access: for example, `AcrPull` for classic RBAC or the appropriate repository-reader role for ABAC-enabled registries.
3. Configure each app's registry settings to use that identity for `<registry-name>.azurecr.io`.
4. Do not enable ACR admin credentials simply to make deployments work.

Confirm ACR's authorization mode before choosing role names. CI push identity and runtime pull identity are separate. Registry network settings must also permit the platform to reach ACR.

## 8. Basic logging and monitoring

Connect the Container Apps environment to Log Analytics. At minimum, review:

- **Console logs:** Nginx and backend logs written to stdout/stderr.
- **System logs:** app startup, revisions, scaling, and platform events.
- **HTTP ingress logs:** configure where supported and useful for diagnosing routing and response codes.
- **Health:** ACA probes using confirmed health/readiness endpoints.
- **Database:** review Flexible Server metrics and available logs; decide whether diagnostic settings should send database logs to the workspace too.

Use structured backend logs and severity levels. Never log passwords, tokens, connection strings, or sensitive payloads. Set workspace retention and access controls. Log Analytics alone is not a full alerting, distributed tracing, or SLO solution; add alert rules and application telemetry as a follow-up requirement.

## 9. Terraform responsibility and proposed layout

Terraform should provision and manage Azure resources and configuration. This ticket does not create Terraform or deploy resources.

```text
infra/
  modules/
    container-registry/
    container-apps-environment/
    container-app/
    postgres-flexible-server/
    monitoring/
  environments/
    dev/
      main.tf
      variables.tf
      outputs.tf
      providers.tf
      versions.tf
      terraform.tfvars.example
```

Terraform should:

- Pin supported Terraform and AzureRM provider versions.
- Parameterize region, names, sizing, tags, image tags, and environment-specific settings.
- Output non-secret values such as ACR login server, frontend FQDN, backend internal FQDN, PostgreSQL FQDN, and resource IDs.
- Keep secrets out of source, committed tfvars, plan artifacts, and outputs. Sensitive values may still exist in state, so protect state access and avoid storing raw secrets where possible.
- Use a remote Azure Storage backend with access controls and state locking/lease behavior; configure versioning/recovery safeguards and never commit state files.
- Use a separate dev state/environment boundary and review plans before applying.
- Avoid portal drift; reconcile any necessary manual changes back into Terraform.
- Order dependencies predictably: logging/resource group, ACR and identities/role assignments, ACA environment, PostgreSQL, then app configuration/revisions. Account for role-assignment propagation and ensure images exist before deploying revisions.
- Separate image build/push from infrastructure provisioning and pass immutable image identifiers to deployment.

## 10. Runtime assumptions

- Frontend is Nginx on port 80; backend is FastAPI/Uvicorn on port 8080.
- Both Container Apps share one ACA environment.
- Frontend API requests use relative `/api/*` paths and Nginx reverse proxying.
- Backend uses `DATABASE_URL` to connect to Azure PostgreSQL, replacing local Compose's `db:5432` and any SQLite default.
- Frontend uses external HTTPS ingress; backend uses internal ingress.
- Development PostgreSQL uses public access plus a restricted firewall; private networking is out of scope here.
- CI pushes images before a revision references them.
- Azure-generated FQDNs, subscription, tenant, region, names, SKUs, retention, and cost budget remain to be chosen.

## 11. Risks and questions before production

### Risks / missing information

- **Database firewall and egress:** verify ACA outbound IP behavior before creating narrow firewall rules.
- **Nginx config:** local/Compose upstreams differ from Azure; a configurable Azure upstream is required.
- **Database identity:** decide password credentials versus supported Entra authentication and rotation.
- **Secrets/state:** prevent secret commits and restrict Terraform state access.
- **Release safety:** never deploy an image tag that has not been pushed; use immutable tags/digests and retain a known-good rollback revision.
- **Availability/recovery:** database sizing, HA, backup retention, restore testing, RPO, and RTO are unspecified.
- **Authorization:** ACR role depends on classic RBAC versus ABAC repository permissions.
- **App behavior:** confirm PostgreSQL schema migrations/initialization and whether readiness checks database connectivity.
- **Observability:** basic logs do not provide alerting, tracing, or SLOs automatically.

### Questions to answer before production

1. Which subscription, tenant, region, naming convention, tags, and budget apply?
2. What CPU/memory, minimum/maximum replicas, scaling rules, and revision/rollback policy are required?
3. Is a custom domain required, and who owns DNS and TLS?
4. What is the approved production database network model and egress design?
5. What database SKU, HA, backup retention, point-in-time recovery, RPO, and RTO are required?
6. Will the backend use a dedicated password-backed role or Microsoft Entra authentication?
7. Which GitHub OIDC identity is approved, and which ACR authorization model/roles will be used?
8. What secret store and rotation process are required?
9. What logs/metrics are retained, for how long, who can query them, and which alerts are mandatory?
10. What migration, seed-data, schema-versioning, and rollback procedure will be used?
11. Are WAF/edge protection, rate limiting, private endpoints, or other network controls required?
12. What compliance, data residency, security review, and operational ownership requirements apply?

## 12. Official references

- [Azure Container Apps ingress](https://learn.microsoft.com/azure/container-apps/ingress)
- [Container Apps logs and Log Analytics](https://learn.microsoft.com/azure/container-apps/log-monitoring)
- [Container Apps ACR image pulls with managed identity](https://learn.microsoft.com/azure/container-apps/managed-identity-image-pull)
- [ACR managed identity authentication and roles](https://learn.microsoft.com/azure/container-registry/container-registry-authentication-managed-identity)
- [PostgreSQL Flexible Server public networking](https://learn.microsoft.com/en-us/azure/postgresql/network/concepts-networking-public)
- [PostgreSQL Flexible Server networking options](https://learn.microsoft.com/en-us/azure/postgresql/network/how-to-networking)
- [Terraform AzureRM provider documentation](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)

**Decision summary:** external frontend ACA + internal backend ACA + PostgreSQL Flexible Server reached by the backend over TLS/TCP 5432; ACR pulls authenticated by managed identity; Log Analytics for basic visibility. Make the Azure Nginx upstream configurable and verify database firewall/egress behavior before DEVOPS-008.
