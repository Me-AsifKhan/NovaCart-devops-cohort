# NovaCart — Application Discovery

> **DEVOPS-001 · Understand the Application Inherited**

| Item | Details |
|---|---|
| Application | NovaCart |
| Environment | Local development |
| Discovery date | 2026-10-05 |
| Status | Initial discovery complete |

---

## 1. Purpose

This document records the runtime and operational baseline for NovaCart before containerization, CI/CD, PostgreSQL deployment, and production configuration.

It covers the application structure, startup flow, API, configuration, persistence, logging, testing, security risks, and production-readiness gaps.

---

## 2. Application Overview

```text
Browser
   │ HTTP / JSON
   ▼
FastAPI + Uvicorn :8080
   │
   ▼
Database
   ├── Local development → SQLite
   └── Expected deployment → PostgreSQL
```

| Component | Location | Purpose |
|---|---|---|
| Frontend | `novacart/frontend/` | Browser UI |
| Backend | `novacart/backend/` | FastAPI REST API |
| Tests | `novacart/backend/tests/` | Backend API tests |
| Configuration | `novacart/.env.example` | Example runtime configuration |
| Dependencies | `novacart/backend/requirements.txt` | Python runtime dependencies |

---

## 3. Technology Stack

### Backend

- Python 3.12.10
- FastAPI `0.128.2`
- Uvicorn `0.48.0`
- Psycopg 3
- SQLite development fallback
- PostgreSQL for the expected deployment environment

### Frontend

- HTML
- CSS
- JavaScript

No separate frontend package/build process is required for the initial local run.

---

## 4. Local Run

From `novacart/backend`:

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1

python -m pip install -r requirements.txt

python -m uvicorn app.main:app --host 0.0.0.0 --port 8080
```

Open `novacart/frontend/index.html` directly in a browser.

### Useful URLs

| URL | Purpose |
|---|---|
| `http://localhost:8080/docs` | Swagger/OpenAPI |
| `http://localhost:8080/health` | Health check |
| `http://localhost:8080/ready` | Readiness check |
| `http://localhost:8080/api/products` | Product API |

> `0.0.0.0` is the server bind address. Browser access should use `localhost` or `127.0.0.1`.

**Why:** the virtual environment isolates Python dependencies, while SQLite provides a lightweight local fallback. PostgreSQL remains the expected deployment database.

---

## 5. API Surface

| Method | Endpoint | Purpose |
|---|---|---|
| `GET` | `/health` | Application health |
| `GET` | `/ready` | Readiness status |
| `GET` | `/api/products` | Retrieve products |
| `GET` | `/api/orders` | Retrieve saved orders |
| `POST` | `/api/orders` | Create an order |
| `GET` | `/api/runtime` | Runtime information |

OpenAPI:

```text
http://localhost:8080/openapi.json
```

---

## 6. Runtime & Test Verification

### Application

```text
[✓] Python 3.12.10
[✓] FastAPI 0.128.2
[✓] Uvicorn 0.48.0
[✓] Backend startup
[✓] Port 8080
[✓] GET /health
[✓] GET /ready
[✓] GET /api/products
[✓] Swagger/OpenAPI
[✓] SQLite development fallback
```

Observed runtime:

```text
environment=development
database_engine=sqlite
```

The product API returned seeded application data, confirming successful application execution and database access.

### Tests

Command:

```powershell
python -m pytest -q
```

Result:

```text
1 passed, 3 warnings
```

The first test run failed during collection because `httpx` was missing. Installing `httpx` allowed the existing test to execute successfully.

**Dependency gap:** `httpx` is required by FastAPI/Starlette `TestClient`, while `pytest` is also a test-only dependency. These should be managed as development/test dependencies rather than production runtime dependencies.

---

## 7. Configuration & Persistence

Example:

```env
APP_ENV=development
API_VERSION=v1
DATABASE_URL=postgresql://novacart:change-me@localhost:5432/novacart
```

| Variable | Purpose |
|---|---|
| `APP_ENV` | Application environment |
| `API_VERSION` | API version configuration |
| `DATABASE_URL` | Database connection |

| Environment | Database |
|---|---|
| Local development | SQLite |
| Expected deployment | PostgreSQL |

Local `*.db` files are excluded through `.gitignore`.

**Why:** environment-specific configuration should stay outside application code so the same application artifact can move between environments.

---

## 8. Frontend → Backend Flow

```text
Browser
   │
   ├── GET  /api/products
   ├── GET  /api/orders
   └── POST /api/orders
          │
          ▼
     FastAPI API
          │
          ▼
       Database
```

When `index.html` is opened through `file://`:

```text
http://localhost:8080/api
```

When served through HTTP:

```text
/api
```

---

## 9. Logging

Startup produces runtime information such as:

```text
event=startup_begin
environment=development
database_engine=sqlite

event=startup_complete
database_engine=sqlite
```

Uvicorn also reports application startup and listening state.

Production follow-up:

- log level and format
- centralized collection
- retention
- request/correlation IDs
- sensitive-data redaction

---

## 10. Problems Found & Resolutions

| Problem | Cause | Resolution |
|---|---|---|
| `No module named uvicorn` | Dependencies not installed | Create `.venv` and install requirements |
| `venv` path/creation issues | Incorrect working directory/path handling | Run from `novacart/backend` |
| PowerShell commands at `>>>` | Python interpreter was active | Exit Python and return to PowerShell |
| `ERR_ADDRESS_INVALID` for `0.0.0.0:8080` | Bind address used as browser address | Open `localhost:8080` |
| Tests failed during collection | `httpx` missing | Install `httpx`; manage it as a test dependency |
| SQLite vs PostgreSQL | Local and deployment database modes differ | Keep DB configuration environment-driven and validate PostgreSQL before deployment |

---

## 11. Security Review

### Key risks

| Risk | Priority | Control |
|---|---:|---|
| Secrets committed to Git | **High** | Secret scanning + runtime injection |
| Production DB credentials in config | **High** | Secret manager / environment injection |
| HTTP without TLS | **High** | HTTPS/TLS at ingress or reverse proxy |
| Authentication/authorization not established | **High** | Define and enforce the required access model |
| Public Swagger/OpenAPI | Medium | Restrict or disable in production if unnecessary |
| Unrestricted network exposure | Medium | Private networking + firewall/security rules |
| Sensitive data in logs | Medium | Redaction and log review |
| Dependency vulnerabilities | Medium | Dependency scanning and controlled upgrades |
| No defined DB recovery process | **High** | Backup, restore and retention policy |

### Security baseline

```text
Secrets       → never commit to Git
Database      → private network + managed credentials
Transport     → HTTPS/TLS in production
Application   → least privilege + required authentication
Dependencies → scan before release
Logs          → redact secrets and sensitive data
CI/CD         → security checks before deployment
```

`change-me` is an example placeholder, not a production credential. Real credentials must never be committed.

---

## 12. Production Readiness Gaps

### Database
- Supported PostgreSQL version
- Migration mechanism
- Connection pooling
- Backup/restore process
- Recovery requirements

### Application
- Complete environment-variable inventory
- Authentication/authorization requirements
- CORS policy
- Exact `/ready` dependency checks
- Production startup command

### Testing & dependencies
- Separate runtime and test dependencies
- CI test execution
- Dependency vulnerability scanning
- Test coverage expectations

### Operations
- Metrics
- Centralized logging
- Alerting
- Tracing
- Resource requirements
- Scaling strategy
- Rollback strategy

### External dependencies
- Required external APIs/services
- Network requirements
- Rate/concurrency limits

---

## 13. Questions for Development

1. Which PostgreSQL version is supported?
2. How are database migrations created and executed?
3. Is SQLite strictly for development?
4. What environment variables are required?
5. Which configuration values are secrets?
6. What exactly does `/ready` validate?
7. Are external APIs or third-party services required?
8. What authentication and authorization model is required?
9. What CORS origins are expected?
10. What data requires backup, and what are the RPO/RTO requirements?
11. What logs must be retained?
12. What frontend hosting model is expected in production?

---

## 14. Recommended DevOps Path

```text
Application discovery
        ↓
Security / configuration hardening
        ↓
Backend containerization
        ↓
PostgreSQL integration
        ↓
Automated tests + security scanning
        ↓
CI pipeline
        ↓
Deployment
        ↓
Monitoring / logging / alerting
```

### Container baseline

- Minimal Python image
- Non-root runtime user
- No secrets inside the image
- Explicit port configuration
- Health check
- Reproducible dependency installation

### CI baseline

```text
Checkout
   ↓
Install dependencies
   ↓
Validate / test
   ↓
Security scan
   ↓
Build image
   ↓
Publish artifact
```

---

## 15. Conclusion

NovaCart is a small browser-based application backed by a Python FastAPI service.

Verified runtime:

```text
Python 3.12.10
FastAPI 0.128.2
Uvicorn 0.48.0
Port 8080
SQLite for local development
PostgreSQL for expected deployment
```

Local startup and the existing test suite are working:

```text
1 passed, 3 warnings
```

The main remaining DevOps work is PostgreSQL, test/dependency management, secrets, containerization, CI/CD, observability, security, and production readiness.

> **Discovery complete. Infrastructure work can proceed from this baseline.**
