#!/bin/sh
# POSIX-compliant entrypoint. Ensure LF line endings and executable permissions.
set -eu

PGDATA="/var/lib/postgresql/data"
PATRONI_NAME="${PATRONI_NAME:-}"
ETCDCTL_ENDPOINTS="${ETCDCTL_ENDPOINTS:-http://172.29.65.52:2379}"

# Check if data directory is empty
if [ ! -d "$PGDATA" ] || [ "`ls -A "$PGDATA" 2>/dev/null`" = "" ]; then
    echo "Data directory is empty. Cleaning up."
    rm -f "$PGDATA"/postmaster.pid "$PGDATA"/backup_label.old "$PGDATA"/backup_label

    # Only patroni-1 cleans up etcd keys and starts Patroni immediately
    if [ "$PATRONI_NAME" = "patroni-1" ]; then
        if command -v etcdctl >/dev/null 2>&1; then
            echo "Cleaning up stale Patroni keys in etcd (only on patroni-1)..."
            etcdctl del --prefix /service/ || true
        fi
        echo "Starting Patroni on patroni-1 to bootstrap cluster."
    else
        # Other nodes wait for Patroni leader
        echo "Waiting for Patroni leader to bootstrap..."
        ATTEMPTS=0
        while true
        do
            if command -v etcdctl >/dev/null 2>&1; then
                LEADER=`etcdctl get /service/ --prefix | grep leader | head -n 1`
                if [ "${LEADER}" != "" ]; then
                    echo "Patroni leader found: $LEADER. Proceeding."
                    break
                fi
            fi
            ATTEMPTS=`expr $ATTEMPTS + 1`
            if [ "$ATTEMPTS" -ge 60 ]; then
                echo "Timeout waiting for Patroni leader. Exiting."
                exit 1
            fi
            sleep 2
        done
    fi
else
    echo "Data directory is not empty. Starting Patroni normally."
fi

# Optionally check etcd connectivity
if command -v etcdctl >/dev/null 2>&1; then
    echo "Checking etcd connectivity..."
    if ! etcdctl endpoint health; then
        echo "Warning: etcd endpoint not healthy. Patroni may retry."
    fi
fi

exec patroni /config/patroni.yml