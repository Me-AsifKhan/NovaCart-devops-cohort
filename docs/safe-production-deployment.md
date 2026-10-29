# Safe Production Deployment — NovaCart

**Purpose:** a small-team release procedure for digest-based Azure Container Apps deployments. This document describes the intended operational behavior; it is not evidence of a live production rollout. The Azure lab is currently deleted.

## Release contract

Every candidate release must have a reviewed pull request and passing NovaCart Verification Suite; source commit SHA and immutable frontend/backend image digests; current known-good frontend/backend revision names and digests recorded before changing traffic; an identified release operator and observation window; and a health-check result plus recorded promotion/rollback decision.

Do not deploy mutable latest tags. The commit tag is useful for humans, but the digest is the artifact identity.

## Release sequence

### 1. Preflight

1. Confirm the deployment is for the intended environment and approved commit.
2. Confirm both Container Apps and the registry exist, the OIDC identity is scoped correctly, and the previous known-good revision is active.
3. Record current frontend/backend images, active revision names, timestamps and current traffic weights.
4. Confirm the previous digests are still present in ACR and can be pulled.
5. Confirm the database schema is backward-compatible with both old and candidate application versions. Do not combine an irreversible database migration with an app rollout.
6. Check current 5xx rate, latency, dependency health and database connections. Abort if the baseline is already unhealthy.

### 2. Build and identify artifacts

Build each image from the approved commit once, push to ACR with the commit SHA tag, and capture the registry digest. Deploy by digest reference:

    <registry>/novacart-backend@sha256:<backend-digest>
    <registry>/novacart-frontend@sha256:<frontend-digest>

Record the GitHub Actions run URL, commit SHA and both digests in the release summary. Never put credentials in image build arguments or logs.

### 3. Create candidate revisions without replacing the known-good revision

Use Azure Container Apps multiple-revision mode for both apps. Deploy the backend candidate first and preserve the previous backend revision. Wait until Azure reports the candidate revision provisioned and healthy. Then deploy the frontend candidate while preserving its prior revision.

Do not send all production traffic to a new revision simply because an image update command succeeded. Configured image digest, provisioned revision, application health, and user-visible correctness are separate checks.

### 4. Validate before promotion

Run the following checks against the candidate revisions or a controlled test route before changing public traffic. If the platform cannot direct a probe to the candidate revision without public promotion, use a staging/preview endpoint or a controlled temporary revision-specific route; do not falsely claim a pre-promotion test occurred.

- Frontend returns HTTP 200 and serves expected static assets.
- Backend /health and /ready return success.
- /api/products returns a valid product list.
- A safe, identifiable test order can be created and then found, if test data and cleanup policy allow it.
- Candidate revisions report the intended image digests and are ready.
- No unexpected rise in 5xx, p95 latency, restart count, database errors or connection saturation is observed during the release watch.

Do not create production orders just to test unless an approved test-data strategy exists. Prefer a non-production environment or a documented harmless read-only test in production.

### 5. Promote traffic

For a small platform, use a simple revision-based controlled rollout rather than adding a service mesh or a complex progressive-delivery controller:

1. Keep the previous known-good revision active.
2. Route a small test share or internal validation traffic to the candidate where the application and ingress support it.
3. Observe the health signals and compare them with the pre-release baseline.
4. Increase traffic only if checks remain healthy; otherwise stop promotion.
5. Once the candidate meets the agreed observation criteria, direct normal traffic to the candidate and retain the old revision for the agreed rollback window.

Do not invent a percentage if the platform configuration has not enabled multiple revisions or traffic weights. Record actual weights from Azure and the time of each change.

## Failure and rollback procedure

Rollback is triggered if any critical smoke test fails, the candidate cannot become ready, 5xx/latency materially regress against the baseline, or database/dependency errors indicate user impact.

1. Stop further traffic promotion.
2. Record the candidate's commit, digests, revision names, logs and failed validation output.
3. Restore traffic to the previously recorded known-good frontend and backend revisions. If a revision is no longer available, redeploy the recorded previous image digests as new revisions and wait for them to become healthy.
4. Keep the failed candidate at zero production traffic for investigation; do not delete its evidence during incident response.
5. Re-run frontend HTTP, backend health/readiness, product read and approved database-backed smoke checks.
6. Verify error rate and latency return to the prior baseline and the database is healthy.
7. Record the rollback timestamp, operator, previous digests/revisions, traffic weights, smoke-test outcomes, customer impact and follow-up owner.
8. If rollback does not restore service, declare an incident and follow the service recovery/escalation path. Do not repeatedly redeploy without understanding the failure.

Application rollback does not reverse database schema changes or restore deleted data. Use backward-compatible expand/migrate/contract changes and a separately tested database backup/PITR recovery plan.

## Post-deployment watch and evidence

Observe the candidate for at least 10–15 minutes as an initial DEV/pilot guideline; extend it for low-volume traffic or critical changes. Compare with the actual baseline rather than treating this duration as a guarantee.

Release evidence must include PR and source commit SHA; workflow run URL; frontend/backend image tags and digests; old and new revision names; before/after traffic weights and timestamps; smoke-test commands and results; 5xx, latency, dependency and database observations; promote/rollback decision and reason; final running revision/digest and follow-up actions.

Keep evidence free of credentials, tokens, connection strings, customer data and order details that should not be retained.

## Capacity and availability guardrails

- Keep the app stateless; store durable order state in PostgreSQL, not local disk or process memory.
- Set and test explicit minimum/maximum replicas and a concurrency/HTTP scaling trigger. A maximum is both a cost ceiling and a capacity constraint.
- Budget database connections across all replicas. Scale-out can worsen connection pressure without pooling or a managed pooler.
- Use resource requests/limits appropriate to measured CPU, memory, p95 latency and restart behavior; do not claim the current 0.5 vCPU/1 GiB defaults are production-validated.
- Monitor container restarts, 5xx rate, p95 latency, replica count, PostgreSQL connections/CPU/latency, and availability probes.
- Test the alert notification path, not just the existence of a rule.

## Current limitations

- The Azure runtime and remote state backend were deleted on 2026-10-29. This runbook cannot be exercised against a live app until a deliberate, cost-approved rebuild.
- The DEVOPS-019 branch changes the Terraform app revision mode to Multiple and adds post-update frontend/API smoke checks plus a best-effort rollback attempt to the previously recorded image references. This behavior has not been live-tested because Azure is torn down. A rollback attempt is not a guarantee of recovery; verify the final running images and smoke checks.
- The Terraform app configuration must be changed to multiple-revision mode before revision traffic control can be relied on.
- There is no verified active Azure alert notification route or load-test baseline.
- This review is documentation for DEVOPS-019; no live cloud deployment was performed.

## Cleanup and cost

This document creates no Azure resources and incurs no Azure runtime charges. When a test deployment is later approved, budget for PostgreSQL compute/storage/backups, ACR storage, Container Apps replica time, Log Analytics ingestion/retention and network egress. Use a time-boxed test window and delete test resources only after saving needed evidence and protecting any required state backup. Do not run Terraform apply until the full plan and costs are reviewed.
