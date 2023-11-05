USE CATALOG default_catalog;

CREATE CATALOG s3_catalog WITH (
    'type' = 'paimon',
    'warehouse' = 's3://my-test-bucket/paimon',
    's3.access-key' = '',
    's3.secret-key' = ''
);

USE CATALOG s3_catalog;

CREATE DATABASE my_database;

USE my_database;

CREATE TABLE myproducts (
    id INT PRIMARY KEY NOT ENFORCED,
    name VARCHAR,
    price DECIMAL(10, 2)
);

create temporary table products (
    id INT,
    name VARCHAR,
    price DECIMAL(10, 2),
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'mysql-cdc',
    'connection.pool.size' = '10',
    'hostname' = 'mariadb',
    'port' = '3306',
    'username' = 'root',
    'password' = 'rootpassword',
    'database-name' = 'mydatabase',
    'table-name' = 'products'
);

SET 'execution.checkpointing.interval' = '10 s';

INSERT INTO myproducts (id,name) SELECT id, name FROM products;