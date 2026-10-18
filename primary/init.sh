#!/bin/bash

set -e

echo "Membuat replication user..."

psql \
  -v ON_ERROR_STOP=1 \
  --username "$POSTGRES_USER" \
  --dbname "$POSTGRES_DB" \
  --set=repl_user="$REPLICATION_USER" \
  --set=repl_password="$REPLICATION_PASSWORD" <<'EOSQL'

CREATE ROLE :"repl_user"
WITH
    REPLICATION
    LOGIN
    PASSWORD :'repl_password';

SELECT pg_create_physical_replication_slot('standby1');
SELECT pg_create_physical_replication_slot('standby2');


EOSQL

echo "Mengatur pg_hba.conf..."

echo "host replication $REPLICATION_USER 0.0.0.0/0 scram-sha-256" \
>> "$PGDATA/pg_hba.conf"

echo "Primary selesai dikonfigurasi."