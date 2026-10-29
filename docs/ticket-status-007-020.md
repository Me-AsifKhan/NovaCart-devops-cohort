# DEVOPS-007–020 status audit

**Audit date:** 2026-10-29  
**Repository:** [Me-AsifKhan/NovaCart-devops-cohort](https://github.com/Me-AsifKhan/NovaCart-devops-cohort)

This audit separates three states: code/documentation in Git, historical evidence from an earlier live deployment, and the current Azure environment. The Azure lab resources were intentionally deleted on 2026-10-29. Successful historical tests remain valid evidence for what worked then, but they do not mean the service is currently online.

## Ticket-by-ticket status

| Ticket | Evidence found in the public repository | Status and remaining work |
|---|---|---|
| **007 — Azure architecture** | `docs/azure-architecture.md` and ticket definition exist. | **Design delivered.** Refresh assumptions only if the target architecture changes. |
| **008 — Azure DEV baseline** | Terraform defines Resource Group, Log Analytics, ACR, managed identity, Container Apps environment, PostgreSQL, variables, and outputs. | **Configuration exists; cloud baseline is currently absent.** Historical resources were deleted to control cost. Review the plan/cost before any rebuild. |
| **009 — working Azure DEV** | `docs/azure-dev-deployment.md` records successful live verification on 2026-10-26, including frontend HTTP 200, health/readiness, products, runtime configuration, and a saved order. | **Historically live-tested; not currently deployed.** Endpoint URLs in the guide are historical. A fresh deployment requires resources, cost approval, and fresh verification. |
| **010 — Terraform maintainability** | `docs/terraform-reproducibility.md`, typed/validated inputs, outputs, separated `.tf` files, provider constraints, and lock file exist. | **Core ticket delivered; mentor structure not yet adopted.** Current files are one root module; child modules and separate dev/prd roots are absent. This is a future refactor, not a reason to claim the original work was not done. |
| **011 — private database path** | `infra/azure/network.tf` and private-mode variables/configuration plus `docs/private-database-connectivity.md` exist. Terraform validation ran in CI. | **Configured, not live-verified.** No evidence proves that PostgreSQL was deployed with public access disabled and the application remained healthy using private DNS/networking. |
| **012 — Week 2 review** | `docs/WEEK-2-ENGINEERING-REVIEW.md` exists and says not production-ready. | **Review delivered; refresh after future implementation.** Keep its conclusions aligned with the deleted runtime and current security/observability gaps. |
| **013 — infrastructure automation/OIDC** | OIDC/backend test succeeded on 2026-10-27; `.github/workflows/terraform-azure-plan.yml` and infrastructure validation workflow exist. | **Verified historically; currently blocked.** The backend Storage Account/resource group were deleted 2026-10-29. Recreate and secure a backend before using OIDC state access or the plan workflow. No apply workflow is implemented. |
| **014 — build, publish, deploy** | `.github/workflows/azure-dev-deploy.yml` and `docs/automated-azure-deployment.md` are in `main`. | **Workflow code delivered; live delivery not proven after teardown.** The workflow expects an existing DEV Resource Group, ACR, frontend/backend Container Apps, and deployment permissions. It does not provision them. |
| **015 — secrets and identity** | `docs/secret-and-identity-hardening.md`; OIDC and managed-identity patterns are documented/partly implemented. | **Partially complete.** Terraform still constructs the app database connection using the PostgreSQL administrator credential; Key Vault integration and a least-privilege application database role are not implemented/verified. |
| **016 — observability** | `docs/observability-foundation.md`; a local Prometheus/Grafana implementation and walkthrough are under PR #30, with CI passing for config/rules/Compose/dashboard and backend tests. | **Local implementation awaiting merge and laptop execution.** Azure acceptance remains pending: no live workspace/runtime, verified Azure log query, external alert delivery, or Azure dashboard exists after teardown. |
| **017 — release safety** | `docs/alerting-and-release-safety.md` documents thresholds, alert-noise controls, traceability, rollback decisions, and post-release evidence. | **Operating guide delivered; controls not live-proven.** No active alert rules or tested Azure Container Apps rollback are available while the environment is deleted. |
| **018 — engineering readiness** | The review is drafted in PR #31 as `ENGINEERING-READINESS-REVIEW.md`. | **Review drafted; merge/checks pending.** The evidence-based decision is NO-GO for a pilot while Azure is empty and security/monitoring/rollback gates remain unverified. |
| **019 — capacity and safe releases** | The supplied ticket definition, capacity review, safe deployment guide, Terraform scaling/probes/connection pooling, and health-gated revision workflow are in PR #32. Releases are manual-only, require explicit `RELEASE`, use a weighted backend canary and a labeled frontend candidate. | **Implementation in PR #32; latest CI must pass and live acceptance remains pending.** The code introduces bounded scaling and rollback-aware releases. Azure is deleted, so no live capacity, canary or rollback drill has run. |
| **020 — production rollback** | The ticket definition is included as `tickets/DEVOPS-020.md` with this update. `docs/production-rollback-runbook.md` was not found before this update. | **Definition added; implementation remains pending.** Write the runbook to match the current image-digest workflow. A live rollback drill cannot be honestly claimed until the runtime is rebuilt and the drill is executed. |

## Terraform structure compared with the mentor's recommendation

**The current configuration is not the same structure.**

Current state:

- One root module in `infra/azure/`.
- Resource files include `main.tf`, `network.tf`, and `apps.tf`, with shared `variables.tf`, `outputs.tf`, provider/version/backend files, and `terraform.tfvars.example`.
- There is no `modules/` directory and no separate `environments/dev` or `environments/prd` root.
- The Log Analytics workspace is in the current root `main.tf`; no separate monitoring module or Key Vault module exists.
- The existing backend definition targets an Azure Storage account that has now been deleted.

Mentor's suggested future layout is more modular: reusable child modules under `modules/`, with an environment root in each of `environments/dev` and `environments/prd` that composes those modules. Each module should expose inputs and outputs. Keep real `terraform.tfvars` files out of Git; commit non-secret examples instead.

The current flat root module is valid Terraform and was the design used for the existing ticket work. A modular refactor is a maintainability improvement. If you choose it, do so on a branch, keep state ownership explicit, run fmt/init/validate and review the plan, and do not apply while the Azure backend is absent. Resource addresses change when resources move into child modules; any future state migration must be deliberate.

## Recommended next sequence

1. **Reconcile documentation and ticket definitions** — merge this audit update; obtain the original DEVOPS-019 definition from the mentor.
2. **Restore local confidence with no Azure spend** — run the existing local Compose checks, backend tests, Terraform formatting, `terraform init -backend=false`, and `terraform validate`. This does not require Azure.
3. **Choose the Terraform structure before rebuilding Azure** — decide whether to adopt the module/environment layout now, before creating resources again. Keep the Dev and production state boundaries separate.
4. **Rebuild remote state only when approved** — bootstrap the Storage Account/container first, then update the backend configuration, verify OIDC/RBAC, and run a plan. State storage is a billable resource even when the app is stopped.
5. **Prioritize security and runtime evidence** — least-privilege app database user/secrets, private PostgreSQL, live deployment, centralized logs, real metrics, and a tested actionable alert.
6. **Finish DEVOPS-018 and DEVOPS-020** — create the readiness review and rollback runbook; perform a real rollback drill only after an environment is deliberately restored.
7. **Use budget controls** — do not run `terraform apply` or enable the deployment workflow until the plan, replacement/deletion actions, role assignments, and cost estimate have been reviewed.

## What not to claim

- Do not say Azure is currently live; it is intentionally deleted.
- Do not describe DEVOPS-011's private route as live-verified.
- Do not say a dashboard/alert exists because its design is in Markdown.
- Do not say the plan-only workflow deploys infrastructure.
- Do not fabricate DEVOPS-019 requirements.
