#!/bin/bash
set -e

echo "Mengatur pg_hba.conf pada Coordinator..."
echo "host all all 0.0.0.0/0 scram-sha-256" >> "$PGDATA/pg_hba.conf"

echo "Coordinator selesai dikonfigurasi."