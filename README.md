# Apache Flink + Apache Paimon + MinIO Integration

A complete Docker-based setup demonstrating how to use **Apache Flink** to write data to **MinIO** (S3-compatible storage) using **Apache Paimon** as a lakehouse storage format. This project solves the dependency hell that often occurs when trying to integrate these components together.

## 🚀 What's Inside

- **Apache Flink 1.20.4** - Stream processing framework
- **Apache Paimon 1.4.1** - Lakehouse storage format with ACID transactions
- **flink-shaded-hadoop 2.8.3-10.0** - Hadoop classes Paimon needs for S3 access
- **MinIO RELEASE.2025-09-07T16-13-09Z** - S3-compatible object storage
- **MinIO Client (mc) RELEASE.2025-08-13T08-35-41Z** - Creates the demo buckets
- **Custom Docker Image** - Pre-built with all required JARs to avoid dependency conflicts

All images and jar versions are pinned, and the jar downloads are checksum-verified at build time so the setup stays reproducible over time.

### Version lane

This demo runs the conservative lane: Flink 1.20.4 with Paimon 1.4.1. It stays close to the long-lived Flink 1.x line while moving Paimon up to a current release, so the upgrade from the original 1.19.3 / 1.2.0 setup is low risk. To move to the modern lane (Flink 2.2.x with Paimon 1.4.1), bump the base image and set `PAIMON_FLINK_MINOR` to the matching Flink minor in the Dockerfile; expect to revisit the config and SQL for any 2.x changes. The cluster uses the standard `config.yaml` format (Flink 1.20 also reads the legacy `flink-conf.yaml`).

## 🎯 Why This Approach Works

Previous attempts to use volume mounts for JARs often failed due to classpath and dependency resolution issues. This project builds a custom Dockerfile that extends `flink:1.20.4-java17` and downloads three critical JARs directly into `/opt/flink/lib/`:

- `paimon-flink-1.20-1.4.1.jar` - Main Paimon connector for Flink
- `paimon-s3-1.4.1.jar` - Paimon's S3 implementation
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

The canonical walkthrough is `sql/test_paimon.sql`, which creates a `test_db.users` table under the `s3://warehouse/` warehouse. In the Flink SQL client, run the same statements it contains:

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

-- Create the database and table
CREATE DATABASE IF NOT EXISTS test_db;
USE test_db;

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

-- Insert sample data
INSERT INTO users VALUES
  (1, 'alice', 'alice@example.com', 28, TIMESTAMP '2024-01-15 10:30:00'),
  (2, 'bob', 'bob@example.com', 35, TIMESTAMP '2024-01-16 11:45:00'),
  (3, 'charlie', 'charlie@example.com', 42, TIMESTAMP '2024-01-17 09:15:00');

-- Query the data
SELECT * FROM users;
```

The `sql/` directory is mounted into the JobManager at `/sql`, so `sql/test_paimon.sql` is available there along with the other example scripts. The smoke test in step 5 checks this same `test_db.users` table.

### 5. Run the Smoke Test

Once the INSERT job has finished, confirm the demo actually wrote Paimon data to MinIO:

```bash
python3 verify_test.py
```

It checks the running containers, the Flink REST API, and the Paimon table in MinIO, and exits non-zero if anything is missing.

## 📊 What You'll See

- Your INSERT job will appear in the Flink Web UI and complete successfully
- Data files will be created in MinIO under the `/warehouse/test_db.db/users/` path
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

## ⚙️ Flink Configuration

The cluster is configured in `conf/config.yaml`. The settings that matter for this demo:

- **Memory**: `jobmanager.memory.process.size` and `taskmanager.memory.process.size` are sized to run both on a laptop. Managed memory stays at the Flink default (0.4 of task manager memory), which is enough for Paimon's writers here.
- **Slots and parallelism**: `taskmanager.numberOfTaskSlots: 4` with `parallelism.default: 1`, so the small examples are easy to follow.
- **Checkpointing**: every 30s into the MinIO `checkpoints` bucket (`state.checkpoints.dir: s3://checkpoints/flink/`), using the hashmap state backend. The bucket is the same one Compose creates at startup. Switch to the rocksdb backend if you experiment with large state.
- **Restart strategy**: `fixed-delay` with 3 attempts and a 10s delay, suitable for local trial and error.
- **S3 access for checkpoints**: the `s3.*` settings point Flink's bundled `flink-s3-fs-hadoop` plugin at MinIO. Paimon's catalog uses its own `s3.*` options from the SQL `CREATE CATALOG` statement, so the warehouse and checkpoint paths are configured independently.

The memory sizes, web submit/cancel, restart strategy, and hard-coded MinIO credentials are local demo choices and should be reviewed before reusing this file elsewhere.

## 📚 Example SQL Walkthroughs

The `sql/` directory holds focused examples that show more of what Paimon can do beyond a basic insert. They are mounted into the JobManager at `/sql` and use their own `paimon_examples` database, so they stay separate from the main `test_db` demo. Each one drops and recreates its table, so it produces the same result every run.

Run any of them after `docker compose up -d`:

```bash
docker exec -i flink-jobmanager /opt/flink/bin/sql-client.sh -f /sql/example_upserts.sql
```

- `example_upserts.sql` - primary-key upserts, where rewriting a key updates the row instead of adding a duplicate
- `example_history.sql` - inspecting snapshot and schema history through Paimon's system tables
- `example_schema_evolution.sql` - adding a column to a live table, with older rows reading back as NULL
- `example_time_travel.sql` - reading an earlier snapshot with a query hint and comparing it to the current table

The smoke test (`verify_test.py`) covers the canonical `test_db.users` demo from the quick start.

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
