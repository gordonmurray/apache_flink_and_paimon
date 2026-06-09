-- Schema evolution: add a column to an existing table without rewriting old
-- data. Rows written before the change read back with NULL for the new column.
-- Run with:
--   docker exec -i flink-jobmanager /opt/flink/bin/sql-client.sh -f /sql/example_schema_evolution.sql
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
DROP TABLE IF EXISTS customers;

CREATE TABLE IF NOT EXISTS customers (
    customer_id INT,
    name STRING,
    PRIMARY KEY (customer_id) NOT ENFORCED
) WITH ('bucket' = '2');

-- Written under the original two-column schema
INSERT INTO customers VALUES (1, 'Ada'), (2, 'Linus');

-- Add a column; existing rows are not rewritten
ALTER TABLE customers ADD (country STRING);

-- New row carries the added column
INSERT INTO customers (customer_id, name, country) VALUES (3, 'Grace', 'US');

SET 'sql-client.execution.result-mode' = 'tableau';
-- Rows 1 and 2 show NULL country, row 3 shows 'US'
SELECT * FROM customers ORDER BY customer_id;
