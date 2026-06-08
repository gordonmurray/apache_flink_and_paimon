# CLAUDE.md

## Project Overview

This repository is a local Docker demo for running Apache Flink with Apache Paimon on MinIO, using MinIO as S3-compatible object storage. The goal is to keep a small, reproducible environment that proves Flink SQL can create and write Paimon tables backed by object storage.

The project is intentionally lightweight. Prefer small, practical changes that make the demo easier to run, verify, and understand.

## Important Files

- `Dockerfile`: Builds the custom Flink image and installs the Paimon and Hadoop jars into `/opt/flink/lib/`.
- `docker-compose.yml`: Starts MinIO, creates buckets, and runs Flink JobManager and TaskManager.
- `conf/flink-conf.yaml`: Local Flink cluster configuration.
- `README.md`: User-facing quick start and project explanation.
- `FLINK_PAIMON_SETUP.md`: Setup notes and troubleshooting guidance. This file is currently untracked unless committed later.
- `sql/`: SQL walkthrough files for creating/querying Paimon tables. This directory is currently untracked unless committed later.
- `verify_test.py`: Local verification script. This file is currently untracked unless committed later.

## Current Dependency Context

The current checked-in Dockerfile uses:

- Apache Flink `1.19.3`
- Apache Paimon `1.2.0`
- Java 17 Flink base image
- MinIO images currently referenced as `latest`

As of June 2026, this should be revisited. Paimon `1.4.1` publishes bundled jars for Flink `2.2`, `2.1`, `2.0`, `1.20`, `1.19`, and older lines. A conservative refresh path is likely Flink `1.20.4` with Paimon `1.4.1`; a more modern path is Flink `2.2.x` with Paimon `1.4.1`.

When changing versions, keep the Flink image, Paimon jar artifact name, Paimon version, and README in sync.

## Common Commands

Build the custom Flink image:

```bash
docker compose build --no-cache
```

Start the local environment:

```bash
docker compose up -d
```

Open the Flink SQL client:

```bash
docker exec -it flink-jobmanager /opt/flink/bin/sql-client.sh embedded
```

Check running services:

```bash
docker compose ps
```

View logs:

```bash
docker compose logs jobmanager
docker compose logs taskmanager
docker compose logs minio
```

Stop the environment:

```bash
docker compose down
```

Reset local data:

```bash
docker compose down -v
```

## Development Guidance

- Keep the README, SQL scripts, verifier, and MinIO warehouse paths aligned. The README currently describes a `user_events` example, while local SQL files use a `users` table.
- Prefer one canonical demo path and make all documentation and tests point to it.
- Pin container images instead of using `latest`.
- Make jar downloads fail fast and verify downloaded artifacts where practical.
- Treat `verify_test.py` as needing improvement: it should fail with a non-zero exit code when Flink, MinIO, the expected table, data files, or snapshots are missing.
- Avoid committing local assistant/editor state such as `.claude/settings.local.json`.
- Be careful with Docker volume cleanup. `docker compose down -v` deletes local MinIO data.

## Open Cleanup Themes

The repo has GitHub issues tracking the main cleanup work:

- Pin container images and verify downloaded jars.
- Update the Flink and Paimon dependency strategy.
- Commit intended demo SQL files and the verifier, and ignore local settings.
- Make README and SQL scripts describe the same demo.
- Tighten Docker Compose startup dependencies and naming.
- Add richer Paimon examples beyond a basic insert.
- Replace `verify_test.py` with a real failing smoke test.
- Document and tune the Flink configuration for the local demo.

## Expected Demo Shape

A strong version of this project should let a user run a small number of commands, then verify:

- Flink Web UI is reachable on `http://localhost:8081`.
- MinIO Console is reachable on `http://localhost:9001`.
- Buckets such as `warehouse` and `checkpoints` exist.
- Flink SQL can create a Paimon catalog backed by MinIO.
- A Paimon table can be created, written to, queried, and inspected in object storage.
- The verifier exits successfully only when the demo has actually produced expected Paimon data.

