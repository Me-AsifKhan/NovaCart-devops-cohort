# DEVOPS-003 — Make Runtime Behavior Repeatable

QA reports that NovaCart behaves differently across developer laptops and test environments, and the team needs one repeatable way to run the application.

Your task is to **package the frontend and backend as Docker container images** so runtime behavior is consistent across machines without depending on host-installed application runtimes or dependencies.

## Requirements

* Frontend and backend must be packaged as Docker container images.
* Frontend and backend containers must be built and run separately using Docker.
* The expected runtime proof for this ticket is two separately started application containers: one frontend container and one backend container.
* A separate database container is not required for this ticket; if the backend uses the local SQLite fallback, document where the SQLite file lives and whether data survives container removal.
* The host machine should not require Python, Nginx, or application-specific dependencies.
* If the frontend needs a webserver such as Nginx to serve the built application, that webserver must run inside the frontend image rather than being installed on the host.
* Runtime configuration must not be hard-coded into the container images.
* Application source code should not require environment-specific edits.
* Dependencies should be installed in a repeatable way during the image build.
* Container images should expose only the ports/interfaces required by the application at runtime.
* Build-time and runtime responsibilities should be clearly separated where appropriate.
* Each application component should be independently buildable and runnable.

## Deliverable

Implement the Docker-based runtime packaging and create:

`docs/runtime-packaging.md`

Document:

* Your Docker packaging approach
* How frontend and backend dependencies are handled
* How the frontend is served at runtime, including any webserver such as Nginx
* How runtime configuration is supplied
* What database mode is used when running the backend container separately
* Which ports/interfaces are exposed
* How each container image is built
* How each application component is started separately as its own container
* What assumptions the runtime environment must satisfy
* Trade-offs or limitations in your approach

## Acceptance Criteria

Another engineer with **Docker installed** should be able to clone the repository, build the frontend and backend container images, and run each component without installing Python, Nginx, or application-specific dependencies directly on the host.

The implementation should demonstrate that:

1. The frontend can be built and run separately as a Docker container.
2. The backend can be built and run separately as a Docker container.
3. Application dependencies are contained within the images rather than installed on the host.
4. Any frontend webserver dependency is contained inside the frontend image and does not need to be installed on the host.
5. Runtime configuration can be supplied without rebuilding or modifying application source code for each environment.
6. The containers expose only the runtime interfaces required by the application.
7. Rebuilding the same application version produces a predictable runtime environment.
