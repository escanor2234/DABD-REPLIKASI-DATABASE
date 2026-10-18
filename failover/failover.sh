#!/bin/bash
set -u

echo "=========================================================="
echo " [AUTO FAILOVER MANAGER] Watchdog Shard PostgreSQL Aktif"
echo "=========================================================="

PRIMARY_SHARD="${PRIMARY_SHARD:-postgres-shard1}"
STANDBY_SHARD="${STANDBY_SHARD:-postgres-standby}"
COORDINATOR_HOST="${COORDINATOR_HOST:-postgres-primary}"
DB_NAME="${POSTGRES_DB:-sales}"
USER="${POSTGRES_USER:-postgres}"
CHECK_INTERVAL=3
MAX_FAILS=3
FAIL_COUNT=0
PROMOTED=0

echo "[Failover Manager] Menunggu Node Primary Shard ($PRIMARY_SHARD) dan Coordinator ($COORDINATOR_HOST) siap..."
until pg_isready -h "$PRIMARY_SHARD" -p 5432 -U "$USER" -d "$DB_NAME" > /dev/null 2>&1 && \
      pg_isready -h "$COORDINATOR_HOST" -p 5432 -U "$USER" -d "$DB_NAME" > /dev/null 2>&1; do
  sleep 2
done
echo "[Failover Manager] Seluruh cluster siap. Memulai pemantauan detak jantung Shard 1..."

while true; do
  if [ $PROMOTED -eq 1 ]; then
    sleep 10
    continue
  fi

  if pg_isready -h "$PRIMARY_SHARD" -p 5432 -U "$USER" -d "$DB_NAME" > /dev/null 2>&1; then
    if [ $FAIL_COUNT -gt 0 ]; then
      echo "[Failover Manager] $PRIMARY_SHARD kembali normal."
      FAIL_COUNT=0
    fi
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
    echo "[Failover Manager] PERINGATAN: $PRIMARY_SHARD gagal dihubungi ($FAIL_COUNT/$MAX_FAILS)..."
    
    if [ $FAIL_COUNT -ge $MAX_FAILS ]; then
      echo "----------------------------------------------------------"
      echo "[Failover Manager] DETEKSI KEGAGALAN: $PRIMARY_SHARD tidak merespons!"
      echo "[Failover Manager] Memulai PROSES AUTO FAILOVER SHARD 1..."
      echo "[Failover Manager] 1. Mengirim perintah pg_promote() ke $STANDBY_SHARD..."
      echo "----------------------------------------------------------"
      
      export PGPASSWORD="${POSTGRES_PASSWORD:-postgres123}"
      psql -h "$STANDBY_SHARD" -p 5432 -U "$USER" -d "$DB_NAME" -c "SELECT pg_promote();"
      
      if [ $? -eq 0 ]; then
        echo "[Failover Manager] BERHASIL: $STANDBY_SHARD sukses dipromosikan menjadi PRIMARY SHARD 1 BARU!"
        echo "[Failover Manager] 2. Mengalihkan Coordinator ($COORDINATOR_HOST) ke $STANDBY_SHARD..."
        
        psql -h "$COORDINATOR_HOST" -p 5432 -U "$USER" -d "$DB_NAME" -c \
          "ALTER SERVER shard1_server OPTIONS (SET host '$STANDBY_SHARD');"
        
        if [ $? -eq 0 ]; then
          echo "[Failover Manager] SUKSES: Coordinator kini terhubung ke $STANDBY_SHARD secara transparan!"
          PROMOTED=1
        else
          echo "[Failover Manager] PERINGATAN: Gagal mengubah pointer FDW di Coordinator. Akan mencoba kembali..."
        fi
      else
        echo "[Failover Manager] ERROR: Gagal mempromosikan $STANDBY_SHARD. Akan mencoba kembali..."
      fi
    fi
  fi

  sleep $CHECK_INTERVAL
done
