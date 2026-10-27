# Automated Azure Infrastructure

## Purpose

Validate Terraform changes in GitHub Actions and establish a secure, reviewable path for managing NovaCart's Azure development infrastructure without depending on a developer's laptop.

## Current Workflow

Three workflows have distinct responsibilities:

- `.github/workflows/ci.yml` runs the main verification suite, including Terraform validation, backend tests, frontend checks, and container image builds.
- `.github/workflows/terraform-azure-infra.yml` validates Terraform formatting and configuration on pull requests affecting the relevant infrastructure files. It initializes Terraform without configuring a backend and does not log in to Azure, create a plan, or apply changes.
- `.github/workflows/terraform-azure-oidc-test.yml` is manually triggered and verifies GitHub Actions authentication to Azure, blob-container access, and Terraform remote-backend initialization.

The OIDC backend test completed successfully on `main` on October 27, 2026. This verifies authentication and backend connectivity, not application infrastructure deployment.

## Remote State

The Azure remote-state bootstrap has been provisioned and verified.

- Resource group: `rg-novacart-tfstate`
- Region: `centralindia`
- Storage account: `stnovacarttf1027`
- Storage redundancy: Standard LRS
- Blob container: `tfstate`
- Terraform state key: `novacart-dev.tfstate`

Anonymous blob access and storage shared-key authorization are disabled. The container is accessed through Microsoft Entra authentication and Azure RBAC.

The storage account has not been verified as network-private, and no private endpoint has been confirmed. Do not describe this storage configuration as private-network-only.

GitHub Actions successfully initialized the AzureRM backend using OIDC. Successful initialization does not prove that a populated Terraform state snapshot already exists. The OIDC test does not run `terraform plan` or `terraform apply`.

Do not commit Terraform state files, backend credentials, or sensitive plan files to the repository.

## Authentication and Permissions

GitHub Actions authenticates to Azure using OpenID Connect (OIDC) and a Microsoft Entra federated identity credential rather than a long-lived client secret.

The GitHub Environment is named `azure-development`. Its federated subject is restricted to this repository and environment.

The GitHub Actions service principal has the `Storage Blob Data Contributor` role scoped to the `tfstate` blob container. It has not been granted this state-access role at subscription scope.

The manually triggered workflow verified:

1. Azure login through OIDC.
2. Azure identity and blob-container access.
3. Terraform initialization using the Azure remote-state backend.

**Deployment protection still needs attention.** The latest environment screenshot showed `No restriction` for deployment branches and tags. Change this to `Selected branches and tags`, add a `Branch` rule named `main`, and verify that the saved rule is displayed before relying on this environment for future infrastructure workflows.

Required reviewers have not been configured. The environment therefore does not currently enforce mandatory human approval.

## Plan, Review, and Apply

The existing infrastructure validation workflow remains validation-only. It checks Terraform formatting and configuration but does not authenticate to Azure, generate a plan, or apply infrastructure.

The OIDC backend test verifies authentication and backend initialization only. It does not create or modify application infrastructure.

The next step is to introduce a restricted Terraform plan workflow. Before running a plan, review:

- Terraform resources, required variables, and provider configuration.
- The selected remote state and whether a populated state snapshot exists.
- Expected resource additions, changes, and deletions.
- Azure permissions and estimated costs.

The earlier local state was archived rather than migrated. Treat the new remote state as potentially empty; do not assume it represents the previous application infrastructure.

Any future apply workflow must use a reviewed plan, restrict the execution branch and environment, and provide appropriate approval controls. Do not apply infrastructure until the proposed changes, permissions, and costs have been reviewed and explicitly approved.

## Visibility and Operational Boundaries

GitHub Actions provides run history and logs for the validation and OIDC test workflows. A future infrastructure deployment workflow should preserve traceability between the source revision, reviewed plan, approval, and applied changes.

Passing Terraform formatting and validation does not prove that Azure can create resources successfully. Live deployment, post-deployment verification, and tested recovery procedures remain future work.

## Development and Production

The intended development workflow should operate independently of a developer's machine and use centrally managed state and secure authentication.

Production use would require additional controls, including separated environments and permissions, state recovery testing, monitoring and alerting, tested rollback procedures, and clear operational ownership.

## Status and Next Steps

**Implemented and verified**

- Terraform formatting and configuration validation in GitHub Actions.
- Azure Storage remote-state bootstrap.
- GitHub Actions OIDC federation with Microsoft Entra.
- Container-scoped Azure RBAC for Terraform state access.
- Successful GitHub Actions verification of OIDC authentication, blob access, and Terraform backend initialization.

**Still pending**

- Restrict the `azure-development` environment to the `main` branch.
- Upgrade outdated JavaScript actions and validate the runner-image migration.
- Add a reviewed Terraform plan workflow.
- Establish explicit approval controls before infrastructure changes.
- Add a controlled apply workflow.
- Perform live infrastructure deployment and post-deployment verification.
- Test state recovery and document operational recovery procedures.

No application infrastructure was deployed by the OIDC backend test. Continue to estimate costs and review the complete plan before any deployment.

## Cost and Cleanup

The remote-state storage account continues to incur storage and transaction charges. The OIDC test does not deploy application compute resources.

When this setup is retired, review the GitHub federated credential, Entra app registration/service principal, container-scoped role assignment, GitHub workflows, and environment configuration. Delete the storage account and `rg-novacart-tfstate` only after safely preserving any Terraform state still required.
