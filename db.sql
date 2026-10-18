-- ====================================================================
-- SKEMA BASIS DATA SALES (PENJUALAN) - 10 ENTITAS DENGAN DUMMY DATA
-- Big Data Storage - PostgreSQL
-- ====================================================================

-- 1. BERSIHKAN TABEL JIKA SUDAH ADA (IDEMPOTENT)
DROP TABLE IF EXISTS payments CASCADE;
DROP TABLE IF EXISTS order_items CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS promotions CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS employees CASCADE;
DROP TABLE IF EXISTS stores CASCADE;
DROP TABLE IF EXISTS customers CASCADE;
DROP TABLE IF EXISTS suppliers CASCADE;
DROP TABLE IF EXISTS categories CASCADE;

-- ====================================================================
-- DDL: PEMBUATAN 10 ENTITAS (TABLES)
-- ====================================================================

-- ENTITAS 1: categories (Kategori Produk)
CREATE TABLE categories (
    category_id SERIAL PRIMARY KEY,
    category_name VARCHAR(100) NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ENTITAS 2: suppliers (Pemasok Produk)
CREATE TABLE suppliers (
    supplier_id SERIAL PRIMARY KEY,
    supplier_name VARCHAR(150) NOT NULL,
    contact_name VARCHAR(100),
    email VARCHAR(100),
    phone VARCHAR(30),
    city VARCHAR(100),
    country VARCHAR(100) DEFAULT 'Indonesia',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ENTITAS 3: stores (Cabang / Toko Fisik)
CREATE TABLE stores (
    store_id SERIAL PRIMARY KEY,
    store_name VARCHAR(100) NOT NULL,
    city VARCHAR(100),
    state VARCHAR(100),
    postal_code VARCHAR(20),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ENTITAS 4: employees (Pegawai / Sales Representative)
CREATE TABLE employees (
    employee_id SERIAL PRIMARY KEY,
    store_id INT REFERENCES stores(store_id) ON DELETE SET NULL,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    phone VARCHAR(30),
    position VARCHAR(50),
    salary NUMERIC(12, 2),
    hire_date DATE DEFAULT CURRENT_DATE
);

-- ENTITAS 5: customers (Pelanggan)
CREATE TABLE customers (
    customer_id SERIAL PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    phone VARCHAR(30),
    address TEXT,
    city VARCHAR(100),
    country VARCHAR(100) DEFAULT 'Indonesia',
    loyalty_points INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ENTITAS 6: products (Produk yang Dijual)
CREATE TABLE products (
    product_id SERIAL PRIMARY KEY,
    product_name VARCHAR(150) NOT NULL,
    category_id INT REFERENCES categories(category_id) ON DELETE SET NULL,
    supplier_id INT REFERENCES suppliers(supplier_id) ON DELETE SET NULL,
    sku VARCHAR(50) UNIQUE NOT NULL,
    unit_price NUMERIC(12, 2) NOT NULL,
    cost_price NUMERIC(12, 2) NOT NULL,
    stock_quantity INT NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ENTITAS 7: promotions (Program Diskon / Promosi)
CREATE TABLE promotions (
    promotion_id SERIAL PRIMARY KEY,
    promo_code VARCHAR(50) UNIQUE NOT NULL,
    discount_percentage NUMERIC(5, 2) NOT NULL CHECK (discount_percentage >= 0 AND discount_percentage <= 100),
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    is_active BOOLEAN DEFAULT TRUE
);

-- ====================================================================
-- KONFIGURASI MULTI-NODE SHARDING DENGAN POSTGRES_FDW
-- Coordinator menghubungkan partisi ke Container Shard 1 & Shard 2
-- ====================================================================
CREATE EXTENSION IF NOT EXISTS postgres_fdw;

DROP SERVER IF EXISTS shard1_server CASCADE;
DROP SERVER IF EXISTS shard2_server CASCADE;

CREATE SERVER shard1_server
    FOREIGN DATA WRAPPER postgres_fdw
    OPTIONS (host 'postgres-shard1', port '5432', dbname 'sales_shard1');

CREATE SERVER shard2_server
    FOREIGN DATA WRAPPER postgres_fdw
    OPTIONS (host 'postgres-shard2', port '5432', dbname 'sales_shard2');

CREATE USER MAPPING FOR postgres
    SERVER shard1_server
    OPTIONS (user 'postgres', password 'postgres123');

CREATE USER MAPPING FOR postgres
    SERVER shard2_server
    OPTIONS (user 'postgres', password 'postgres123');

-- ENTITAS 8: orders (Header Transaksi Penjualan) - MULTI-NODE SHARDED TABLE
CREATE TABLE orders (
    order_id INT NOT NULL,
    order_number VARCHAR(50) NOT NULL,
    customer_id INT,
    employee_id INT,
    store_id INT,
    promotion_id INT,
    order_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(30) CHECK (status IN ('Pending', 'Processing', 'Shipped', 'Delivered', 'Cancelled')),
    total_amount NUMERIC(14, 2) DEFAULT 0.00
) PARTITION BY RANGE (order_date);

-- SHARD 1: Disimpan di Service Docker postgres-shard1 (Port 5435)
-- Menampung data order periode lama (< 2026-09-25)
CREATE FOREIGN TABLE orders_shard1
    PARTITION OF orders
    FOR VALUES FROM ('2025-01-01 00:00:00') TO ('2026-09-25 00:00:00')
    SERVER shard1_server
    OPTIONS (table_name 'orders_shard1');

-- SHARD 2: Disimpan di Service Docker postgres-shard2 (Port 5436)
-- Menampung data order periode baru (>= 2026-09-25)
CREATE FOREIGN TABLE orders_shard2
    PARTITION OF orders
    FOR VALUES FROM ('2026-09-25 00:00:00') TO ('2027-01-01 00:00:00')
    SERVER shard2_server
    OPTIONS (table_name 'orders_shard2');

-- Safety default partition lokal
CREATE TABLE orders_default PARTITION OF orders DEFAULT;

-- ENTITAS 9: order_items (Detail Item dalam Penjualan)
CREATE TABLE order_items (
    order_item_id SERIAL PRIMARY KEY,
    order_id INT NOT NULL,
    product_id INT REFERENCES products(product_id) ON DELETE RESTRICT,
    quantity INT NOT NULL CHECK (quantity > 0),
    unit_price NUMERIC(12, 2) NOT NULL,
    subtotal NUMERIC(14, 2) NOT NULL
);

-- ENTITAS 10: payments (Transaksi Pembayaran Pesanan) - MULTI-NODE SHARDED TABLE
CREATE TABLE payments (
    payment_id INT NOT NULL,
    order_id INT NOT NULL,
    payment_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    payment_method VARCHAR(50) CHECK (payment_method IN ('Credit Card', 'Bank Transfer', 'E-Wallet', 'Cash', 'QRIS')),
    payment_status VARCHAR(30) CHECK (payment_status IN ('Completed', 'Pending', 'Failed', 'Refunded')),
    amount NUMERIC(14, 2) NOT NULL
) PARTITION BY RANGE (payment_date);

-- SHARD 1: Disimpan di Service Docker postgres-shard1 (Port 5435)
CREATE FOREIGN TABLE payments_shard1
    PARTITION OF payments
    FOR VALUES FROM ('2025-01-01 00:00:00') TO ('2026-09-25 00:00:00')
    SERVER shard1_server
    OPTIONS (table_name 'payments_shard1');

-- SHARD 2: Disimpan di Service Docker postgres-shard2 (Port 5436)
CREATE FOREIGN TABLE payments_shard2
    PARTITION OF payments
    FOR VALUES FROM ('2026-09-25 00:00:00') TO ('2027-01-01 00:00:00')
    SERVER shard2_server
    OPTIONS (table_name 'payments_shard2');

-- Safety default partition lokal
CREATE TABLE payments_default PARTITION OF payments DEFAULT;

-- INDEXING UNTUK OPTIMASI PERFORMA QUERY / BIG DATA
CREATE INDEX idx_orders_id ON orders(order_id);
CREATE INDEX idx_orders_customer_id ON orders(customer_id);
CREATE INDEX idx_orders_order_date ON orders(order_date);
CREATE INDEX idx_order_items_order_id ON order_items(order_id);
CREATE INDEX idx_order_items_product_id ON order_items(product_id);
CREATE INDEX idx_products_category ON products(category_id);
CREATE INDEX idx_payments_id ON payments(payment_id);
CREATE INDEX idx_payments_order_id ON payments(order_id);

-- ====================================================================
-- DML: GENERATE DUMMY DATA (MENGGUNAKAN GENERATE_SERIES)
-- ====================================================================

-- 1. Insert Categories (50 records)
INSERT INTO categories (category_name, description)
SELECT 
    'Category ' || i,
    'Deskripsi untuk kategori produk kelompok ke-' || i
FROM generate_series(1, 50) i;

-- 2. Insert Suppliers (50 records)
INSERT INTO suppliers (supplier_name, contact_name, email, phone, city, country)
SELECT
    'Supplier ' || i || ' Corp',
    'PIC Sales ' || i,
    'supplier' || i || '@vendor.id',
    '+62812' || LPAD(i::text, 8, '0'),
    (ARRAY['Jakarta', 'Surabaya', 'Bandung', 'Medan', 'Semarang', 'Yogyakarta'])[1 + (i % 6)],
    'Indonesia'
FROM generate_series(1, 50) i;

-- 3. Insert Stores (20 records)
INSERT INTO stores (store_name, city, state, postal_code)
SELECT
    'Store Cabang ' || i,
    (ARRAY['Jakarta', 'Surabaya', 'Bandung', 'Medan', 'Semarang', 'Yogyakarta', 'Denpasar', 'Makassar'])[1 + (i % 8)],
    'Indonesia',
    LPAD((10000 + i)::text, 5, '0')
FROM generate_series(1, 20) i;

-- 4. Insert Employees (100 records)
INSERT INTO employees (store_id, first_name, last_name, email, phone, position, salary, hire_date)
SELECT
    1 + (i % 20),
    'Staff',
    'Pegawai_' || i,
    'employee' || i || '@retailsales.com',
    '+62811' || LPAD(i::text, 8, '0'),
    (ARRAY['Sales Associate', 'Cashier', 'Store Manager', 'Supervisor', 'Inventory Specialist'])[1 + (i % 5)],
    4500000 + (i % 15) * 500000,
    CURRENT_DATE - (i * 5)
FROM generate_series(1, 100) i;

-- 5. Insert Customers (1000 RECORDS)
INSERT INTO customers (first_name, last_name, email, phone, address, city, country, loyalty_points)
SELECT
    'Customer',
    'User_' || i,
    'customer' || i || '@example.com',
    '+62813' || LPAD(i::text, 8, '0'),
    'Jl. Penjualan Raya Blok ' || (i % 200 + 1),
    (ARRAY['Jakarta', 'Surabaya', 'Bandung', 'Medan', 'Semarang', 'Yogyakarta', 'Malang', 'Solo'])[1 + (i % 8)],
    'Indonesia',
    (i * 13) % 1000
FROM generate_series(1, 1000) i;

-- 6. Insert Products (1000 RECORDS)
INSERT INTO products (product_name, category_id, supplier_id, sku, unit_price, cost_price, stock_quantity)
SELECT
    'Sales Product #' || i,
    1 + (i % 50),
    1 + (i % 50),
    'SKU-' || LPAD(i::text, 6, '0'),
    (25000 + (i % 100) * 10000)::numeric,
    (18000 + (i % 100) * 8000)::numeric,
    50 + (i % 250)
FROM generate_series(1, 1000) i;

-- 7. Insert Promotions (20 records)
INSERT INTO promotions (promo_code, discount_percentage, start_date, end_date, is_active)
SELECT
    'PROMO' || LPAD(i::text, 3, '0'),
    (ARRAY[5.0, 10.0, 15.0, 20.0, 25.0, 50.0])[1 + (i % 6)],
    CURRENT_DATE - 30,
    CURRENT_DATE + 60,
    TRUE
FROM generate_series(1, 20) i;

-- 8. Insert Orders (1000 RECORDS) - Terdistribusi otomatis ke Container Shard 1 & Shard 2
INSERT INTO orders (order_id, order_number, customer_id, employee_id, store_id, promotion_id, order_date, status, total_amount)
SELECT
    i,
    'ORD-' || TO_CHAR(CURRENT_DATE, 'YYYYMMDD') || '-' || LPAD(i::text, 5, '0'),
    1 + (i % 1000),
    1 + (i % 100),
    1 + (i % 20),
    CASE WHEN (i % 3 = 0) THEN (1 + (i % 20)) ELSE NULL END,
    CURRENT_TIMESTAMP - (i || ' hours')::interval,
    (ARRAY['Delivered', 'Shipped', 'Processing', 'Pending', 'Cancelled'])[1 + (i % 5)],
    (1 + (i % 5)) * (25000 + (((i * 19) % 1000) % 100) * 10000)::numeric
FROM generate_series(1, 1000) i;

-- 9. Insert Order Items (1000 RECORDS)
INSERT INTO order_items (order_item_id, order_id, product_id, quantity, unit_price, subtotal)
SELECT
    i,
    i,
    1 + ((i * 19) % 1000),
    1 + (i % 5),
    (25000 + (((i * 19) % 1000) % 100) * 10000)::numeric,
    (1 + (i % 5)) * (25000 + (((i * 19) % 1000) % 100) * 10000)::numeric
FROM generate_series(1, 1000) i;

-- 10. Insert Payments (1000 RECORDS) - Terdistribusi otomatis ke Container Shard 1 & Shard 2
INSERT INTO payments (payment_id, order_id, payment_date, payment_method, payment_status, amount)
SELECT
    o.order_id,
    o.order_id,
    o.order_date + interval '10 minutes',
    (ARRAY['QRIS', 'Bank Transfer', 'Credit Card', 'E-Wallet', 'Cash'])[1 + (o.order_id % 5)],
    CASE WHEN o.status = 'Cancelled' THEN 'Failed' ELSE 'Completed' END,
    o.total_amount
FROM orders o;


