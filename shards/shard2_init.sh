#!/bin/bash
set -e

echo "=========================================================="
echo " Inisialisasi Shard 2: Konfigurasi Replikasi & pg_hba.conf"
echo "=========================================================="

# 1. Konfigurasi pg_hba.conf untuk mengizinkan replikasi streaming
echo "host replication replicator 0.0.0.0/0 scram-sha-256" >> "$PGDATA/pg_hba.conf"
echo "host all all 0.0.0.0/0 scram-sha-256" >> "$PGDATA/pg_hba.conf"

# 2. Buat user replicator dan replication slot
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<'EOSQL'
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'replicator') THEN
        CREATE ROLE replicator WITH REPLICATION LOGIN PASSWORD 'replica123';
    END IF;
END
$$;

SELECT pg_create_physical_replication_slot('standby2')
WHERE NOT EXISTS (
    SELECT 1 FROM pg_replication_slots WHERE slot_name = 'standby2'
);
EOSQL

echo "Shard 2 replikasi siap dikonfigurasi."
