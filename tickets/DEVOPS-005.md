# DEVOPS-005 — Protect Merges with Automatic Validation

Engineering wants every pull request validated automatically before it can be merged, because reviewers should not have to guess whether a change is safe.

Your task is to design and implement a CI workflow that gives reviewers confidence that a proposed change is safe to merge.

## Requirements

* Application tests must run automatically for pull requests.
* Application/package builds must be validated.
* The workflow should validate that the frontend and backend container images from the runtime-packaging work can still be built.
* Failed validation must prevent the change from being considered merge-ready.
* Use the merge-protection approach from the Git/GitHub workflow work so failed validation blocks the pull request from being treated as merge-ready.
* No credentials or sensitive values may be committed to the repository.
* The workflow should fail clearly when a validation step fails.
* Validation should run automatically without requiring a developer to trigger it manually.

## Deliverable

Implement the CI workflow and create:

`docs/ci-design.md`

Document:

* workflow triggers
* validation stages
* what is tested or built
* what happens when a check fails
* how the workflow integrates with the pull request process
* how secrets or credentials are handled
* limitations or checks you would add before using this workflow for production

## Acceptance Criteria

For a pull request:

1. Validation starts automatically.
2. Application tests are executed.
3. Required application/container builds are verified.
4. A deliberately failing test or build causes the workflow to fail.
5. The failed validation prevents the change from being treated as merge-ready.
6. No real credentials are stored in the repository.