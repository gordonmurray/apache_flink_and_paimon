# Apache Flink + Apache Paimon + MinIO Integration

A complete Docker-based setup demonstrating how to use **Apache Flink** to write data to **MinIO** (S3-compatible storage) using **Apache Paimon** as a lakehouse storage format. This project solves the dependency hell that often occurs when trying to integrate these components together.

## 🚀 What's Inside

- **Apache Flink 1.19.3** - Stream processing framework
- **Apache Paimon 1.2.0** - Lakehouse storage format with ACID transactions
- **flink-shaded-hadoop 2.8.3-10.0** - Hadoop classes Paimon needs for S3 access
- **MinIO RELEASE.2025-09-07T16-13-09Z** - S3-compatible object storage
- **MinIO Client (mc) RELEASE.2025-08-13T08-35-41Z** - Creates the demo buckets
- **Custom Docker Image** - Pre-built with all required JARs to avoid dependency conflicts

All images and jar versions are pinned, and the jar downloads are checksum-verified at build time so the setup stays reproducible over time.

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

### 4. Create Your First Paimon Table

Once in the Flink SQL client, run these commands:

```sql
-- Create the Paimon catalog pointing to MinIO
CREATE CATALOG paimon_catalog WITH (
   'type' = 'paimon',
   'warehouse' = 's3://warehouse/paimon/',
   's3.endpoint' = 'http://minio:9000',
   's3.access-key' = 'admin',
   's3.secret-key' = 'password123',
   's3.path.style.access' = 'true'
);

-- Switch to the Paimon catalog
USE CATALOG paimon_catalog;

-- Create a database
CREATE DATABASE test_db;
USE test_db;

-- Create a table with primary key
CREATE TABLE user_events (
  user_id BIGINT,
  event_type STRING,
  timestamp_val TIMESTAMP(3),
  PRIMARY KEY (user_id) NOT ENFORCED
);

-- Insert some test data
INSERT INTO user_events VALUES
  (1001, 'login', TIMESTAMP '2024-01-01 10:00:00'),
  (1002, 'purchase', TIMESTAMP '2024-01-01 10:15:00');

-- Query the data
SELECT * FROM user_events;
```

### 5. Run the Smoke Test

Once the INSERT job has finished, confirm the demo actually wrote Paimon data to MinIO:

```bash
python3 verify_test.py
```

It checks the running containers, the Flink REST API, and the Paimon table in MinIO, and exits non-zero if anything is missing.

## 📊 What You'll See

- Your INSERT job will appear in the Flink Web UI and complete successfully
- Data files will be created in MinIO under the `/warehouse/paimon/` path
- Paimon maintains full ACID properties with snapshots, manifests, and schema evolution support

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
- MinIO credentials default to `admin` / `password123`; copy `.env.example` to `.env` to change them or the container names
- The custom Flink image is built locally as `flink-paimon:local`
- Bucket creation runs to completion before Flink starts, so the `warehouse` and `checkpoints` buckets always exist first
- All data is persisted in Docker volumes between restarts

## 🎉 Success

If everything works correctly, you should see:
- Flink jobs complete successfully in the Web UI
- Data files appear in MinIO storage with proper Paimon structure
- No JAR conflicts or classpath issues in the logs

This integration finally makes Flink + Paimon + S3 storage work reliably together! 🚀
