-- ====================================================================
-- FILE: test_verification.sql
-- SCRIPT PENGUJIAN TUGAS (PENDEKATAN 2: MULTI-NODE SHARDING DOCKER)
-- 1. Master-Slave Replication
-- 2. Multi-Node Sharding (Container postgres-shard1 & postgres-shard2)
-- 3. Routing Read/Write via HAProxy (Port 5000 / 5001)
-- 4. Auto Failover Watchdog
-- ====================================================================

-- ====================================================================
-- 1. VERIFIKASI REPLIKASI MASTER-SLAVE (Port 5432 atau 5000)
-- ====================================================================
SELECT 
    application_name,
    client_addr,
    state,
    sync_state,
    write_lag,
    flush_lag
FROM pg_stat_replication;

SELECT pg_is_in_recovery() AS is_standby;


-- ====================================================================
-- 2. VERIFIKASI MULTI-NODE SHARDING
-- ====================================================================
-- A. DARI COORDINATOR/MASTER (Port 5432):
-- Melihat data gabungan yang diroute secara transparan ke kedua container shard:
SELECT 
    tableoid::regclass AS nama_foreign_shard,
    COUNT(*) AS total_baris
FROM orders
GROUP BY tableoid
ORDER BY nama_foreign_shard;

-- B. PEMBUKTIAN PARTITION PRUNING (Hanya query ke Shard 2 container):
EXPLAIN ANALYZE
SELECT order_id, order_number, order_date, total_amount
FROM orders
WHERE order_date >= '2026-10-01 00:00:00';

-- ====================================================================
-- C. QUERY LANGSUNG KE CONTAINER FISIK MASING-MASING SHARD:
-- (Jalankan di port masing-masing container untuk membuktikan isolasi data)
-- --------------------------------------------------------------------
-- Di Terminal Shard 1 (Port 5435, Database sales_shard1):
-- SELECT COUNT(*) AS data_di_shard1 FROM orders_shard1;
--
-- Di Terminal Shard 2 (Port 5436, Database sales_shard2):
-- SELECT COUNT(*) AS data_di_shard2 FROM orders_shard2;


-- ====================================================================
-- 3. UJI ROUTING WRITE VIA HAPROXY (Port 5000)
-- ====================================================================
INSERT INTO categories (category_name, description)
VALUES ('Test Kategori via HAProxy', 'Uji routing port 5000');


-- ====================================================================
-- 4. UJI ROUTING READ VIA HAPROXY (Port 5001)
-- ====================================================================
SELECT category_id, category_name, created_at 
FROM categories 
ORDER BY category_id DESC 
LIMIT 5;
