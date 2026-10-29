# Production Capacity and Availability Review — DEVOPS-019

**Review date:** 2026-10-29  
**Decision:** Not ready for a production pilot. The Azure lab was deliberately deleted on 2026-10-29, so there is no live deployment to load-test or inspect today.

This review distinguishes Terraform/source configuration from live evidence. No throughput, latency, or availability target is represented as measured until a load test and runtime observation are performed.

## 1. Target architecture

```text
Browser
  |
  v
Public Frontend Container App (Nginx)
  |
  | same-origin /api/* proxy
  v
Backend Container App (FastAPI, internal ingress)
  |
  | PostgreSQL over TLS
  v
Azure Database for PostgreSQL Flexible Server
```

The intended Azure design uses Azure Container Apps, Azure Container Registry, PostgreSQL Flexible Server, Log Analytics, and Terraform. The local Compose deployment uses PostgreSQL in a named volume. The Azure resources are deleted; recorded endpoint URLs are historical.

## 2. Capacity and availability findings

| Area | Finding | Risk / decision |
|---|---|---|
| Application size | Terraform allocates 0.5 vCPU and 1 GiB memory per frontend/backend replica. | Conservative starting size, not measured capacity. Load-test before changing it. |
| Replica range | Previously one minimum replica and max two, with no explicit HTTP scale rule. | Limited burst capacity. This ticket introduces an explicit HTTP scaler with a bounded maximum of five. |
| Minimum replicas | Proposed default remains one per app. | Reduces idle cost relative to two permanently warm replicas, but one replica is not redundancy. |
| Scale trigger | Proposed HTTP concurrency target is 50 requests per replica. | Initial hypothesis only. Tune from measured latency, CPU/memory, errors and DB connections. |
| Release mode | Previous Terraform used Single revision mode and 100% latest-revision traffic. | A failed version could not be canaried intentionally. This ticket moves both apps to Multiple revision mode with release-owned traffic weights. |
| Health signals | Backend exposes /health (process) and /ready (database readiness); frontend serves /. | Adds startup, liveness and readiness probes. Must still be verified after a future deployment. |
| Database | One PostgreSQL Flexible Server; Terraform defaults to B1ms, 32 GiB storage, seven-day backups, no geo-redundant backup and no zone-redundant HA. | Single point of failure and likely first scaling bottleneck. App scaling cannot overcome DB outage or connection exhaustion. |
| Connections | Backend opens PostgreSQL connections per operation; no persistent connection pool is configured. | Connection churn and max connections can become bottlenecks as replicas scale. Add bounded pooling and calculate a connection budget before higher concurrency. |
| Region | One region (Central India), one database server. | No region-level recovery or proven failover. Define RPO/RTO and test backup restore before production. |
| Monitoring | Application stdout logs, health endpoints, Terraform Log Analytics configuration, and documented thresholds exist. | No current Azure runtime, workspace, active alert or notification route. A proposal in Markdown is not a live alert. |
| Release traceability | Workflow tags images by commit and deploys image digests. | New controlled workflow records previous/candidate revisions, digests, commit and workflow run. |
| Recovery | Rollback is documented but has not been rehearsed against a live runtime. | A config review cannot prove recovery. A non-production rollback drill remains a gate. |

## 3. Concrete platform changes in this ticket

The Terraform changes in this PR implement these configuration improvements:

1. **Multiple Container Apps revisions.** Both apps use Multiple revision mode so old and candidate versions can coexist. A lifecycle rule prevents Terraform from resetting deployed image digests or traffic weights owned by the release workflow.
2. **Bounded scale-out.** Each app keeps at least one replica and can scale to a configurable maximum of five using an HTTP concurrency rule targeting 50 concurrent requests. These are conservative starting defaults, not a capacity guarantee.
3. **Startup, liveness and readiness probes.** Backend startup/liveness uses /health; readiness uses /ready, which tests the database connection. This avoids restarting a process solely because PostgreSQL is unavailable while preventing an unready replica from receiving traffic. Frontend probes use /.
4. **Bounded inactive revision history.** Each app retains up to 20 inactive revisions. The release workflow deactivates the previous revision only after successful promotion checks, reducing idle replica cost while leaving an earlier version available for reactivation.

No Terraform apply or live Azure deployment was run for this ticket. CI must validate the changes. Apply only after the remote state backend is deliberately restored, a full plan is reviewed, and cost is approved.

## 4. Why these scaling choices

- **One minimum replica** preserves a warm development service without keeping two replicas running all the time. For an availability target that requires replica redundancy, a production configuration may need at least two replicas, with increased cost.
- **Five-replica maximum** gives limited headroom for a small demo while bounding cost and potential database connection pressure. Raise it only after load testing and calculating the DB connection budget.
- **50 concurrent requests per replica** is an initial HTTP scaler threshold. Tune it from measured latency, CPU/memory, queueing and errors; concurrency is not a service-level objective.
- **0.5 vCPU / 1 GiB** remains a starting allocation for each replica. Change it only after evidence shows resource constraint or over-allocation.
- **One PostgreSQL server** remains the low-cost DEV design. It is a clear availability bottleneck; HA is not configured or claimed.

Azure Container Apps uses configured rules to scale and supports multiple active revisions. See [Microsoft's scaling guidance](https://learn.microsoft.com/en-us/azure/container-apps/scale-app) and [revision management](https://learn.microsoft.com/en-us/azure/container-apps/revisions).

## 5. Stateless scaling and database limits

In the Azure design, PostgreSQL is the system of record for catalog/order data, so multiple backend replicas can serve requests against the same database. The static Nginx frontend is also stateless. The local SQLite fallback is for local development only; SQLite file storage is not a shared persistence model for horizontally scaled cloud replicas.

Before increasing the replica cap:

1. Load-test and capture throughput, p50/p95/p99 latency, errors, CPU/memory, replica count and DB connections.
2. Calculate the maximum database-connection budget across replicas and workers.
3. Add a bounded connection pool or another deliberate pooling strategy; leave headroom for administration, migrations and health checks.
4. Alert on PostgreSQL connections, CPU, storage, query latency and failed readiness.
5. Review slow queries and indexes before selecting a larger database SKU.

## 6. Operational signals and remaining gaps

After redeployment, useful signals include Container Apps revision provisioning/health state, probe results, replica count, scale-out events, frontend/API smoke tests, console logs in Log Analytics, and release evidence in the GitHub Actions summary.

These are not a finished monitoring system. Current gaps are a live Azure runtime/workspace, validated Azure log queries, a service-level dashboard, a tested alert rule/notification route, and evidence that an alert fires and recovers. Thresholds must be tuned using a measured baseline rather than treated as proven SLOs.

## 7. Risks before production

- PostgreSQL has no configured HA or proven failover.
- No load test establishes throughput, p95/p99 latency, error rate or safe replica limits.
- The scale cap protects cost but can still saturate under higher traffic.
- No connection pool is configured; database connection pressure can rise with replicas.
- One minimum replica per app does not provide strong redundancy; a higher minimum costs more.
- Canary requests reach a small sample of real traffic; old/new frontend and backend APIs must remain compatible during rollout.
- The workflow uses smoke tests and a short observation period, not metric-based SLO gating.
- Deactivating old revisions lowers idle cost but reactivation may take time.
- ACR images must be retained for rollback; no automatic image-purge policy is configured here.
- Application rollback does not roll back database schema changes. Use backward-compatible expand/migrate/contract migrations.
- Azure resources were deleted; live capacity and recovery acceptance remain unverified.
- ACR storage, Log Analytics ingestion/retention, PostgreSQL and running Container Apps replicas can incur charges. Budget alerts are not hard spending caps.

## 8. Acceptance evidence checklist

Do not check an item until evidence is collected from the current deployment.

- [ ] Terraform fmt/init without backend/validate and CI pass.
- [ ] Reviewed plan shows intended revision mode, probes, scale settings and no unexpected replacement/deletion.
- [ ] Load test records throughput, p50/p95/p99 latency, error ratio, replica count, CPU/memory and PostgreSQL connection/latency metrics.
- [ ] A synthetic test verifies /health and /ready behavior during a controlled database-unavailable test, then recovery.
- [ ] Candidate revision becomes healthy before canary traffic begins.
- [ ] Backend and frontend are canaried, promoted, and traceable by commit/image digest/revision.
- [ ] Failed validation restores the previous revision pair and passes post-rollback checks.
- [ ] Alert routing and recovery notifications are tested.
- [ ] Cost and cleanup evidence is recorded.

**Current boundary:** this ticket adds configuration and workflow in source control. Live capacity, Azure monitoring and live rollback remain unverified while the Azure environment is deleted.
