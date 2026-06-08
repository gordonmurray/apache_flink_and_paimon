-- Create Paimon catalog
CREATE CATALOG paimon_catalog WITH (
    'type' = 'paimon',
    'warehouse' = 's3://warehouse/',
    's3.endpoint' = 'http://minio:9000',
    's3.access-key' = 'admin',
    's3.secret-key' = 'password123',
    's3.path.style.access' = 'true'
);

USE CATALOG paimon_catalog;
USE test_db;

-- Set execution mode to batch for query
SET execution.runtime-mode=batch;

-- Create a sink table to output results
CREATE TEMPORARY TABLE print_sink (
    user_id INT,
    username STRING,
    email STRING,
    age INT,
    registration_date TIMESTAMP(3)
) WITH (
    'connector' = 'print'
);

-- Insert query results into print sink to display them
INSERT INTO print_sink
SELECT * FROM users;