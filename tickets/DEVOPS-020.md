# DEVOPS-020 — Prove the Production Rollback Path

NovaCart can now deploy new versions, but the team needs confidence that a bad release can be reversed quickly and clearly.

This ticket is a final production-readiness exercise focused on rollback, traceability, and validation.

Do not add new application settings or feature changes for this ticket. The work is to prove and document how NovaCart restores a previous known-good version if a deployment causes problems.

## Deliverable

Create:

`docs/production-rollback-runbook.md`

Review the current deployment approach and document a practical rollback path for the frontend and backend Container Apps.

Document:

- how to identify the currently running image or revision
- how to identify the previous known-good image or revision
- how to validate the current release before deciding to roll back
- how to restore the backend to a previous known-good version
- how to restore the frontend to a previous known-good version
- how health is checked after rollback
- what evidence should be recorded after rollback
- what risks remain in the rollback process
- what should be improved before a larger production launch

Your rollback approach may use image tags, Container Apps revisions, or both. Choose the approach that matches your deployment implementation and explain the trade-off.

## Acceptance Criteria

Your solution should demonstrate that:

- the running frontend and backend versions can be identified
- the previous known-good version can be identified
- rollback steps are specific enough for another engineer to follow
- health checks are part of the rollback decision
- validation happens after rollback
- the rollback leaves clear evidence, such as image tags, revision names, timestamps, and validation results
- the work does not require application setting changes or feature changes
- remaining rollback risks are documented

The goal is not to create a perfect enterprise release system. The goal is to prove that NovaCart can recover from a bad deployment in a clear and repeatable way.
