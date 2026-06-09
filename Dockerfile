FROM flink:1.20.4-java17

# Dependency versions and download location, kept as build args so they are
# easy to find and bump in one place. PAIMON_FLINK_MINOR must match the Flink
# minor version of the base image above.
ARG PAIMON_VERSION=1.4.1
ARG PAIMON_FLINK_MINOR=1.20
ARG HADOOP_UBER_VERSION=2.8.3-10.0
ARG MAVEN_BASE=https://repo1.maven.org/maven2

# Expected SHA-512 checksums for each jar. The build fails if a download is
# corrupt, truncated, or replaced. Maven Central does not publish .sha512 for
# these artifacts, so the values are computed from the released jars (their
# .sha1 checksums were cross-checked against Maven Central when recorded).
ARG PAIMON_FLINK_SHA512=97b5b8dbff1c3ad44bae947fafc481e23378a053f730e83beba2320dc861633e62ee9d738bf1103497c89861a2b65a44779e91f0133819617916eb0261a8855a
ARG PAIMON_S3_SHA512=b52b07409c8dca20b4e8484a252d8a167f38798b36125d4c4d8df6a50d61ca30b2818d2202b178ab534285fcdda165efa56b7c8c85134d0438cf6c08f7364c11
ARG HADOOP_UBER_SHA512=c04d217fb53123054c58c5c492cc8d87e75aa72b798e3b4858757cb4d389ccd9866c224662a012e1e9b012c05e481372e2bbc97cd45746f924814733d864591f

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
      "${PAIMON_FLINK_SHA512}" "paimon-flink-${PAIMON_FLINK_MINOR}-${PAIMON_VERSION}.jar" \
      "${PAIMON_S3_SHA512}" "paimon-s3-${PAIMON_VERSION}.jar" \
      "${HADOOP_UBER_SHA512}" "flink-shaded-hadoop-2-uber-${HADOOP_UBER_VERSION}.jar" \
      > jars.sha512; \
    sha512sum -c jars.sha512; \
    rm jars.sha512; \
    chown flink:flink paimon-*.jar flink-shaded-hadoop-*.jar; \
    ls -la paimon-* flink-shaded-hadoop-*

# Enable Flink's bundled S3 filesystem plugin so the cluster can write
# checkpoints to the MinIO 'checkpoints' bucket. The jar ships with the base
# image under /opt/flink/opt, so no extra download is needed.
RUN set -eux; \
    mkdir -p /opt/flink/plugins/s3-fs-hadoop; \
    cp /opt/flink/opt/flink-s3-fs-hadoop-*.jar /opt/flink/plugins/s3-fs-hadoop/
