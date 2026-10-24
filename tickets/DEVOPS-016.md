# DEVOPS-016 — See What the Platform Is Doing

Operations wants a basic observability foundation before the team tries to support real users at scale.

The current question is not “can we deploy?” but “can we see what the platform is doing when something goes wrong?”

## Deliverable

Create:

`docs/observability-foundation.md`

Implement the monitoring and telemetry foundation for NovaCart.

Document:

* where logs go
* what telemetry the application or platform emits
* what metrics matter for this workload
* how health is checked
* what signals would help during an incident
* what alert conditions are meaningful
* what would create alert noise

## Acceptance Criteria

Your solution should demonstrate that:

* logs are centralized
* the application or platform emits useful telemetry
* metrics can answer operational questions
* health can be checked without guessing
* at least one alert is meaningful and not just decorative
* another engineer could use the information during an incident