# PANDUAN PENGUJIAN SISTEM BASIS DATA TERDISTRIBUSI
**Mata Kuliah:** Big Data Storage / Basis Data Terdistribusi  
**Arsitektur:** Replicated Sharding (Sharded Replica Sets), Broadcast Reference Tables, Routing HAProxy, dan Auto Failover Shard  

---

## 📋 Daftar Service, Port & Peran Sistem

| Service Docker | Host & Port | Peran / Deskripsi | Database / Kredensial |
| :--- | :--- | :--- | :--- |
| **`haproxy-lb`** | `localhost:5000` | Routing WRITE & Coordinator Gateway | `sales` / `postgres:postgres123` |
| **`haproxy-lb`** | `localhost:5001` | Routing READ (Load Balancing Round-Robin Replicas) | `sales` / `postgres:postgres123` |
| **`haproxy-lb`** | `http://localhost:7000` | Web Dashboard Monitoring Traffic & Nodes | Browser GUI (Tanpa login) |
| **`postgres-primary`** | `localhost:5432` | **Sharding Coordinator** (`postgres_fdw`) | `sales` / `postgres:postgres123` |
| **`postgres-shard1`** | `localhost:5435` | **Primary Shard 1** (Data Periode Lama + Reference Tables) | `sales` / `postgres:postgres123` |
| **`postgres-standby`** | `localhost:5433` | **Replica Shard 1** (Disinkronisasi via Streaming WAL Shard 1) | `sales` / `postgres:postgres123` |
| **`postgres-shard2`** | `localhost:5436` | **Primary Shard 2** (Data Periode Baru + Reference Tables) | `sales` / `postgres:postgres123` |
| **`postgres-standby-2`**| `localhost:5434` | **Replica Shard 2** (Disinkronisasi via Streaming WAL Shard 2) | `sales` / `postgres:postgres123` |
| **`failover-manager`** | *(Internal)* | Watchdog Pemantau & Auto-Failover Shard 1 | Script bash otomatis |

---

## 🚀 LANGKAH 0: Menjalankan Seluruh Service Docker

Buka PowerShell / CMD pada direktori `code/`, lalu jalankan:

```bash
# 1. Hentikan container lama dan hapus volume lama agar inisialisasi bersih:
docker compose down -v

# 2. Bangun dan jalankan seluruh container di background:
docker compose up -d

# 3. Periksa status seluruh container (pastikan semua status running/healthy):
docker compose ps
```

*Tunggu sekitar 15–25 detik hingga seluruh container selesai melakukan inisialisasi awal dan replikasi streaming.*

---

## 🧪 PENGUJIAN 1: Multi-Node Sharding & Partition Pruning

Tujuan: Membuktikan data transaksi fisik benar-benar disimpan di **dua container Shard yang terpisah**, namun dapat diakses secara transparan dan utuh melalui Coordinator.

### 1.1 Cek Langsung ke Dalam Shard 1 (Port 5435)
```bash
docker exec -it postgres-shard1 psql -U postgres -d sales -c "
SELECT COUNT(*) AS total_transaksi_lama_shard1 FROM orders_shard1;"
```
> **Hasil:** Menampilkan data transaksi periode historis (~500 baris).

### 1.2 Cek Langsung ke Dalam Shard 2 (Port 5436)
```bash
docker exec -it postgres-shard2 psql -U postgres -d sales -c "
SELECT COUNT(*) AS total_transaksi_baru_shard2 FROM orders_shard2;"
```
> **Hasil:** Menampilkan data transaksi periode baru (~500 baris).

### 1.3 Akses Transparan Melalui Coordinator (Port 5432)
```bash
docker exec -it postgres-primary psql -U postgres -d sales -c "
SELECT 
    tableoid::regclass AS nama_foreign_shard,
    COUNT(*) AS total_baris
FROM orders
GROUP BY tableoid
ORDER BY nama_foreign_shard;"
```
> **Hasil:** Coordinator menggabungkan data dari kedua container shard secara transparan (Total = 1.000 data).

### 1.4 Uji Partition Pruning (Hanya Menghubungi Shard yang Relevan)
```bash
docker exec -it postgres-primary psql -U postgres -d sales -c "
EXPLAIN ANALYZE 
SELECT * FROM orders 
WHERE order_date >= '2026-10-01';"
```
> **Hasil:** Query planner hanya mengirim *Remote SQL* ke `orders_shard2` (`postgres-shard2`) dan mengabaikan `orders_shard1`.

---

## 🧪 PENGUJIAN 2: Shard-Level Streaming Replication (Standby Mereplikasi Shard)

Tujuan: Membuktikan bahwa **Standby 1 mereplikasi Shard 1**, dan **Standby 2 mereplikasi Shard 2**.

### 2.1 Cek Status Replikasi di Shard 1 (Port 5435)
```bash
docker exec -it postgres-shard1 psql -U postgres -d sales -c "
SELECT application_name, client_addr, state, sync_state FROM pg_stat_replication;"
```
> **Hasil:** Muncul replica aktif `standby1` dengan status `streaming`.

### 2.2 Cek Status Replikasi di Shard 2 (Port 5436)
```bash
docker exec -it postgres-shard2 psql -U postgres -d sales -c "
SELECT application_name, client_addr, state, sync_state FROM pg_stat_replication;"
```
> **Hasil:** Muncul replica aktif `standby2` dengan status `streaming`.

### 2.3 Cek Status Pemulihan Read-Only di Standby 1 & 2 (Port 5433 & 5434)
```bash
docker exec -it postgres-standby psql -U postgres -d sales -c "SELECT pg_is_in_recovery() AS is_standby;"
docker exec -it postgres-standby-2 psql -U postgres -d sales -c "SELECT pg_is_in_recovery() AS is_standby;"
```
> **Hasil:** Keduanya mengembalikan nilai `t` (*True*), membuktikan keduanya adalah node replika streaming siaga.

---

## 🧪 PENGUJIAN 3: Reference Tables & Local Zero-Network JOINs

Tujuan: Membuktikan tabel master ada di setiap shard, memungkinkan query analitik berjalan 100% lokal di node replika.

### 3.1 Jalankan Script Analitik Standby 1 (Port 5433)
Jalankan query analitik yang melakukan `JOIN` tabel master dengan `orders`:
```bash
docker exec -it postgres-standby psql -U postgres -d sales -f /dev/stdin < standby1.sql
```
> **Hasil:** Query 1 & Query 2 berhasil dieksekusi **secara lokal** di Standby 1 tanpa perlu meminta data master dari Coordinator.

### 3.2 Jalankan Script Analitik Standby 2 (Port 5434)
```bash
docker exec -it postgres-standby-2 psql -U postgres -d sales -f /dev/stdin < standby2.sql
```
> **Hasil:** Query 3 & Query 4 berhasil dieksekusi **secara lokal** di Standby 2.

---

## 🧪 PENGUJIAN 4: Routing Read/Write via HAProxy

Tujuan: Membuktikan pemisahan traffic Write (ke Coordinator) dan Read (Load balanced ke Replicas).

### 4.1 Buka Web Dashboard HAProxy
Buka browser dan kunjungi:
👉 **[http://localhost:7000](http://localhost:7000)**  
*(Seluruh node berstatus HIJAU / UP).*

### 4.2 Uji Routing WRITE ke Coordinator (Port 5000)
```bash
docker exec -it postgres-primary psql -h haproxy -p 5000 -U postgres -d sales -c "
INSERT INTO orders (order_id, order_number, customer_id, order_date, status, total_amount)
VALUES (9999, 'ORD-TEST-HAPROXY', 1, '2026-10-18 10:00:00', 'Delivered', 125000);"
```
> **Hasil:** `INSERT 0 1` sukses. Data diteruskan oleh Coordinator ke Shard 2 dan langsung tersinkronkan ke Standby 2.

### 4.3 Uji Routing READ via HAProxy (Port 5001)
```bash
docker exec -it postgres-primary psql -h haproxy -p 5001 -U postgres -d sales -c "
SELECT category_id, category_name FROM categories LIMIT 3;"
```
> **Hasil:** Query berhasil dieksekusi secara Round-Robin oleh `postgres-standby` dan `postgres-standby-2`.

---

## 🧪 PENGUJIAN 5: Pengujian Auto Failover pada Shard

Tujuan: Membuktikan jika Shard 1 Primary mati, Standby 1 otomatis dipromosikan dan Coordinator secara otomatis mengalihkan koneksi ke Standby 1 tanpa downtime bagi klien.

### 5.1 Buka Log Failover Manager di Terminal 1
```bash
docker logs -f failover-manager
```

### 5.2 Matikan Shard 1 Primary di Terminal 2 (Simulasi Crash)
```bash
docker stop postgres-shard1
```

### 5.3 Amati Log Failover Otomatis
Pada terminal log `failover-manager`, amati proses:
```text
[Failover Manager] DETEKSI KEGAGALAN: postgres-shard1 tidak merespons!
[Failover Manager] Memulai PROSES AUTO FAILOVER SHARD 1...
[Failover Manager] 1. Mengirim perintah pg_promote() ke postgres-standby...
[Failover Manager] BERHASIL: postgres-standby sukses dipromosikan menjadi PRIMARY SHARD 1 BARU!
[Failover Manager] 2. Mengalihkan Coordinator (postgres-primary) ke postgres-standby...
[Failover Manager] SUKSES: Coordinator kini terhubung ke postgres-standby secara transparan!
```

### 5.4 Uji Akses Transparan Coordinator Pasca-Failover
Kirim query ke Coordinator (Port 5432 atau via HAProxy Port 5000):
```bash
docker exec -it postgres-primary psql -U postgres -d sales -c "
SELECT COUNT(*) FROM orders WHERE order_date < '2026-09-25';"
```
> **Hasil:** Data transaksi Shard 1 tetap terbaca dengan normal karena Coordinator telah dialihkan secara otomatis ke `postgres-standby`!

---

## 🧹 Langkah Pembersihan
```bash
docker compose down -v
```
