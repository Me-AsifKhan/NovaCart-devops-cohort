# Safe Production Deployment — NovaCart

This guide describes `.github/workflows/azure-dev-deploy.yml`, a **manual-only Azure DEV release workflow**. It is not a ready-to-use production environment. An operator must select `main`, explicitly confirm `RELEASE`, and choose the backend canary share and observation time. The flow uses Azure Container Apps Multiple revision mode, immutable image digests, a weighted backend canary, a labeled frontend candidate, health checks, traffic cutover, and attempted recovery to the prior revision if validation fails.

**Current environment note:** NovaCart Azure resources were deleted on 2026-10-29. This runbook describes the intended future release path. Do not run the Azure deployment workflow until the Resource Group, ACR, Container Apps, permissions and protected OIDC configuration have been recreated and verified.

## Release model

Use immutable image digests and explicit revision names. Do not depend on a mutable `latest` tag.

- **Stable revision:** the revision whose name/image is recorded as receiving 100% of traffic before the release.
- **Candidate revision:** the newly created revision named with an `r<short-sha>-<run-number>` suffix. The backend candidate receives only the selected 5%, 10%, or 20% share during its observation window. The frontend candidate is tested using the `candidate` label URL before the main frontend traffic changes.
- **Candidate frontend label:** the Container Apps label `candidate` provides a dedicated FQDN that can be tested without switching the main frontend URL.
- **Promotion:** after repeated frontend/API/database-readiness smoke tests pass during the backend canary, the workflow sends 100% of backend traffic to the candidate. It then validates the frontend candidate by label URL and moves main frontend traffic only after those checks pass.
- **Rollback:** an error after traffic has started to move triggers a trap that attempts to route both apps back to their recorded previous revisions. The job fails even if the rollback succeeds, so operators can inspect the release and evidence rather than mistaking recovery for a successful deployment.
- **Revision retention:** after successful post-cutover checks, the previous revisions are deactivated to stop their replicas. They remain available in revision history up to the configured inactive revision retention. Rollback reactivates the old revision before assigning traffic.

The workflow refuses to proceed unless both Container Apps are in **Multiple** revision mode and exactly one named revision receiving 100% of traffic can be identified for each app. It also refuses to proceed unless the workflow runs on `main` and the operator selects `RELEASE`. This is intentional: when state does not match the deployment assumptions, fail closed rather than changing revision mode or guessing which version is stable. Merging application changes alone never triggers deployment.

## How a release runs

1. **Manual start and preflight:** choose *NovaCart Azure DEV Deployment* in Actions, branch `main`, input `RELEASE`, a backend canary percentage of 5/10/20, and an observation window of 30/60/120 seconds. GitHub Actions authenticates with Azure OIDC, confirms the resource group, ACR, Container Apps, Multiple revision mode, current 100%-traffic revisions, image references and frontend URL. It smoke-tests the current release before creating candidates.
2. **Build and publish:** Buildx publishes the backend and frontend with the source commit SHA as a tag. The workflow captures their immutable registry digests.
3. **Backend candidate:** the workflow creates a new backend revision by digest and a unique suffix. The startup/liveness probes use `/health`; the readiness probe uses `/ready`, so a database failure prevents a candidate from being treated as ready.
4. **Backend canary and verification:** after the candidate is provisioned, running and healthy, the workflow routes the selected small percentage to the new backend and keeps the remaining traffic on the known-good backend. It repeats frontend availability, API health, database readiness and products smoke tests throughout the observation window. The tests exercise the candidate through the existing public frontend proxy. Only after the repeated checks pass does the workflow send 100% of backend traffic to the candidate. If any check fails, both apps are routed back to their recorded old revisions.
5. **Frontend candidate:** the workflow creates the new frontend revision, waits for its probes, moves the `candidate` label to the new revision, and tests the candidate URL directly. This verifies Nginx plus API health, database readiness and product retrieval before main frontend traffic is changed.
6. **Frontend cutover:** only after candidate checks pass does the workflow switch the main frontend ingress to the candidate revision. It then repeats the production smoke tests.
7. **Finish or recover:** success writes a deployment summary and deactivates old revisions to stop their replicas. Failure restores old traffic targets when possible and records any manual action needed.

The rollout order requires backward compatibility: the current frontend must continue to work with the candidate backend. If an API or schema change breaks that contract, deploy it in backward-compatible stages and use expand/migrate/contract database migrations.

## Health and smoke tests

The workflow checks all of these before calling a release successful:

- Platform revision state: provisioning is complete and running state is `Running`; an explicit `Unhealthy` result fails the release.
- Backend readiness: the ACA readiness probe calls `/ready`, which tests database connectivity.
- Frontend readiness: ACA readiness checks `/`.
- User-facing smoke tests: HTTP success for `/`; `/api/health` returns `status=ok`; `/api/ready` returns `status=ready`; and `/api/products` returns a non-empty array.
- Post-cutover repeat: the same smoke tests pass again through the production frontend FQDN.

These checks are more reliable than testing only the container process, but they do not constitute a load test, a complete checkout/order acceptance suite, or an SLO-based release gate. The selected 30/60/120-second backend observation is intentionally short for DEV. Before a real production launch, add a representative safe order transaction and metric-based release watch.

## Evidence and traceability

Every run summary records:

- source commit SHA and workflow run URL
- release suffix and immutable backend/frontend image digests
- previous backend/frontend revision names and image references
- candidate backend/frontend revision names and image references
- whether candidate and post-cutover smoke tests passed
- whether the old revisions were deactivated
- when automatic rollback was attempted and whether each traffic restoration command succeeded

Keep the GitHub Actions run and summary as the release record. The current application response does not embed a build identifier, so the Azure revision/image digest plus workflow commit/run is the authoritative version evidence. Do not infer the live version from the current GitHub `main` commit alone.

## Manual rollback procedure

Use this when the automated rollback reports an error, when health regresses after the workflow has completed, or when an operator decides to roll back. First retrieve the previous revision names and image digests from the last successful or failed deployment summary. Confirm that the chosen images/revisions match the known-good release.

Set these values for the target resource group:

```bash
RESOURCE_GROUP="rg-novacart-dev"
BACKEND_APP="ca-novacart-dev-backend"
FRONTEND_APP="ca-novacart-dev-frontend"
OLD_BACKEND_REVISION="<previous-backend-revision>"
OLD_FRONTEND_REVISION="<previous-frontend-revision>"
```

Inspect revision history and the existing traffic configuration:

```bash
az containerapp revision list -g "$RESOURCE_GROUP" -n "$BACKEND_APP" --all -o table
az containerapp revision list -g "$RESOURCE_GROUP" -n "$FRONTEND_APP" --all -o table
az containerapp ingress traffic show -g "$RESOURCE_GROUP" -n "$BACKEND_APP" -o json
az containerapp ingress traffic show -g "$RESOURCE_GROUP" -n "$FRONTEND_APP" -o json
```

If the known-good revision is inactive, activate it and wait until the revision is provisioned and healthy:

```bash
az containerapp revision activate \
  --name "$BACKEND_APP" \
  --resource-group "$RESOURCE_GROUP" \
  --revision "$OLD_BACKEND_REVISION"

az containerapp revision activate \
  --name "$FRONTEND_APP" \
  --resource-group "$RESOURCE_GROUP" \
  --revision "$OLD_FRONTEND_REVISION"

az containerapp revision show -g "$RESOURCE_GROUP" -n "$BACKEND_APP" --revision "$OLD_BACKEND_REVISION" -o json
az containerapp revision show -g "$RESOURCE_GROUP" -n "$FRONTEND_APP" --revision "$OLD_FRONTEND_REVISION" -o json
```

After reviewing both revisions' images and readiness, restore backend traffic first, then frontend traffic:

```bash
az containerapp ingress traffic set \
  --name "$BACKEND_APP" \
  --resource-group "$RESOURCE_GROUP" \
  --revision-weight "$OLD_BACKEND_REVISION=100"

az containerapp ingress traffic set \
  --name "$FRONTEND_APP" \
  --resource-group "$RESOURCE_GROUP" \
  --revision-weight "$OLD_FRONTEND_REVISION=100"
```

Then smoke-test the public frontend:

```bash
FRONTEND_FQDN=$(az containerapp show -g "$RESOURCE_GROUP" -n "$FRONTEND_APP" --query properties.configuration.ingress.fqdn -o tsv)
curl --fail --silent --show-error "https://$FRONTEND_FQDN/" -o /dev/null
curl --fail --silent --show-error "https://$FRONTEND_FQDN/api/health" | jq -e '.status == "ok"'
curl --fail --silent --show-error "https://$FRONTEND_FQDN/api/ready" | jq -e '.status == "ready"'
curl --fail --silent --show-error "https://$FRONTEND_FQDN/api/products" | jq -e 'type == "array" and length >= 1'
```

If health or readiness still fails, do not keep switching revisions at random. Keep evidence, inspect Container Apps and backend logs, verify database connectivity/schema compatibility, and escalate to the platform owner.

## Failure behavior

- If OIDC/preflight fails, production traffic is not changed.
- If a candidate fails startup/readiness or candidate smoke tests, the run fails and attempts to restore previous backend and frontend traffic targets.
- If a traffic reset fails, the job summary marks that rollback leg as failed and directs the operator to inspect and restore it manually.
- If the candidate frontend passes but post-cutover verification fails, the workflow attempts to return both frontend and backend traffic to the previous revisions.
- If the old revision is inactive, manual rollback activates it first.
- A process exit, infrastructure API response or passing smoke test alone is not proof that every business operation is healthy.

The workflow cannot make incompatible database schema changes reversible. Use backward-compatible migrations, retain backups, and validate a representative persisted-order flow before production.

## Scaling and costs

Terraform sets per-container resources using the default `0.5 vCPU / 1 GiB` pair. Initial HTTP scale targets are 25 concurrent requests per backend replica and 50 per frontend replica; DEV maxima are three backend and ten frontend replicas. These are starting assumptions for controlled testing, not measured throughput or an SLA.

The backend uses a bounded PostgreSQL pool (default maximum four connections per replica). At the configured three-replica ceiling this is at most 12 app-pool connections per backend revision, potentially 24 during the temporary old/new revision overlap. Verify PostgreSQL's actual connection limit and keep administrative/other-client headroom before changing either ceiling.

Minimum replica count of one and temporary overlapping revisions cost money when Azure is provisioned. After successful validation, the workflow deactivates old revisions to stop their replicas while retaining revision history. ACR image storage, PostgreSQL, Container Apps environment, Log Analytics ingestion and remote Terraform state can also incur charges. The lab is currently deleted; no live release or cost measurement was performed by this documentation change.

## Current status

The runbook and configuration describe the intended safe release design. CI can validate source, but no Azure rollout or rollback has been exercised because the Azure lab was deleted on 2026-10-29. The workflow is manual-only and requires explicit confirmation; do not run it until the backend and DEV resources have been deliberately recreated and their permissions/cost reviewed. Mark operational acceptance complete only after the environment is rebuilt, a canary release succeeds, and a controlled rollback is tested with current evidence.
