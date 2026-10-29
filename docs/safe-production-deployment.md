# Safe Production Deployment — DEVOPS-019

## Current status and scope

The release pattern implemented here currently targets the **NovaCart Azure DEV workflow**, not an already-running production environment. All Azure lab resources were deleted on 2026-10-29 to control cost. This guide describes the intended controlled release and the configuration in `.github/workflows/azure-dev-deploy.yml`; it does not claim the flow has been exercised against live Azure after teardown.

The workflow is manual-only. It runs on `main`, requires an operator to select `RELEASE`, and uses the `azure-development` GitHub Environment and OIDC. A separate QA/production workflow, environment, and reviewer gate are still required before a true production promotion.

## Chosen strategy

Use **multiple Container Apps revisions with a small canary and explicit promotion**, rather than immediately routing all traffic to the newest revision.

- The application has two services and does not need a large release platform.
- Azure Container Apps can keep a previous revision active while the candidate is validated.
- The workflow offers a 5%, 10%, or 20% canary and a short configurable observation window.
- If a check fails, it attempts to activate and restore the previous backend/frontend revision pair, then repeats health/readiness/product checks.
- After successful promotion, old revisions are deactivated to avoid paying for idle replicas, but remain in the configured inactive revision history for reactivation.
- Source commit and immutable registry digests provide version evidence.

This is a small-team development release pattern, not a complete enterprise canary system. It does not gate on live error/latency SLOs or send external paging notifications.

## Platform requirements

The Terraform changes in this PR:

- Set both apps to Multiple revision mode.
- Add bounded HTTP scaling, startup/liveness/readiness probes, and a retained inactive revision history.
- Keep one minimum replica and a maximum of five per app in the cost-conscious DEV design.
- Tell Terraform to ignore image and ingress traffic-weight drift after bootstrap because the release workflow owns image and traffic changes.

Do not run the workflow until an approved Terraform deployment has created the apps in Multiple revision mode. The workflow fails its preflight if an app is not in Multiple mode.

## Release sequence

1. **Review and merge.** Application changes must pass PR CI. Review API/database compatibility and any schema migration. Old and new frontend/backend revisions can coexist.
2. **Start deliberately.** In GitHub Actions select *NovaCart Safe Azure DEV Release*, branch `main`, input `RELEASE`, canary percentage and observation duration. A workflow-only merge does not trigger deployment.
3. **Authenticate and preflight.** GitHub Actions exchanges an OIDC token with Microsoft Entra, verifies the resource group, ACR and both apps, confirms Multiple revision mode, and obtains the public frontend URL. Missing resources/permissions stop the release before image updates.
4. **Capture the known-good state.** Record the highest-weight revision and its image for both apps, then pin 100% of traffic to explicit revision names. This also normalizes an interrupted split where a previous run left partial traffic weights.
5. **Build immutable artifacts.** Build and push images tagged with the commit SHA; capture registry digests. Deploy by `repository@sha256:...`, not a mutable `latest` tag.
6. **Deploy backend candidate.** Update the backend image and wait until the candidate reports provisioned, running, and healthy. Split traffic between the known-good revision and candidate. The readiness probe includes the database path through `/ready`.
7. **Validate the backend canary.** Through the existing public frontend proxy, repeat frontend availability, `/api/health`, `/api/ready`, and `/api/products` checks, then observe the canary. A small share of actual API traffic reaches the candidate, so the old frontend must remain compatible with the new backend.
8. **Promote the backend.** If the checks pass, route 100% of backend traffic to the candidate. If validation fails, the job fails and the rollback step attempts to restore both previous revisions.
9. **Deploy and validate the frontend candidate.** Repeat candidate-health, canary split, smoke checks, and observation for the frontend while the promoted backend serves requests.
10. **Promote and record.** Route 100% to the frontend candidate, deactivate the previous revisions to reduce idle compute cost, rerun the critical-path checks, and write the commit, workflow run, previous images/revisions, candidate digests/revisions, traffic share, observation window and outcome to the GitHub Actions summary.

The backend is deployed before the frontend so a backward-compatible backend can serve the old frontend during its canary. If a change is not backward-compatible, separate the schema/API migration into safe steps before using this sequence.

## Health and validation gates

- **Platform gate:** candidate revision must report successful provisioning, running state and healthy state before traffic shifts.
- **Backend startup/liveness:** Azure probes call `/health`, which checks process health without coupling liveness to database availability.
- **Backend readiness:** Azure probes call `/ready`, which checks database connectivity. An unready replica should not receive traffic.
- **Frontend probes:** startup/liveness/readiness call `/`.
- **Canary smoke tests:** frontend responds with HTML, health returns `status=ok`, readiness returns `status=ready`, and products returns a non-empty array.
- **Observation:** repeat health/readiness checks during the configured canary window.

These gates catch startup failures and basic user-path regressions. They do not replace load tests, security scans, alert evaluation, or measured latency/error SLOs. The workflow does not yet gate on a live dashboard's error ratio or p95 latency.

## Automatic rollback behavior

If the deployment/canary step fails after the previous revision pair is captured, the workflow attempts to:

1. Activate the previous backend and frontend revisions.
2. Wait until both revisions report healthy.
3. Route 100% of backend and frontend traffic to the previous revision names.
4. Repeat health, readiness and products checks through the public frontend.
5. Leave rollback outcome in the Actions logs and release summary.

The rollback step itself can fail due to permissions, Azure resource availability, an unavailable image, database incompatibility, or a wider outage. Treat that as an incident: inspect revision traffic, activate the recorded previous revisions manually, and verify the API/database path.

## Manual inspection commands (PowerShell)

Run only after the DEV environment has been deliberately rebuilt.

```powershell
$ResourceGroup = "rg-novacart-dev"
$BackendApp = "ca-novacart-dev-backend"
$FrontendApp = "ca-novacart-dev-frontend"

az containerapp show --name $BackendApp --resource-group $ResourceGroup --query "{mode:properties.configuration.activeRevisionsMode,latest:properties.latestRevisionName,ready:properties.latestReadyRevisionName,traffic:properties.configuration.ingress.traffic}" -o json

az containerapp revision list --name $BackendApp --resource-group $ResourceGroup --all --query "[].{Revision:name,Active:properties.active,Provisioning:properties.provisioningState,Running:properties.runningState,Health:properties.healthState,Traffic:properties.trafficWeight,Replicas:properties.replicas}" -o table

az containerapp revision list --name $FrontendApp --resource-group $ResourceGroup --all --query "[].{Revision:name,Active:properties.active,Provisioning:properties.provisioningState,Running:properties.runningState,Health:properties.healthState,Traffic:properties.trafficWeight,Replicas:properties.replicas}" -o table

$KnownGoodBackendRevision = "<recorded-backend-revision>"
az containerapp revision show --name $BackendApp --resource-group $ResourceGroup --revision $KnownGoodBackendRevision --query "properties.template.containers[0].image" -o tsv
```

## Manual emergency rollback

Use the revision names from the release summary. Do not guess a revision name or assume the latest revision is the known-good one.

```powershell
$KnownGoodBackendRevision = "<recorded-backend-revision>"
$KnownGoodFrontendRevision = "<recorded-frontend-revision>"

az containerapp revision activate --name $BackendApp --resource-group $ResourceGroup --revision $KnownGoodBackendRevision
if ($LASTEXITCODE -ne 0) { throw "Could not activate the known-good backend revision." }

az containerapp revision activate --name $FrontendApp --resource-group $ResourceGroup --revision $KnownGoodFrontendRevision
if ($LASTEXITCODE -ne 0) { throw "Could not activate the known-good frontend revision." }

# Wait for both revisions to report healthy in the Azure portal or CLI.
az containerapp ingress traffic set --name $BackendApp --resource-group $ResourceGroup --revision-weight "$KnownGoodBackendRevision=100"
if ($LASTEXITCODE -ne 0) { throw "Could not restore backend traffic." }

az containerapp ingress traffic set --name $FrontendApp --resource-group $ResourceGroup --revision-weight "$KnownGoodFrontendRevision=100"
if ($LASTEXITCODE -ne 0) { throw "Could not restore frontend traffic." }

$FrontendUrl = "https://<current-frontend-fqdn>"
Invoke-RestMethod "$FrontendUrl/api/health"
Invoke-RestMethod "$FrontendUrl/api/ready"
Invoke-RestMethod "$FrontendUrl/api/products"
```

If a known-good revision is inactive, activate it first and allow it to become healthy before assigning traffic. Keep the current failing revision available until rollback verification completes; preserve its logs and image digest for diagnosis.

## Database and compatibility guardrails

- Application rollback does not roll back PostgreSQL schema changes.
- Use backward-compatible expand/migrate/contract changes and keep the old application compatible while rollout is in progress.
- Take and verify a database backup before destructive schema operations.
- Implement the least-privilege application database identity and secret lifecycle required by DEVOPS-015 before a production pilot; the current Terraform baseline still uses the PostgreSQL administrator credential for the app connection.
- The database is a single point of failure with no configured HA. Replica scaling does not increase database capacity.

## Release evidence and production gaps

Each release should record source commit, PR, workflow run URL, both image digests, prior/candidate revision names, canary percentage, observation window, smoke-test results, final traffic weights, timestamps, rollback decision and operator.

Before a larger production launch, add a separate production GitHub Environment with required reviewers, a tested alert/notification route, metric-based canary gates, load testing, database recovery tests, image-retention policy, and an observation window based on a measured baseline. Do not use this DEV workflow as an unrestricted production release workflow.

## Current validation boundary

The Azure resources are intentionally deleted, so this workflow cannot currently pass its Azure preflight. CI can validate configuration, tests, builds, and documentation, but that is **not** evidence of a live deployment, canary, alert or rollback. Perform the live exercise only after the state backend is restored, cost is reviewed, and an approved Terraform plan has created the DEV resources.
