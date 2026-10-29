# Engineering Readiness Review — NovaCart

**Review date:** 2026-10-29  
**Decision: NO-GO for a controlled production pilot.**  
**Permitted use today:** local development, CI validation, and learning exercises only.

This review distinguishes committed source/configuration, historical live evidence, and currently running infrastructure. Passing CI or having a runbook does not prove that Azure services are deployed or that recovery paths work.

## Executive decision

NovaCart has a working application codebase, Docker Compose development stack, pull-request CI, Terraform configuration, an OIDC authentication design, and deployment/operations documentation. A public Azure DEV deployment was successfully exercised on **2026-10-26**, including frontend HTTP 200, health/readiness, product retrieval, runtime configuration, and saved-order checks.

The Azure lab was deliberately deleted on **2026-10-29** to avoid continued charges. After cleanup, the selected Azure subscription showed no resource groups and no resources. The remote Terraform state Storage Account/container were deleted too; the state blob was backed up locally before deletion.

Therefore the previous Azure evidence proves the earlier deployment worked at that time, but there is no live DEV environment today. The repository is not ready for a production pilot because critical deployment, identity, private networking, monitoring, alert notification, and rollback controls are either incomplete or not live-verified.

## Readiness matrix

| Area | Current evidence | Decision / remaining work |
|---|---|---|
| **Artifact and version strategy** | The Azure deployment workflow builds backend/frontend images using the Git commit SHA as a tag and deploys by digest. Historical DEV images had versioned tags. | **Partially implemented.** Confirm CI publishes both images, preserve the digest-to-commit mapping, and retain the previous known-good digests before release. |
| **CI/CD** | PR CI runs Terraform formatting and validation, Compose configuration, backend tests, and frontend/backend image builds. The manual plan workflow is separate from application delivery. | **Partially implemented.** CI is not proof of live deployment. The Azure deployment workflow needs the resource prerequisites and scoped roles. |
| **Azure DEV deployment** | Historical deployment and API evidence dated 2026-10-26 is recorded in the deployment guide. The latest cleanup inventory on 2026-10-29 showed no resources. | **Not currently deployed.** Rebuild only after cost review, state backend restoration, permissions review, and an approved plan. Old endpoint URLs are historical. |
| **QA/PROD promotion** | The current pipeline targets the azure-development Environment. No separate QA or production environment/promotion workflow has been verified in the repository. | **Not implemented.** Define immutable artifact promotion from DEV to QA/PROD, environment-specific variables/permissions, required reviews, and separation of state. Do not rebuild an image for each environment if the same digest should be promoted. |
| **Rollback** | The release-safety guide describes the rollback decision process. The deployment workflow updates existing Container Apps to digest references. | **Not proven.** The production rollback runbook has not yet been written, and no live rollback drill is possible while the runtime is deleted. A rollback must record previous digests/revisions and verify /api/health, /api/ready, and a representative critical path. |
| **Secrets and identity** | GitHub-to-Azure OIDC and state-container access were verified historically on 2026-10-27. Terraform code defines a user-assigned identity for ACR pulls and disables ACR admin credentials. | **Not hardened for pilot.** The old state backend and its role-assignment scope were deleted. Terraform still constructs the application database connection with the PostgreSQL administrator credential. A least-privilege app DB role and a controlled secret lifecycle/Key Vault design are not implemented/verified. Recreate OIDC/RBAC for any new backend. |
| **Logs and metrics** | The backend writes to stdout and provides /health and /ready; the Terraform design connects the Container Apps environment to Log Analytics. | **Application signals exist, Azure telemetry is not live.** Verify workspace integration, actual log tables and queries, and a safe test-error event after a future deployment. |
| **Application Insights / monitoring** | No Application Insights resource was present in the post-cleanup inventory. The current main branch contains the observability design; a local Prometheus/Grafana implementation is being developed separately. | **Not ready.** Local metrics work does not meet Azure monitoring acceptance. Decide whether Application Insights adds needed distributed traces/dependency telemetry, then configure and validate it deliberately. |
| **Alerts** | Proposed thresholds and noise controls are in the release-safety guide. | **Not live-proven.** Configure a real alert, notification destination, named owner, and recovery notification. Test firing and recovery; do not treat a rule file or dashboard as proof of notification. |
| **Private PostgreSQL** | Terraform contains optional VNet integration, delegated subnets, private DNS, and a mode that disables PostgreSQL public access. | **Design only.** There is no live evidence that private DNS resolves from the backend, public access is disabled, and database-backed application requests remain healthy. |
| **Engineering acceptance evidence** | Historical checks, CI logs, and ticket documentation exist. | **Incomplete for pilot.** Capture current environment, source commit/image digests, smoke tests, security checks, telemetry and rollback evidence after rebuilding. |
| **Cost and state safety** | Azure resource inventory is empty; the last remote state file is backed up locally. | **Cost goal achieved for identified resources.** The Terraform OIDC/plan workflows are blocked until a new backend is bootstrapped. Keep the state backup private; do not restore an older archived state blindly. |

## Major blockers

1. **No runtime to validate.** Current Azure endpoint URLs are not active. There is no ACR, Container Apps, PostgreSQL, or Log Analytics workspace in the post-cleanup inventory.
2. **State/backend unavailable.** The existing OIDC backend test and plan workflow refer to the deleted backend. A new state backend must be bootstrapped and its access/locking verified before CI can plan against remote state.
3. **Database identity and secret lifecycle need hardening.** The app should not use the PostgreSQL server administrator credential for ordinary application queries. Use a dedicated, least-privilege database role and an explicit secret rotation approach.
4. **Private database mode is not proven.** Configuration is not enough; deploy and verify it before the database can be treated as private.
5. **Monitoring and alert notification are not operationally proven.** Azure logs, metrics, dashboards, a real notification route, and the response process need a safe test.
6. **Rollback is not rehearsed.** A runbook and known-good digest/revision are required, followed by a controlled non-production drill.
7. **QA/PROD promotion and environment isolation are missing.** A pilot needs an intentional release path and environment-specific access boundaries.

## Minimum gates before reconsidering a pilot

Do not treat these gates as passed until evidence is collected for the actual candidate environment.

- [ ] Recreate the Terraform state backend, secure it, verify OIDC and scoped RBAC, and prove backend access/locking.
- [ ] Adopt or explicitly defer the mentor's module/environment Terraform layout; keep DEV and PRD state boundaries independent.
- [ ] Review the complete Terraform plan, role assignments, replacement/deletion actions, regional availability, and cost before an approved apply.
- [ ] Deploy the DEV baseline and both images; record commit SHA and immutable image digests.
- [ ] Apply private PostgreSQL networking and prove public access is disabled, DNS resolves from the backend, readiness succeeds, and a database-backed operation works.
- [ ] Replace the PostgreSQL administrator connection with a dedicated application DB role and implement/verify secret storage and rotation.
- [ ] Verify real Azure logs and queries; implement metrics/trace strategy as justified; configure and test at least one actionable alert and its notification route.
- [ ] Write the production rollback runbook; execute a controlled rollback to a known-good backend and frontend digest, then verify health and record the evidence.
- [ ] Define the DEV → QA → PROD promotion/approval path and confirm the same approved artifacts are promoted without rebuilding.
- [ ] Complete the missing DEVOPS-019 definition using the mentor's original ticket. It was not found in either the public repo or the checked upstream/main; its scope must not be invented.
- [ ] Run the readiness review again using current evidence, not historic URLs or expected configuration.

## Final recommendation

**Do not proceed to a production pilot now.** The application and CI are a credible foundation for local development and interviews, but the current cloud state is intentionally empty and several security/operational controls are only designed or encoded—not deployed and proven.

Given the cost constraint, continue with local Compose, tests, the local observability lab, Terraform static checks, and documentation first. Restore Azure only for a short, explicitly costed test window. Before that window, prepare the state backend, target architecture, secret/identity model, verification commands, rollback plan, and a complete cleanup checklist. Apply only after reviewing the plan and accepting the spend and replacement/deletion risks.
