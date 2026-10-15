# DEVOPS-009 — Deliver a Working Azure Development Environment

The team has Terraform-managed platform resources from DEVOPS-008, but the actual NovaCart application is not running in Azure yet.

Extend the public development environment with the frontend and backend application containers. Configure it so a browser can reach the frontend, the frontend can reach the backend endpoint, and the backend can reach the database endpoint.

## Deliverable

Create:

* Terraform changes under `infra/azure/` needed to deploy the NovaCart frontend and backend on the DEVOPS-008 baseline
* `docs/azure-dev-deployment.md`

Document:

* how the development deployment is assembled
* which Azure services are involved
* which endpoint the frontend uses to reach the backend
* which endpoint the backend uses to reach the database
* what the expected development endpoint(s) are
* what you verified after deployment

## Scope Boundary

Do not redesign the infrastructure from scratch unless the DEVOPS-008 baseline cannot support the application deployment. This ticket is about adding the application containers, configuring runtime values, verifying behavior, and documenting the public development environment.

Do not introduce private database networking here.

## Acceptance Criteria

The development environment should demonstrate that:

* the deployment can be applied from Terraform with the required runtime variables
* the frontend and backend application containers are deployed
* the frontend responds in Azure
* the backend is reachable through the configured development endpoint
* the database is part of the environment, not an implied external dependency
* the backend is configured to use the deployed database endpoint
* the frontend is configured to call the deployed backend endpoint
* the infrastructure choices are understandable to another DevOps engineer

This is a deployment task, not a feature rewrite task.

When this ticket is complete, the public development environment should be running and verified.