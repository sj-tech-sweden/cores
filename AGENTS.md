# Repository Guidelines

## Project Structure & Module Organization
- `docker-compose.yml` orchestrates RentalCore, WarehouseCore, MySQL, and Mosquitto; keep service names aligned with upstream app repos.
- `rentalcore/` (Go 1.23) handles job and customer flows; key paths are `cmd/server`, `internal/`, `web/`, and migrations.
- `warehousecore/` (Go 1.24) mirrors the layout for warehouse features; shared validators live in `internal/validation`.
- Root `migrations/` and `RentalCore.sql` feed MySQL; update when schema changes span services.
- Deployment examples in `nginx-reverse-proxy.conf`, `docker-compose.*.yml`, and `docs/` must mirror port, domain, or env changes.
- Ensure both cores stay fully deployable and feature-complete with one `docker-compose.yml` plus `.env` on any host.

## Build, Test & Development Commands
- Managed environment runs on `docker03.nt.local` (user `noah`, SSH key installed); Komodo API access is allowed here to redeploy stacks, pull images, start/stop/restart stacks, and inspect logs as needed.

- `docker compose logs -f rentalcore|warehousecore` — stream logs.

- `make build`, `make run`, `make dev-setup` inside `rentalcore/` — compile, run, or bootstrap dependencies.
- `make build`, `make test`, `go test ./...` inside `warehousecore/` — build and test.

## Operations & Access
- The `cores-migrations` Docker image is published to GHCR (`ghcr.io/<org>/cores-migrations`) and built/pushed automatically via GitHub Actions on merge — do not build or push manually.

## Coding Style & Naming Conventions
- Run `gofmt` (or `go fmt ./...`) before review; apply `goimports` when imports change.
- Keep `internal/` packages scoped by domain (`jobs`, `validation`, `mqtt`) and avoid cross-package coupling.
- Follow identifier patterns: PascalCase for exports, camelCase for locals, uppercase snake case for config keys.
- Static assets in `web/` use kebab-case filenames and established folder splits (`css/`, `js/`, `img/`).

## Testing Guidelines
- Mirror the source tree with package-level `_test.go` files and favor table-driven cases.
- Run `go test ./...` from each service root before pushing; add coverage whenever touching `internal` logic or SQL migrations.
- For database-impacting changes, refresh root migrations and validate with `docker compose up` against a clean volume.

## Deployment Discipline
- Releases are triggered automatically by GitHub Actions when a PR is merged with a version label:
  - `major` — breaking change, bumps the major version (e.g., 1.x.x → 2.0.0)
  - `minor` — new feature, bumps the minor version (e.g., 1.2.x → 1.3.0)
  - `patch` — bug fix or small change, bumps the patch version (e.g., 1.2.3 → 1.2.4)
- Always apply exactly one of these labels to every PR before merging; GitHub Actions will build, tag, and push the Docker image to Docker Hub automatically.
- After merging, update README files and relevant docs if behavior, configuration, or deployment steps changed.

## Commit & Pull Request Guidelines
- Use imperative, present-tense commit subjects (e.g., `Ensure default admin seeding matches new RBAC`) capped at 72 characters.
- Group related work per service; cross-cutting updates should call out both modules and referenced schema changes in the body.
- PRs must describe the scenario, list test commands, link issues, and include UI screenshots when `web/` assets change.
- Apply exactly one of the version labels (`major`, `minor`, `patch`) before merging so the CI release workflow fires correctly.
- Highlight secrets or domain changes for release notes and request review from both service owners on shared infrastructure updates.

## Issues
- When working on an issue, change the label to `in_progress`.
- When the issue is resolved, change the label to `done` and close the issue if possible.
- After resolving an issue, list remaining issues and ask which one to work on next; do this after the PR is merged and the automated release has completed.
