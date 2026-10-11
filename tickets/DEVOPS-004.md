# DEVOPS-004 — One-Command Local Stack

QA needs the complete NovaCart application stack to start reliably and consistently with a single command.

The team wants a local environment that behaves like a complete system instead of a set of unrelated containers.

Your task is to **use Docker Compose to run the frontend, backend, and PostgreSQL together as a complete local application stack** that can be started and managed consistently with a single command.

## Requirements

* Frontend, backend, and PostgreSQL must run together using Docker Compose.
* The Compose stack should use the frontend and backend container images from the runtime-packaging work rather than requiring host-installed application runtimes or a host-installed webserver.
* Services must communicate using stable service discovery rather than host-specific or hard-coded IP addresses.
* Database data must survive application and container restarts.
* Runtime configuration must be environment-driven and must not require environment-specific source-code changes.
* Service dependencies, startup ordering, and readiness must be handled appropriately.
* Individual services should be restartable without requiring the entire environment to be rebuilt.
* The environment should be easy to start, stop, recreate, and troubleshoot.
* Only the interfaces required for local access should be published to the host.

## Deliverable

Implement the complete Docker Compose-based local runtime environment and create:

`docs/local-environment.md`

Document:

* How the complete environment is started and stopped
* How individual services can be restarted
* How the frontend container, including any webserver packaged with it, runs as part of the Compose stack
* How services discover and communicate with each other
* How runtime configuration is supplied
* How database persistence is handled
* How service health and readiness are determined
* What happens when an individual service restarts
* Which services and ports are accessible from the host
* Any assumptions, trade-offs, or limitations

## Acceptance Criteria

Another engineer with **Docker and Docker Compose available** should be able to:

1. Start the complete NovaCart stack with a single command.
2. Access the frontend and verify application functionality.
3. Verify that the frontend can reach the backend through the intended application path.
4. Verify that no host-installed Nginx or application runtime is required to serve the frontend.
5. Verify that the backend can communicate with PostgreSQL using service discovery rather than a hard-coded IP address.
6. Restart the frontend or backend independently without losing persisted database data.
7. Restart PostgreSQL without losing persisted application data.
8. Stop and recreate the application environment predictably.
9. Verify the health/readiness state of the relevant application services.
10. Change supported runtime configuration without modifying application source code.
