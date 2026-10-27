# Week 1 Engineering Review — NovaCart

## 1. Purpose and Scope

This review assesses the Week 1 NovaCart engineering baseline before cloud infrastructure design begins. It evaluates source control, application runtime, CI validation, and the risks that must be addressed before production deployment.

Evidence is based on the repository implementation and documented local verification. A documented procedure is not automatically proof that a GitHub control is enforced.

## 2. Source Control

### Git workflow

The documented workflow uses short-lived feature branches and pull requests into `main`. Changes should be reviewed, automated checks should pass, and approved pull requests should be merged using Squash and Merge. Feature branches should be synchronized with `main` regularly and deleted after merging.

### Main branch protection

The repository has an active ruleset named `Protect Main` targeting `main`. The exact enforcement of required approvals, required status checks, and branch-update requirements must be confirmed in GitHub settings before these controls are described as enforced.

### Review and validation

The CI workflow runs on pull requests targeting `main`. The documented CI job is named `NovaCart Verification Suite`. The team should confirm that this exact check is required by the `main` ruleset and that direct changes to `main` are prevented.

### Emergency fixes

The documented process is to create a narrowly scoped fix, open an immediate pull request, run CI, request priority review, and merge after approval. Emergency handling must not silently bypass required checks or review controls. Any exceptional bypass should be explicitly authorized and audited.

## 3. Runtime and Application

### Packaging and startup

The frontend and backend have separate Dockerfiles. Docker Compose provides a local stack containing the frontend, backend API, and PostgreSQL database.

The documented startup commands, from the repository root, are:

```powershell
Set-Location .\novacart
docker compose -f compose.yaml up -d --build
docker compose -f compose.yaml ps
```

The frontend is published on host port 8081 by default. The backend listens on container port 8080 and is not directly published to the host by the Compose configuration. PostgreSQL uses container port 5432 and is also not published to the host by that configuration.

### Service discovery

The Compose-specific Nginx configuration forwards `/api/` requests to the `backend` service on port 8080. Compose service-name DNS provides internal service discovery. The backend connects to PostgreSQL through the `DATABASE_URL` environment variable using the `db` service name.

### Runtime configuration and secrets

Configuration includes `APP_ENV`, `API_VERSION`, `LOG_LEVEL`, database connection settings, and `FRONTEND_PORT`. The `.env.example` file documents local development settings, and `.env` is excluded from Git.

The Compose configuration contains fallback development database credentials. These defaults are suitable only for local development and must not be reused in a production environment. Production secrets must be supplied through an approved secret-management mechanism.

### Persistence

PostgreSQL uses a named Docker volume, `postgres_data`, to retain database files across ordinary container recreation. This is local persistence, not a production backup or disaster-recovery solution. A successful backup and restore procedure has not been established by the evidence reviewed here.

### Health and readiness

Compose defines a PostgreSQL health check using `pg_isready`, a backend health check against `/ready`, and a frontend health check against its root endpoint. The backend waits for the database to become healthy, and the frontend waits for the backend to become healthy.

Previously documented local verification reports successful container startup, backend health/readiness checks, product API access, and frontend API proxy behavior. These results support local-stack functionality; they do not establish production availability or resilience.

## 4. Continuous Integration

### Pull request workflow

The workflow in `.github/workflows/ci.yml` runs for pull requests targeting `main`. It grants read-only repository content permission and disables persisted checkout credentials.

### Automated validation

The workflow:
1. Verifies that required frontend files exist.
2. Sets up Python 3.11.
3. Installs backend dependencies and the `pytest` and `httpx` test dependencies.
4. Runs backend tests using `python -m pytest -v`.
5. Builds the backend Docker image.
6. Builds the frontend Docker image.

### Failure behavior

A failing shell command, backend test, or Docker image build causes the relevant CI job to fail. A failed required status check should block merging when the GitHub ruleset is configured to enforce that check.

The existence of a workflow alone does not prove that its status check is required for merging. That setting must be verified in GitHub.

### Important missing validation

The current workflow does not demonstrate:
- Automated end-to-end testing of the complete Compose stack.
- Automated frontend-to-backend-to-PostgreSQL integration tests in CI.
- Dependency and container image vulnerability scanning.
- Secret scanning, software bill of materials generation, or image signing.
- Automated coverage thresholds or deployment smoke tests.

These are identified gaps, not features claimed to be implemented.

## 5. Top Five Production Risks

### Risk 1 — Development credentials and secret handling

**Priority: High**

- **Problem:** Compose includes fallback database credentials intended for local development.
- **Impact:** Reusing these values in cloud environments could expose the database to unauthorized access.
- **Recommendation:** Use a managed secret store, least-privilege database accounts, credential rotation, and environment-specific configuration. Fail deployment validation when development defaults are used in production.

### Risk 2 — Database recovery is not established

**Priority: High**

- **Problem:** The named PostgreSQL volume provides local persistence, but a production backup, restore, and recovery process has not been demonstrated.
- **Impact:** Data loss or prolonged recovery following database failure or accidental deletion.
- **Recommendation:** Design managed database backups, point-in-time recovery where supported, retention policies, and tested restoration procedures. Define recovery time and recovery point objectives.

### Risk 3 — CI does not validate the complete application stack

**Priority: High**

- **Problem:** CI checks frontend file presence, runs backend tests, and builds images, but does not demonstrate end-to-end validation of the complete Compose stack.
- **Impact:** Service integration, database connectivity, migrations, or frontend API routing regressions may escape CI.
- **Recommendation:** Add automated Compose-based integration and smoke tests that verify application startup, readiness, API behavior, and database connectivity.

### Risk 4 — Supply-chain security checks are missing

**Priority: Medium**

- **Problem:** The reviewed workflow does not include automated dependency or container vulnerability scanning, secret scanning, or image provenance controls. Third-party actions use version tags rather than verified commit-SHA pins.
- **Impact:** Vulnerable dependencies, exposed secrets, or compromised build inputs may reach later environments.
- **Recommendation:** Add appropriate security scanning, pin third-party actions to verified commit SHAs, establish vulnerability remediation rules, and evaluate SBOM generation and image signing.

### Risk 5 — Production operations and network controls are not established

**Priority: High**

- **Problem:** The local Compose setup does not demonstrate production TLS and ingress controls, resource limits, centralized logs, monitoring and alerting, or a resilient deployment architecture.
- **Impact:** The application may be difficult to secure, scale, diagnose, or recover from failures after deployment.
- **Recommendation:** Address these requirements during cloud infrastructure design, including network segmentation, TLS, workload health, resource sizing, observability, availability, and disaster recovery.

## 6. Recommendation

READY TO PROCEED TO CLOUD INFRASTRUCTURE DESIGN

### Evidence and conditions

The repository has separate frontend and backend container packaging, a Compose-based local stack with PostgreSQL, service-name-based internal communication, runtime configuration, health checks, and a pull-request CI workflow that tests the backend and builds both container images.

These capabilities provide a reasonable foundation for beginning cloud infrastructure design. The recommendation means that design work can proceed while the identified gaps are tracked and addressed; it does not mean the application is production-ready.

Before treating the source-control safeguards as enforced, verify that the `Protect Main` ruleset requires pull requests and the `NovaCart Verification Suite` status check, and confirm the intended approval and branch-update requirements. Before production release, prioritize secret management, database recovery, end-to-end validation, security scanning, and production operations controls.

## 7. Evidence and Limitations

This review distinguishes repository configuration and documented local verification from controls that still require independent confirmation. It does not claim that cloud deployment, production backups, vulnerability scanning, end-to-end CI testing, or production-grade availability controls have been implemented.

Update this review if subsequent verification changes any of these findings.
