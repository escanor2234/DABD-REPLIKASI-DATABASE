-- ====================================================================
-- FILE: test_verification.sql
-- SCRIPT PENGUJIAN TUGAS (ARSITEKTUR SHARDED REPLICA SETS + REFERENCE TABLES)
-- 1. Shard-Level Streaming Replication (Standby 1 -> Shard 1, Standby 2 -> Shard 2)
-- 2. Multi-Node Sharding & Partition Pruning via Coordinator
-- 3. Reference Tables Verification (Zero-Network Local JOINs)
-- 4. Routing via HAProxy (Port 5000 & 5001)
-- ====================================================================

-- ====================================================================
-- 1. VERIFIKASI REPLIKASI STREAMING PADA LEVEL SHARD
-- ====================================================================
-- A. DARI SHARD 1 PRIMARY (Port 5435):
-- Memastikan Standby 1 aktif menerima streaming WAL dari Shard 1:
SELECT 
    application_name,
    client_addr,
    state,
    sync_state,
    write_lag
FROM pg_stat_replication;

-- B. DARI SHARD 2 PRIMARY (Port 5436):
-- Memastikan Standby 2 aktif menerima streaming WAL dari Shard 2:
SELECT 
    application_name,
    client_addr,
    state,
    sync_state,
    write_lag
FROM pg_stat_replication;

-- C. DARI REPLICA STANDBY 1 (Port 5433) & STANDBY 2 (Port 5434):
-- Memastikan node berstatus Read-Only Standby:
SELECT pg_is_in_recovery() AS is_standby;


-- ====================================================================
-- 2. VERIFIKASI REFERENCE TABLES PADA SHARD (BROADCAST TABLES)
-- ====================================================================
-- Membuktikan tabel master (customers, categories, products) ada di Shard:
SELECT 
    (SELECT COUNT(*) FROM categories) AS total_categories,
    (SELECT COUNT(*) FROM products) AS total_products,
    (SELECT COUNT(*) FROM customers) AS total_customers;


-- ====================================================================
-- 3. VERIFIKASI MULTI-NODE SHARDING DARI COORDINATOR (Port 5432)
-- ====================================================================
-- A. Melihat data gabungan orders yang didistribusikan ke kedua shard:
SELECT 
    tableoid::regclass AS nama_foreign_shard,
    COUNT(*) AS total_baris
FROM orders
GROUP BY tableoid
ORDER BY nama_foreign_shard;

-- B. PEMBUKTIAN PARTITION PRUNING (Query hanya diteruskan ke Shard 2):
EXPLAIN ANALYZE
SELECT order_id, order_number, order_date, total_amount
FROM orders
WHERE order_date >= '2026-10-01 00:00:00';


-- ====================================================================
-- 4. UJI ROUTING WRITE VIA HAPROXY (Port 5000)
-- ====================================================================
INSERT INTO categories (category_name, description)
VALUES ('Test Kategori via HAProxy', 'Uji routing write port 5000');


-- ====================================================================
-- 5. UJI ROUTING READ VIA HAPROXY (Port 5001)
-- ====================================================================
SELECT category_id, category_name, created_at 
FROM categories 
ORDER BY category_id DESC 
LIMIT 5;
