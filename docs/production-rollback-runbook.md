# Production Rollback Runbook — DEVOPS-020

**Status:** procedural runbook added; a live rollback drill has **not** been run.  
**Applies after:** the DEVOPS-019 multiple-revision deployment workflow and Terraform configuration have been merged and a new Azure environment has been deliberately provisioned and verified.

The NovaCart Azure lab was deleted on 2026-10-29. These commands are for a future, approved Azure Container Apps deployment; they cannot run successfully against the currently empty subscription. Do not recreate paid resources merely to mark this documentation ticket complete.

## Goal and rollback rule

Restore both the frontend and backend to the recorded previous known-good Container Apps revisions when a release causes a regression. Use **the previously deployed revision and its immutable image digest**, not a rebuilt branch or mutable `latest` tag.

The DEVOPS-019 workflow uses multiple revision mode, keeps the previous revision serving traffic while a candidate is prepared, tests the candidate, then changes traffic. If health validation fails after a traffic change, it attempts to restore the previous traffic targets and reports the outcome. This runbook is the manual fallback when automation cannot restore traffic or a regression is discovered after a successful workflow.

**Dependency:** merge/review [PR #32](https://github.com/Me-AsifKhan/NovaCart-devops-cohort/pull/32) before using these steps. The workflow must be running against the intended multiple-revision Terraform configuration. The current Azure resources are deleted, so the real rollout and rollback remain unproven.

## 1. Decide whether rollback is warranted

First verify that the problem is real and release-related:

1. Repeat the external frontend request. Check whether the issue is persistent, not a single transient timeout.
2. Check `/api/health` (process/API response) and `/api/ready` (database readiness). A failed readiness check may be a database/network/credential issue rather than an application image regression.
3. Review the failed release's GitHub Actions run, deployment summary, Container Apps revision health/running state, logs, and any available metrics.
4. Compare the failure start time with the candidate revision, commit, and image digest.
5. Roll back when a release correlates with a customer-visible regression, critical smoke-test failure, or sustained health/readiness issue and the prior revision is compatible with current database state.

Do not roll back blindly if a database migration has removed columns or changed data in a way the previous application cannot read. Pause further rollout, preserve evidence, and use the migration/restore recovery plan with the database owner.

## 2. Identify the currently running and previous known-good versions

Use Azure Cloud Shell (Bash) or another Bash terminal with Azure CLI and `jq`. Select the intended subscription explicitly; do not run against an unknown default subscription.

```bash
az account show --query "{name:name,id:id,tenantId:tenantId}" -o table
az account set --subscription "<approved-subscription-id>"

RG="rg-novacart-dev"
BACKEND_APP="ca-novacart-dev-backend"
FRONTEND_APP="ca-novacart-dev-frontend"

az containerapp show -g "$RG" -n "$BACKEND_APP"   --query "properties.configuration.{mode:activeRevisionsMode,traffic:ingress.traffic}" -o json
az containerapp show -g "$RG" -n "$FRONTEND_APP"   --query "properties.configuration.{mode:activeRevisionsMode,traffic:ingress.traffic}" -o json
```

Both apps should report `Multiple` revision mode. Inspect all active/inactive revision history:

```bash
az containerapp revision list -g "$RG" -n "$BACKEND_APP" --all   --query "[].{name:name,active:properties.active,created:properties.createdTime,provisioning:properties.provisioningState,running:properties.runningState,health:properties.healthState}" -o table

az containerapp revision list -g "$RG" -n "$FRONTEND_APP" --all   --query "[].{name:name,active:properties.active,created:properties.createdTime,provisioning:properties.provisioningState,running:properties.runningState,health:properties.healthState}" -o table
```

The workflow's last successful or failed deployment summary should record the prior revision and image digest. Confirm that they agree with the traffic configuration before changing anything. The revision carrying 100% traffic is the current target; the revision recorded as previous known-good is the rollback target.

For the chosen revision, inspect its exact image reference:

```bash
BACKEND_REVISION="<revision-name-from-the-summary>"
FRONTEND_REVISION="<revision-name-from-the-summary>"

az containerapp revision show -g "$RG" -n "$BACKEND_APP" --revision "$BACKEND_REVISION"   --query "properties.template.containers[?name=='novacart-backend'].image | [0]" -o tsv

az containerapp revision show -g "$RG" -n "$FRONTEND_APP" --revision "$FRONTEND_REVISION"   --query "properties.template.containers[?name=='novacart-frontend'].image | [0]" -o tsv
```

Record the image digests exactly. If the previous revision cannot be identified or the image is no longer available in ACR, **stop** and escalate; do not guess which image was previously healthy.

## 3. Capture evidence before rollback

Create an incident/release record before switching traffic. Capture:

- UTC timestamp and operator.
- Azure subscription, resource group and application names.
- Current backend/frontend revision names, image digests, health/running state and traffic weights.
- Intended previous known-good backend/frontend revision names and image digests.
- Source commit SHA, pull request, GitHub Actions run URL, candidate suffix, and failure symptom.
- Health/readiness responses and relevant logs/metrics around the failure.
- Database migration/change status and whether the prior version is schema-compatible.

Preserve the failed release's GitHub Actions run and summary. Do not paste secrets, `DATABASE_URL`, tokens, or credentials into the record.

## 4. Restore the backend to the known-good revision

Fill in the exact backend revision from the previous successful release summary:

```bash
OLD_BACKEND_REVISION="<previous-known-good-backend-revision>"

az containerapp revision show -g "$RG" -n "$BACKEND_APP"   --revision "$OLD_BACKEND_REVISION" -o json
```

If that revision is inactive, activate it. Wait until it is provisioned and running, and inspect its health state before directing traffic:

```bash
az containerapp revision activate -g "$RG" -n "$BACKEND_APP"   --revision "$OLD_BACKEND_REVISION"

az containerapp revision show -g "$RG" -n "$BACKEND_APP"   --revision "$OLD_BACKEND_REVISION"   --query "properties.{provisioningState:provisioningState,runningState:runningState,healthState:healthState,template:template}" -o json
```

After confirming the old revision is ready, send backend ingress traffic to it:

```bash
az containerapp ingress traffic set -g "$RG" -n "$BACKEND_APP"   --revision-weight "$OLD_BACKEND_REVISION=100"
```

If the backend has no external ingress, this changes its internal ingress routing; the smoke test should go through the frontend's API proxy rather than trying to reach the backend from a public network.

## 5. Restore the frontend to the known-good revision

Fill in the exact frontend revision from the previous known-good release:

```bash
OLD_FRONTEND_REVISION="<previous-known-good-frontend-revision>"

az containerapp revision show -g "$RG" -n "$FRONTEND_APP"   --revision "$OLD_FRONTEND_REVISION" -o json
```

If it is inactive, activate it and verify it becomes provisioned/running before changing traffic:

```bash
az containerapp revision activate -g "$RG" -n "$FRONTEND_APP"   --revision "$OLD_FRONTEND_REVISION"

az containerapp revision show -g "$RG" -n "$FRONTEND_APP"   --revision "$OLD_FRONTEND_REVISION"   --query "properties.{provisioningState:provisioningState,runningState:runningState,healthState:healthState}" -o json

az containerapp ingress traffic set -g "$RG" -n "$FRONTEND_APP"   --revision-weight "$OLD_FRONTEND_REVISION=100"
```

Check that the ingress traffic report shows the intended revision at 100% for both apps. Do not deactivate the failed revision until the service is healthy and the evidence has been captured. Keep the failed revision available for diagnosis unless there is a specific security or cost reason to deactivate it.

## 6. Validate after rollback

Run the smoke tests against the public frontend's current FQDN:

```bash
FRONTEND_FQDN=$(az containerapp show -g "$RG" -n "$FRONTEND_APP"   --query "properties.configuration.ingress.fqdn" -o tsv)
BASE_URL="https://$FRONTEND_FQDN"

curl --fail --silent --show-error "$BASE_URL/" -o /dev/null
curl --fail --silent --show-error "$BASE_URL/api/health" | jq -e '.status == "ok"'
curl --fail --silent --show-error "$BASE_URL/api/ready" | jq -e '.status == "ready"'
curl --fail --silent --show-error "$BASE_URL/api/products" | jq -e 'type == "array" and length >= 1'
```

Then:

1. Inspect backend and frontend Container Apps revisions/traffic to confirm the intended old revisions are receiving traffic.
2. Check logs for database connection errors, startup failures, repeated readiness failures, and HTTP 5xx responses.
3. If safe and appropriate for the environment, submit a controlled test order and confirm it appears in order history. Do not create test transactions against real customers or production payment systems.
4. Observe error rate and latency long enough to verify recovery against the agreed release baseline. Do not claim recovery solely because the first request returned HTTP 200.
5. If any test fails, leave the incident open, preserve logs, and escalate rather than repeating revision switches without a diagnosis.

## 7. Record the rollback outcome

Complete this record with actual values after a real rollback; never pre-fill success:

| Evidence | Record |
|---|---|
| Incident/release ID | |
| Rollback start/end timestamps (UTC) | |
| Operator / approver | |
| Failed GitHub run and source commit | |
| Failed backend revision + digest | |
| Restored backend revision + digest | |
| Failed frontend revision + digest | |
| Restored frontend revision + digest | |
| Traffic weights after rollback | |
| `/`, `/api/health`, `/api/ready`, products checks | |
| Database-backed operation, if run | |
| Error/latency observations after rollback | |
| Did automated rollback work? If not, which leg failed? | |
| User impact, mitigation, and follow-up owner | |

Link the record to the GitHub Actions run and retain the failed revision's logs for diagnosis.

## 8. Risks and improvements before broader production use

- **Database compatibility:** rolling back images does not roll back schema/data. Use expand/migrate/contract changes and verified backups.
- **Single database and region:** the prior revision can still fail if PostgreSQL, the region, or the Container Apps environment is unavailable. Prove database restore/failover separately.
- **Rollback permissions:** the workflow identity must be able to read revision state, change traffic weights, and activate/deactivate revisions. Test least-privilege permissions before relying on automation.
- **Retained images/revisions:** a revision record is not useful if the corresponding ACR digest or required config/secret has been removed. Set a retention policy that preserves the last known-good image and required deployment metadata.
- **Probe limitations:** `/health` only shows that the application process responds; `/ready` checks database reachability. Smoke tests should include representative business flows and observed metrics for production.
- **Partial failure:** backend and frontend traffic are switched separately. The workflow can encounter an Azure API failure during a rollback; its summary must make a failed rollback leg obvious, and an operator may need to restore it manually.
- **Cold start and cost:** reactivating an inactive revision takes time. Keeping both versions active improves immediate rollback speed but costs more; this design deactivates prior revisions after success and accepts a reactivation delay.
- **No live proof yet:** the Azure environment is deleted. This runbook has not been exercised against live Container Apps. Conduct a controlled DEV rollback drill before marking the operational acceptance criteria complete.

## Current status

This file makes the intended procedure specific and reviewable. It does not claim that a rollback was run. Complete DEVOPS-020's live acceptance only after DEVOPS-019 is merged, the Azure backend/runtime are deliberately rebuilt and secured, a known-good version exists, and a controlled rollback is executed with the evidence above.
