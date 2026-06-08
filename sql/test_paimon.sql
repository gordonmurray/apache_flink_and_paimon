-- Create Paimon catalog using S3 (MinIO) storage
CREATE CATALOG paimon_catalog WITH (
    'type' = 'paimon',
    'warehouse' = 's3://warehouse/',
    's3.endpoint' = 'http://minio:9000',
    's3.access-key' = 'admin',
    's3.secret-key' = 'password123',
    's3.path.style.access' = 'true'
);

-- Switch to the Paimon catalog
USE CATALOG paimon_catalog;

-- Create a database
CREATE DATABASE IF NOT EXISTS test_db;
USE test_db;

-- Create a Paimon table with primary key
CREATE TABLE IF NOT EXISTS users (
    user_id INT,
    username STRING,
    email STRING,
    age INT,
    registration_date TIMESTAMP(3),
    PRIMARY KEY (user_id) NOT ENFORCED
) WITH (
    'bucket' = '4',
    'changelog-producer' = 'input'
);

-- Insert test data
INSERT INTO users VALUES
    (1, 'alice', 'alice@example.com', 28, TIMESTAMP '2024-01-15 10:30:00'),
    (2, 'bob', 'bob@example.com', 35, TIMESTAMP '2024-01-16 11:45:00'),
    (3, 'charlie', 'charlie@example.com', 42, TIMESTAMP '2024-01-17 09:15:00'),
    (4, 'diana', 'diana@example.com', 31, TIMESTAMP '2024-01-18 14:20:00'),
    (5, 'edward', 'edward@example.com', 26, TIMESTAMP '2024-01-19 16:30:00');

-- Set result mode for queries
SET sql-client.execution.result-mode=TABLEAU;

-- Query the data
SELECT * FROM users;

-- Update some records
INSERT INTO users VALUES
    (2, 'bob_updated', 'bob.updated@example.com', 36, TIMESTAMP '2024-02-01 12:00:00'),
    (4, 'diana_updated', 'diana.new@example.com', 32, TIMESTAMP '2024-02-02 15:00:00');

-- Query again to see updates
SELECT * FROM users ORDER BY user_id;

-- Count records
SELECT COUNT(*) as total_users FROM users;

-- Filter query
SELECT * FROM users WHERE age > 30;