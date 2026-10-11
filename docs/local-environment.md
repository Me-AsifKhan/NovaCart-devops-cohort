# DEVOPS-004 — One-Command Local Stack

## 1. Overview

NovaCart's local development environment uses Docker Compose to run
the frontend, backend API, and PostgreSQL database together.

## 2. Start the stack

From the repository root:

```powershell
docker compose up -d --build
docker compose ps
