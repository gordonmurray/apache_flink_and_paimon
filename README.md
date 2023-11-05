# Trying out Apache Paimon with Apache Flink using Docker Compose

Created the following docker-compose.yml file to create a mariadb databae and flink job/task manger to work with:

JARs from https://repository.apache.org/snapshots/org/apache/paimon/

```
version: '3.7'

services:
  mariadb:
    image: mariadb:10.6.14
    environment:
      MYSQL_ROOT_PASSWORD: rootpassword
    volumes:
      - ./sql/mariadb.cnf:/etc/mysql/mariadb.conf.d/mariadb.cnf
      - ./sql/init.sql:/docker-entrypoint-initdb.d/init.sql
    ports:
      - "3306:3306"

  jobmanager:
    image: flink:1.17.1
    environment:
      - JOB_MANAGER_RPC_ADDRESS=jobmanager
    ports:
      - "8081:8081"
    command: jobmanager
    volumes:
      - ./jars/flink-sql-connector-mysql-cdc-2.4.1.jar:/opt/flink/lib/flink-sql-connector-mysql-cdc-2.4.1.jar
      - ./jars/flink-connector-jdbc-3.1.0-1.17.jar:/opt/flink/lib/flink-connector-jdbc-3.1.0-1.17.jar
      - ./jars/paimon-flink-1.17-0.6-20231007.001939-31.jar:/opt/flink/lib/paimon-flink-1.17-0.6-20231007.001939-31.jar
      - ./jars/flink-shaded-hadoop-2-uber-2.8.3-10.0.jar:/opt/flink/lib/flink-shaded-hadoop-2-uber-2.8.3-10.0.jar
      - ./jars/flink-s3-fs-hadoop-1.17.1.jar:/opt/flink/plugins/s3-fs-hadoop/flink-s3-fs-hadoop-1.17.1.jar
      - ./jars/paimon-s3-0.6-20231007.001939-34.jar:/opt/flink/lib/paimon-s3-0.6-20231007.001939-34.jar
    deploy:
          replicas: 1
  taskmanager:
    image: flink:1.17.1
    environment:
      - JOB_MANAGER_RPC_ADDRESS=jobmanager
    depends_on:
      - jobmanager
    command: taskmanager
    volumes:
      - ./jars/flink-sql-connector-mysql-cdc-2.4.1.jar:/opt/flink/lib/flink-sql-connector-mysql-cdc-2.4.1.jar
      - ./jars/flink-connector-jdbc-3.1.0-1.17.jar:/opt/flink/lib/flink-connector-jdbc-3.1.0-1.17.jar
      - ./jars/paimon-flink-1.17-0.6-20231007.001939-31.jar:/opt/flink/lib/paimon-flink-1.17-0.6-20231007.001939-31.jar
      - ./jars/flink-shaded-hadoop-2-uber-2.8.3-10.0.jar:/opt/flink/lib/flink-shaded-hadoop-2-uber-2.8.3-10.0.jar
      - ./jars/flink-s3-fs-hadoop-1.17.1.jar:/opt/flink/plugins/s3-fs-hadoop/flink-s3-fs-hadoop-1.17.1.jar
      - ./jars/paimon-s3-0.6-20231007.001939-34.jar:/opt/flink/lib/paimon-s3-0.6-20231007.001939-34.jar
    deploy:
          replicas: 2
```


The database was seeded using init.sql

```
CREATE DATABASE IF NOT EXISTS mydatabase;

USE mydatabase;

CREATE TABLE IF NOT EXISTS products (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    price DECIMAL(10,2) NOT NULL
);

INSERT INTO products (name, price) VALUES
    ('Product A', 19.99),
    ('Product B', 29.99),
    ('Product C', 39.99);
```


And its conf to make the binlog readable:

```
[mysqld]
max_connections = 100
bind-address            = 0.0.0.0
binlog_format = ROW
log_bin = /var/log/mysql/mysql-bin.log
```

I was able to create catalogs that persisted to s3 with databases and tables.

I was able to insert data directly and query the data too

However I wasn’t able to get it to send data from a temp CDC table to a table in the catalog - the temp table had the data alright, it just didn’t copy to the catalog table

I used the following in Flink:

```
USE CATALOG default_catalog;

CREATE CATALOG s3_catalog WITH (
    'type' = 'paimon',
    'warehouse' = 's3://my-s3-bucket/paimon',
    's3.access-key' = 'xxxxx',
    's3.secret-key' = 'xxxxx'
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
```

I could see the data on s3, in orc format ( Optimized Row Columnar (ORC) file format )

> aws s3 ls my-s3-bucket/paimon/my_database.db/myproducts/

Gave the following

```
PRE bucket-0/
PRE manifest/
PRE schema/
PRE snapshot
```

The schema it stored for the products table on s3 was in JSON format:

```
{
  "id" : 0,
  "fields" : [ {
    "id" : 0,
    "name" : "id",
    "type" : "INT NOT NULL"
  }, {
    "id" : 1,
    "name" : "name",
    "type" : "STRING"
  }, {
    "id" : 2,
    "name" : "price",
    "type" : "DECIMAL(10, 2)"
  } ],
  "highestFieldId" : 2,
  "partitionKeys" : [ ],
  "primaryKeys" : [ "id" ],
  "options" : { },
  "timeMillis" : 1696694538055
}
```





