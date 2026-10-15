# DEVOPS-008 — Build the Reproducible Azure Dev Baseline

NovaCart now has an Azure target, and the team needs a repeatable way to create and review it instead of relying on portal clicks or hidden state.

Create the first Terraform-managed development baseline for NovaCart. This baseline should define the Azure platform resources, database, service endpoints, and outputs needed for a public development environment that later tickets can use to deploy the application.

This ticket is about making the required Azure resources reproducible from code. Deploying the actual NovaCart frontend and backend containers, proving browser/API behavior, and writing the deployment runbook are handled in future tickets.

## Deliverable

Create or update the Terraform under:

`infra/azure/`

Include:

* a clear entry point for the environment
* provider and version setup, pinned to `azurerm` `4.81.x`
* naming and tagging conventions
* reusable input variables
* shared Azure foundation resources, such as a resource group, logging, and the Container Apps environment
* a development PostgreSQL server and database
* public development configuration needed for the later app deployment
* useful outputs

Your Terraform should make the deployment shape understandable even if someone has never seen the repository before.

## Scope Boundary

You may apply Terraform to create the required Azure platform resources, but do not deploy the actual NovaCart frontend or backend application containers in this ticket.

Do not spend this ticket proving the app works in a browser or writing the deployment runbook.

Do not introduce private database networking here. This ticket should produce the public development baseline.

## Acceptance Criteria

A fresh clone should contain:

* a readable Terraform entry point
* reusable variables instead of hard-coded values
* outputs that help another engineer understand what was created
* platform and database resources represented in Terraform
* a plan that can be reviewed without needing manual portal history
* a structure that can be extended in later Week 2 tasks

The goal is a reproducible public-dev baseline, not a final production architecture. Future tickets will focus on applying, wiring runtime values, verifying the running app, and documenting the deployment.