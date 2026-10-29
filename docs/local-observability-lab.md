# Local Observability Lab — NovaCart

This lab runs Prometheus and Grafana beside the local NovaCart Compose stack. It requires Docker Desktop but **does not require Azure**. It is designed for local learning and does not prove that Azure monitoring or production alert delivery is deployed.

## What gets collected

- FastAPI request counter and duration histogram at the internal `/metrics` endpoint.
- Prometheus scrape availability (`up`).
- A provisioned Grafana dashboard with request rate, 5xx ratio, p95 request latency, and backend scrape availability.
- Two Prometheus alert rules: backend target down, and sustained elevated 5xx ratio with a minimum request volume.

The API metrics endpoint is reachable only on the Compose network; it is not published as a host port. Grafana and Prometheus bind their host ports to `127.0.0.1` so they are not exposed to the LAN by this Compose mapping.

## Start it on Windows PowerShell

Run from the repository root:

```powershell
Set-Location .\novacart

$securePassword = Read-Host "Choose a strong local-only Grafana password" -AsSecureString
$env:GRAFANA_ADMIN_PASSWORD = [System.Net.NetworkCredential]::new("", $securePassword).Password

docker compose -f compose.yaml config --quiet
if ($LASTEXITCODE -ne 0) { throw "Compose validation failed." }

docker compose -f compose.yaml up --build -d
if ($LASTEXITCODE -ne 0) { throw "Compose startup failed." }

Remove-Item Env:GRAFANA_ADMIN_PASSWORD
docker compose -f compose.yaml ps
```

Use a new password only for this local Grafana instance. The command keeps it in the current PowerShell process environment while Compose reads it; do not paste it into chat or commit it to a file. If Compose reports the variable is missing, set it again before running `docker compose up`.

## Verify the application and metrics

```powershell
Invoke-RestMethod "http://localhost:8081/api/health"
Invoke-RestMethod "http://localhost:8081/api/ready"
Invoke-RestMethod "http://localhost:8081/api/products"

# Generate a small amount of normal traffic for the dashboard.
1..25 | ForEach-Object {
    Invoke-RestMethod "http://localhost:8081/api/products" | Out-Null
    Start-Sleep -Milliseconds 200
}

# Check Prometheus and Grafana readiness.
(Invoke-WebRequest "http://localhost:9090/-/ready" -UseBasicParsing).StatusCode
(Invoke-WebRequest "http://localhost:3000/api/health" -UseBasicParsing).StatusCode

# Check /metrics from inside the backend container; it is intentionally not host-published.
docker compose -f compose.yaml exec backend python -c "import urllib.request; print(urllib.request.urlopen('http://127.0.0.1:8080/metrics').read().decode()[:1200])"
```

Expected results: the application health/readiness checks succeed; Prometheus and Grafana return HTTP 200; the backend metrics endpoint contains `http_requests_total` and `http_request_duration_seconds`.

Open:

- Prometheus targets: http://localhost:9090/targets — target `novacart-backend` should be **UP**.
- Prometheus alerts: http://localhost:9090/alerts — the local rules should be loaded.
- Grafana: http://localhost:3000 — sign in with username `admin` and the password entered at startup, then open **Dashboards → NovaCart → NovaCart Local Service Overview**.

Give Prometheus at least two scrape intervals after generating traffic before judging whether the charts contain data.

## Safe alert drill

This test intentionally stops only the local backend container. It does not affect Azure.

```powershell
docker compose -f compose.yaml stop backend
```

After at least 75–90 seconds, check **Prometheus → Alerts**. `NovaCartBackendTargetDown` should become pending/firing after the scrape target has been down for the configured one-minute `for` period. Confirm it only after the rule's evaluation interval has had time to observe the outage.

Recover the service:

```powershell
docker compose -f compose.yaml start backend
docker compose -f compose.yaml ps
Invoke-RestMethod "http://localhost:8081/api/ready"
```

Wait for the scrape target to return **UP** and for the alert to resolve. Record the actual time, observed alert state and recovery result. Do not claim an external notification was tested: this local stack has no notification receiver configured.

## Troubleshooting

- **Grafana container exits immediately:** set `GRAFANA_ADMIN_PASSWORD` in the same PowerShell session before rerunning Compose.
- **Prometheus target is DOWN:** inspect `docker compose -f compose.yaml logs backend prometheus`; check backend health and that `/metrics` responds from inside the container.
- **Dashboard says no data:** generate traffic, wait two scrape intervals, confirm the target is UP, and check query names in Prometheus.
- **Port conflict:** change the left side of the loopback port mapping in Compose (9090 or 3000), then recreate the stack.
- **Metrics labels:** the instrumentator groups status codes and ignores untemplated routes. Avoid adding raw user IDs, order IDs, query strings, or other unbounded values as Prometheus labels.

## Cleanup and data retention

Stop the services and keep their named volumes:

```powershell
docker compose -f compose.yaml down
```

To delete the local database volume, Prometheus time series, and Grafana's persisted state as well, only when you deliberately want to lose that local data:

```powershell
docker compose -f compose.yaml down -v
```

This only cleans local Docker resources; it does not change GitHub or Azure. There are no Azure resource charges from this lab.

## Acceptance evidence boundary

A successful local run can demonstrate FastAPI metrics exposure, local Prometheus scraping, dashboard provisioning, and Prometheus alert evaluation. It does **not** prove centralized Azure logs, Application Insights, external alert notification, Azure monitoring, or production readiness. Update the project record only with the results you actually observed.
