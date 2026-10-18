-- ====================================================================
-- SHARD NODE 2 SCHEMA & REFERENCE TABLES
-- Container: postgres-shard2 (Port 5436) / Replica: postgres-standby-2 (Port 5434)
-- Database: sales
-- Menyimpan: Reference Tables + Data Transaksi Periode Baru
-- ====================================================================

\i /docker-entrypoint-initdb.d/reference_tables.sql

-- 1. TABEL FISIK PARTISI SHARD 2
DROP TABLE IF EXISTS orders_shard2 CASCADE;
DROP TABLE IF EXISTS payments_shard2 CASCADE;

CREATE TABLE orders_shard2 (
    order_id INT,
    order_number VARCHAR(50),
    customer_id INT,
    employee_id INT,
    store_id INT,
    promotion_id INT,
    order_date TIMESTAMP NOT NULL,
    status VARCHAR(30),
    total_amount NUMERIC(14, 2)
);

CREATE TABLE payments_shard2 (
    payment_id INT,
    order_id INT,
    payment_date TIMESTAMP NOT NULL,
    payment_method VARCHAR(50),
    payment_status VARCHAR(30),
    amount NUMERIC(14, 2)
);

CREATE INDEX IF NOT EXISTS idx_orders_shard2_date ON orders_shard2(order_date);
CREATE INDEX IF NOT EXISTS idx_payments_shard2_date ON payments_shard2(payment_date);

-- 2. VIEW KOMPATIBILITAS QUERY LOKAL SHARD 2
-- Memungkinkan query analitik lokal langsung mengakses nama tabel 'orders' dan 'payments'
CREATE OR REPLACE VIEW orders AS SELECT * FROM orders_shard2;
CREATE OR REPLACE VIEW payments AS SELECT * FROM payments_shard2;
