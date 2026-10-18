-- ====================================================================
-- FILE: standby1.sql
-- ANALYTIC QUERIES UNTUK STANDBY 1 (Port 5433)
-- Database: sales
-- ====================================================================

-- --------------------------------------------------------------------
-- QUERY 1 • Standby 1
-- Syarat: Gunakan JOIN + GROUP BY
-- Analisis: Total Pendapatan, Jumlah Produk Terjual, dan Frekuensi Order
--           berdasarkan Kategori Produk.
-- --------------------------------------------------------------------
SELECT 
    c.category_id,
    c.category_name,
    COUNT(DISTINCT o.order_id) AS total_orders,
    SUM(oi.quantity) AS total_quantity_sold,
    SUM(oi.subtotal) AS total_revenue,
    ROUND(AVG(oi.subtotal), 2) AS avg_revenue_per_item
FROM categories c
JOIN products p ON c.category_id = p.category_id
JOIN order_items oi ON p.product_id = oi.product_id
JOIN orders o ON oi.order_id = o.order_id
WHERE o.status != 'Cancelled'
GROUP BY c.category_id, c.category_name
ORDER BY total_revenue DESC;


-- --------------------------------------------------------------------
-- QUERY 2 • Standby 1
-- Syarat: Salah satu query di skema database
-- Analisis: Performa Penjualan Tiap Cabang Toko (Store Performance)
--           menghitung total transaksi, akumulasi nilai penjualan, 
--           dan rata-rata transaksi per toko.
-- --------------------------------------------------------------------
SELECT 
    s.store_id,
    s.store_name,
    s.city,
    COUNT(o.order_id) AS total_transactions,
    COALESCE(SUM(o.total_amount), 0) AS total_sales_amount,
    ROUND(COALESCE(AVG(o.total_amount), 0), 2) AS avg_transaction_amount
FROM stores s
LEFT JOIN orders o ON s.store_id = o.store_id
GROUP BY s.store_id, s.store_name, s.city
ORDER BY total_sales_amount DESC;
