# DEVOPS-012 — Decide What Week 2 Is Ready For

Leadership wants a final Week 2 review before the project moves on.

Your job is to evaluate the Azure environment you built and clearly separate what is ready for development use from what is still missing for production.

This review should cover the final Week 2 state after the public development deployment, Terraform maintainability pass, private database connectivity change, and any incident remediation.

## Deliverable

Create:

`WEEK-2-ENGINEERING-REVIEW.md`

Document:

* what is currently working
* what the environment is ready for
* what it is not ready for yet
* the strongest parts of the design
* the remaining risks
* the controls you would still want before production
* any assumptions you made during review

## Acceptance Criteria

A reader should be able to tell from your review alone:

* what is safe to use for the current Week 2 goal
* what is still missing for production
* where the biggest risks remain
* why the environment should or should not move forward

Do not call the environment production ready unless you can justify that claim with controls and evidence.