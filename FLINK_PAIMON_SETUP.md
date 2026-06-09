# Flink + Paimon Integration Guide

## Critical Setup Requirements

### 1. Docker Configuration
- **File Permissions**: Ensure `conf/config.yaml` has proper permissions (`chmod 644`)
- **Volume Mounts**: Mount config files directly, not directories
- **Health Checks**: Use proper health checks for service dependencies

### 2. Paimon Catalog Configuration
```sql
CREATE CATALOG paimon_catalog WITH (
    'type' = 'paimon',
    'warehouse' = 's3://warehouse/',  -- Must have trailing slash
    's3.endpoint' = 'http://minio:9000',
    's3.access-key' = 'admin',
    's3.secret-key' = 'password123',
    's3.path.style.access' = 'true'  -- Required for MinIO
);
```

### 3. Common Issues and Fixes

#### Permission Denied on config.yaml
- **Symptom**: `java.io.FileNotFoundException: /opt/flink/conf/config.yaml (Permission denied)`
- **Fix**: Run `chmod 644 conf/config.yaml` before starting containers

#### Warehouse Path Must Be Absolute
- **Symptom**: `java.lang.IllegalArgumentException: path must be absolute`
- **Fix**: Ensure warehouse path has trailing slash: `'warehouse' = 's3://warehouse/'`

#### SQL Client Execution Mode
- **Issue**: Queries fail in non-interactive mode
- **Fix**: For batch queries, use `SET execution.runtime-mode=batch;`
- **Note**: SET commands don't work in `-f` file mode with certain Flink versions

### 4. Testing Data Flow

#### Create Table with Primary Key
```sql
CREATE TABLE users (
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
```

#### Verify Data in MinIO
```bash
# Check warehouse structure
docker exec minio mc ls local/warehouse/test_db.db/users/

# Expected directories:
# - bucket-0/ bucket-1/ bucket-2/  (data buckets)
# - manifest/  (table manifests)
# - schema/    (table schema)
# - snapshot/  (data snapshots)

# Count data files
docker exec minio sh -c "mc ls --recursive local/warehouse/test_db.db/users/ | grep -c 'data-'"
```

### 5. Verification Checklist
- [ ] All containers running and healthy: `docker compose ps`
- [ ] Flink UI accessible: `http://localhost:8081`
- [ ] MinIO buckets created: `warehouse` and `checkpoints`
- [ ] Catalog creation succeeds without errors
- [ ] Data insertion jobs show as FINISHED in Flink UI
- [ ] Data files present in MinIO storage
- [ ] Multiple snapshots created after inserts/updates

### 6. Key Dependencies
- **Flink**: 1.19.3 (or compatible version)
- **Paimon**: 1.2.0 (must match Flink version compatibility)
- **Hadoop AWS**: Required for S3 filesystem support
- **Dockerfile must include**: Paimon JARs in `/opt/flink/lib/`

### 7. Important Notes
- Catalogs are session-scoped in SQL Client - recreate in each session
- Use `docker cp` to copy SQL files into containers for execution
- Monitor job status via Flink REST API: `curl http://localhost:8081/jobs`
- Check logs with: `docker compose logs [jobmanager|taskmanager]`