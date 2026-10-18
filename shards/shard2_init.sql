-- ====================================================================
-- SHARD NODE 2 INITIALIZATION
-- Container: postgres-shard2 (Port 5436)
-- Database: sales_shard2
-- Menyimpan: Data Transaksi Periode Terkini / Terbaru
-- ====================================================================

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

CREATE INDEX idx_orders_shard2_date ON orders_shard2(order_date);
CREATE INDEX idx_payments_shard2_date ON payments_shard2(payment_date);
