# Automated Azure DEV Deployment — DEVOPS-014 / DEVOPS-019

## Current status

The Azure lab resources, including the Terraform state backend, were deliberately deleted on 2026-10-29 to control cost. The workflow and Terraform configuration remain in GitHub, but a live Azure deployment is not currently available. The workflow's Azure preflight will fail until the resource group, ACR, Container Apps, state/backend plan prerequisites, and required permissions are intentionally restored.

A public Azure DEV deployment was verified historically on 2026-10-26. Its URL and test results are historical, not a live demo. See [the deployment record](azure-dev-deployment.md).

## Scope

The workflow is `.github/workflows/azure-dev-deploy.yml`. It is **manual-only**, uses GitHub OIDC, and targets the `azure-development` environment. It does not provision infrastructure and should not be used as a production workflow without a separate production environment, reviewer controls, and production-specific validation.

## Controlled release flow

1. An application change merges into `main` after the required PR CI checks pass.
2. An operator manually starts **NovaCart Safe Azure DEV Release** from branch `main`, selects `RELEASE`, and chooses the canary percentage and observation window.
3. GitHub Actions authenticates to Azure using the `azure-development` OIDC identity. No long-lived Azure client secret is stored in the workflow.
4. Preflight verifies the resource group, registry, both Container Apps, and Multiple revision mode. It stops before image changes if prerequisites are absent.
5. The workflow records the highest-weight known-good revision and its immutable image, then pins 100% traffic to explicit revision names. This prevents a later update from implicitly shifting all traffic to the newest revision.
6. Docker builds and pushes frontend/backend images tagged with the source commit SHA. The workflow captures registry digests and deploys by digest.
7. The backend candidate is created, and the workflow waits for a healthy/provisioned/running revision. It then sends a small configured traffic share to the candidate and validates the critical path through the existing frontend.
8. If the backend passes health/readiness/product checks and a short observation window, it receives 100% of backend traffic. A failure aborts the rollout and attempts to restore the previous backend/frontend revision pair.
9. The frontend candidate follows the same platform-health, canary, smoke-check and observation sequence. Only after validation does it receive 100% of frontend traffic.
10. The workflow deactivates previous revisions after successful promotion to avoid idle replica cost, runs final smoke checks, and writes commit, image digests, previous/candidate revisions, traffic share, observation duration and outcome to the GitHub Actions summary.

This is a small-team canary strategy. It gives the team a recoverable version boundary without requiring a large deployment platform. It does not yet include a metric-based SLO gate or an external alert notification route. See [the safe deployment guide](safe-production-deployment.md).

## Infrastructure expected

| Resource | Expected name |
|---|---|
| Resource group | `rg-novacart-dev` |
| Azure Container Registry | GitHub Environment variable `NOVACART_ACR_NAME` |
| Backend Container App | `ca-novacart-dev-backend` |
| Frontend Container App | `ca-novacart-dev-frontend` |
| Revision mode | `Multiple` |
| Backend liveness/startup | `/health` |
| Backend readiness | `/ready` |
| Frontend probes | `/` |

Terraform keeps the first image and traffic configuration as bootstrap defaults. After bootstrap, the Terraform lifecycle rules ignore image and traffic-weight changes, because the release workflow owns those fields. Terraform continues to own resource/platform configuration. The application resources are still gated by `deploy_application`, whose default is `false`.

## GitHub Environment configuration

The `azure-development` Environment requires these **variables**:

- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`
- `NOVACART_ACR_NAME`

The Microsoft Entra federated credential subject must match this repository's `azure-development` GitHub Environment identity exactly. Restrict deployment to `main`. The current workflow verifies that branch and also requires explicit `RELEASE` input.

No database password is needed to build or push these images. Database credentials must never be baked into an image, passed as a Docker build argument, or printed in a workflow log.

## Azure permissions

The old OIDC service principal had `Storage Blob Data Contributor` scoped to the deleted Terraform state container. That scope is gone with the backend and does not provide usable access now.

After resources are intentionally recreated, grant the deployment identity only the permissions needed to:
- push images to ACR (for example, `AcrPush` scoped to that registry);
- read and update the two Container Apps and inspect their revisions;
- read the resource group/registry metadata required for preflight.

Do not grant subscription-wide `Owner` or `Contributor` as a shortcut. For a production setup, separate build/publish and deploy identities or scopes where practical, and require review through a protected production Environment.

## Failure handling and validation

The workflow fails early if an app is not in Multiple revision mode. After image update, it waits for the new revision to report successful provisioning, running state and healthy state before sending canary traffic. It then validates:

- frontend returns HTML;
- `/api/health` returns `status=ok`;
- `/api/ready` returns `status=ready`;
- `/api/products` returns a non-empty product list;
- repeated health/readiness checks pass during the selected observation window.

If validation fails after the previous revisions have been captured, the rollback step attempts to activate both previous revisions, wait for them to become healthy, set each to 100% traffic, and rerun the critical API checks. If the rollback step also fails, treat it as an incident and inspect revision traffic manually.

These are smoke checks, not full load tests or SLO monitoring. The workflow does not currently gate on an Azure dashboard's error ratio/p95 latency and does not notify an external on-call system.

## Current acceptance boundary

**Implemented in source control by this change:** manual release gate, OIDC login, preflight checks, digest-based images, multiple-revision canary flow, post-deploy health checks, automatic attempted rollback, and release evidence.

**Not live-verified:** this requires the deleted Azure DEV resources to be intentionally recreated, the deployment identity's scoped roles to be configured, the reviewed Terraform plan to be applied, and an actual deployment/rollback drill to succeed. Passing CI alone is not evidence of live deployment.

## Cost and cleanup

GitHub Actions consumes runner/build minutes, ACR stores image layers, and running Container Apps replicas plus PostgreSQL/Log Analytics may incur Azure charges. The min-replica value of one is a deliberate warm-service/cost trade-off, not HA. Review current prices before rebuilding, preserve required database data and Terraform state, and remove only explicitly approved temporary resources after testing.
