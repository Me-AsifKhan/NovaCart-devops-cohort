# Automated Azure Infrastructure — DEVOPS-013

## Current status — 2026-10-29

The Terraform configuration and GitHub Actions workflows remain in the public repository. The Azure remote-state backend was deliberately deleted on **2026-10-29** to stop ongoing charges. The post-deletion inventory returned no resource groups or resources in the selected subscription.

The OIDC backend workflow successfully authenticated to Azure, listed the Terraform-state blob, and initialized the AzureRM backend on **2026-10-27**, before the teardown. That historical test is valid evidence of the setup at that time; it does not mean the backend currently exists.

The old remote backend details were:

- Resource Group: `rg-novacart-tfstate`
- Region: `centralindia`
- Storage Account: `stnovacarttf1027`
- Blob container: `tfstate`
- State key: `novacart-dev.tfstate`

The 181-byte state blob was downloaded to a private local backup before deletion. Keep that file out of Git. It showed no managed resources when the user last ran `terraform state list`; a separate older archived local state may describe prior resources and must not be restored blindly.

## Workflow inventory

| Workflow | What it does | Current condition |
|---|---|---|
| `.github/workflows/ci.yml` | Pull-request tests, Terraform static checks, Compose validation, and container image builds | Does not require Azure resources for these validation steps |
| `.github/workflows/terraform-azure-infra.yml` | On relevant PRs, runs Terraform fmt/init without backend/validate | Static validation only; does not log in to Azure or provision infrastructure |
| `.github/workflows/terraform-azure-oidc-test.yml` | Manually logs in with OIDC, lists the state blob, initializes the remote backend | **Currently blocked:** the configured Storage Account/container were deleted |
| `.github/workflows/terraform-azure-plan.yml` | Manually logs in and generates a reviewable plan; there is no `terraform apply` | **Currently blocked:** remote backend no longer exists; do not run until it is re-created |
| `.github/workflows/azure-dev-deploy.yml` | Builds/pushes both images and updates existing DEV Container Apps by digest | **Currently blocked:** it expects a pre-existing DEV Resource Group, ACR, frontend and backend Container Apps, and deployment permissions. It does not create infrastructure. |

## Identity, environment and permissions

GitHub Actions uses OIDC with the `azure-development` GitHub Environment and the Microsoft Entra app registration/federated credential. This avoids storing a long-lived Azure client secret in the repository.

The environment's branch restriction was configured for `main`. Required reviewers were not configured, so the environment was not an enforced human-approval gate.

Before teardown, the GitHub service principal had `Storage Blob Data Contributor` scoped to the `tfstate` blob container. That scope belonged to the deleted backend. Re-create and verify the appropriate scoped role assignment when a new state backend is bootstrapped. Do not grant subscription-wide `Owner` or `Contributor` just to make the plan work.

## How to resume safely

Do not start with the existing plan workflow; it hard-codes the deleted backend's resource names. If/when Azure usage is approved:

1. Estimate the monthly and per-run cost. State storage has a small ongoing charge, and the app/registry/database can cost substantially more.
2. Bootstrap the state Storage Account and container through a separately controlled process. Do not attempt to manage the first state account solely from a root module that already requires that backend.
3. Configure OIDC, check the exact issuer/audience/subject, and grant the GitHub identity blob access at the state container. For infrastructure planning, evaluate a separate read-only Azure resource role; state access alone is not resource-read access.
4. Update the backend arguments in both `terraform-azure-oidc-test.yml` and `terraform-azure-plan.yml` if the new resource names differ. Keep state keys separated by environment.
5. Run the OIDC backend test first and verify Azure identity, blob access, backend initialization, and locking.
6. Run the plan workflow only after required environment variables/secrets and read permissions are ready. Review every resource addition, replacement, deletion, role assignment, network change, and estimated cost.
7. Do not add an apply workflow until a reviewed-plan workflow, restricted environment, appropriate permissions, an approval mechanism, and recovery procedures have been designed and tested.

## Secrets and variables

The Terraform plan workflow expects these GitHub Environment variables:

- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`
- `NOVACART_ACR_NAME`
- `NOVACART_POSTGRES_SERVER_NAME`

It also expects `NOVACART_DB_ADMIN_PASSWORD` as a protected environment secret for Terraform planning. Keep real values out of YAML, Git, terminal logs, issues, and PR comments. Do not paste the password into chat.

## Current acceptance state

**Implemented and verified historically:** Azure OIDC login, state-container access, and Terraform backend initialization (2026-10-27); Terraform format/configuration validation in PR CI; manual plan-only workflow code.

**Not currently operational:** remote state/backend connectivity, live infrastructure planning against that backend, application deployment, live telemetry, and rollback. These need the relevant Azure resources re-created and the full process re-verified.

## Cost and cleanup

Current Azure inventory showed no resources in the target subscription after cleanup. Cost Analysis may still show previously incurred charges because billing data can lag. If you rebuild, record resource names and owners, use tags, estimate costs first, and delete only resources explicitly approved for cleanup after preserving the required Terraform state and data.
