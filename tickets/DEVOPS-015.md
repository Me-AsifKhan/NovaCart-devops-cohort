# DEVOPS-015 — Remove Credential Risk from the Platform

Security review found that NovaCart’s Azure setup still has room for improvement around secrets and identity handling.

The team wants to reduce long-lived credentials, improve least-privilege access, and keep secrets out of source control.

## Deliverable

Create:

`docs/secret-and-identity-hardening.md`

Implement the hardening changes needed to support the Azure environment safely.

Document:

* what secrets exist
* where they are stored
* how the application receives them
* how deployment authentication works
* which identities are used by which components
* how access is limited to what the app actually needs
* how secret rotation would happen without source-code changes

## Acceptance Criteria

Your solution should demonstrate that:

* application secrets are not committed to the repository
* long-lived credentials are avoided where practical
* Azure workload access uses a managed identity or equivalent secure approach
* deployment authentication is not a hard-coded password in the repo
* permissions follow least privilege
* the design is understandable to another DevOps engineer

If a secret still has to be handled manually, explain why and how risk is reduced.