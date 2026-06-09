FROM flink:1.20.4-java17

# Dependency versions and download location, kept as build args so they are
# easy to find and bump in one place. PAIMON_FLINK_MINOR must match the Flink
# minor version of the base image above.
ARG PAIMON_VERSION=1.4.1
ARG PAIMON_FLINK_MINOR=1.20
ARG HADOOP_UBER_VERSION=2.8.3-10.0
ARG MAVEN_BASE=https://repo1.maven.org/maven2

# Expected SHA-1 checksums published on Maven Central for each jar. The build
# fails if a download is corrupt, truncated, or replaced.
ARG PAIMON_FLINK_SHA1=951adaacf361b3d2e22ef7077019d0522527c2b1
ARG PAIMON_S3_SHA1=58068d37c72d5ddbb56cdbd48db69f9467bda5c5
ARG HADOOP_UBER_SHA1=5dd57b5d38965c0f70e3f63d2581755df6c296bb

# Download the Paimon and Hadoop jars, then verify them against the pinned
# checksums. curl -f makes an HTTP error page fail the build instead of being
# saved as a jar, and --retry rides out transient network blips.
RUN set -eux; \
    cd /opt/flink/lib; \
    curl -fL --retry 3 --retry-delay 2 -o paimon-flink-${PAIMON_FLINK_MINOR}-${PAIMON_VERSION}.jar \
      ${MAVEN_BASE}/org/apache/paimon/paimon-flink-${PAIMON_FLINK_MINOR}/${PAIMON_VERSION}/paimon-flink-${PAIMON_FLINK_MINOR}-${PAIMON_VERSION}.jar; \
    curl -fL --retry 3 --retry-delay 2 -o paimon-s3-${PAIMON_VERSION}.jar \
      ${MAVEN_BASE}/org/apache/paimon/paimon-s3/${PAIMON_VERSION}/paimon-s3-${PAIMON_VERSION}.jar; \
    curl -fL --retry 3 --retry-delay 2 -o flink-shaded-hadoop-2-uber-${HADOOP_UBER_VERSION}.jar \
      ${MAVEN_BASE}/org/apache/flink/flink-shaded-hadoop-2-uber/${HADOOP_UBER_VERSION}/flink-shaded-hadoop-2-uber-${HADOOP_UBER_VERSION}.jar; \
    printf '%s  %s\n' \
      "${PAIMON_FLINK_SHA1}" "paimon-flink-${PAIMON_FLINK_MINOR}-${PAIMON_VERSION}.jar" \
      "${PAIMON_S3_SHA1}" "paimon-s3-${PAIMON_VERSION}.jar" \
      "${HADOOP_UBER_SHA1}" "flink-shaded-hadoop-2-uber-${HADOOP_UBER_VERSION}.jar" \
      > jars.sha1; \
    sha1sum -c jars.sha1; \
    rm jars.sha1; \
    chown flink:flink paimon-*.jar flink-shaded-hadoop-*.jar; \
    ls -la paimon-* flink-shaded-hadoop-*

# Enable Flink's bundled S3 filesystem plugin so the cluster can write
# checkpoints to the MinIO 'checkpoints' bucket. The jar ships with the base
# image under /opt/flink/opt, so no extra download is needed.
RUN set -eux; \
    mkdir -p /opt/flink/plugins/s3-fs-hadoop; \
    cp /opt/flink/opt/flink-s3-fs-hadoop-*.jar /opt/flink/plugins/s3-fs-hadoop/
