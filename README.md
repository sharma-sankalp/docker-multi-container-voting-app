# Example Voting App — Docker Security Hardening

A simple distributed voting application running across multiple Docker containers.

This repository is based on the Docker Example Voting App and has been extended as a practical **Docker security and production-hardening project**.

The application uses Python, Node.js, .NET, Redis, and PostgreSQL to demonstrate a multi-container application architecture and how it can be hardened using Docker security controls.

---

## Getting Started

### Prerequisites

Install:

* Docker
* Docker Compose

Docker Desktop includes Docker Compose. On Linux, install a recent version of Docker Engine and the Docker Compose plugin.

### Run the development environment

The default Compose configuration is intended for local development:

```bash
docker compose up --build
```

The applications will be available at:

* Vote: http://localhost:8080
* Result: http://localhost:8081

Stop the application with:

```bash
docker compose down
```

---

# Architecture

```text
                         ┌───────────────┐
                         │    Browser    │
                         └───────┬───────┘
                                 │
                    ┌────────────┴────────────┐
                    │                         │
              :8080 │                         │ :8081
                    ▼                         ▼
              ┌───────────┐             ┌───────────┐
              │   Vote    │             │  Result   │
              │  Python   │             │  Node.js  │
              └─────┬─────┘             └─────┬─────┘
                    │                         │
                    ▼                         ▼
              ┌───────────┐             ┌───────────┐
              │   Redis   │             │ PostgreSQL│
              │           │             │           │
              └─────┬─────┘             └─────▲─────┘
                    │                         │
                    └──────────┐   ┌──────────┘
                               ▼   ▼
                         ┌───────────────┐
                         │    Worker     │
                         │    .NET 10    │
                         └───────────────┘
```

### Services

| Service  | Technology     | Purpose                                       |
| -------- | -------------- | --------------------------------------------- |
| `vote`   | Python / Flask | Accepts votes from users                      |
| `redis`  | Redis          | Queues votes for processing                   |
| `worker` | .NET 10        | Processes votes and stores them in PostgreSQL |
| `db`     | PostgreSQL     | Persistent vote storage                       |
| `result` | Node.js        | Displays voting results in real time          |
| `seed`   | Bash           | Generates sample votes                        |

### Network Architecture

The application uses two Docker networks:

* `front-tier` — Vote and Result
* `back-tier` — Redis, Worker, PostgreSQL, and application services

Only the Vote and Result services publish ports to the host.

Redis and PostgreSQL are not directly exposed to the host.

---

# Development vs Production

Two Compose configurations are provided.

### Development

```text
docker-compose.yml
```

The development configuration is designed for local development and iteration, including source bind mounts and development tooling where required.

Start it with:

```bash
docker compose up --build
```

### Production / Hardened

```text
docker-compose.prod.yml
```

The production configuration removes development-only behaviour and enables the security controls implemented in this project.

Start it with:

```bash
docker compose -f docker-compose.prod.yml up -d --build
```

---

# Docker Security & Hardening

The main objective of this project is to demonstrate practical Docker hardening techniques that can be applied to a multi-container application before moving it towards production.

## 1. Non-root containers

Application containers run as non-root users wherever possible.

Implemented for:

* Vote
* Result
* Worker
* Redis
* Seed where applicable

For example, the Vote image creates a dedicated user:

```dockerfile
RUN groupadd --system vote && \
    useradd --system --gid vote --home-dir /nonexistent \
    --shell /usr/sbin/nologin vote
```

and runs the application with:

```dockerfile
USER vote
```

The Worker uses a dedicated numeric non-root runtime user.

The Result production image uses the Distroless non-root image.

---

## 2. Minimal and hardened images

Base images were selected to reduce unnecessary packages and attack surface.

Examples include:

* Python Slim
* Alpine-based Redis
* Alpine-based PostgreSQL
* .NET runtime images
* Distroless Node.js for the Result production image

The Result production image uses:

```text
gcr.io/distroless/nodejs24-debian13:nonroot
```

The production Result container therefore does not contain a shell or unnecessary development utilities.

---

## 3. Multi-stage builds

Multi-stage Docker builds are used where they provide a clear separation between build and runtime environments.

The Result image separates:

```text
base
dev
dependencies
final
```

The Worker image separates the .NET SDK build environment from the runtime environment.

This keeps build tools and development dependencies out of production images.

---

## 4. Unnecessary packages removed

Unnecessary operating-system packages were removed from application images.

For example, `curl` was removed from the Vote runtime image because the application itself does not require it.

Health checks use functionality already available in the application runtime rather than installing additional utilities solely for health checking.

This reduces both image size and attack surface.

---

## 5. `.dockerignore`

`.dockerignore` files were added to the application build contexts.

They exclude unnecessary or sensitive content such as:

```text
.git
.env
secrets
node_modules
logs
coverage
IDE configuration
temporary files
build artifacts
```

This reduces Docker build context size and helps prevent accidental inclusion of sensitive files.

---

## 6. Docker Compose secrets

Database credentials are handled using Docker Compose secrets rather than hard-coded passwords.

The production configuration uses:

```yaml
secrets:
  db_password:
    file: ./secrets/db_password.txt
```

The secret is mounted inside the relevant containers at:

```text
/run/secrets/db_password
```

The following services consume the database password from the secret:

* PostgreSQL
* Worker
* Result

The real password file is excluded from Git.

Create the local secret from the example:

```bash
mkdir -p secrets
cp secrets/db_password.txt.example secrets/db_password.txt
```

**Never commit `secrets/db_password.txt`.**

---

## 7. Read-only root filesystems

Production containers use:

```yaml
read_only: true
```

This prevents applications from modifying the container's root filesystem.

Where temporary writes are required, a temporary filesystem is provided:

```yaml
tmpfs:
  - /tmp
```

This is enabled for the application and transient services where appropriate.

PostgreSQL intentionally retains a writable filesystem because it must write to its persistent database volume.

---

## 8. Linux capabilities

Production containers drop all Linux capabilities by default:

```yaml
cap_drop:
  - ALL
```

This reduces the privileges available to processes inside the containers.

PostgreSQL requires a small set of capabilities for its normal operation, so only the required capabilities are added back:

```yaml
cap_add:
  - CHOWN
  - FOWNER
  - DAC_OVERRIDE
  - SETUID
  - SETGID
```

The principle used is:

> Drop all capabilities by default and add back only those that are required.

---

## 9. Prevent privilege escalation

Production services use:

```yaml
security_opt:
  - no-new-privileges:true
```

This prevents processes inside the container from gaining additional privileges through mechanisms such as setuid/setgid binaries.

---

## 10. CPU and memory limits

Production services have resource limits.

Example:

```yaml
mem_limit: 256m
cpus: "0.50"
```

Resource limits help prevent a runaway process or compromised container from consuming unlimited host resources.

---

## 11. Restart policies

Production services use:

```yaml
restart: unless-stopped
```

This allows containers to restart automatically after unexpected failures while still allowing intentional administrative stops.

---

## 12. Health checks

Health checks were added for the application and infrastructure services.

They verify actual service functionality rather than only checking whether the process is running.

Implemented health checks include:

* Vote HTTP endpoint
* Result HTTP endpoint
* Redis connectivity
* PostgreSQL connectivity

Compose dependencies use health status where required.

For example:

```yaml
depends_on:
  redis:
    condition: service_healthy
```

---

## 13. Network isolation

Only the services that need external access publish host ports.

```text
Host
 │
 ├── :8080 → Vote
 └── :8081 → Result
```

Redis, PostgreSQL, and Worker remain internal to the Docker networks.

This reduces unnecessary network exposure.

---

## 14. Image version and digest pinning

Base images are pinned to known versions and, where appropriate, immutable image digests.

For example:

```dockerfile
FROM python:3.11.16-slim@sha256:...
```

Redis and PostgreSQL base images are also pinned to reviewed digests.

Digest pinning improves build reproducibility and prevents an image tag from silently moving to a different image.

Image updates should therefore be deliberate and reviewed.

---

## 15. OS security updates

Base image packages are updated during the build.

Debian-based images use:

```dockerfile
RUN apt-get update && \
    apt-get upgrade -y && \
    rm -rf /var/lib/apt/lists/*
```

Alpine-based images use:

```dockerfile
RUN apk update && \
    apk upgrade --no-cache
```

This ensures available OS package updates are applied when the image is built.

---

# Application Dependency Hardening

## Node.js

The Result application's dependencies were reviewed and updated.

The dependency lockfile was migrated to lockfile version 3 and the dependency tree was checked using:

```bash
npm audit
```

The final dependency audit reported:

```text
0 vulnerabilities
```

The production image installs only production dependencies:

```bash
npm ci --omit=dev
```

---

## .NET Worker

The Worker application was upgraded to:

```text
.NET 10
```

An unnecessary `System.Drawing.Common` dependency chain was removed.

The dependency tree was verified using:

```bash
dotnet nuget why Worker.csproj System.Drawing.Common
```

No dependency path remained after the cleanup.

---

# Vulnerability Scanning

Container images were scanned using Trivy.

Example:

```bash
trivy image <image>
```

The images were reviewed for:

* Operating system vulnerabilities
* Language/package vulnerabilities
* HIGH vulnerabilities
* CRITICAL vulnerabilities

The hardened Result, Worker and Redis images were brought to zero HIGH/CRITICAL findings during the hardening work.

The Vote image still contains HIGH findings primarily associated with packages for which no fixed version was available at the time of scanning, along with findings related to vendored Python package metadata.

These findings were reviewed rather than changing application dependencies solely to achieve a zero scanner count.

The purpose of vulnerability scanning is therefore not simply to achieve:

```text
0 vulnerabilities
```

but to identify, investigate and appropriately remediate or document security findings.

---

# Production Verification

Start the hardened environment:

```bash
docker compose -f docker-compose.prod.yml up -d --build
```

Check service health:

```bash
docker compose -f docker-compose.prod.yml ps
```

The expected state is:

```text
vote      healthy
result    healthy
redis     healthy
db        healthy
worker    running
```

## Functional checks

Vote:

```bash
curl http://localhost:8080
```

Result:

```bash
curl http://localhost:8081
```

Redis:

```bash
docker compose -f docker-compose.prod.yml exec redis redis-cli ping
```

Expected:

```text
PONG
```

PostgreSQL:

```bash
docker compose -f docker-compose.prod.yml exec db \
  psql -U postgres -d postgres -c "SELECT 1;"
```

Expected:

```text
1
```

---

# Security Runtime Verification

The production containers can be inspected using Docker:

```bash
docker inspect <container> \
  --format '{{.Config.User}}'
```

Check read-only filesystem:

```bash
docker inspect <container> \
  --format '{{.HostConfig.ReadonlyRootfs}}'
```

Check dropped capabilities:

```bash
docker inspect <container> \
  --format '{{json .HostConfig.CapDrop}}'
```

Check security options:

```bash
docker inspect <container> \
  --format '{{json .HostConfig.SecurityOpt}}'
```

Expected hardened application configuration includes:

```text
ReadonlyRootfs = true
CapDrop        = ALL
SecurityOpt    = no-new-privileges:true
```

PostgreSQL is intentionally different because it requires persistent writable storage and a limited set of capabilities.

---

# Persistence

PostgreSQL uses a named Docker volume:

```text
db-data
```

The volume contains persistent database data.

When stopping the production environment, use:

```bash
docker compose -f docker-compose.prod.yml down
```

Do **not** use `-v` if the database data needs to be retained.

To remove the database volume as well:

```bash
docker compose -f docker-compose.prod.yml down -v
```

This permanently removes the Compose-managed database volume.

---

# Project Structure

```text
.
├── docker-compose.yml
├── docker-compose.prod.yml
├── vote/
│   ├── Dockerfile
│   ├── app.py
│   ├── requirements.txt
│   └── .dockerignore
├── result/
│   ├── Dockerfile
│   ├── server.js
│   ├── package.json
│   ├── package-lock.json
│   └── .dockerignore
├── worker/
│   ├── Dockerfile
│   ├── Worker.csproj
│   └── .dockerignore
├── redis/
│   └── Dockerfile
├── postgres/
│   └── Dockerfile
├── seed-data/
│   ├── Dockerfile
│   ├── generate-votes.sh
│   └── .dockerignore
├── healthchecks/
│   ├── postgres.sh
│   └── redis.sh
├── secrets/
│   ├── db_password.txt
│   └── db_password.txt.example
└── README.md
```

The real secret file is intentionally ignored by Git:

```text
secrets/db_password.txt
```

Only the example file should be committed.

---

# Hardening Summary

The project covers the following Docker security practices:

| Area                 | Implementation                       |
| -------------------- | ------------------------------------ |
| Non-root execution   | Dedicated non-root users             |
| Image minimisation   | Slim, Alpine and Distroless images   |
| Multi-stage builds   | Result and Worker                    |
| Package reduction    | Unnecessary packages removed         |
| Build context        | `.dockerignore`                      |
| Secrets              | Docker Compose secrets               |
| Filesystem           | Read-only root filesystem            |
| Temporary storage    | `tmpfs`                              |
| Linux privileges     | `cap_drop: ALL`                      |
| Privilege escalation | `no-new-privileges`                  |
| Resource protection  | CPU and memory limits                |
| Reliability          | Restart policies                     |
| Health               | Docker health checks                 |
| Network security     | Front/back network separation        |
| Reproducibility      | Image version/digest pinning         |
| OS security          | Package upgrades                     |
| Node security        | `npm audit`, production dependencies |
| .NET security        | Dependency cleanup and .NET 10       |
| Image security       | Trivy vulnerability scanning         |
| Persistence          | PostgreSQL named volume              |

---

# Notes

The voting application only accepts one vote per client browser. Additional votes from the same client are not registered.

This project is intentionally a simple distributed application used to demonstrate Docker concepts and security hardening techniques. It is not intended to represent a complete production architecture.

The focus of this repository is **practical Docker security hardening using Docker Compose**.