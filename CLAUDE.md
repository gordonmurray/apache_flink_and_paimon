# CLAUDE.md

## Project Overview

This repository is a local Docker demo for running Apache Flink with Apache Paimon on MinIO, using MinIO as S3-compatible object storage. The goal is to keep a small, reproducible environment that proves Flink SQL can create and write Paimon tables backed by object storage.

The project is intentionally lightweight. Prefer small, practical changes that make the demo easier to run, verify, and understand.

## Important Files

- `Dockerfile`: Builds the custom Flink image and installs the Paimon and Hadoop jars into `/opt/flink/lib/`.
- `docker-compose.yml`: Starts MinIO, creates buckets, and runs Flink JobManager and TaskManager.
- `conf/flink-conf.yaml`: Local Flink cluster configuration.
- `README.md`: User-facing quick start and project explanation.
- `FLINK_PAIMON_SETUP.md`: Setup notes and troubleshooting guidance.
- `sql/`: SQL walkthrough files for creating/querying Paimon tables, including the canonical `test_paimon.sql` and the focused `example_*.sql` demos.
- `verify_test.py`: Smoke test that fails with a non-zero exit code unless the stack is healthy and the demo has written Paimon data.
- `.env.example`: Documents the MinIO credentials and container-name overrides read by Compose.

## Current Dependency Context

The current checked-in Dockerfile uses:

- Apache Flink `1.20.4`
- Apache Paimon `1.4.1` (`paimon-flink-1.20` jar)
- Java 17 Flink base image
- Pinned MinIO and MinIO client images

This is the conservative lane: it stays on the Flink 1.x line while moving Paimon to a current release. The modern lane is Flink `2.2.x` with Paimon `1.4.1`; moving there means bumping the base image, setting `PAIMON_FLINK_MINOR` to the matching Flink minor, and revisiting the config and SQL for any 2.x changes. Note Flink 1.20 still reads the legacy `flink-conf.yaml`, while `config.yaml` is the newer format to migrate to later.

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

- Keep the README, SQL scripts, verifier, and MinIO warehouse paths aligned. The canonical demo is `test_db.users` under `s3://warehouse/`, matching `sql/test_paimon.sql`, the README quick start, and `verify_test.py`.
- Prefer one canonical demo path and make all documentation and tests point to it.
- Pin container images instead of using `latest`.
- Make jar downloads fail fast and verify downloaded artifacts where practical.
- Keep `verify_test.py` a real smoke test: it must exit non-zero when Flink, MinIO, the expected table, data files, or snapshots are missing.
- Avoid committing local assistant/editor state such as `.claude/settings.local.json`.
- Be careful with Docker volume cleanup. `docker compose down -v` deletes local MinIO data.

## Cleanup Status

The initial cleanup round is complete:

- Container images are pinned and downloaded jars are checksum-verified.
- The dependency strategy is documented (conservative lane: Flink 1.20.4, Paimon 1.4.1).
- The demo SQL files and the verifier are tracked, and local settings are ignored.
- The README and SQL scripts describe the same canonical demo.
- Docker Compose startup waits for bucket creation and uses overridable names.
- Richer Paimon examples cover upserts, history, schema evolution, and time travel.
- `verify_test.py` is a real smoke test that exits non-zero on failure.
- The Flink configuration is documented and tuned, with checkpoints written to MinIO.

## Expected Demo Shape

A strong version of this project should let a user run a small number of commands, then verify:

- Flink Web UI is reachable on `http://localhost:8081`.
- MinIO Console is reachable on `http://localhost:9001`.
- Buckets such as `warehouse` and `checkpoints` exist.
- Flink SQL can create a Paimon catalog backed by MinIO.
- A Paimon table can be created, written to, queried, and inspected in object storage.
- The verifier exits successfully only when the demo has actually produced expected Paimon data.

