# NovaCart Git Strategy

## 1. Chosen Workflow: GitHub Flow
We use **GitHub Flow** with short-lived feature branches targeting a stable `main` branch.
* **Why it fits:** With 5 developers, heavy frameworks like GitFlow introduce massive merge conflicts and delay releases. GitHub Flow keeps work unblocked and lightweight.

## 2. How Developers Contribute Changes
Developers isolate their work and follow a strict, fast sequence:
1. Sync local code: `git checkout main && git pull origin main`
2. Spin up a short-lived branch: `git checkout -b feature/DEVOPS-XXX-description`
3. Commit cleanly and test changes locally.
4. Push remote branch: `git push origin feature/DEVOPS-XXX-description`
5. Open a Pull Request (PR) targeting `main` to trigger automated checks.
6. Delete local and remote feature branches immediately after merging.

## 3. How Production Code is Protected (Security Rulesets)
The `main` branch represents stable production code. We enforce security configurations on it using modern GitHub Repository Rulesets:
* **No Direct Pushes:** Direct pushes to `main` are fully blocked for everyone (including admins). All code must go through a PR.
* **Mandatory Peer Reviews:** Every PR requires at least **1 positive approval** from another teammate. Authors cannot approve their own PRs.
* **Status Check Gates:** The merge button stays completely locked until our automated `.github/workflows/ci.yml` pipeline (`NovaCart Verification Suite`) passes cleanly.

## 4. How Emergency Fixes are Handled (The Hotfix Path)
When a critical bug breaches validation and breaks production, we run an accelerated loop:
1. Pull the live baseline directly: `git checkout main && git pull origin main`
2. Create an express track branch: `git checkout -b hotfix/critical-patch-description`
3. Fix only the specific bug. Do not combine features or formatting cleanups here.
4. Open an immediate PR, run CI checks, and ping the team on Slack for priority review.
5. Merge immediately once approved and delete the temporary branch.

## 5. Workflow Trade-offs
* **Advantages:** Fast iteration cycles, zero branch management friction, clear linear commit history via **Squash and Merge**, and absolute team peer review accountability.
* **Risks & Mitigation:** Open PRs can bottleneck features if team members ignore reviews. *Mitigation:* The team dedicates the first 15 minutes of every daily standup to clear the active PR queue.

## 6. Developer Rules & Hygiene
* **No Secrets:** Never track credentials, environment secrets, or database binaries (`novacart.db`) in Git. Use externalized environment variables (`.env`).
* **Branch Lifespan:** Feature branches should live no longer than 48 hours to minimize merge conflicts.
* **Sync Daily:** Rebase or pull updates from `main` into your feature track daily to catch integration issues early.
