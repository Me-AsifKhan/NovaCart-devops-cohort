# NovaCart Azure Architecture

**Ticket:** DEVOPS-007

**Status:** Proposed — design only
**Environment:** Development

## 1. Overview

The goal is to define how NovaCart will run in Azure before we start writing Terraform or deploying anything.

I'm proposing Azure Container Apps for the frontend and backend, Azure Container Registry for images, PostgreSQL Flexible Server for application data, and Log Analytics for basic visibility. Terraform will manage the infrastructure.

The main idea is to keep the frontend publicly accessible while keeping the backend off the public application entry point. The database will use restricted public access for the initial development environment. Private database networking is outside this ticket's scope.

## 2. Azure resources

| Resource | Why we need it |
|---|---|
| Resource group | Keeps the development resources together. |
| Container Apps environment | Provides the shared runtime environment for the frontend and backend. |
| Frontend Container App | Runs Nginx and serves the web application. |
| Backend Container App | Runs the FastAPI application. |
| Azure Container Registry (ACR) | Stores the frontend and backend images. |
| Managed identity | Lets Container Apps pull images without registry passwords. |
| PostgreSQL Flexible Server | Stores persistent application data as a managed database service. |
| PostgreSQL database and application role | Provide an isolated database and limited application permissions. |
| Log Analytics workspace | Collects platform and container logs. |
| Database firewall rules | Restrict which approved development sources can connect to PostgreSQL. |

The region, resource names, service sizes, budget and log retention period still need to be agreed upon.

## 3. How traffic will flow

The intended request flow is:

```text
                         GitHub Actions
                               |
                         Build and test
                               |
                          Push images
                               |
                               v
                     Azure Container Registry
                               |
                         Pull using identity
                               |
              +----------------+----------------+
              |                                 |
              v                                 v
      Frontend Container App            Backend Container App
       External ingress                  Internal ingress
          Nginx :80                       FastAPI :8080
              |                                 |
              | /api/*                         |
              +-------------------------------->|
                                                |
                                                v
                                    PostgreSQL Flexible Server
                                      TLS / TCP 5432

              Container Apps logs
                       |
                       v
                 Log Analytics
```

The browser connects to the frontend over HTTPS. It does not connect directly to the backend's internal hostname or to PostgreSQL.

## 4. Frontend and backend communication

The frontend will run Nginx on container port 80. The backend will run FastAPI/Uvicorn on port 8080 and must listen on `0.0.0.0`, not just localhost.

I want the frontend to call relative API paths such as `/api/products`. Nginx will forward those requests to the backend's internal Container Apps endpoint.

This keeps the browser-facing setup simple and normally avoids cross-origin browser requests.

The Azure Nginx configuration must use the backend's actual internal endpoint. The local Compose address `backend:8080` should not be assumed to work in Azure. We also need to confirm the internal hostname and DNS behavior after the Container Apps environment exists.

## 5. Database connectivity

PostgreSQL Flexible Server will run as a separate managed Azure service rather than inside an application container.

The backend will connect using a `DATABASE_URL` configuration value. Its structure will be similar to:

```text
postgresql://<app-user>:<encoded-password>@<server>.postgres.database.azure.com:5432/<database>?sslmode=require
```

This is an example, not a real connection string.

The backend must use TLS, and we should validate certificate and hostname verification before treating the connection as production-ready. Credentials must not be committed to Git or baked into the container image.

I'll use a dedicated application database role with only the permissions it needs, rather than using the PostgreSQL administrator account for normal application requests.

For development, the server will use public access with restrictive firewall rules. Before implementing this, we must verify the Container Apps environment's actual outbound IP behavior and determine how the allowed addresses will be maintained. If we cannot establish a suitably narrow and reliable allowlist, we need to agree on another supported development connectivity approach rather than opening access broadly.

## 6. Container images and identity

ACR will store separate images for the frontend and backend. Images should be tagged with a commit SHA or another immutable identifier so we know exactly what is deployed.

The expected naming pattern is:

```text
<registry>.azurecr.io/novacart-frontend:<commit-sha>
<registry>.azurecr.io/novacart-backend:<commit-sha>
```

GitHub Actions should build and test the images before publishing them to ACR. For CI authentication, I recommend Azure workload identity federation through OIDC instead of a long-lived client secret.

Container Apps should use a managed identity with pull-only permission to retrieve images. The CI identity and runtime pull identity should be separate because they have different responsibilities.

The exact ACR role depends on the registry's authorization mode. We need to confirm whether it uses classic registry RBAC or repository-level ABAC permissions before choosing the role.

## 7. Logging and health checks

The Container Apps environment will send system and console logs to Log Analytics.

At a minimum, I want to be able to inspect:

- Nginx and backend application logs.
- Container startup, revision and scaling events.
- HTTP ingress errors where the available logging configuration supports them.
- PostgreSQL service metrics and relevant diagnostic logs.

Application logs should be useful for troubleshooting without containing passwords, tokens or sensitive request data.

The repository documents `/health` and `/ready`. Before configuring Azure health probes, we need to confirm what each endpoint actually checks. Basic logging is a starting point; alert rules, application metrics, distributed tracing and service-level objectives will need further work.

## 8. Terraform approach

Terraform will be responsible for creating and managing the Azure resources and their configuration. This ticket does not include Terraform implementation or an Azure deployment.

The initial code will live under `infra/azure/`, with a clear entry point, provider/version configuration, reusable variables, resource definitions, outputs and an example variables file.

The configuration should cover the resource group, Log Analytics, ACR and its permissions, the Container Apps environment, and PostgreSQL resources. It should be structured so later tickets can add the actual application containers without rebuilding the environment from scratch.

I'll keep environment-specific values configurable and avoid committing real credentials. Outputs should expose useful information such as resource IDs, the ACR login server and service hostnames, but never passwords or other secrets.

Terraform state must be protected because it can contain sensitive values. A secured remote state backend with access controls and recovery safeguards should be established as part of the implementation plan.

## 9. Assumptions and open risks

For this design, I'm assuming:

- Nginx serves the frontend on port 80.
- FastAPI listens on port 8080.
- The frontend and backend share a Container Apps environment.
- The frontend uses relative `/api/*` paths.
- PostgreSQL is accessed using its FQDN over TLS on port 5432.
- The development database uses public access with a restricted firewall.
- Images are published to ACR before a Container Apps revision references them.

The biggest item to validate early is database connectivity from Container Apps. The firewall rules must match the actual supported outbound connectivity, not an assumed IP address.

We also need to confirm how the application initializes its schema, whether readiness checks include database availability, and how the Azure Nginx upstream will be configured.

## 10. Before production

Before calling this production-ready, I would want clear answers on:

- Which Azure subscription, region, naming rules and budget apply?
- What replica counts, CPU/memory limits and scaling rules are required?
- Is a custom domain or additional edge protection needed?
- What database availability, backup retention, RPO and RTO are expected?
- What is the approved production database networking design?
- How will database credentials or identities be managed and rotated?
- Which alerts, logs and metrics are mandatory, and who owns them?
- How will database migrations, failed releases and rollback be handled?
- What security, compliance and data residency requirements apply?

## Decision summary

For the initial development environment, I propose a public HTTPS frontend on Azure Container Apps, an internally accessible FastAPI backend, and PostgreSQL Flexible Server reached by the backend over TLS. ACR stores the images, managed identity handles runtime image pulls, and Log Analytics provides basic platform visibility. Terraform will manage the environment so it can be reviewed and recreated consistently.

This gives us a clear starting point for DEVOPS-008. It is a proposed design only; the Azure resources have not been created or tested as part of DEVOPS-007.