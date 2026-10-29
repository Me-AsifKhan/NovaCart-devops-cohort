# Week 2 Engineering Review — NovaCart

**Decision: ready for local development and controlled demos; not production-ready.**

## What is working

- The frontend, FastAPI backend, PostgreSQL integration, container builds, and pull-request CI have been implemented in the repository.
- The public Azure development deployment was previously live-tested. The recorded checks covered the frontend, health/readiness, products, runtime configuration, and saved orders.
- DEVOPS-010 Terraform formatting and validation checks passed.
- DEVOPS-011 private-network Terraform and documentation are merged, and CI passed.

## Current environment status

The Azure lab resource group was deliberately deleted to stop ongoing resource usage. The subscription inventory subsequently showed no remaining Azure resource groups or resources. The previously recorded Azure URL is historical and is not an active deployment.

DEVOPS-011 is **not fully verified**: the private PostgreSQL design is in code, but the private path was not deployed and tested live before the lab was deleted. Do not claim the database was proven private or that the application was verified after public access was disabled.

A PostgreSQL custom-format dump was created and copied to the PC. Treat it as an unverified backup until its `PGDMP` header, local `pg_restore --list`, and SHA-256 match against the Cloud Shell source have been confirmed.

## Main risks and remaining controls

- Recreate the private networking path only when cloud spend is approved; inspect all Terraform replacements before applying.
- Verify PostgreSQL public access is disabled, private DNS resolves correctly, `/api/ready` succeeds, and a new order persists.
- Recreate the protected remote Terraform state backend, then re-verify OIDC and scoped RBAC before CI manages shared infrastructure. The OIDC backend test passed historically, but the backend Storage Account/container were deleted on 2026-10-29.
- Keep secrets out of source control and saved plan files out of Git.
- Add and verify alerting/observability controls before any production claim.

## Recommendation

Proceed with local validation and DEVOPS-013 workflow preparation. For live DEVOPS-011 acceptance, redeploy the required infrastructure, run the documented security and application checks, record evidence, and clean up temporary resources after verification. The current repository is suitable for continued development, but the Azure private-network acceptance criteria remain pending.