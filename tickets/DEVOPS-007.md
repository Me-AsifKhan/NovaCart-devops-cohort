# DEVOPS-007 — Define the Azure Shape Before Building It

You have joined the NovaCart Azure migration effort, and the team needs a target architecture before anyone starts writing infrastructure code.

For this migration, the platform direction is:

* **Azure Container Apps** for the frontend and backend runtime
* **Azure Container Registry** for container images
* **Azure Database for PostgreSQL Flexible Server** for the database
* **Log Analytics** for basic platform logging and visibility
* **Terraform** for infrastructure provisioning

Your task is to research these services and design how NovaCart should be connected and deployed predictably.

Before building anything, define how the environment should behave and how traffic should flow between the browser, frontend, backend, database, and container registry.

Use this document as the decision record for the infrastructure work that follows, especially where you define traffic flow, service endpoints, and database connectivity.

## Deliverable

Create:

`docs/azure-architecture.md`

Document:

* Azure resources you expect to create
* How the frontend and backend will run in Azure Container Apps
* How container images will be stored and accessed from Azure Container Registry
* Frontend, backend, and PostgreSQL traffic flow
* Which endpoints the browser, frontend, backend, and database need to use
* How the backend should reach PostgreSQL
* Where PostgreSQL should live in the development architecture
* Any hostname, URL, port, or configuration assumptions required for the services to communicate
* How Container Apps should authenticate when pulling images from ACR
* What basic platform logging or monitoring should exist for the environment
* How Terraform should organize and manage the environment
* Runtime assumptions
* Risks or missing information
* Questions you would ask before a production deployment

## Scope Boundary

Do not write Terraform or deploy Azure resources in this ticket. This is the design and connectivity planning step.

Optional: If you are not familiar with these Azure services, you may explore or create them manually in the Azure Portal in a sandbox environment to understand how they connect. This is only for learning. The actual deployment must be done with Terraform in a later ticket, starting with DEVOPS-008.

Do not design the private database networking solution here. Focus on how the application components need to communicate in the initial development environment.

## Acceptance Criteria

Another DevOps engineer should be able to read your document and understand:

1. Which Azure resources need to exist.
2. How NovaCart traffic moves through the Azure environment.
3. Which endpoints each component needs to reach.
4. How the frontend communicates with the backend.
5. How the backend communicates with PostgreSQL.
6. How Container Apps access container images from ACR.
7. What endpoints, hostnames, or configuration values are required for the services to communicate.
8. What basic platform visibility or logging is expected.
9. What Terraform is responsible for provisioning and managing.
10. What assumptions or uncertainties still exist before production.
