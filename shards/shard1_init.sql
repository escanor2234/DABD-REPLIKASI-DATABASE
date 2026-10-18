-- ====================================================================
-- SHARD NODE 1 INITIALIZATION
-- Container: postgres-shard1 (Port 5435)
-- Database: sales_shard1
-- Menyimpan: Data Transaksi Historis / Periode Awal
-- ====================================================================

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

CREATE INDEX idx_orders_shard1_date ON orders_shard1(order_date);
CREATE INDEX idx_payments_shard1_date ON payments_shard1(payment_date);
