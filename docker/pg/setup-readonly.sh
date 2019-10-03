#!/bin/bash
set -e

if [ ! -s "$PGDATA/PG_VERSION" ]; then
    echo "*:*:*:$POSTGRES_REPLICATION_USER:$POSTGRES_REPLICATION_PASSWORD" > ~/.pgpass
    chmod 0600 ~/.pgpass
    until ping -c 1 -W 1 pg_primary
    do
        echo "Waiting for primary to ping..."
        sleep 1s
    done

    until pg_basebackup -h pg_primary -D ${PGDATA} -U ${POSTGRES_REPLICATION_USER} -vP -W
    do
        echo "Waiting for primary to connect..."
        sleep 1s
    done

    sed -i 's/wal_level = hot_standby/wal_level = replica/g' ${PGDATA}/postgresql.conf

    cat > ${PGDATA}/recovery.conf <<EOF
standby_mode = on
primary_conninfo = 'host=pg_primary port=5432 user=$POSTGRES_REPLICATION_USER password=$POSTGRES_REPLICATION_PASSWORD application_name=pg_readonly'
primary_slot_name = 'node_a_slot'
EOF

    chown postgres:postgres ${PGDATA} -R
    chmod 700 ${PGDATA} -R
fi