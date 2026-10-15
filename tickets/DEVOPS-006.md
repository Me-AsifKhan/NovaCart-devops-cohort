# DEVOPS-006 — Decide Whether Week 1 Is Safe to Hand Off

Management is preparing to move NovaCart into Azure and wants an engineering assessment before cloud infrastructure work begins.

Your task is to review what you built during Week 1 and decide whether NovaCart is ready to proceed to cloud infrastructure design. This decision is separate from deciding whether NovaCart is ready for public production traffic.

## Deliverable

Create:

`docs/WEEK-1-ENGINEERING-REVIEW.md`

Use evidence from the implemented Week 1 repository, executed validation, pull requests, and repository settings where applicable. Clearly label controls that are planned or recommended rather than implemented.

Document:

### Source Control

* How does your Git workflow operate?
* How is `main` protected?
* How are changes reviewed and validated?
* How would an emergency fix be handled?

### Runtime & Application

* How is the application packaged?
* How are frontend, backend, and PostgreSQL started?
* How do services discover and communicate with each other?
* How is runtime configuration supplied?
* Where does persistent data live?
* How are health and readiness verified?

### CI

* What happens when a pull request is created?
* What does CI validate?
* What happens when validation fails?
* Which checks are required before merge?
* What important checks are still missing?

### Production Readiness

Identify the **top five real risks** you would address before exposing NovaCart to real customers.

For each risk, document:

* Problem
* Potential impact
* Recommended improvement
* Priority: High / Medium / Low

Your risks must be based on the environment you actually built, not generic production recommendations.

### Recommendation

Finish with one of the following exact recommendations. “READY” means that cloud infrastructure design may begin; it does not mean that NovaCart is safe to expose to real customers.

**READY TO PROCEED TO CLOUD INFRASTRUCTURE DESIGN**

or

**NOT READY TO PROCEED TO CLOUD INFRASTRUCTURE DESIGN**

Explain and defend your decision with evidence from Week 1.

## Acceptance Criteria

Your assessment must reflect the environment you actually implemented during Week 1.

* Do not describe controls as implemented unless you can demonstrate them.
* Clearly separate what exists today from what is planned or recommended.
* Identify the most important remaining risks before production use.
* Your recommendation must be supported by evidence.

Another engineer should be able to read the review and understand:

* the current state of NovaCart
* which controls are already in place
* the major remaining risks
* whether cloud infrastructure work should begin
* what should happen next