-- ====================================================================
-- REFERENCE TABLES (BROADCAST TABLES)
-- Tabel master referensi yang disalin ke seluruh node shard
-- untuk mendukung Local Zero-Network JOINs.
-- ====================================================================

-- 1. categories
CREATE TABLE IF NOT EXISTS categories (
    category_id SERIAL PRIMARY KEY,
    category_name VARCHAR(100) NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. suppliers
CREATE TABLE IF NOT EXISTS suppliers (
    supplier_id SERIAL PRIMARY KEY,
    supplier_name VARCHAR(150) NOT NULL,
    contact_name VARCHAR(100),
    email VARCHAR(100),
    phone VARCHAR(30),
    city VARCHAR(100),
    country VARCHAR(100) DEFAULT 'Indonesia',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 3. stores
CREATE TABLE IF NOT EXISTS stores (
    store_id SERIAL PRIMARY KEY,
    store_name VARCHAR(100) NOT NULL,
    city VARCHAR(100),
    state VARCHAR(100),
    postal_code VARCHAR(20),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 4. employees
CREATE TABLE IF NOT EXISTS employees (
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

-- 5. customers
CREATE TABLE IF NOT EXISTS customers (
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

-- 6. products
CREATE TABLE IF NOT EXISTS products (
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

-- 7. promotions
CREATE TABLE IF NOT EXISTS promotions (
    promotion_id SERIAL PRIMARY KEY,
    promo_code VARCHAR(50) UNIQUE NOT NULL,
    discount_percentage NUMERIC(5, 2) NOT NULL CHECK (discount_percentage >= 0 AND discount_percentage <= 100),
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    is_active BOOLEAN DEFAULT TRUE
);

-- 8. order_items
CREATE TABLE IF NOT EXISTS order_items (
    order_item_id SERIAL PRIMARY KEY,
    order_id INT NOT NULL,
    product_id INT REFERENCES products(product_id) ON DELETE RESTRICT,
    quantity INT NOT NULL CHECK (quantity > 0),
    unit_price NUMERIC(12, 2) NOT NULL,
    subtotal NUMERIC(14, 2) NOT NULL
);

-- ====================================================================
-- POPULATE DATA REFERENSI (HANYA JIKA MASIH KOSONG)
-- ====================================================================
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM categories LIMIT 1) THEN
        -- 1. Insert Categories (50 records)
        INSERT INTO categories (category_name, description)
        SELECT 'Category ' || i, 'Deskripsi kategori ke-' || i FROM generate_series(1, 50) i;

        -- 2. Insert Suppliers (50 records)
        INSERT INTO suppliers (supplier_name, contact_name, email, phone, city, country)
        SELECT 'Supplier ' || i || ' Corp', 'PIC Sales ' || i, 'supplier' || i || '@vendor.id',
               '+62812' || LPAD(i::text, 8, '0'),
               (ARRAY['Jakarta', 'Surabaya', 'Bandung', 'Medan', 'Semarang', 'Yogyakarta'])[1 + (i % 6)],
               'Indonesia'
        FROM generate_series(1, 50) i;

        -- 3. Insert Stores (20 records)
        INSERT INTO stores (store_name, city, state, postal_code)
        SELECT 'Store Cabang ' || i,
               (ARRAY['Jakarta', 'Surabaya', 'Bandung', 'Medan', 'Semarang', 'Yogyakarta', 'Denpasar', 'Makassar'])[1 + (i % 8)],
               'Indonesia', LPAD((10000 + i)::text, 5, '0')
        FROM generate_series(1, 20) i;

        -- 4. Insert Employees (100 records)
        INSERT INTO employees (store_id, first_name, last_name, email, phone, position, salary, hire_date)
        SELECT 1 + (i % 20), 'Staff', 'Pegawai_' || i, 'employee' || i || '@retailsales.com',
               '+62811' || LPAD(i::text, 8, '0'),
               (ARRAY['Sales Associate', 'Cashier', 'Store Manager', 'Supervisor', 'Inventory Specialist'])[1 + (i % 5)],
               4500000 + (i % 15) * 500000, CURRENT_DATE - (i * 5)
        FROM generate_series(1, 100) i;

        -- 5. Insert Customers (1000 records)
        INSERT INTO customers (first_name, last_name, email, phone, address, city, country, loyalty_points)
        SELECT 'Customer', 'User_' || i, 'customer' || i || '@example.com',
               '+62813' || LPAD(i::text, 8, '0'), 'Jl. Penjualan Raya Blok ' || (i % 200 + 1),
               (ARRAY['Jakarta', 'Surabaya', 'Bandung', 'Medan', 'Semarang', 'Yogyakarta', 'Malang', 'Solo'])[1 + (i % 8)],
               'Indonesia', (i * 13) % 1000
        FROM generate_series(1, 1000) i;

        -- 6. Insert Products (1000 records)
        INSERT INTO products (product_name, category_id, supplier_id, sku, unit_price, cost_price, stock_quantity)
        SELECT 'Sales Product #' || i, 1 + (i % 50), 1 + (i % 50), 'SKU-' || LPAD(i::text, 6, '0'),
               (25000 + (i % 100) * 10000)::numeric, (18000 + (i % 100) * 8000)::numeric, 50 + (i % 250)
        FROM generate_series(1, 1000) i;

        -- 7. Insert Promotions (20 records)
        INSERT INTO promotions (promo_code, discount_percentage, start_date, end_date, is_active)
        SELECT 'PROMO' || LPAD(i::text, 3, '0'),
               (ARRAY[5.0, 10.0, 15.0, 20.0, 25.0, 50.0])[1 + (i % 6)],
               CURRENT_DATE - 30, CURRENT_DATE + 60, TRUE
        FROM generate_series(1, 20) i;

        -- 8. Insert Order Items (1000 records)
        INSERT INTO order_items (order_item_id, order_id, product_id, quantity, unit_price, subtotal)
        SELECT i, i, 1 + ((i * 19) % 1000), 1 + (i % 5),
               (25000 + (((i * 19) % 1000) % 100) * 10000)::numeric,
               (1 + (i % 5)) * (25000 + (((i * 19) % 1000) % 100) * 10000)::numeric
        FROM generate_series(1, 1000) i;
    END IF;
END
$$;
