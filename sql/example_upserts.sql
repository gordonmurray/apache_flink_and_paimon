-- Primary-key upserts: writing a row with an existing key updates it in place
-- rather than appending a duplicate. Run after `docker compose up -d`:
--   docker exec -i flink-jobmanager /opt/flink/bin/sql-client.sh -f /sql/example_upserts.sql
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
DROP TABLE IF EXISTS products;

CREATE TABLE IF NOT EXISTS products (
    product_id INT,
    name STRING,
    price DECIMAL(10, 2),
    PRIMARY KEY (product_id) NOT ENFORCED
) WITH ('bucket' = '2');

-- First write
INSERT INTO products VALUES
    (1, 'Keyboard', 49.99),
    (2, 'Mouse', 19.99);

-- Re-writing key 1 updates it; key 3 is a new row
INSERT INTO products VALUES
    (1, 'Mechanical Keyboard', 89.99),
    (3, 'Monitor', 199.00);

SET 'sql-client.execution.result-mode' = 'tableau';
-- Three rows: product 1 shows the updated name and price, not a duplicate
SELECT * FROM products ORDER BY product_id;
