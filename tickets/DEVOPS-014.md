# DEVOPS-014 — Build, Publish, and Deploy from Merge to Azure

Engineering wants merged changes to reach the Azure development environment automatically.

Manual deployment is too slow and too easy to get wrong.

This ticket focuses on application delivery after the Azure infrastructure path exists. It should build the frontend and backend images, publish them to the registry, and deploy a specific, traceable image version to Azure development.

First-time Azure infrastructure provisioning belongs to DEVOPS-013. This ticket should build on the existing Azure development infrastructure.

## Deliverable

Create:

* `.github/workflows/`
* `docs/automated-azure-deployment.md`

Implement a GitHub Actions-based deployment flow that:

* builds frontend and backend container images
* publishes images to a registry
* deploys to the Azure development environment
* updates Azure DEV to run a specific image version
* makes failures visible
* can be verified after the run
* uses credentials provided securely outside source files

## Acceptance Criteria

Your solution should demonstrate that:

* a merged change can trigger delivery to Azure DEV
* the frontend image can be built and published
* the backend image can be built and published
* the deployment uses immutable or clearly versioned artifacts
* the deployed Azure DEV version can be traced back to the published image and source change
* credentials are provided securely outside source files
* the deployment result is visible from the workflow or the environment
* another engineer can understand how the pipeline fits together
* the work stays focused on image delivery and application deployment

The goal is a realistic development deploy path with clear boundaries for future production release work.