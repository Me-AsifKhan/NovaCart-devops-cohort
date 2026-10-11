
# DEVOPS-005 — Protect Merges with Automatic Validation

## 1. Purpose

NovaCart uses GitHub Actions to validate proposed changes before they
are merged into `main`. The workflow gives reviewers automated evidence
that application tests pass and both container images can be built.

## 2. Workflow triggers

The workflow is defined in `.github/workflows/ci.yml`.

It runs automatically when a pull request targets `main`. Developers
do not need to trigger the workflow manually.

## 3. Validation stages

The `NovaCart Verification Suite` job performs these checks in order:

1. **Checkout:** Retrieves the repository using `actions/checkout`.
   Persisting the checkout token in Git configuration is disabled.
2. **Frontend structure:** Verifies that `index.html`, `app.js`, and
   `styles.css` exist.
3. **Python setup:** Configures Python 3.11.
4. **Dependency installation:** Installs backend requirements when
   `requirements.txt` exists, plus `pytest` and `httpx`.
5. **Application tests:** Runs `python -m pytest -v` in
   `novacart/backend`.
6. **Backend image build:** Builds the image from
   `novacart/backend/Dockerfile`.
7. **Frontend image build:** Builds the image from
   `novacart/frontend/Dockerfile`.

These image builds validate that the respective Docker build contexts
and Dockerfiles can produce images. They do not publish images to a
registry or deploy the application.

## 4. Failure behavior

GitHub Actions stops the job when a command fails. For example:

- Missing frontend assets fail the structural check.
- Failed tests cause the test step and job to fail.
- An invalid Dockerfile or failed image build causes that build step
  and job to fail.

A failed run is reported against the pull request. The required
`NovaCart Verification Suite` status check must pass before the PR
can be merged under the configured branch protection rules.

## 5. Pull request integration

The workflow uses the job name `NovaCart Verification Suite`, matching
the status check configured for `main`.

The intended workflow is:

1. Create a feature branch.
2. Commit and push the changes.
3. Open a pull request targeting `main`.
4. Wait for the required CI check to finish.
5. Review the changes and resolve conversations.
6. Merge only when required checks and review rules are satisfied.

Repository branch protection must remain enabled. If the required
status check is not configured or enforced, a workflow alone does not
guarantee that failed changes are blocked from merging.

## 6. Secrets and credentials

The workflow does not require cloud credentials, production secrets,
or registry credentials because it only tests code and builds images.

- Do not commit `.env` files containing real secrets.
- Keep real credentials in an approved secret manager or GitHub
  Actions secrets when a future workflow genuinely requires them.
- Use least-privilege permissions.
- The workflow grants only `contents: read`.
- Checkout credential persistence is disabled.

## 7. Limitations and production improvements

This workflow is an initial CI validation gate, not complete production
assurance.

Recommended improvements before production use:

- Pin third-party GitHub Actions to reviewed full commit SHAs.
- Add dependency and vulnerability scanning for application packages
  and container images.
- Add linting, formatting, type checking, and coverage thresholds.
- Add integration tests using a temporary PostgreSQL service.
- Verify application behavior using container-based smoke tests.
- Add secret scanning and infrastructure-as-code security checks.
- Use a supported Node.js runtime for JavaScript-based actions and
  monitor GitHub Actions runner deprecation notices.
- Add image tagging, registry publishing, provenance, and deployment
  controls only when those capabilities are required.
- Periodically verify that branch protection still requires the
  intended status check.

## 8. Validation evidence

The pull request should show a successful `NovaCart Verification Suite`
run, including application tests and both Docker image builds.

A deliberately failing test or Docker build should make the workflow
fail. The negative test should be performed on a temporary change and
reverted before merging.

Record the actual workflow run and repository protection settings
when submitting this ticket. Do not report checks as enforced unless
the repository settings confirm it.
