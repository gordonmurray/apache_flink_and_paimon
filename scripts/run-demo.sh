#!/usr/bin/env bash
# Bring up the local Flink + Paimon + MinIO stack, run the canonical demo, and
# verify that it wrote data to MinIO. One command from a clean checkout.
#
# Usage: scripts/run-demo.sh
# Stop and reset afterwards with: docker compose down -v
set -euo pipefail

cd "$(dirname "$0")/.."

JOBMANAGER="${FLINK_JOBMANAGER_CONTAINER:-flink-jobmanager}"
REST="${FLINK_REST_URL:-http://localhost:8081}"
SQL_FILE="${DEMO_SQL:-/sql/test_paimon.sql}"

echo "==> Building and starting the stack"
docker compose up -d --build

echo "==> Waiting for the JobManager to become healthy"
status=""
for _ in $(seq 1 60); do
  status="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{end}}' "$JOBMANAGER" 2>/dev/null || true)"
  if [ "$status" = "healthy" ]; then break; fi
  sleep 3
done
if [ "$status" != "healthy" ]; then
  echo "JobManager did not become healthy in time" >&2
  exit 1
fi

echo "==> Waiting for a task manager to register"
tms=0
for _ in $(seq 1 30); do
  tms="$(curl -fsS "$REST/overview" 2>/dev/null \
    | python3 -c 'import sys,json; print(json.load(sys.stdin).get("taskmanagers",0))' 2>/dev/null || echo 0)"
  if [ "${tms:-0}" -ge 1 ]; then break; fi
  sleep 3
done
if [ "${tms:-0}" -lt 1 ]; then
  echo "No task manager registered in time" >&2
  exit 1
fi

echo "==> Running the canonical demo ($SQL_FILE)"
# Run in batch mode with synchronous DML so every statement completes and the
# client exits instead of streaming forever.
docker exec -i "$JOBMANAGER" sh -c 'cat > /tmp/demo-init.sql' <<'SQL'
SET 'execution.runtime-mode' = 'batch';
SET 'table.dml-sync' = 'true';
SQL
docker exec "$JOBMANAGER" /opt/flink/bin/sql-client.sh -i /tmp/demo-init.sql -f "$SQL_FILE"

echo "==> Verifying the demo wrote data to MinIO"
python3 verify_test.py

echo "==> Demo complete. Stop and reset with: docker compose down -v"
