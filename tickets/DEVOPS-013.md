# DEVOPS-013 — Automate Azure Infrastructure from GitHub Actions

NovaCart has an Azure development architecture, but the team still needs a reliable way to create and update the Azure infrastructure without relying on a developer laptop.

This ticket focuses on infrastructure automation only: running the Azure infrastructure workflow from GitHub Actions, making the result visible, and keeping credentials out of source files.

Image build, image publishing, and application version rollout are handled by the image delivery and deployment ticket.

## Deliverable

Create:

* `.github/workflows/`
* `docs/automated-azure-infrastructure.md`

Implement the GitHub Actions-based infrastructure automation approach you think is appropriate for NovaCart.

Document:

* what infrastructure the pipeline manages
* when the infrastructure workflow should run
* how infrastructure changes are reviewed before they are applied
* how Terraform state is stored and protected when infrastructure runs from CI
* how the pipeline authenticates without hard-coded long-lived credentials
* where workflow results and failures are visible
* what assumptions the pipeline makes about the Azure development environment
* what would be risky to rely on in production

## Acceptance Criteria

Your solution should demonstrate that:

* Azure development infrastructure can be created or updated from GitHub Actions
* infrastructure changes can be reviewed before apply
* Terraform state has a durable location suitable for CI-based infrastructure changes
* the workflow result is visible to another engineer
* credentials are provided securely outside source files
* the infrastructure workflow can run independently of a developer laptop
* another engineer can understand what the pipeline manages and when it should run
* the work stays focused on infrastructure automation

The goal is a realistic development infrastructure path with clear boundaries for future production hardening.