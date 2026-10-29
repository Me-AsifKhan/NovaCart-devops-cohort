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

Focus on outcomes rather than prescribing exact Azure settings. Reference concepts may include Container Apps revisions, controlled traffic shifting, blue/green-like behavior, rollback, post-deployment validation, and release traceability. Choose an approach that improves safety while staying appropriate for the size of the platform.

## Acceptance Criteria

- [ ] Current capacity and availability posture assessed.
- [ ] At least one concrete platform improvement implemented.
- [ ] Scaling behavior is understandable and intentional.
- [ ] Health checks support safe operation.
- [ ] Backend and database limits considered.
- [ ] Operational signals exist for the capacity/availability risk addressed.
- [ ] Stateless scaling is supported, or the trade-off is justified.
- [ ] A new version can be introduced without blindly replacing the old one.
- [ ] Safer release behavior is represented in platform/deployment configuration.
- [ ] Health checks influence release success.
- [ ] Rollback is practical and understandable.
- [ ] The previous known-good version can be restored.
- [ ] Release validation leaves clear evidence.
- [ ] Another engineer can explain the flow and reasoning behind limits/trade-offs.

Justify scaling choices. If validation fails, leave the deployment in a clear and recoverable state.

## Validation boundary

The implementation must not claim a live capacity or rollback test until the Azure environment has been rebuilt and the release/rollback drill has been performed. The Azure lab was intentionally deleted on 2026-10-29 to control cost.
