# Production Capacity and Availability Review — NovaCart

**Review date:** 2026-10-29  
**Scope:** source/configuration review for DEVOPS-019  
**Current Azure state:** intentionally torn down; no live capacity claim is made.

## Executive assessment

NovaCart is a small Nginx frontend, FastAPI backend, and PostgreSQL-backed commerce demo. The frontend and backend can be scaled horizontally if all durable application state remains outside individual replicas. The backend stores orders in PostgreSQL; the example product catalogue is seeded in the database, and the browser keeps demo cart state. There is no intended dependency on files written inside a backend container for durable order state.

The main growth risks are the single PostgreSQL server, a previously unbounded per-operation connection pattern, missing live capacity/latency baselines, and a deployment process that previously updated the backend and frontend directly without candidate-specific smoke tests or automatic rollback.

The DEVOPS-019 changes introduce bounded HTTP scaling, startup/readiness/liveness probes, bounded PostgreSQL pooling, revision-based deployment, candidate validation, traffic cutover, and an automatic attempt to restore prior traffic targets when release validation fails.

**Decision:** these changes improve the source design, but NovaCart is not proven production-ready. Azure resources were deleted on 2026-10-29. There is no live load test, availability test, Azure telemetry, or rollback drill for the new configuration.

## Current architecture and availability posture

| Component | Intended role | Availability/capacity posture and risk |
|---|---|---|
| Nginx frontend Container App | Public web UI; proxies `/api/*) to the backend | Stateless and horizontally scalable. Frontend container health verifies HTTP `/`, while release smoke tests also exercise the API path. The Azure region/environment remains a shared failure domain. |
| FastAPI backend Container App | API, order processing and readiness | Stateless with respect to durable business data when configured with PostgreSQL. Uses database-backed readiness at `/ready`. Application-level errors and database latency can still affect every replica. |
| PostgreSQL Flexible Server | Durable products/orders | Single database server is a major dependency and single point of failure. Terraform defaults to a small development SKU, 32 GiB storage, seven-day backups, and no geo-redundant backup. High availability/failover and restore drills are not configured/proven. |
| Azure Container Apps environment | Runs application revisions and writes console/system logs to the configured workspace | One region/environment is a shared failure domain. Multi-revision deployment improves release recovery; it is not multi-region disaster recovery. |
| Azure Container Registry | Stores versioned frontend/backend images | A release depends on image retention and registry access. ACR admin credentials are disabled in the Terraform design; the managed identity is intended for runtime pulls. |
| Terraform state backend | Coordinates shared infrastructure changes | The former Storage Account/container were deleted on 2026-10-29. OIDC/backend and remote plan workflows are currently unavailable until the backend is deliberately bootstrapped again. |

## Scaling decisions and justification

The Azure Terraform configuration is for a cost-conscious DEV environment, not a production sizing promise. Its initial settings are explicit and bounded:

| Setting | Starting value | Reason and caveat |
|---|---:|---|
| Container CPU/memory | 0.5 vCPU / 1 GiB per container | A valid Azure Container Apps Consumption resource pair and a small baseline. The value is not based on a load test. Terraform validates supported CPU/memory pairs. |
| Backend replicas | Minimum 1, maximum 3 | Keeps a warm backend replica, while limiting the first PostgreSQL connection and CPU load envelope until load testing proves that more replicas are safe. |
| Frontend replicas | Minimum 1, maximum 10 | Nginx is stateless and lighter than the API, so it has a higher ceiling. It must still be load-tested before claiming throughput. |
| Backend HTTP scaling target | 25 concurrent requests per replica | Initial scale trigger, not an RPS/SLO. Tune based on request latency, CPU, queueing and database pool wait. |
| Frontend HTTP scaling target | 50 concurrent requests per replica | Initial trigger for a lightweight Nginx service; tune from measurements. |
| Per-replica PostgreSQL pool | Minimum 1, maximum 4 connections | Bounds each backend process instead of opening a fresh database connection for every operation. |
| Inactive Container Apps revisions | Retain up to 10 inactive revisions | Keeps a useful history for recovery without leaving every prior revision running. Revision history is not a substitute for retaining the corresponding images in ACR. |

With a maximum of three backend replicas and four pooled connections per replica, one active backend revision has a theoretical application-pool ceiling of **12 database connections**. During a blue/green-like overlap between the previous and candidate revisions, that can temporarily rise to **24**. This is a conservative connection-budget estimate from the configured limits, not an observed connection count or proof that the PostgreSQL SKU can sustain the desired workload. Keep headroom for administration, health checks and any other database clients.

The pool queues requests for a bounded period when no connection is available. This protects the database from unbounded connection creation, but a small pool can also increase request latency under load. Observe pool wait/timeouts and application latency during a local/controlled load test, then tune pool size and replica ceilings together. Do not raise backend maximum replicas without recalculating the total database connection budget.

The warm minimum replica values improve response time and give candidate revisions a chance to pass readiness checks before traffic moves. They add cost when the service is running. The deployment workflow deactivates the former revision after successful validation to stop its replicas; during the release window the old and new versions overlap, and temporary extra compute is expected.

## Database bottlenecks and statelessness

The code uses PostgreSQL for durable orders when `DATABASE_URL` points at the hosted database. The new bounded `psycopg` pool is created per application process. With one Uvicorn process per container, the default pool budget is easy to reason about as replicas increase. If worker-process count changes later, the maximum database connection budget must be recalculated because every process owns a separate pool.

The current application still has several database risks:

- The Terraform design uses the PostgreSQL administrator credential for the application connection. Replace it with a dedicated least-privilege database role before a controlled pilot (DEVOPS-015).
- There is no demonstrated load-test baseline for query duration, database CPU, storage throughput, connection exhaustion, or order-creation latency.
- The default database SKU is a small development configuration. Replica scale-out can make the database the bottleneck before it makes the web tier faster.
- Backups are configured in Terraform for seven days, but a restore/failover drill is not evidenced.
- Schema changes can break an older application revision. Use backward-compatible expand/migrate/contract migrations; never assume reverting a container image reverses a database schema change.

The frontend is stateless Nginx. Backend replicas rely on PostgreSQL for durable business data and should not depend on local files, in-memory sessions, or per-replica caches for correctness. Cart state is a browser-side demo feature. If an external cache, session store, file upload, or background job is introduced, its persistence and shared-state model must be designed separately before scaling out.

## Single points of failure and recovery posture

1. **PostgreSQL Flexible Server:** a single database instance is the primary dependency. Without configured and tested high availability, an outage or maintenance event can interrupt order/readiness paths.
2. **Single region/environment:** a regional or environment-level outage affects the whole application. No multi-region active/active setup or tested disaster-recovery target is implemented.
3. **Release and identity path:** deployment requires GitHub OIDC, ACR push permission, Container Apps update/read permission and pre-existing resources. The former state backend has been deleted and must be rebuilt separately before infrastructure automation works.
4. **External observability:** code emits stdout logs and implements health/readiness endpoints, but no live Azure workspace, metric baseline, or external alert receiver exists while the environment is deleted.
5. **Human recovery:** release summaries, image digests and revision names provide traceability; the process still requires an operator to assess an incident and validate a rollback. The new workflow attempts automatic traffic rollback for validation failures.

## Monitoring and operational signals

The platform configuration now has the following signals/guards:

- **Startup probe:** lets the process initialize before the revision is considered ready.
- **Backend readiness probe:** requests `/ready`, which checks database connectivity; readiness failure should prevent that replica from being used for ingress traffic.
- **Liveness probe:** checks `/health` to detect a process that is no longer responding.
- **Frontend readiness/liveness probe:** requests `/`; the release workflow supplements this with checks to `/api/health`, `/api/ready`, and `/api/products).
- **HTTP scaling rules:** concurrent request targets and replica maxima are explicit in Terraform.
- **Release evidence:** the deployment summary records source commit, image digests, previous/current revisions, and smoke-test outcome. If validation fails, the workflow records a failure and attempts to restore previous traffic targets.

These are signals and guardrails, not a full observability platform. In the current Azure state there is no active Log Analytics workspace or Azure alert. Before production, add and test metrics/log queries for 5xx rate, p95/p99 latency, replica/restart count, database pool exhaustion/wait time, PostgreSQL CPU/storage/connections, and alert delivery/recovery. Thresholds should follow observed normal traffic and the agreed user-facing SLO, not arbitrary defaults.

## Release risk addressed by DEVOPS-019

The deployment workflow uses **multi-revision, health-gated, blue/green-like cutover**:

1. Identify the revisions/images currently receiving 100% of traffic and record them.
2. Build/push commit-tagged images and capture immutable registry digests.
3. Create a uniquely suffixed backend candidate while the old frontend remains stable.
4. Wait for the candidate revision's platform readiness, send a 10/20/30% weighted backend canary while the known-good revision retains the rest, and repeat public frontend health/readiness/products checks during the 60/120/300-second observation window. The backend health response exposes the platform revision name, and the workflow requires at least one confirmed candidate response before routing 100% to it.
5. Create a frontend candidate, add a candidate label URL and test that URL directly before changing production frontend traffic.
6. Promote the frontend only after those candidate checks succeed; test the production URL again.
7. If any step after a traffic shift fails, the workflow attempts to restore both old revision targets and fails the run. It records whether rollback succeeded.
8. After a successful cutover, old revisions are deactivated to stop their replicas; they remain in the revision history up to the configured retention limit. Rollback must reactivate an old revision before reassigning traffic.

Backend-first rollout assumes the backend change remains compatible with the current frontend. Releases that break API compatibility must be split into backward-compatible steps rather than relying on traffic weights alone.

## Costs and remaining production work

- ACR, PostgreSQL Flexible Server, the Container Apps environment, replicas, and Log Analytics ingestion can each cost money when provisioned. Two active revisions temporarily increase compute use; successful releases deactivate the previous revisions.
- Minimum replicas of one avoid scale-from-zero delay but incur runtime cost while the environment exists.
- The Azure lab is currently deleted, so the values above describe what Terraform would configure if approved and rebuilt. No Azure scale, failover, or release drill was executed for this change.
- Before a production pilot: restore protected Terraform state/OIDC, harden database identity/secrets, prove private networking, perform realistic load tests, define an SLO and alerts, verify database backup/restore, and rehearse a rollback using known-good digests.

## What changed

- Switched the Container Apps to multiple revision mode and pinned bootstrap traffic to a known revision instead of automatically sending traffic to every latest revision.
- Added startup, readiness and liveness probes for the backend and frontend.
- Added explicit HTTP scale targets, min/max replica settings, and compatible CPU/memory validation.
- Added a bounded PostgreSQL connection pool with a configurable per-process maximum.
- Updated the Azure DEV deployment workflow to validate candidates before cutover, run smoke tests, attempt automatic traffic rollback on failed validation, and retain clear release evidence.

These source changes need CI and local checks. Live acceptance remains pending until the Azure environment is intentionally rebuilt and the rollout/capacity behavior is exercised.
