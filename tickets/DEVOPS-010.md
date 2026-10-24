# DEVOPS-010 — Make Terraform Safer to Maintain

The Week 2 environment exists, but the team wants it organized so it can be maintained by someone other than the original author.

Your job is to improve the Terraform so it is easier to review, safer to change, and more reproducible across environments.

Start from the working public development environment produced by DEVOPS-008 and DEVOPS-009. This ticket should improve structure, inputs, outputs, validation, and documentation without changing the application architecture for its own sake.

DEVOPS-009 already documents the deployed Azure development environment: the application containers, service endpoints, connectivity, and deployment verification. Do not repeat that deployment walkthrough here. DEVOPS-010 should document how the Terraform itself is organized, configured, reviewed, validated, and safely reused.

## Deliverable

Create or update:

* Terraform under `infra/azure/`
* `docs/terraform-reproducibility.md`

Document:

* how the Terraform is organized
* which values are environment-specific
* which values should remain stable across runs
* how validation should be performed before apply
* any conventions another engineer should follow when extending the code
* where to find the DEVOPS-009 deployment documentation when someone needs the environment-level explanation

## Scope Boundary

Do not add new Azure architecture just to make the Terraform look more advanced. This ticket is about maintainability, reviewability, inputs, outputs, and validation.

Do not duplicate `docs/azure-dev-deployment.md`. Reference it only when the reader needs deployment context.

## Acceptance Criteria

The result should make it clear:

* what is hard-coded and what is not
* what needs to be provided per environment
* how to format and plan the Terraform consistently
* what someone should check before applying changes
* how a teammate would confidently use the code without guessing
* how this document differs from the DEVOPS-009 deployment documentation

If the code can be read but not safely reused, the task is not done.