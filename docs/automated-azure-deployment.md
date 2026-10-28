# Automated Azure DEV Deployment

## Purpose

DEVOPS-014 builds and publishes the NovaCart frontend and backend containers after application changes merge to `main), then updates the Azure development Container Apps to run the exact image digests produced by that run.

The workflow is `.github/workflows/azure-dev-deploy.yml`. It complements, rather than replaces, the CI verification suite and Terraform infrastructure workflows.

## Delivery flow

1. An application change merges into `main`. GitHub branch protection is expected to require the existing `NovaCart Verification Suite` before the merge.
2. GitHub Actions checks out the merged commit and authenticates to Azure with the `azure-development` environment's OIDC identity. No client secret is placed in YAML.
3. The workflow checks that the development resource group, ACR, and both Container Apps already exist. It fails early if these prerequisites or the identity's permissions are missing.
4. Docker Buildx builds the backend from `novacart/backend` and the frontend from `novacart/frontend).
5. Both images are pushed to ACR with the source commit SHA as a traceable tag. The workflow captures each registry digest.
6. The backend and then the frontend are updated to use digest references (`image@sha256:...`), not a mutable `latest` tag.
7. The workflow verifies that Azure reports the requested image references and writes the source commit, image digests, active revisions, and run link to the GitHub Actions summary.

The workflow also supports `workflow_dispatch` for a controlled manual rerun from `main`. It does not run Terraform and does not create Azure infrastructure.

## Existing infrastructure expected

The resource names follow the defaults in `infra/azure`:

| Resource | Expected name |
|---|---|
| Resource group | `rg-novacart-dev` |
| Azure Container Registry | The value of `NOVACART_ACR_NAME` |
| Backend Container App | `ca-novacart-dev-backend` |
| Frontend Container App | `ca-novacart-dev-frontend` |

Terraform currently declares the application Container Apps behind `deploy_application`, whose default is `false`. The infrastructure must therefore be provisioned with the application resources enabled before this deployment workflow can succeed. DEVOPS-013 owns infrastructure provisioning; DEVOPS-014 should not create infrastructure as a side effect of deploying images.

## GitHub environment configuration

The `azure-development` environment must contain these **variables**:

- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`
- `NOVACART_ACR_NAME`

The corresponding Entra federated credential must trust this repository's `azure-development` GitHub Environment subject. Keep deployment restricted to `main`; the workflow also checks the branch before it proceeds.

No database administrator password is needed by this workflow. Database credentials belong to the runtime configuration and must not be printed, committed, or passed into the image build.

## Azure permissions

The currently verified OIDC service principal has `Storage Blob Data Contributor` at the Terraform state container. That role alone is **not enough** to publish images or update Container Apps.

After the relevant resources exist, grant only the additional permissions required by the deployment identity:
- ACR push permission scoped to the NovaCart registry.
- Container Apps update/read permission for the NovaCart development apps, scoped to the development resource group.

For a straightforward development setup, the built-in `Contributor` role can be scoped to **only** `rg-novacart-dev`, plus `AcrPush` scoped to the registry. This is still broader than ideal at resource-group level because the registry shares the group. Do not grant subscription-wide `Contributor` or `Owner`; use a custom role or separate registry/workload scopes if tighter least privilege is required. Role assignments must be made by an authorized Azure administrator after those scopes exist.

## Failure visibility and verification

A failed preflight indicates that the expected infrastructure cannot be found or read. A failed push generally indicates ACR authentication or permission trouble. A failed update or digest verification indicates a deployment or Azure permission problem.

Check the GitHub Actions run log and the final job summary. For independent verification, inspect the app image and active revision in Azure:

```bash
az containerapp show \
  --name ca-novacart-dev-backend \
  --resource-group rg-novacart-dev \
  --query "properties.template.containers[].image" \
  --output tsv

az containerapp show \
  --name ca-novacart-dev-frontend \
  --resource-group rg-novacart-dev \
  --query "properties.template.containers[].image" \
  --output tsv

az containerapp revision list \
  --name ca-novacart-dev-backend \
  --resource-group rg-novacart-dev \
  --query "[?properties.active == `true`].name" \
  --output tsv
```

The deployed image should contain the expected digest and correspond to the commit linked from the workflow run. The successful update check verifies the configured image reference; it does not by itself prove application-level health. Use the application's existing health/readiness endpoints and later observability work for runtime-health confirmation.

## Safety and operational boundaries

- Delivery is limited to pushes to `main) affecting the frontend, backend, or this workflow; manual runs must use `main`.
- The workflow has read-only GitHub repository permissions and OIDC login; it does not use a stored Azure client secret.
- Image tags contain the source commit SHA, and deployments use image digests.
- The workflow does not run Terraform, create/delete Azure infrastructure, modify database schema, or implement automatic rollback.
- The backend is updated before the frontend. If one service updates and the second fails, inspect the run and both app revisions before retrying or manually restoring the prior image digest.

## Current status and remaining prerequisites

**Implemented in this ticket's workflow/documentation:** push-to-main trigger, OIDC authentication, early resource checks, frontend/backend image build and publish, digest-based rollout, post-update image verification, and a run summary.

**Not yet verified as a live delivery:** this depends on DEVOPS-013 provisioning the Azure development resources and on the deployment identity receiving the necessary ACR and Container Apps permissions. The earlier OIDC backend check and Terraform plan workflow do not demonstrate that these application resources exist or are deployed. Do not mark end-to-end delivery complete until an actual GitHub Actions run successfully publishes both images and verifies both deployed digests.

## Cost notes

A GitHub Actions run consumes runner/build minutes and pushes image layers into ACR. Existing ACR storage can incur registry charges. Updating Container Apps does not create the first-time infrastructure, but running application replicas and the PostgreSQL server can incur ongoing Azure charges. Review Azure Cost Management before enabling the application resources, and delete paid development resources only when they are no longer required and after any needed data/state has been preserved.
