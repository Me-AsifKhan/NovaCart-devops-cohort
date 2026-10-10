# NovaCart Runtime Packaging

## 1. Overview

NovaCart is packaged as two separate Docker images:

- **Backend:** Python 3.12, FastAPI, and Uvicorn.
- **Frontend:** Nginx serving static HTML, CSS, and JavaScript.

The frontend routes API requests through Nginx to the backend.

## 2. Image Build Commands

Run these commands from the repository root:

```powershell
docker build -t novacart-backend:dev ./novacart/backend
docker build -t novacart-frontend:dev ./novacart/frontend
```

These commands build the backend and frontend images separately.

## 3. Container Run Commands

Start the backend:

```powershell
docker run -d --name novacart-backend -p 8080:8080 -e APP_ENV=development novacart-backend:dev
```

Start the frontend:

```powershell
docker run -d --name novacart-frontend -p 8081:80 novacart-frontend:dev
```

The backend and frontend run in separate containers.

## 4. Ports and API Routing

| Component | Container port | Host port |
|---|---:|---:|
| Backend API | 8080 | 8080 |
| Frontend Nginx | 80 | 8081 |

The frontend is available at `http://localhost:8081`.

The backend health endpoints are `http://localhost:8080/health` and `http://localhost:8080/ready`.

The Nginx configuration forwards requests under `/api/` to `http://host.docker.internal:8080/api/`. This allows the frontend container to reach the backend published on the Docker Desktop host.

For Docker Compose, the API proxy target must change to the backend service name, `http://backend:8080/api/`.

## 5. Runtime Configuration

The backend supports these environment variables:

- `APP_ENV`: application environment; defaults to `development`.
- `API_VERSION`: API version; defaults to `v1`.
- `LOG_LEVEL`: logging level; defaults to `INFO`.
- `DATABASE_URL`: database connection; defaults to `sqlite:///./novacart.db`.

The backend logs to standard output, which can be inspected using `docker logs`.

## 6. SQLite Location and Persistence

With the backend image's working directory set to `/app`, the default SQLite database is `/app/novacart.db`.

The standalone run command does not mount a volume. Therefore, database data inside the container is not guaranteed to survive container removal.

A persistent volume or an external database is needed when data must survive container replacement. Docker Compose will address the PostgreSQL setup and persistent database volume in the next stage.

## 7. Limitations and Assumptions

- The standalone frontend configuration assumes Docker Desktop on Windows and uses `host.docker.internal`.
- The backend uses SQLite by default; PostgreSQL requires a valid `DATABASE_URL` and a reachable database.
- The commands use the `dev` image tag for local development.
- `EXPOSE` documents a container port; `-p` publishes a port on the host.
- Container builds, startup, and endpoint checks must be run before reporting them as successful.
- This setup does not yet provide the complete Docker Compose environment, production orchestration, or persistent SQLite storage.

## 8. Verification Status

- Backend and frontend images built successfully.
- Both containers started successfully.
- Backend health and readiness endpoints verified.
- Products API and frontend API proxy verified.