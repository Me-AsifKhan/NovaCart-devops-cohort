# DEVOPS-017 — Know When a Release Has Gone Bad

NovaCart now deploys automatically and emits operational data.

The team wants to know when the system is drifting into trouble and how to respond safely when a release goes wrong.

## Deliverable

Create:

`docs/alerting-and-release-safety.md`

Document how the team should think about:

* alert thresholds
* alert noise
* meaningful operational signals
* release traceability
* rollback decisions
* deployment history
* what evidence should exist after a release

If you add automation or config, explain how it supports those operational goals.

## Acceptance Criteria

Your solution should demonstrate that:

* alerts are tied to real operational risk
* the team can tell what version is running
* rollback is possible in a controlled way
* deployment history can be reviewed
* the alerting approach is practical for a small DevOps team