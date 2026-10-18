#!/bin/bash
set -u

echo "=========================================================="
echo " [AUTO FAILOVER MANAGER] Watchdog PostgreSQL Aktif"
echo "=========================================================="

PRIMARY_HOST="${PRIMARY_HOST:-postgres-primary}"
STANDBY_HOST="${STANDBY_HOST:-postgres-standby}"
DB_NAME="${POSTGRES_DB:-sales}"
USER="${POSTGRES_USER:-postgres}"
CHECK_INTERVAL=3
MAX_FAILS=3
FAIL_COUNT=0
PROMOTED=0

echo "[Failover Manager] Menunggu Node Primary ($PRIMARY_HOST) siap..."
until pg_isready -h "$PRIMARY_HOST" -p 5432 -U "$USER" -d "$DB_NAME" > /dev/null 2>&1; do
  sleep 2
done
echo "[Failover Manager] Node Primary siap. Memulai pemantauan detak jantung..."

while true; do
  if [ $PROMOTED -eq 1 ]; then
    # Standby sudah menjadi Primary baru
    sleep 10
    continue
  fi

  if pg_isready -h "$PRIMARY_HOST" -p 5432 -U "$USER" -d "$DB_NAME" > /dev/null 2>&1; then
    if [ $FAIL_COUNT -gt 0 ]; then
      echo "[Failover Manager] Primary kembali normal."
      FAIL_COUNT=0
    fi
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
    echo "[Failover Manager] PERINGATAN: Primary gagal dihubungi ($FAIL_COUNT/$MAX_FAILS)..."
    
    if [ $FAIL_COUNT -ge $MAX_FAILS ]; then
      echo "----------------------------------------------------------"
      echo "[Failover Manager] DETEKSI KEGAGALAN: Primary tidak merespons!"
      echo "[Failover Manager] Memulai PROSES AUTO FAILOVER..."
      echo "[Failover Manager] Mengirim perintah pg_promote() ke $STANDBY_HOST..."
      echo "----------------------------------------------------------"
      
      export PGPASSWORD="${POSTGRES_PASSWORD:-postgres123}"
      psql -h "$STANDBY_HOST" -p 5432 -U "$USER" -d "$DB_NAME" -c "SELECT pg_promote();"
      
      if [ $? -eq 0 ]; then
        echo "[Failover Manager] BERHASIL: $STANDBY_HOST sukses dipromosikan menjadi PRIMARY BARU!"
        echo "[Failover Manager] HAProxy akan otomatis mengalihkan WRITE ke node ini."
        PROMOTED=1
      else
        echo "[Failover Manager] ERROR: Gagal mempromosikan $STANDBY_HOST. Akan mencoba kembali..."
      fi
    fi
  fi

  sleep $CHECK_INTERVAL
done
