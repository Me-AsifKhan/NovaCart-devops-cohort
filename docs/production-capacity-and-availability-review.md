# Production Capacity and Availability Review — NovaCart

**Review date:** 2026-10-29  
**Scope:** repository design and recorded evidence, not a live load test.  
**Current status:** Azure lab resources were intentionally deleted on 2026-10-29. The previous DEV deployment was exercised on 2026-10-26; that is historical evidence, not current availability.

## Executive summary

NovaCart is a small two-tier web application: a public Nginx frontend, an internal FastAPI backend, and PostgreSQL. Azure Container Apps and PostgreSQL Flexible Server are the intended cloud runtime. The design can be made more elastic, but the repository alone does not prove production capacity or high availability. No current Azure runtime is deployed and no representative load test has been recorded.

**Recommendation:** allow local development and CI, but do not claim production capacity or pilot readiness until the gates below are tested in a restored DEV environment.

## Current capacity and availability posture

| Risk area | Current design/evidence | Risk and improvement |
|---|---|---|
| Frontend/backend replicas | Terraform currently sets minimum replicas to 1 and maximum replicas to 2 for each app; no explicit application-specific scaling trigger is defined in the shown app templates. | Maximum capacity is intentionally small and not justified by load measurements. Configure a clear scale trigger and bounds, then tune using measured CPU, memory, concurrency, latency and database pressure. |
| Single points of failure | A single PostgreSQL Flexible Server is the data dependency; geo-redundant backup is disabled. App minimum replicas are one. | One database outage can affect all order/product operations. A single app replica has no spare replica during restart or deployment. Do not imply zone-level resilience. Evaluate zone-redundant HA, backup/PITR and restore time only if the service's recovery goals justify their cost. |
| Application resource limits | Container CPU defaults to 0.5 vCPU and memory to 1 GiB. No load test validates these defaults. | Keep a small starting size for the learning environment, measure CPU/memory/restarts and p95 latency, then change limits based on evidence. Raising limits alone will not fix database saturation. |
| Backend concurrency and database connections | The backend opens a PostgreSQL connection for each operation; no connection pool or explicit connection budget is visible. | As replicas scale, connection demand can grow with replica count and request concurrency. Add a bounded pool or managed pooler, set pool size/timeouts, and ensure total possible connections remain below the database limit with headroom for migrations/administration. |
| Database throughput | PostgreSQL Flexible Server defaults to B_Standard_B1ms, 32 GiB configured storage, 7-day backups and no geo-redundant backup. These are development-oriented defaults, not proven production capacity. | Observe query latency, active connections, CPU, storage/IO and lock waits. Add indexes only after query-plan evidence; use pagination and bounded result sets. Run backup/restore drills. |
| Stateless scaling | Product seed data is in code; orders are stored in the configured database. The frontend is a static Nginx site. | The application is compatible with multiple stateless app replicas provided session/user state is not stored in process memory or container disk. PostgreSQL is the durable system of record. Verify all replicas use the same database and do not depend on local filesystem state. |
| Health and readiness | /health and /ready endpoints exist. Compose waits for backend readiness; the deployment workflow currently verifies configured image digests but that alone is not a health check. | Health checks must test the intended dependency level and be used after deployment. A green process check is not enough if database-backed requests fail. |
| Release safety | Images are tagged with commit SHA and deployed by digest. Terraform currently sets Container Apps revision mode to Single and the workflow updates both apps sequentially. | Single-revision replacement and sequential two-app updates create risk of mixed frontend/backend versions and make traffic-based rollback less clear. Use multiple revisions and an explicit smoke-test/traffic-promotion decision; preserve the old digest/revision until the candidate passes. |
| Monitoring | Backend logs to stdout; Terraform attaches the Container Apps environment to Log Analytics. A local Prometheus/Grafana lab is being added separately. | The cloud environment is currently absent, and there is no verified Azure dashboard, alert notification route or measured baseline. Local observability does not prove Azure alerting. |
| Cost | PostgreSQL, ACR, Container Apps, Log Analytics ingestion/retention, network egress and image storage can incur charges. A minimum replica of one avoids scale-to-zero but may cost more than a lab that can idle. | Do not provision for speculative growth. Use a short test window, budget alerts, conservative max replicas, short log retention, and a cleanup checklist. Scale bounds are safety limits, not an SLA. |

## Scaling decision and justification

Use bounded horizontal scaling for the stateless frontend/backend rather than starting with large fixed instances:

- Keep the development starting point small; measure before increasing CPU/memory or maximum replicas.
- Configure an explicit concurrency/HTTP scaling trigger so the scale-out behavior can be explained and load-tested. Pick the initial concurrency threshold from a controlled test, then tune based on p95 latency and saturation—not a guessed production traffic number.
- Set a hard maximum replica count to cap both capacity and cost. The current max of two is suitable only as a conservative learning limit, not a promise that two replicas can handle expected growth.
- Keep at least one replica only when the availability benefit justifies the continuous baseline cost. For a zero-cost local lab, do not run Azure workloads.
- Scale the database separately from app replicas. App scale-out can make a database bottleneck worse if every new replica opens more connections.
- Ensure app instances are replaceable: no authoritative state in memory or container filesystem; use PostgreSQL for durable orders and externalized configuration/secrets.

No numeric production throughput claim is made because there is no recorded load-test baseline.

## Deployment and recovery posture

The existing workflow provides a commit tag, immutable image digest, OIDC login and a deployment summary. Its current workflow checks configured image references, but does not by itself prove application health. The current Terraform app templates use single-revision mode, so traffic control and rollback should be improved before production use.

The target release flow is:

1. Merge a reviewed change only after CI passes.
2. Build and push each image once; record commit SHA and digest.
3. Deploy as a new, identifiable revision while preserving the known-good revision.
4. Wait for revision provisioning and run frontend, backend health/readiness, product-read and safe database-backed checks.
5. Shift traffic only after validation succeeds; monitor 5xx, p95 latency, dependency errors, restarts and database pressure.
6. If validation fails, do not promote the candidate. Route traffic back to the previous known-good revision/digest, run the same smoke checks, and record both the failed candidate and rollback result.
7. Retain release evidence: commit, workflow URL, image digests, revision names, deployment timestamps, smoke-test output, decision and rollback result.

The implementation must not claim automatic rollback until a tested failure path actually performs and verifies it.

## Required acceptance tests before production

- [ ] Run a repeatable load test against a non-production deployment with documented request mix, concurrency, duration and dataset.
- [ ] Record throughput, p50/p95/p99 latency, 4xx/5xx rates, CPU/memory, replica count, database CPU/connections/latency, and errors.
- [ ] Verify the scale trigger fires, replicas increase, and they return down within the intended bounds.
- [ ] Test database connection exhaustion/slow dependency safely in DEV and verify clear errors, timeouts and recovery.
- [ ] Verify /health, /ready, product reads and a controlled order path after each candidate deployment.
- [ ] Prove a failed smoke test prevents traffic promotion and restores the prior known-good version.
- [ ] Test backup restoration and document observed RPO/RTO before claiming database recoverability.
- [ ] Verify cloud alerts reach a named responder and recover/resolve correctly.
- [ ] Recalculate cost using the actual region, replica bounds, database SKU, storage, log volume and test duration.

## What changed and why

The accompanying safe-deployment change proposes multi-revision releases, post-deployment smoke validation, and an explicit promotion/rollback decision. This improves reversibility and evidence without adding a large enterprise release platform. It does not create Azure resources and has not been live-tested because the lab is currently torn down.

**Conclusion:** NovaCart has a reasonable small-platform starting design, not demonstrated production capacity. Increase capacity only after measurement, keep app scale bounded, protect the database from connection storms, and make release promotion depend on health evidence.
