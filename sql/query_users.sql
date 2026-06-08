-- Create Paimon catalog
CREATE CATALOG paimon_catalog WITH (
    'type' = 'paimon',
    'warehouse' = 's3://warehouse/',
    's3.endpoint' = 'http://minio:9000',
    's3.access-key' = 'admin',
    's3.secret-key' = 'password123',
    's3.path.style.access' = 'true'
);

-- Use the Paimon catalog
USE CATALOG paimon_catalog;
USE test_db;

-- Set result mode for queries
SET sql-client.execution.result-mode=TABLEAU;

-- Query all users
SELECT * FROM users;