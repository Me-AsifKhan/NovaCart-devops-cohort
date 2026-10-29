# Alerting and Release Safety

## Purpose

Give the NovaCart team a small, actionable operating model for detecting risky releases, identifying what is running, and rolling back safely. Alerts should indicate customer or service risk, not merely that a metric moved.

**Current implementation boundary (2026-10-29):** GitHub Actions OIDC and remote-state access passed a test on 2026-10-27, before the remote-state Storage Account was deleted on 2026-10-29. No NovaCart Azure application infrastructure is currently present. The thresholds and release controls below are the documented operating standard to implement and tune when the application is redeployed; they are not active alert rules or proof of live rollback capability.

## 1. Signals and Initial Alert Thresholds

Start with a small set of signals that cover availability, user-visible failures, latency, and dependency health. Treat these numbers as initial defaults: establish a baseline from normal traffic, then tune thresholds to the service's SLO and observed noise.

| Signal | Initial warning | Urgent / page-worthy condition | Why it matters |
|---|---|---|---|
| User-visible availability / synthetic smoke test | One failed run; investigate and repeat | Three consecutive failures or user-facing outage lasting 5 minutes | Confirms whether users can reach and use the service |
| HTTP 5xx error ratio | Above 2% for 10 minutes, with enough requests to be meaningful | Above 5% for 5 minutes, or clearly correlated with failed critical user actions | Indicates failed requests rather than harmless resource variation |
| Request latency | p95 above 1 second for 10 minutes, then tune to measured baseline | p95 remains above the agreed SLO and affects critical flows | Slow responses may precede timeouts and abandoned transactions |
| Backend / database dependency | Connection failures, timeouts, or connection saturation trending upward | Sustained errors prevent a core API or transaction from completing | Identifies dependency failures that can make the app unusable |
| Runtime resource pressure | CPU or memory above 80% for 15 minutes | Above 90% with rising latency, restarts, or failed requests | Resource usage alone is not customer impact; pair it with symptoms |
| Release health | Compare error rate and latency with the pre-release baseline | New critical failures or a material regression immediately after rollout | Helps connect symptoms to a specific change |

For low-volume services, percentage-only thresholds can mislead. Use a minimum request count, synthetic probes, and absolute failure counts where appropriate. A single failed request or short CPU spike should not page someone unless it represents a critical operation or a credible immediate risk.

## 2. Alert Noise and Severity

Use three levels:

- **Critical / page now:** sustained outage, critical transaction failures, or a severe release regression with immediate customer impact. The alert must say what is broken and how to mitigate it.
- **Warning / investigate during working hours:** elevated errors, latency or capacity pressure that has not yet crossed the agreed urgent threshold.
- **Informational:** a deployment completed, a rollback occurred, or a non-actionable trend worth keeping in release history. Do not page for informational events.

Noise controls:
- Use a sustained evaluation window and, for ratios, a minimum traffic threshold.
- Group repeated alerts for the same service and incident; use a recovery notification when the condition clears.
- Suppress duplicate symptom alerts during a known incident, but do not suppress a distinct critical user-impact signal.
- Route alerts to a named owner or team and include severity, environment, service, release identifier, dashboard/log location, runbook, and first response action.
- Review alert volume and false positives after incidents; change thresholds based on evidence instead of simply muting noisy alerts.

Every paging alert must answer: **What is affected? How bad is it? Since when? Which release is running? Where is the evidence? What should the responder do first?**

## 3. Release Traceability and Deployment History

Every release should be reconstructable from version control to the running workload. At minimum, record:

- Git commit SHA and pull request that introduced the change.
- CI workflow run URL and the pass/fail results for tests and image/security checks.
- Immutable container image digest (prefer digest over a mutable tag such as `latest`); human-readable version/tag may supplement it.
- Target environment, deployment/revision identifier, start/completion time, and initiating workflow or operator.
- Smoke-test outcome, health/error/latency comparison, alerts raised, and rollback decision if any.

For a GitHub Actions deployment, preserve the workflow run and release/deployment record, and emit a concise release event with the commit SHA, image digest, environment, and revision. For Azure Container Apps, use the Container App revision and deployed image digest as part of the record when that runtime is actually deployed. Never infer a live version from the repository's latest commit alone.

Keep a short release log that links each production or pilot release to its PR, CI run, artifact digest, deployment record, and post-release check. Retain enough history to identify the last known-good version and explain why a rollback happened.

## 4. Release Watch and Rollback Decisions

For each release:

1. **Before deployment:** verify the PR is reviewed, CI passed, the image/artifact is identifiable, the previous known-good version is recorded, and rollback steps are understood.
2. **Deploy progressively where available:** use a limited pilot, canary, or controlled revision shift before broad rollout. If the runtime cannot do progressive delivery, perform a scheduled rollout with a clear observer and a tested rollback path.
3. **Run smoke tests:** verify storefront availability and the critical frontend-to-backend flow; check dependency connectivity and a representative read/write path if safe test data is available.
4. **Watch the release:** compare 5xx rate, latency, dependency failures and resource pressure with the pre-release baseline for at least 10–15 minutes, or longer where traffic is low.
5. **Decide:** continue only if smoke tests pass and there is no material, release-correlated regression. If critical tests fail or user-impact metrics cross the urgent threshold, stop further rollout and roll back rather than waiting for every dashboard to become red.
6. **Verify recovery:** confirm the previous version is serving traffic, repeat smoke tests, watch error/latency signals, and record the result.

### Rollback guardrails

- Roll back to a recorded, known-good artifact digest or runtime revision; do not rebuild an old commit and assume the result is identical.
- Prefer a reversible deployment/revision switch or traffic rollback. Preserve logs and the failed release's metadata for diagnosis.
- Database changes require special care. Use backward-compatible expand/migrate/contract changes so the old application can still work. Never assume rolling back an application also rolls back its schema safely.
- If rollback is unsafe because of irreversible data changes, stop rollout, mitigate traffic or disable the affected feature, preserve evidence, and escalate to the owner with a documented recovery plan.
- A rollback is not complete until user-facing checks pass and the resulting version is recorded.

## 5. Evidence After Every Release

Complete this checklist and link the evidence from the release record:

- [ ] Release commit, PR, CI run, and immutable artifact digest recorded.
- [ ] Environment and deployed version/revision recorded with timestamps.
- [ ] Smoke tests passed for frontend availability and critical API flow.
- [ ] Error ratio, latency, and dependency health compared with the pre-release baseline.
- [ ] Alerts during the observation window reviewed; false positives and real incidents distinguished.
- [ ] Rollback decision recorded, including reason and outcome, or explicitly marked not needed.
- [ ] Any incident has an owner, follow-up actions, and a review date.

If telemetry or deployment records are not available yet, mark the check **not implemented** rather than claiming success. A passing CI run alone is not evidence that a live deployment is healthy.

## 6. Small-Team Operating Rhythm

- **Every release:** use the release-watch and evidence checklist above.
- **Weekly (15 minutes):** review noisy alerts, failed releases, time to detect/recover, and whether the last known-good artifact is still available.
- **After a significant incident:** write a short, blameless note with timeline, customer impact, detection gap, mitigation/rollback, and one or two owned follow-up actions.
- **Before pilot/production:** prove that alert delivery reaches the responsible person and rehearse a rollback using a non-production release.

## Current Readiness

This document defines the operating approach; it does not itself provision monitoring, create alerts, or prove that application rollback is available. The Azure lab resources, including the Terraform-state Storage Account, were deleted on 2026-10-29. Implement and verify the relevant alerts, telemetry, release records, and rollback procedure after the application infrastructure is intentionally rebuilt.
