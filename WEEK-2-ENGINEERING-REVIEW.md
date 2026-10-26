# NovaCart — Week 2 Engineering Review

**Review date:** 2026-10-26  
**Scope:** DEVOPS-009 public Azure development deployment, DEVOPS-010 Terraform maintainability, DEVOPS-011 private database connectivity, and documented operational risks.  
**Decision:** **Conditional go for controlled development; no-go for production.** The public application path has live verification evidence, but the private PostgreSQL path is implemented in Terraform and merged—not yet verified in the live Azure environment.

## 1. Executive assessment

NovaCart has a functioning Azure development deployment with a public HTTPS storefront, an internal backend Container App, Azure Database for PostgreSQL Flexible Server, Azure Container Registry (ACR), managed-identity image pulls, Terraform-managed resources, and basic logging through Log Analytics. The recorded live checks on 2026-10-26 passed for the frontend and the health, readiness, products, runtime, and orders APIs.

The main outstanding Week 2 gap is security and operability of the database network path. The latest known deployed state still has PostgreSQL public network access enabled and a broad `allow-azure-services-dev` firewall rule (`0.0.0.0`–`0.0.0.0`). The DEVOPS-011 Terraform and design documentation are merged, and CI passed, but live private connectivity has not been proven. Therefore, do not describe the current running environment as privately connected or production-ready.

## 2. What is currently working

- **Public frontend:** The recorded endpoint returned HTTP 200 on 2026-10-26: `https://ca-novacart-dev-frontend.purplemeadow-6a1a6da7.centralindia.azurecontainerapps.io`.
- **Application path:** Browser → public frontend/Nginx → internal backend Container App → PostgreSQL. The frontend proxies same-origin `/api/*` requests; browsers do not need direct backend or database access.
- **Backend/API verification:** Recorded checks returned `health=status=ok`, `ready=status=ready`, three seeded products, `database_configured=true`, and a saved order record. `/ready` was used as the database-connectivity check.
- **Container image delivery:** ACR stores separate frontend and backend images. The deployment documentation records a user-assigned managed identity for image pulls and disabled ACR admin credentials.
- **Terraform maintainability:** Infrastructure is organized by responsibility within one root module, uses documented inputs/outputs, and has a committed provider lock file. Local `fmt`, `init -backend=false`, and `validate` checks passed in the recorded development work.
- **Code review automation:** PR #15 containing the DEVOPS-011 Terraform/documentation changes merged and its CI check passed. This is evidence of code checks, not proof of a successful live network migration.
- **Database export:** A PostgreSQL custom-format dump was generated in Cloud Shell and `pg_restore --list` showed entries for `products`, `orders`, and `order_items`. The Windows copy has been reconstructed, but its header and SHA-256 comparison still need to be verified before relying on it for restore.

## 3. What the environment is ready for

The environment is suitable for **controlled, non-sensitive development demonstrations and API/integration testing** while the existing deployment remains available and its known limitations are understood. The public frontend/internal backend routing, current database-backed API behavior, and basic infrastructure-as-code workflow have evidence behind them.

It is **not yet ready to claim the Week 2 private-database acceptance criteria are complete**. The running environment must not be represented as having a verified private PostgreSQL path until Azure control-plane settings and application tests confirm it. Avoid storing sensitive or production data in the current environment.

## 4. Strongest parts of the design

1. **Clear traffic boundaries:** The frontend is the only public application ingress; the backend remains internal; the browser does not talk directly to PostgreSQL.
2. **Reusable infrastructure code:** Terraform inputs, outputs, file responsibilities, lock-file usage, and plan-review guidance are documented.
3. **Identity-based registry pulls:** Container Apps pull images with managed identity rather than enabling ACR admin credentials for convenience.
4. **Application-level verification:** The recorded checks include readiness and a persisted order, not only a successful page load.
5. **Risk-aware change control:** A plan that proposed resource replacement was not applied blindly; a database export was created before proceeding.

## 5. Remaining risks and gaps

| Risk | Current evidence / impact | Required next control |
|---|---|---|
| PostgreSQL public exposure | Latest known state has `publicNetworkAccess=Enabled`; the broad `allow-azure-services-dev` rule permits a much wider set of sources than a narrow allowlist. | Complete the private path and confirm public access is disabled and no public firewall rules remain. Do not use `0.0.0.0` rules as a workaround. |
| Destructive infrastructure transition | The reviewed private-mode Terraform plan showed **10 additions and 6 destructions**, including replacement of PostgreSQL, its database, the Container Apps environment, and both apps. | Treat as a migration, not a routine apply. Verify backup integrity, review the complete plan, account for data loss/downtime/URL change, and apply only an explicitly accepted plan. |
| Backup copy integrity | Cloud archive was listed successfully; the reconstructed Windows copy has not yet had its `PGDMP` header and SHA-256 checked against Cloud Shell. | Verify the header and matching SHA-256 hashes before restore. Preserve the original database until restored data and application behavior are verified. |
| Private network not live-verified | DEVOPS-011 code/doc changes merged and CI passed, but the actual private database path and public-access disablement are pending. | Verify PostgreSQL subnet/DNS IDs and `publicNetworkAccess=Disabled`; verify ACA environment is VNet-integrated but remains external; run `/ready`, products and orders tests; place and verify a test order. |
| Terraform state is local | Current Terraform backend is local; state and saved plans can contain sensitive values and are not yet a durable shared CI state solution. | Before CI manages shared infrastructure, use a protected remote state backend with locking/recovery and least-privilege access. |
| CI infrastructure automation not yet in scope/completed | Current PR CI validates code/tests, but this does not mean Azure infrastructure can safely be applied from GitHub Actions. | Address in DEVOPS-013: plan review before apply, remote state, OIDC/workload federation, clear run results, and separation from image delivery. |
| Production security controls incomplete | Application authentication/authorization requirements, secret rotation, edge protection/rate limiting, and a formal least-privilege runtime DB identity are not evidenced as production controls. | Define access requirements; use a least-privilege application DB role; protect/rotate secrets; decide WAF/edge/rate-limiting controls and secure runtime configuration. |
| Recovery and availability objectives undefined | The reviewed materials do not specify approved RPO/RTO, production backup retention, HA, restore-test cadence, or a tested rollback procedure. | Set recovery objectives, configure appropriate backup/HA/retention, and test restore and rollback before production. |
| Observability is basic | Log Analytics receives platform/container logs; comprehensive alerting, tracing, service-level objectives, and incident ownership are not established by the available evidence. | Add actionable alerts, metrics/traces, dashboards, retention/access policies, and an operational runbook. |
| Cost and lifecycle controls | Azure resources may continue to incur charges; a budget alert is not a hard spending cap. | Review current SKUs and spend, set budget alerts, and delete only approved temporary/lab resources after preserving needed data and evidence. |

## 6. DEVOPS-011 migration gate

The desired design documented in `docs/private-database-connectivity.md` is:

```text
Browser -- HTTPS --> Public Frontend Container App (Nginx)
                         |
                         | /api/* via internal backend FQDN
                         v
                  Internal Backend Container App (FastAPI)
                         |
                         | PostgreSQL TCP 5432 + TLS
                         v
                  Private PostgreSQL Flexible Server
```

Before declaring DEVOPS-011 complete, verify all of the following in the deployed environment:

- The backup copy on the PC starts with `PGDMP`, and its SHA-256 matches the Cloud Shell source file.
- PostgreSQL reports `publicNetworkAccess=Disabled`, has the expected delegated subnet and private DNS zone, and no broad public firewall rule remains.
- The Container Apps environment is VNet-integrated and remains **external** (`internal=false`) so the storefront remains publicly reachable; the frontend retains external ingress and the backend retains internal ingress.
- The public frontend returns HTTP 200; `/api/health` returns `ok`; `/api/ready` returns `ready`; products and orders return expected JSON; and a new test order appears in order history.
- Record the deployment date, resource IDs, frontend URL (it may change if the environment is replaced), command results, and test-order reference.

Do not apply the previously reviewed plan simply because the backup exists. The replacement effects, data restore path, downtime, endpoint change, and cost must be explicitly accepted first. Do not delete the original PostgreSQL server until the replacement database is restored and application behavior is verified.

## 7. Controls still required before production

At minimum, production promotion should be blocked until the team has:

- verified private database networking and removed public database access;
- a reviewed Terraform plan/apply process, remote protected state, locking and recovery, and OIDC-based CI authentication;
- a secret management and rotation policy, least-privilege identities, and a defined application authentication/authorization model;
- tested database backups/restoration, schema migration, rollback, HA, RPO/RTO, and retention requirements;
- defined capacity/scaling, availability targets, cost ownership, and an alerting/on-call process;
- dependency/image/security scanning, production deployment approvals, and evidence that checks must pass before release;
- documented log retention, access control, data handling, and any compliance/data residency requirements.

## 8. Incident and remediation record

The repository review did not surface a separate incident/postmortem record to cite. The actionable operational hazard found during this work was the destructive Terraform plan for private-mode migration. It was not applied; the safer response was to stop, preserve the data through an export, and require plan/backup verification before proceeding. This is a preventive change-control decision—not a claim that a production incident occurred or was fully remediated.

If a distinct incident occurred, add its timeline, user impact, detection method, root cause, remediation, and follow-up owner here before describing it as closed.

## 9. Assumptions and evidence limits

- This review reflects repository documentation and the latest recorded Azure verification dated **2026-10-26**; live state can change after the recorded checks.
- The public app/API checks are documented evidence from the development deployment. They do not prove production capacity, security, or resilience.
- PR #15 and its CI pass prove the DEVOPS-011 change was reviewed/checked at code level; they do not prove that private connectivity is active in Azure.
- No production workload, customer data, formal availability target, approved RPO/RTO, or compliance requirement is assumed.
- The Windows backup copy's integrity check is still pending as of this review.

## 10. Go / no-go decision

**Conditional go:** continue development and non-destructive planning. The current public application path has working evidence and the Terraform code is maintainable enough for the development phase.

**No-go:** do not label Week 2's private database objective complete, do not promote this environment to production, and do not run GitHub Actions against the live infrastructure until the backup, migration plan, remote-state design, and credentials are safely controlled.

The next immediate action is to verify the dump on the PC and match its SHA-256 with the Cloud Shell source. Then complete the carefully reviewed DEVOPS-011 migration and capture live verification evidence. DEVOPS-013 should address remote Terraform state and OIDC-based Azure infrastructure automation before CI is permitted to make shared infrastructure changes.

## Source references

- [DEVOPS-012 acceptance criteria](tickets/DEVOPS-012.md)
- [Azure development deployment and recorded live verification](docs/azure-dev-deployment.md)
- [Terraform maintainability and safe plan review](docs/terraform-reproducibility.md)
- [Private database design and verification plan](docs/private-database-connectivity.md)
- [DEVOPS-013 infrastructure automation ticket](tickets/DEVOPS-013.md)
- [PR #15 — private PostgreSQL networking](https://github.com/Me-AsifKhan/NovaCart-devops-cohort/pull/15)
