-- ====================================================================
-- FILE: standby2.sql
-- ANALYTIC QUERIES UNTUK STANDBY 2 (Port 5434)
-- Database: sales (dan opsi database postgres)
-- ====================================================================

-- --------------------------------------------------------------------
-- QUERY 3 • Standby 2
-- Syarat: Gunakan COUNT dan ORDER BY
-- Analisis: Persebaran Pelanggan dan Volume Order Berhasil Berdasarkan Kota
--           (Melihat kota mana dengan aktivitas belanja tertinggi).
-- --------------------------------------------------------------------
SELECT 
    c.city,
    COUNT(o.order_id) AS total_delivered_orders,
    COUNT(DISTINCT c.customer_id) AS total_active_customers
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
WHERE o.status = 'Delivered'
GROUP BY c.city
ORDER BY total_delivered_orders DESC;


-- --------------------------------------------------------------------
-- QUERY 4 • Standby 2
-- Syarat: Query di database/topik yang berbeda dengan standby 1
-- Analisis: Analisis Finansial, Metode Pembayaran (QRIS, CC, Transfer, dll),
--           dan Tingkat Keberhasilan Transaksi Pembayaran.
-- --------------------------------------------------------------------
SELECT 
    p.payment_method,
    p.payment_status,
    COUNT(p.payment_id) AS total_payment_records,
    SUM(p.amount) AS total_collected_amount,
    ROUND(AVG(p.amount), 2) AS avg_payment_amount
FROM payments p
GROUP BY p.payment_method, p.payment_status
ORDER BY total_collected_amount DESC;


-- --------------------------------------------------------------------
-- OPSI TAMBAHAN QUERY 4 (Jika dosen bermaksud query ke database 'postgres'):
-- Dijalankan pada: psql -U postgres -d postgres
-- Analisis: Monitoring aktivitas kluster database dan ukuran database.
-- --------------------------------------------------------------------
-- SELECT 
--     datname AS database_name,
--     pg_size_pretty(pg_database_size(datname)) AS disk_size,
--     numbackends AS active_connections,
--     xact_commit AS total_commits,
--     xact_rollback AS total_rollbacks
-- FROM pg_stat_database
-- WHERE datname IN ('sales', 'postgres')
-- ORDER BY pg_database_size(datname) DESC;
