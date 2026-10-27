# Automated Azure Infrastructure

## Objective

Run Terraform infrastructure validation and, after the required security and state-management prerequisites are configured, manage Azure development infrastructure through GitHub Actions rather than depending on a developer's laptop.

## Current Workflow

The `terraform-azure-infra.yml` workflow runs on pull requests targeting `main` when Terraform configuration, the workflow, or this document changes.

The current workflow:

1. Checks out the repository.
2. Sets up Terraform.
3. Checks Terraform formatting.
4. Initializes Terraform without configuring the remote backend.
5. Validates the Terraform configuration.

This is a validation-only workflow. It does not authenticate to Azure, create an infrastructure plan, or apply infrastructure changes.

## State Management

The Terraform configuration declares an AzureRM backend, but the CI workflow currently bypasses it using `terraform init -backend=false`.

Before CI can safely manage real infrastructure, a durable Azure Blob Storage backend must be provisioned and configured. State access must be restricted, and concurrent changes must be controlled through backend locking.

Terraform state can contain sensitive infrastructure information and must not be committed to Git.

## Authentication and Permissions

The future infrastructure workflow should use GitHub Actions OpenID Connect (OIDC) with an Azure federated identity credential rather than storing long-lived Azure credentials in source files.

Azure permissions should follow least privilege and be scoped to the resources the workflow needs to manage.

## Review and Apply Controls

Infrastructure changes must be reviewed before they are applied. A future workflow should generate a Terraform plan, make the proposed changes available for review, and require the configured approval controls before applying changes.

The apply workflow must not run until remote state, OIDC authentication, Azure permissions, and environment protection have been verified.

## Visibility and Operational Boundaries

GitHub Actions run logs provide visibility into validation and workflow failures. A future apply job can use a protected GitHub Environment to record deployment history and enforce approval controls.

This repository's current validation workflow does not prove that Azure infrastructure can be deployed successfully.

## Development and Production Assumptions

The intended development workflow is independent of a developer's local machine. It must use centrally managed state and secure authentication.

Production use would additionally require reviewed access policies, controlled state recovery, environment separation, tested rollback and recovery procedures, monitoring, and a documented operational ownership model.

## Current Status

Terraform formatting, initialization without the remote backend, and configuration validation have passed locally. GitHub Actions execution and live Azure infrastructure automation have not yet been verified.
