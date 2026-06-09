-- Snapshot and schema history: every commit creates a new snapshot, and Paimon
-- exposes that history through system tables you can query directly. Run with:
--   docker exec -i flink-jobmanager /opt/flink/bin/sql-client.sh -f /sql/example_history.sql
SET 'execution.runtime-mode' = 'batch';
-- Wait for each INSERT job to finish before the next statement reads the table
SET 'table.dml-sync' = 'true';

CREATE CATALOG paimon_catalog WITH (
    'type' = 'paimon',
    'warehouse' = 's3://warehouse/',
    's3.endpoint' = 'http://minio:9000',
    's3.access-key' = 'admin',
    's3.secret-key' = 'password123',
    's3.path.style.access' = 'true'
);
USE CATALOG paimon_catalog;
CREATE DATABASE IF NOT EXISTS paimon_examples;
USE paimon_examples;

-- Start from a clean table so the example is the same every run
DROP TABLE IF EXISTS inventory;

CREATE TABLE IF NOT EXISTS inventory (
    sku STRING,
    quantity INT,
    PRIMARY KEY (sku) NOT ENFORCED
) WITH ('bucket' = '2');

-- Two separate commits produce two snapshots
INSERT INTO inventory VALUES ('A-100', 5), ('A-200', 12);
INSERT INTO inventory VALUES ('A-100', 8), ('A-300', 3);

SET 'sql-client.execution.result-mode' = 'tableau';
-- One row per commit
SELECT snapshot_id, schema_id, commit_kind, total_record_count
FROM inventory$snapshots ORDER BY snapshot_id;

-- The table schema as Paimon tracks it
SELECT schema_id, fields FROM inventory$schemas ORDER BY schema_id;
