# Automated Azure DEV Deployment

## Purpose

DEVOPS-014 defines the NovaCart Azure DEV delivery workflow. The DEVOPS-019 update makes the release **manual-only**: merging an application change to `main` does not deploy to Azure. An operator must start the workflow on `main`, select `RELEASE`, and choose the backend canary share/observation window.

The workflow is `.github/workflows/azure-dev-deploy.yml`. It complements, rather than replaces, the CI verification suite and Terraform infrastructure workflows.

## Delivery flow

1. An application change merges into `main` after the required `NovaCart Verification Suite` checks pass. The merge itself never starts Azure deployment.
2. GitHub Actions checks out the merged commit and authenticates to Azure with the `azure-development` environment's OIDC identity. No Azure client secret is stored in YAML.
3. Preflight confirms the Resource Group, ACR, both Container Apps, **Multiple** revision mode, the current 100%-traffic revisions and their image references. It smoke-tests the current release before creating candidates. If these assumptions are not met, the workflow fails without changing traffic.
4. Docker Buildx builds the backend and frontend, tags each image with the source commit SHA, and records the immutable registry digests.
5. A uniquely suffixed backend candidate is created while the old frontend remains stable. After its startup/readiness/liveness health is good, the workflow routes the selected 10/20/30% backend canary to the candidate while the previous revision retains the remainder. It repeats frontend/API/DB-readiness/products smoke tests during the selected 60/120/300-second window, then requires an `X-NovaCart-Revision` health response from the actual candidate before routing 100% to it.
6. A uniquely suffixed frontend candidate is created with no production frontend traffic. The workflow assigns the `candidate` revision label and tests its dedicated label URL for the homepage, API health, database readiness and products.
7. Only after candidate tests pass does the workflow switch the main frontend ingress to the candidate. It repeats the smoke tests on the production URL.
8. On a failure after traffic starts to move, the workflow attempts to restore both recorded previous revisions. It fails the run even if rollback succeeds and writes a summary showing old/candidate revisions, image digests, smoke test outcome and rollback result.
9. On success, old revisions are deactivated to stop their replicas; their revision history is retained subject to the configured inactive-revision limit.

The workflow is manual-only (`workflow_dispatch`), can run from `main` only, and requires an explicit `RELEASE` input. It does not run Terraform or create Azure infrastructure. The workflow requires the Apps to have been created from the reviewed multiple-revision Terraform configuration; it deliberately fails closed if it detects a single-revision app or cannot identify the previous 100%-traffic revision.

## Existing infrastructure expected

The resource names follow the defaults in `infra/azure`:

| Resource | Expected name |
|---|---|
| Resource group | `rg-novacart-dev` |
| Azure Container Registry | The value of `NOVACART_ACR_NAME` |
| Backend Container App | `ca-novacart-dev-backend` |
| Frontend Container App | `ca-novacart-dev-frontend` |

Terraform currently declares the application Container Apps behind `deploy_application`, whose default is `false`. The infrastructure must therefore be provisioned with the application resources enabled before this deployment workflow can succeed. DEVOPS-013 owns infrastructure provisioning; DEVOPS-014 should not create infrastructure as a side effect of deploying images. The Terraform app resources also ignore subsequent changes to the image field, so a later infrastructure apply does not replace the digest deployed by CI with the bootstrap image tag. Terraform remains responsible for the app configuration; this workflow owns subsequent image rollouts.

## GitHub environment configuration

The `azure-development` environment must contain these **variables**:

- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`
- `NOVACART_ACR_NAME`

The corresponding Entra federated credential must trust this repository's `azure-development` GitHub Environment subject. Keep the GitHub Environment restricted to `main`; the workflow independently checks the branch and requires explicit release confirmation.

No database administrator password is needed by this workflow. Database credentials belong to the runtime configuration and must not be printed, committed, or passed into the image build.

## Azure permissions

Before the 2026-10-29 teardown, the OIDC service principal had `Storage Blob Data Contributor` at the Terraform state container. That resource scope was deleted with the backend, so it does not provide usable state access now. It was never enough to publish images or update Container Apps.

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

- Deployment is triggered only by `workflow_dispatch`. The workflow accepts runs from `main` only and requires the operator to select `RELEASE`; a push or PR merge alone cannot deploy.
- The workflow has read-only GitHub repository permissions and OIDC login; it does not use a stored Azure client secret.
- Image tags contain the source commit SHA, deployments use immutable digests, and each revision receives a unique suffix.
- The workflow does not run Terraform or create/delete Azure infrastructure.
- The backend is promoted first and the old frontend is smoke-tested against it. The frontend candidate is then validated by label URL before the main frontend traffic is shifted.
- Release changes must remain backward-compatible across the backend-first/frontend-second sequence. Database schema migrations need expand/migrate/contract discipline.
- If automatic rollback fails for either app, the run summary marks the failed rollback leg and manual operator intervention is required.

## Current status and remaining prerequisites

**Implemented in source configuration (DEVOPS-019 follow-up):** multiple revision mode, pinned bootstrap traffic, probes, HTTP scale rules, bounded replica and DB-pool settings, candidate-label smoke tests, traffic cutover, failure-triggered traffic rollback, release summary, and best-effort deactivation of previous revisions.

**Not live-verified:** the Azure lab was deleted on 2026-10-29. This workflow cannot pass its resource preflight until the Azure runtime and role assignments are rebuilt. CI validates source/configuration; only a real deployment run can prove ACR publishing, candidate readiness, traffic cutover, rollback and live health checks.

## Cost notes

A GitHub Actions run consumes runner/build minutes and pushes image layers into ACR. Existing ACR storage can incur registry charges. Updating Container Apps does not create the first-time infrastructure, but running application replicas and the PostgreSQL server can incur ongoing Azure charges. Review Azure Cost Management before enabling the application resources, and delete paid development resources only when they are no longer required and after any needed data/state has been preserved.
