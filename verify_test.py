#!/usr/bin/env python3
"""Smoke test for the Flink + Paimon + MinIO demo.

Run this after `docker compose up -d` and the SQL walkthrough in
`sql/test_paimon.sql`. It exits non-zero unless the stack is healthy and the
demo has actually written Paimon data to MinIO, so it can be used in CI or as
a quick local sanity check.

The expected warehouse, database, and table can be overridden with the
PAIMON_WAREHOUSE, PAIMON_DATABASE, and PAIMON_TABLE environment variables to
match a different demo. The container names follow the same MINIO_CONTAINER,
FLINK_JOBMANAGER_CONTAINER, and FLINK_TASKMANAGER_CONTAINER variables that
docker-compose.yml uses, so renaming the containers there is picked up here too.
"""
import json
import os
import sys
import urllib.error
import urllib.request
from subprocess import run, CalledProcessError, PIPE

FLINK_REST = os.environ.get("FLINK_REST_URL", "http://localhost:8081")
# Container names default to the Compose values but follow the same environment
# variables as docker-compose.yml, so overriding them there (or in .env) keeps
# the smoke test pointing at the right containers.
MINIO_CONTAINER = os.environ.get("MINIO_CONTAINER", "minio")
JOBMANAGER_CONTAINER = os.environ.get("FLINK_JOBMANAGER_CONTAINER", "flink-jobmanager")
TASKMANAGER_CONTAINER = os.environ.get("FLINK_TASKMANAGER_CONTAINER", "flink-taskmanager")
WAREHOUSE = os.environ.get("PAIMON_WAREHOUSE", "warehouse")
DATABASE = os.environ.get("PAIMON_DATABASE", "test_db")
TABLE = os.environ.get("PAIMON_TABLE", "users")
EXPECTED_CONTAINERS = (MINIO_CONTAINER, JOBMANAGER_CONTAINER, TASKMANAGER_CONTAINER)

# MinIO single-drive layout stores each object under /data/<bucket>/...
TABLE_PATH = f"/data/{WAREHOUSE}/{DATABASE}.db/{TABLE}"


class SmokeTestError(Exception):
    """Raised when a check fails so main() can report it and exit non-zero."""


def docker(*args):
    """Run a docker command with an explicit argument list."""
    return run(["docker", *args], check=True, stdout=PIPE, stderr=PIPE, text=True).stdout


def check_containers():
    for name in EXPECTED_CONTAINERS:
        try:
            state = docker(
                "inspect", "-f",
                "{{.State.Running}} {{if .State.Health}}{{.State.Health.Status}}{{end}}",
                name,
            ).strip()
        except CalledProcessError:
            raise SmokeTestError(f"container '{name}' is not present, start the stack with docker compose up -d")
        running, _, health = state.partition(" ")
        if running != "true":
            raise SmokeTestError(f"container '{name}' is not running")
        if health and health != "healthy":
            raise SmokeTestError(f"container '{name}' is {health}, expected healthy")
        print(f"  ok   container {name} running{f' ({health})' if health else ''}")


def check_flink():
    url = f"{FLINK_REST}/overview"
    try:
        with urllib.request.urlopen(url, timeout=5) as resp:
            overview = json.load(resp)
    except (urllib.error.URLError, OSError) as exc:
        raise SmokeTestError(f"Flink REST API unavailable at {url}: {exc}")
    taskmanagers = overview.get("taskmanagers", 0)
    if taskmanagers < 1:
        raise SmokeTestError("Flink reports no registered task managers")
    print(f"  ok   Flink {overview.get('flink-version', 'unknown')}, "
          f"{taskmanagers} task manager(s), {overview.get('slots-total', 0)} slot(s)")


def minio_listing(path, recursive=False):
    """Recursively or shallowly list a path inside the MinIO container."""
    flag = "-1R" if recursive else "-1"
    try:
        return docker("exec", MINIO_CONTAINER, "sh", "-c", f"ls {flag} {path}")
    except CalledProcessError:
        return ""


def check_paimon_data():
    if not minio_listing(f"/data/{WAREHOUSE}/{DATABASE}.db"):
        raise SmokeTestError(f"database '{DATABASE}' not found under {WAREHOUSE}, run the SQL demo first")

    table_tree = minio_listing(TABLE_PATH, recursive=True)
    if not table_tree:
        raise SmokeTestError(f"table '{DATABASE}.{TABLE}' not found at {TABLE_PATH}")

    for component in ("schema", "manifest", "snapshot"):
        if f"{component}" not in table_tree:
            raise SmokeTestError(f"table '{TABLE}' is missing its {component} directory")

    if "data-" not in table_tree:
        raise SmokeTestError(f"table '{TABLE}' has no data files, the demo wrote no rows")
    if "snapshot-" not in table_tree:
        raise SmokeTestError(f"table '{TABLE}' has no snapshots, no commit has completed")

    # Count object names only; recursive ls also prints each object as a
    # directory header (a line ending in ':'), which we skip.
    entries = [line.strip() for line in table_tree.splitlines() if not line.strip().endswith(":")]
    data_files = sum(1 for line in entries if "data-" in line and line.endswith(".parquet"))
    snapshots = sum(1 for line in entries if line.startswith("snapshot-"))
    print(f"  ok   table {DATABASE}.{TABLE}: {data_files} data file(s), {snapshots} snapshot(s)")


def main():
    checks = (
        ("Docker containers", check_containers),
        ("Flink REST API", check_flink),
        ("Paimon data in MinIO", check_paimon_data),
    )
    print("Flink + Paimon smoke test")
    for title, check in checks:
        print(f"- {title}")
        try:
            check()
        except SmokeTestError as exc:
            print(f"  FAIL {exc}", file=sys.stderr)
            print("\nSmoke test failed.", file=sys.stderr)
            return 1
    print("\nSmoke test passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
