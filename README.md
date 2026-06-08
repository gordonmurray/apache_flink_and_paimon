# Apache Flink + Apache Paimon + MinIO Integration

A complete Docker-based setup demonstrating how to use **Apache Flink** to write data to **MinIO** (S3-compatible storage) using **Apache Paimon** as a lakehouse storage format. This project solves the dependency hell that often occurs when trying to integrate these components together.

## 🚀 What's Inside

- **Apache Flink 1.19.3** - Stream processing framework
- **Apache Paimon 1.2.0** - Lakehouse storage format with ACID transactions
- **MinIO (latest)** - S3-compatible object storage
- **Custom Docker Image** - Pre-built with all required JARs to avoid dependency conflicts

## 🎯 Why This Approach Works

Previous attempts to use volume mounts for JARs often failed due to classpath and dependency resolution issues. This project builds a custom Dockerfile that extends `flink:1.19.3-java17` and downloads three critical JARs directly into `/opt/flink/lib/`:

- `paimon-flink-1.19-1.2.0.jar` - Main Paimon connector for Flink
- `paimon-s3-1.2.0.jar` - Paimon's S3 implementation
- `flink-shaded-hadoop-2-uber-2.8.3-10.0.jar` - Required Hadoop classes

**The key insight:** Paimon internally requires Hadoop classes regardless of which S3 approach you use, but Flink's base images don't include them. The custom Docker image ensures all dependencies are available in a single, consistent environment - eliminating the dependency hell that plagued earlier versions of this integration.

## 🛠️ Quick Start

### 1. Build and Start the Services

```bash
# Build the custom Flink image with embedded JARs
docker compose build --no-cache

# Start all services (MinIO, Flink JobManager, Flink TaskManager)
docker compose up -d
```

### 2. Verify Everything is Running

- **Flink Web UI**: http://localhost:8081
- **MinIO Console**: http://localhost:9001 (admin/password123)
- **MinIO API**: http://localhost:9000

### 3. Connect to Flink SQL Client

```bash
docker exec -it flink-jobmanager /opt/flink/bin/sql-client.sh embedded
```

### 4. Run the Canonical Paimon Demo

The checked demo lives in `sql/test_paimon.sql`. It creates the `paimon_catalog`
catalog, uses `s3://warehouse/` as the warehouse path, creates
`test_db.users`, inserts sample rows, updates a couple of users, and runs a few
queries.

Copy the SQL file into the JobManager container and run it with Flink SQL:

```bash
docker cp sql/test_paimon.sql flink-jobmanager:/tmp/test_paimon.sql
docker exec -it flink-jobmanager /opt/flink/bin/sql-client.sh embedded -f /tmp/test_paimon.sql
```

If you prefer to run the commands manually, connect to the Flink SQL client:

```bash
docker exec -it flink-jobmanager /opt/flink/bin/sql-client.sh embedded
```

Then paste the canonical demo from `sql/test_paimon.sql`:

```sql
-- Create the Paimon catalog pointing to MinIO
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

-- Create a table with primary key
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

-- Insert some test data
INSERT INTO users VALUES
  (1, 'alice', 'alice@example.com', 28, TIMESTAMP '2024-01-15 10:30:00'),
  (2, 'bob', 'bob@example.com', 35, TIMESTAMP '2024-01-16 11:45:00'),
  (3, 'charlie', 'charlie@example.com', 42, TIMESTAMP '2024-01-17 09:15:00'),
  (4, 'diana', 'diana@example.com', 31, TIMESTAMP '2024-01-18 14:20:00'),
  (5, 'edward', 'edward@example.com', 26, TIMESTAMP '2024-01-19 16:30:00');

-- Query the data
SELECT * FROM users;
```

## 📊 What You'll See

- Your INSERT job will appear in the Flink Web UI and complete successfully
- Data files will be created in MinIO under `/warehouse/test_db.db/users/`
- Paimon maintains full ACID properties with snapshots, manifests, and schema evolution support

To verify the demo storage layout after running `sql/test_paimon.sql`, run:

```bash
python3 verify_test.py
```

## 🌩️ Using with Real AWS S3

To use this setup with actual AWS S3 instead of MinIO, simply modify the catalog configuration:

```sql
CREATE CATALOG paimon_catalog WITH (
   'type' = 'paimon',
   'warehouse' = 's3://your-bucket/paimon/',
   's3.access-key' = 'your-access-key',
   's3.secret-key' = 'your-secret-key',
   's3.path.style.access' = 'false'  -- Use virtual-hosted style for AWS
);
```

The same JARs work perfectly with real AWS S3!

## 🧹 Cleanup

```bash
# Stop all services
docker compose down

# Remove volumes (if you want to start fresh)
docker compose down -v
```

## 📝 Notes

- This is an updated version of a project I originally started two years ago
- MinIO credentials are `admin` / `password123` for local development
- The setup automatically creates the required buckets (`warehouse` and `checkpoints`)
- All data is persisted in Docker volumes between restarts

## 🎉 Success

If everything works correctly, you should see:
- Flink jobs complete successfully in the Web UI
- Data files appear in MinIO storage with proper Paimon structure
- No JAR conflicts or classpath issues in the logs

This integration finally makes Flink + Paimon + S3 storage work reliably together! 🚀
