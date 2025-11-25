ARG BASE_TAG
FROM docker.io/postgres:${BASE_TAG}

ENTRYPOINT [ "/autoconf-entrypoint" ]
CMD []

ENV CERTS="{}" \
    CONF_EXTRA="" \
    LAN_AUTH_METHOD=md5 \
    LAN_CONNECTION=host \
    LAN_DATABASES='["all"]' \
    LAN_HBA_TPL="{connection} {db} {user} {cidr} {meth}" \
    LAN_TLS=0 \
    LAN_USERS='["all"]' \
    WAN_AUTH_METHOD=cert \
    WAN_CONNECTION=hostssl \
    WAN_DATABASES='["all"]' \
    WAN_HBA_TPL="{connection} {db} {user} {cidr} {meth}" \
    WAN_TLS=1 \
    WAN_USERS='["all"]' \
    HBA_EXTRA_RULES=""

# Base runtime deps + pgvector (if available) + writable config dir
RUN set -eux; \
    apk add --no-cache python3 py3-netifaces; \
    if [ "${PG_MAJOR:-0}" -ge 12 ]; then \
        apk add --no-cache "postgresql${PG_MAJOR}-pgvector" || apk add --no-cache postgresql-pgvector || true; \
        if [ -d "/usr/share/postgresql${PG_MAJOR}/extension" ]; then \
            cp /usr/share/postgresql${PG_MAJOR}/extension/vector* /usr/local/share/postgresql/extension/; \
        elif [ -d "/usr/share/postgresql/extension" ]; then \
            cp /usr/share/postgresql/extension/vector* /usr/local/share/postgresql/extension/; \
        fi; \
        so_path=$(find /usr/lib -name vector.so | head -n 1); \
        if [ -n "${so_path}" ]; then \
            cp "${so_path}" /usr/local/lib/postgresql/; \
        fi; \
    fi; \
    mkdir -p /etc/postgres; \
    chmod a=rwx /etc/postgres

COPY autoconf-entrypoint /

# Optional pgxn extensions (best-effort to keep build working on new PG majors)
RUN set -eux; \
    apk add --no-cache -t .build \
        "postgresql${PG_MAJOR}-dev" "postgresql${PG_MAJOR}-contrib" \
        curl-dev libcurl \
        wget jq cmake build-base ca-certificates py3-pip pipx \
      || apk add --no-cache -t .build \
        postgresql-dev postgresql-contrib \
        curl-dev libcurl \
        wget jq cmake build-base ca-certificates py3-pip pipx; \
    pipx ensurepath; \
    export PATH="$PATH:/root/.local/bin"; \
    for ext in pg_qualstats pg_stat_kcache pg_track_settings powa postgresql_anonymizer; do \
        if ! pgxn install "$ext"; then \
            echo "WARN: skipping $ext (pgxn install failed)" >&2; \
        fi; \
    done; \
    apk del .build

# Metadata
ARG VCS_REF
ARG BUILD_DATE
LABEL org.label-schema.vendor=openspp \
      org.label-schema.license=Apache-2.0 \
      org.label-schema.build-date="$BUILD_DATE" \
      org.label-schema.vcs-ref="$VCS_REF" \
      org.label-schema.vcs-url="https://github.com/openspp/docker-postgres-autoconf"
