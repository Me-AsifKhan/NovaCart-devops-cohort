# Automated Azure Infrastructure

## Purpose

Validate Terraform changes in GitHub Actions and prepare a secure, reviewable path for managing NovaCart's Azure development infrastructure without relying on a developer's laptop.

## Current Workflow

`.github/workflows/terraform-azure-infra.yml` runs on pull requests to `main` when changes affect `infra/azure/**`, this workflow, or this document.

It currently:

1. Checks out the repository.
2. Sets up Terraform.
3. Checks formatting with `terraform fmt -check -recursive`.
4. Initializes Terraform with `terraform init -backend=false -input=false`.
5. Validates the configuration with `terraform validate`.

This is a **validation-only** workflow. It does not sign in to Azure, generate a Terraform plan, or change infrastructure. The DEVOPS-013 pull request was merged, and its checks were reported as passing.

## Remote State

Terraform declares an AzureRM backend in `infra/azure/backend.tf`, but the current workflow deliberately disables backend initialization.

The Azure Storage account and blob container needed for remote state have not been verified or provisioned. Before CI uses the backend, the team must establish the storage, configure secure access, and verify state locking and recovery.

Terraform state can contain sensitive information. Do not commit state files, backend credentials, or sensitive plan files to the repository.

## Authentication and Permissions

The future workflow should authenticate to Azure using GitHub Actions OpenID Connect (OIDC) and a Microsoft Entra federated identity credential, rather than a long-lived client secret.

OIDC federation and the Azure RBAC permissions needed by GitHub Actions have not yet been configured or verified. A successful Azure CLI login on a developer's computer does not authenticate a GitHub-hosted runner.

Grant only the permissions required for each job. In particular, a planning job should not have permission to modify infrastructure where a read-only approach is practical.

## Plan, Review, and Apply

The current workflow does not create or apply a Terraform plan. Before infrastructure changes are allowed, the workflow must:

- Use the configured remote state and secure Azure authentication.
- Generate a plan for the reviewed source revision.
- Make the proposed additions, changes, and deletions available for review.
- Apply only the reviewed plan, with appropriate branch and environment restrictions.
- Stop if the source revision changes or the plan is no longer appropriate.

The `azure-development` GitHub Environment exists, but required reviewers have not been configured. Do not describe the current setup as enforcing mandatory human approval. Configure and verify the intended protections before enabling apply.

Do not deploy application infrastructure until the proposed changes, permissions, and estimated costs have been reviewed.

## Visibility and Operational Boundaries

The current validation workflow exposes its results and failures through GitHub Actions. A future apply job can use the `azure-development` environment to record deployment history; approval enforcement depends on the environment's actual protection settings.

Passing Terraform formatting and validation does not prove that Azure can create the resources successfully. A live deployment, post-deployment verification, and recovery procedure remain future work.

## Development and Production

The intended development workflow should run independently of a developer's machine and use centrally managed state and secure authentication.

Production use would require additional controls, including separated environments and permissions, state recovery testing, monitoring and alerting, tested rollback procedures, and clear operational ownership.

## Status and Next Steps

**Implemented**
- Terraform formatting, backend-independent initialization, and configuration validation.
- A pull-request workflow for the defined Terraform, workflow, and documentation paths.
- The DEVOPS-013 pull request was merged; its checks were reported as passing.

**Not yet implemented or verified**
- Azure Blob remote-state storage and backend access.
- GitHub Actions OIDC federation and least-privilege Azure RBAC.
- Terraform plan generation and review in GitHub Actions.
- A controlled apply workflow and live Azure infrastructure automation.
- Post-apply verification and tested recovery procedures.

**Next**
1. Estimate the cost of the minimum remote-state setup before provisioning anything.
2. Establish the backend and verify access and locking.
3. Configure and test GitHub OIDC and Azure permissions.
4. Add a restricted plan/apply workflow and test it safely.
5. Document verification, failure handling, and recovery.

Do not create or modify Azure infrastructure until the relevant plan, permissions, and costs have been reviewed and explicitly approved.
