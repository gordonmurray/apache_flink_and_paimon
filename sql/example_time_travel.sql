-- Time travel: read the table as it looked at an earlier snapshot using a query
-- hint, then compare with the current state. Run with:
--   docker exec -i flink-jobmanager /opt/flink/bin/sql-client.sh -f /sql/example_time_travel.sql
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
DROP TABLE IF EXISTS metrics;

CREATE TABLE IF NOT EXISTS metrics (
    name STRING,
    metric_value INT,
    PRIMARY KEY (name) NOT ENFORCED
) WITH ('bucket' = '1');

-- Snapshot 1
INSERT INTO metrics VALUES ('signups', 10);
-- Snapshot 2
INSERT INTO metrics VALUES ('signups', 25), ('logins', 40);

SET 'sql-client.execution.result-mode' = 'tableau';
-- The table as of the first snapshot: only signups = 10
SELECT * FROM metrics /*+ OPTIONS('scan.snapshot-id' = '1') */ ORDER BY name;

-- The current table
SELECT * FROM metrics ORDER BY name;
