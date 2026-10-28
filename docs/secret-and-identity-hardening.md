# Secret and Identity Hardening — DEVOPS-015

## Status and scope

This document records the current security controls in the repository and the changes required before a live Azure deployment can be treated as hardened. It is not evidence that the deleted NovaCart runtime resources are currently deployed. At the last subscription inventory, only the Terraform-state Storage Account remained.

## 1. Credential and secret inventory

| Item | Where it belongs | Current position / risk |
|---|---|---|
| Azure subscription, tenant and app client IDs | GitHub Environment variables for `azure-development` | Identifiers, not secrets. Current workflow uses `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, and `AZURE_SUBSCRIPTION_ID`. |
| GitHub-to-Azure authentication | GitHub OIDC plus Microsoft Entra federated credential | Implemented and tested for the state-container workflow. No client secret is stored in the repository. |
| Terraform state access | Azure RBAC on the `tfstate` container | The GitHub service principal has `Storage Blob Data Contributor` scoped to the container only. This does not grant permission to provision subscription resources. |
| PostgreSQL administrator password | Local shell environment or protected CI secret, supplied as `TF_VAR_db_admin_password` only when needed | Sensitive Terraform input. It must not be committed in `terraform.tfvars`, command history, CI logs, or image build arguments. Terraform state and saved plans can contain sensitive values. |
| Runtime database credential / `DATABASE_URL` | A runtime secret store or managed secret reference | Current Terraform code constructs the Container Apps secret from the PostgreSQL administrator credentials. This means the app uses an administrator-level credential and Terraform state can contain the connection string. This should be replaced before any production pilot. |
| Local Compose database password | Local-only `novacart/.env` ignored by Git | `novacart/.env.example` uses a demo default for local development only. Never reuse it in Azure or production. |
| Container Registry credentials | No ACR admin credential | Terraform disables ACR admin access. The Container Apps user-assigned managed identity is assigned `AcrPull` in the Terraform design. |
| Application keys / external API tokens | No such live external integration is currently evidenced in this repository | If introduced, inventory each key, owner, scope, storage location, rotation method, and expiry before use. |

## 2. Identity model

| Identity | Intended use | Required scope |
|---|---|---|
| Developer's Entra user | Local bootstrap and approved manual administration | Only the roles needed for the particular task; avoid using a human user in unattended workflows. |
| GitHub Actions Entra service principal | Terraform state backend authentication now; future CI roles must be added deliberately | Currently state-container access only. For read-only plan, grant an appropriate read role separately after review. Apply permissions must be limited to the intended resource group where possible. |
| Container Apps user-assigned managed identity | Pull frontend/backend images from ACR at runtime | `AcrPull` on the registry only. Do not grant subscription Contributor. |
| PostgreSQL application user (target state) | Backend CRUD on NovaCart application tables | A dedicated non-owner, non-administrator database role limited to the required database/schema. The current code does not provision or verify this separation. |

Never reuse the GitHub workflow identity as the application runtime identity. OIDC authenticates deployment automation; the user-assigned managed identity authenticates the runtime's registry pull.

## 3. Current controls and gaps

### Implemented in code or verified

- GitHub Actions uses OIDC to exchange a workflow identity for an Azure token; the OIDC backend test passed on `main`.
- GitHub Environment identifiers are stored as variables rather than embedded credentials.
- The Azure Storage backend disables anonymous blob access and storage shared-key authorization; blob access is via Entra ID and scoped Azure RBAC.
- ACR admin access is disabled in Terraform.
- Terraform defines a user-assigned managed identity with an `AcrPull` assignment for Container Apps.
- `DATABASE_URL` is provided to the backend as a Container Apps secret reference rather than as a plain environment variable in the container definition.

### Required before a controlled pilot

- Replace use of the PostgreSQL administrator account in the application with a dedicated least-privilege application database role.
- Decide and implement the secret source for the runtime connection credential (prefer a controlled Key Vault / managed-identity integration where justified); document whether Terraform or the application owns each secret lifecycle.
- Protect Terraform state and plan artifacts because `sensitive = true` suppresses display but does not remove secret values from state.
- Keep plan and apply permissions separate. The current workflow identity's container-scoped permission is intentionally insufficient to create or modify Azure resources.
- Verify the `azure-development` GitHub Environment is restricted to `main`; do not treat the absence of required reviewers as an approval gate.
- Review repository history and rotate any credential if a real secret was ever committed. Do not paste real values into issues or PRs.

## 4. Secret delivery and rotation

1. Create a dedicated PostgreSQL application role with only the permissions needed for the NovaCart schema.
2. Generate a unique strong credential outside source control. Store it in the approved secret store and expose it to the runtime only through a secret reference or protected deployment mechanism.
3. Configure the Container App to read the secret without baking it into the image or a Docker build argument.
4. Roll the credential: create/enable the replacement credential, update the secret version/reference, restart or deploy a new Container Apps revision, and verify `/ready` plus a representative database operation.
5. Revoke the old credential only after the new revision is confirmed healthy.
6. Record who rotated it, when, which secret version was used, and the verification outcome—never the value itself.

Rotation must not require editing application source code or committing configuration changes containing the secret.

## 5. Validation and operational controls

- Scan repository changes for secrets before merge.
- Keep real `.env`, `terraform.tfvars`, state files, crash logs, and saved plans out of Git.
- Run Terraform formatting and validation in pull requests.
- Use OIDC instead of long-lived client secrets for unattended GitHub Actions.
- Test that the runtime identity can pull images but cannot perform unrelated Azure resource management.
- Test database authorization with the app role; verify that it cannot administer the server or create unrelated roles.
- On suspected exposure, disable/revoke the credential, rotate dependent secrets, inspect access logs, and document the incident.

## Readiness statement

The platform has a working OIDC path for Terraform state and a managed-identity pattern for ACR pulls in Terraform code. Secret hardening is not complete: the current Terraform design passes the PostgreSQL administrator credential into the application connection string, no Key Vault integration is configured, and the Azure application runtime is not currently deployed. Do not claim the live workload satisfies the full DEVOPS-015 acceptance criteria until the app database identity and secret lifecycle are implemented and verified.
