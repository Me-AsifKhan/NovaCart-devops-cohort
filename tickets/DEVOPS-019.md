# DEVOPS-019 — Assess Growth Risk and Make Releases Safer

Management says NovaCart traffic is growing and the platform may soon serve significantly more users.

The team needs to know whether the current production design can handle growth safely, and whether new releases can be introduced without blindly replacing the last known-good version.

## Deliverables

Create:

- `docs/production-capacity-and-availability-review.md`
- `docs/safe-production-deployment.md`

Review the current platform and implement the changes needed to make growth behavior and production releases more intentional, visible, and reversible.

Document:

- single points of failure
- scaling behavior
- application resource limits
- database bottlenecks
- deployment risks
- how a new version reaches production
- how health is checked after deployment
- how traffic is shifted or controlled
- what happens if validation fails
- how the previous working version is restored
- how the running version can be traced later
- monitoring gaps
- recovery capability
- cost risks
- what changed in the platform and why

Your design should focus on outcomes rather than prescribing exact Azure settings. Reference concepts may include Container Apps revisions, controlled traffic shifting, blue/green-like behavior, rollback, post-deployment validation, and release traceability. Choose an approach appropriate to the platform's size.

## Acceptance Criteria

The solution should demonstrate that:

- current capacity and availability posture has been assessed
- at least one concrete platform improvement was implemented
- scaling behavior is understandable and intentional
- health checks support safe operation
- backend and database limits have been considered
- operational signals exist for the capacity or availability risk addressed
- the application remains compatible with stateless scaling, or the trade-off is justified
- a new version can be introduced without blindly replacing the old one
- the safer release approach is represented in platform/deployment configuration
- health checks influence release success
- rollback is practical and understandable
- the previous known-good version can be restored
- release validation leaves evidence for another engineer
- another engineer can explain the flow and chosen limits

Scaling choices must be justified. If validation fails, the deployment should leave the system in a clear and recoverable state.
