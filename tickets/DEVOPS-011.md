# DEVOPS-011 — Remove Public Exposure from the Database Path

Security review found that the Week 2 database should not stay publicly reachable.

The team still needs the application to work after the change, but the database must no longer be treated as a public service.

This is the point in Week 2 where Azure networking becomes part of the implementation. Start from the verified public development environment. Evolve the infrastructure so the application can use a private database path while preserving the frontend -> backend -> PostgreSQL application flow.

This is not only a PostgreSQL setting change. The backend must run in Azure infrastructure that can reach the private database network, resolve the private PostgreSQL hostname, and keep the application path working after public database access is removed.

## Deliverable

Create or update:

* Terraform under `infra/azure/`
* `docs/private-database-connectivity.md`

Introduce or update Azure networking resources needed for the private application-to-database path, such as VNet, application/container app subnet, delegated PostgreSQL subnet, private DNS, and related links.

Document:

* how PostgreSQL connectivity changed
* what Azure networking resources were required
* how the application compute is connected to the network that can reach PostgreSQL
* what name-resolution resources were required
* what changed in the app-to-database path
* how you verified the database is no longer public
* how you verified the application still works after the change

## Scope Boundary

Keep frontend and backend feature logic unchanged. This is an infrastructure connectivity change, not an application rewrite.

The final state should keep PostgreSQL private. Reopening public access means the network path still needs work.

Update the surrounding Terraform as needed so the backend, network, DNS, and PostgreSQL path all work together. Changing only the PostgreSQL resource is not enough.

## Acceptance Criteria

Your solution should demonstrate that:

* the database is no longer publicly exposed
* the application still reaches PostgreSQL from the Azure environment
* the backend is attached to infrastructure that can reach the private PostgreSQL path
* the Azure networking and DNS pieces support the private path
* the private design is understandable to another engineer
* you can explain how you proved the fix works

If the app only works by reopening the database to the public internet, the task is not complete.

After this change, expect to prove both security and operability: PostgreSQL should no longer be public, and the application should still work from inside Azure.