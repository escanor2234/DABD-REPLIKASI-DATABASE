-- ====================================================================
-- FILE: bonus.sql
-- QUERY 5 • BONUS
-- Syarat: Menggunakan CASE, SUM, GROUP BY
-- Database: sales
-- ====================================================================

-- --------------------------------------------------------------------
-- QUERY 5 • Bonus
-- Analisis: Ringkasan Kinerja Penjualan berdasarkan Status Transaksi & Promosi.
--           Membedakan pendapatan sukses (Delivered/Shipped), potensi rugi 
--           akibat transaksi dibatalkan (Cancelled), dan pesanan yang tertunda 
--           (Pending/Processing) menggunakan teknik Conditional Aggregation.
-- --------------------------------------------------------------------
SELECT 
    COALESCE(pr.promo_code, 'REGULER (TANPA PROMO)') AS promo_campaign,
    COUNT(o.order_id) AS total_orders,
    
    -- 1. SUM + CASE: Menghitung total omset yang berhasil dikirim/diterima
    SUM(
        CASE 
            WHEN o.status IN ('Delivered', 'Shipped') THEN o.total_amount 
            ELSE 0 
        END
    ) AS successful_revenue,
    
    -- 2. SUM + CASE: Menghitung nilai transaksi yang batal (Lost Opportunity)
    SUM(
        CASE 
            WHEN o.status = 'Cancelled' THEN o.total_amount 
            ELSE 0 
        END
    ) AS cancelled_revenue,
    
    -- 3. SUM + CASE: Menghitung nilai transaksi yang masih dalam proses
    SUM(
        CASE 
            WHEN o.status IN ('Pending', 'Processing') THEN o.total_amount 
            ELSE 0 
        END
    ) AS pending_revenue,
    
    -- 4. SUM: Total kotor keseluruhan
    SUM(o.total_amount) AS total_gross_amount,

    -- 5. CASE + SUM: Tingkat persentase transaksi sukses
    ROUND(
        (SUM(CASE WHEN o.status IN ('Delivered', 'Shipped') THEN 1 ELSE 0 END)::numeric / COUNT(o.order_id)) * 100, 
        2
    ) AS success_rate_percentage

FROM orders o
LEFT JOIN promotions pr ON o.promotion_id = pr.promotion_id
GROUP BY pr.promo_code
ORDER BY successful_revenue DESC;
