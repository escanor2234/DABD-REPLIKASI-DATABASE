-- ====================================================================
-- SHARD NODE 1 SCHEMA & REFERENCE TABLES
-- Container: postgres-shard1 (Port 5435) / Replica: postgres-standby (Port 5433)
-- Database: sales
-- Menyimpan: Reference Tables + Data Transaksi Periode Lama
-- ====================================================================

\i /docker-entrypoint-initdb.d/reference_tables.sql

-- 1. TABEL FISIK PARTISI SHARD 1
DROP TABLE IF EXISTS orders_shard1 CASCADE;
DROP TABLE IF EXISTS payments_shard1 CASCADE;

CREATE TABLE orders_shard1 (
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

CREATE TABLE payments_shard1 (
    payment_id INT,
    order_id INT,
    payment_date TIMESTAMP NOT NULL,
    payment_method VARCHAR(50),
    payment_status VARCHAR(30),
    amount NUMERIC(14, 2)
);

CREATE INDEX IF NOT EXISTS idx_orders_shard1_date ON orders_shard1(order_date);
CREATE INDEX IF NOT EXISTS idx_payments_shard1_date ON payments_shard1(payment_date);

-- 2. VIEW KOMPATIBILITAS QUERY LOKAL SHARD 1
-- Memungkinkan query analitik lokal langsung mengakses nama tabel 'orders' dan 'payments'
CREATE OR REPLACE VIEW orders AS SELECT * FROM orders_shard1;
CREATE OR REPLACE VIEW payments AS SELECT * FROM payments_shard1;
