# Observability Foundation — DEVOPS-016

## Purpose and current deployment status

NovaCart should be diagnosable through a small set of useful logs, health checks, metrics, and actionable alerts. This document distinguishes what exists in source/configuration from what has been verified in a live deployment.

**Current live status:** the recent Azure subscription inventory showed only the Terraform-state Storage Account. No NovaCart Container Apps, PostgreSQL server, ACR, Log Analytics workspace, or Application Insights resource was present. Therefore no live application telemetry pipeline or alert is currently proven active. Provisioning and runtime verification are future work.

## 1. Current signals available in the application

The FastAPI backend configures Python logging to stdout. Its current log events include:

- Startup started/completed and startup failure.
- Request completion: method, path, HTTP status code, duration in milliseconds.
- Request exception: method, path, duration and exception stack.
- Readiness failures, rejected orders, and successful order creation.

The API provides:

- `GET /health`: process-level health response.
- `GET /ready`: attempts a database query and returns HTTP 503 if the database is unavailable.
- `GET /api/runtime`: returns environment, API version, and whether a database URL is configured. It must not return connection-string values or credentials.

These checks have different purposes: `/health` indicates that the process responds; `/ready` tests the database path needed to serve requests. Use `/ready` for a deployment smoke test, and keep secret values out of logs and health responses.

The current request logs are useful but are not yet structured JSON and do not establish a complete distributed trace or a dedicated request correlation ID. Metrics and traces must not be claimed as implemented merely because request durations appear in logs.

## 2. Intended Azure log path

The Terraform configuration defines an Azure Log Analytics workspace with 30-day retention and connects the Container Apps environment to that workspace. Container Apps console/system logs are intended to flow to Log Analytics.

When the Azure runtime is recreated, verify all of these live:
1. The workspace and Container Apps environment exist.
2. System and console logging are enabled and the environment points at the intended workspace.
3. A known application request appears in the expected log table.
4. A deliberately generated safe test error can be found in the workspace.
5. The retention and ingestion configuration are suitable for the budget.

No workspace or application runtime was found in the latest inventory, so this is a configured design in Terraform—not current live centralized logging.

## 3. Operational questions and useful signals

| Question | Signal / evidence | Initial interpretation |
|---|---|---|
| Can a user reach the storefront? | External frontend smoke test and HTTP status | A failing probe is a user-visible symptom; confirm from a second probe before treating one transient timeout as an outage. |
| Is the API failing requests? | Request logs and 5xx ratio once request telemetry is collected | Compare errors with total request volume; inspect affected routes and the deployed version. |
| Is the API slow? | Request duration and p95 latency from logs or a dedicated metric | Compare with the baseline and user-facing SLO; a single slow request is not enough. |
| Is the database breaking readiness? | `/ready` response plus `event=readiness_failed` logs | Check PostgreSQL availability, networking, credentials and connection saturation; do not log connection strings. |
| Did a release introduce a regression? | Commit/image digest, deployment timestamp and metrics before/after the release | Correlate the start of symptoms with the deployed revision. |
| Is capacity becoming a risk? | CPU/memory, replica count/restarts, request failures and latency | Resource saturation is more meaningful when paired with service impact. |

## 4. Log Analytics query examples

Validate the workspace's selected log mode and actual table/column names after deployment before saving queries as workbooks or alert rules. For the common Container Apps custom-log table, a first-pass query can be adapted as follows:

```kusto
ContainerAppConsoleLogs_CL
| where TimeGenerated > ago(1h)
| where Log_s has_any ("event=request_failed", "event=readiness_failed", "ERROR")
| project TimeGenerated, ContainerAppName_s, Log_s
| order by TimeGenerated desc
```

To inspect request-completion lines and compare latency/status after verifying the table schema:

```kusto
ContainerAppConsoleLogs_CL
| where TimeGenerated > ago(1h)
| where Log_s contains "event=request_completed"
| project TimeGenerated, ContainerAppName_s, Log_s
| order by TimeGenerated desc
```

These are starting queries, not proof that a live workspace currently contains the table. Adjust the table names and fields based on the schema actually enabled in the deployment.

## 5. Initial alert policy

Create a small number of alerts only after the runtime and logging path are verified. The following are proposed starting thresholds, not live alert rules:

- **Critical availability:** the frontend synthetic health/smoke check fails three consecutive times, or a confirmed outage persists for five minutes.
- **API error regression:** 5xx ratio exceeds 5% for five minutes and a minimum request volume is present, or multiple critical purchase/order requests fail.
- **Database readiness:** repeated `/ready` failures or repeated readiness-failure events over five minutes.
- **Latency warning:** p95 exceeds the agreed baseline/SLO for ten minutes with enough traffic to be meaningful.

For low traffic, use synthetic checks and absolute failure counts rather than a ratio alone. Tune thresholds after observing a baseline. Do not page on one transient request failure, one short CPU spike, or a metric no one is responsible for acting upon.

**Alert ownership:** every actionable alert needs an owner, service/environment, severity, time window, dashboard/query link, current release identifier, and first response action. Test the delivery path and recovery notification before relying on alerts.

## 6. Cost and retention controls

- Keep development retention at the configured 30 days unless a documented need justifies more.
- Avoid high-volume debug logs and never log passwords, tokens, authorization headers, or full database URLs.
- Review ingestion volume and estimated cost after the first day of real traffic; set usage/cost notifications where supported.
- Use a single small workspace for development until separation or retention requirements justify more.
- Container Apps Consumption can scale to zero when configured for it; do not use minimum replicas purely to make monitoring look active. Current Terraform app configuration specifies one minimum replica per app, which would change runtime cost if those apps are deployed.

Azure Monitor costs depend on log ingestion, retention, and feature usage. A defined workspace by itself does not guarantee a zero-cost observability setup.

## 7. Incident response checklist

1. Confirm the user-visible symptom with the frontend and `/health`/`/ready`.
2. Identify the active deployment commit, image digest and revision.
3. Query console/system logs in the window before and after symptom onset.
4. Compare error rate, latency and dependency health with the pre-release baseline.
5. Decide whether to stop rollout or roll back; preserve evidence before changing the environment.
6. Verify recovery using the same smoke checks.
7. Record impact, timeline, root cause or leading hypothesis, owner, and follow-up actions.

## 8. Implementation checklist

- [ ] Recreate the required Azure runtime after cost review and approval.
- [ ] Confirm Container Apps system/console logs reach Log Analytics.
- [ ] Confirm the workspace tables and saved KQL queries against real events.
- [ ] Add a correlation/release identifier to runtime logs.
- [ ] Add an agreed dashboard or saved queries for requests, errors, latency, readiness and resource pressure.
- [ ] Create and test at least one alert tied to real user/operational risk.
- [ ] Verify alert routing and recovery notifications.
- [ ] Record actual deployment and validation evidence.

## Readiness statement

The code emits useful stdout logs and implements `/health` and database-backed `/ready` checks. Terraform defines a Log Analytics workspace and links the Container Apps environment to it. However, the latest Azure inventory contained no application runtime or workspace, and no live alert or telemetry query has been verified. DEVOPS-016 is therefore **partially designed but not fully implemented or live-verified**.
