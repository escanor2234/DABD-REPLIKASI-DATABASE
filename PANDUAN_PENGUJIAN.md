# PANDUAN PENGUJIAN SISTEM BASIS DATA TERDISTRIBUSI
**Mata Kuliah:** Big Data Storage / Basis Data Terdistribusi  
**Arsitektur:** Pendekatan 2 - Multi-Node Sharding Docker Container, Master-Slave Streaming Replication, Routing HAProxy, dan Auto Failover  

---

## 📋 Daftar Service, Port & Peran Sistem

| Service Docker | Host & Port | Peran / Deskripsi | Database / Kredensial |
| :--- | :--- | :--- | :--- |
| **`haproxy-lb`** | `localhost:5000` | Routing WRITE (Meneruskan ke Master aktif) | `sales` / `postgres:postgres123` |
| **`haproxy-lb`** | `localhost:5001` | Routing READ (Load Balancing Round-Robin Slaves) | `sales` / `postgres:postgres123` |
| **`haproxy-lb`** | `http://localhost:7000` | Web Dashboard Monitoring Cluster & Traffic | Browser GUI (Tanpa login) |
| **`postgres-primary`** | `localhost:5432` | Master & Coordinator Node (`postgres_fdw`) | `sales` / `postgres:postgres123` |
| **`postgres-standby`** | `localhost:5433` | Replica 1 (Disinkronisasi via Streaming WAL) | `sales` / `postgres:postgres123` |
| **`postgres-standby-2`**| `localhost:5434` | Replica 2 (Disinkronisasi via Streaming WAL) | `sales` / `postgres:postgres123` |
| **`postgres-shard1`** | `localhost:5435` | **Dedicated Shard Node 1 Container** | `sales_shard1` / `postgres:postgres123` |
| **`postgres-shard2`** | `localhost:5436` | **Dedicated Shard Node 2 Container** | `sales_shard2` / `postgres:postgres123` |
| **`failover-manager`** | *(Internal)* | Watchdog Pemantau & Pemicu Auto Failover | Script bash otomatis |

---

## 🚀 LANGKAH 0: Menjalankan Seluruh Service Docker

Buka PowerShell / CMD pada direktori `code/`, lalu jalankan:

```bash
# 1. Hentikan container lama dan hapus volume lama agar inisialisasi bersih:
docker compose down -v

# 2. Bangun dan jalankan seluruh container secara asynchronous di background:
docker compose up -d

# 3. Periksa status seluruh container (pastikan semua berjalan / healthy):
docker compose ps
```

*Tunggu sekitar 15–20 detik hingga container shard, primary, dan standby selesai melakukan inisialisasi dan sinkronisasi awal.*

---

## 🧪 PENGUJIAN 1: Multi-Node Sharding (Buktinya Tersebar di Container Terpisah)

Tujuan: Membuktikan bahwa data transaksi fisik benar-benar disimpan pada **dua container Docker shard yang terpisah secara fisik** (`postgres-shard1` dan `postgres-shard2`), namun dapat diakses secara transparan dan utuh melalui Coordinator / Master.

### 1.1 Cek Langsung ke Dalam Container Fisik Shard 1 (Port 5435)
Jalankan query langsung ke container `postgres-shard1`:
```bash
docker exec -it postgres-shard1 psql -U postgres -d sales_shard1 -c "
SELECT COUNT(*) AS total_data_di_container_shard1 FROM orders_shard1;"
```
> **Hasil:** Menampilkan data transaksi periode lama (~500 baris).

### 1.2 Cek Langsung ke Dalam Container Fisik Shard 2 (Port 5436)
Jalankan query langsung ke container `postgres-shard2`:
```bash
docker exec -it postgres-shard2 psql -U postgres -d sales_shard2 -c "
SELECT COUNT(*) AS total_data_di_container_shard2 FROM orders_shard2;"
```
> **Hasil:** Menampilkan data transaksi periode baru (~500 baris).

### 1.3 Akses Transparan Melalui Coordinator / Primary (Port 5432)
Jalankan query ke tabel induk `orders` di Node Primary:
```bash
docker exec -it postgres-primary psql -U postgres -d sales -c "
SELECT 
    tableoid::regclass AS nama_foreign_shard,
    COUNT(*) AS total_baris
FROM orders
GROUP BY tableoid
ORDER BY nama_foreign_shard;"
```
> **Hasil:** Coordinator menggabungkan data dari kedua container foreign shard secara transparan (Total = 1.000 data).

### 1.4 Uji Partition Pruning (Hanya Menghubungi Container yang Relevan)
```bash
docker exec -it postgres-primary psql -U postgres -d sales -c "
EXPLAIN ANALYZE 
SELECT * FROM orders 
WHERE order_date >= '2026-10-01';"
```
> **Hasil:** Engine hanya mengirim *Remote SQL* ke `orders_shard2` (`postgres-shard2`) dan tidak menghubungi `orders_shard1`.

---

## 🧪 PENGUJIAN 2: Verifikasi Replikasi Master-Slave

Tujuan: Membuktikan bahwa skema basis data terdistribusi dan metadata foreign server telah direplikasi secara realtime ke Standby 1 dan Standby 2.

### 2.1 Cek Status Replikasi di Node Master (Port 5432)
```bash
docker exec -it postgres-primary psql -U postgres -d sales -c "
SELECT 
    application_name,
    client_addr,
    state,
    sync_state,
    write_lag
FROM pg_stat_replication;"
```
> **Hasil:** Muncul 2 replica aktif (`standby1` dan `standby2`) dengan status `streaming`.

### 2.2 Uji Query Sharding Melalui Node Replica (Port 5433 / 5434)
Karena metadata direplikasi, node replica juga bisa membaca data dari container shard:
```bash
docker exec -it postgres-standby psql -U postgres -d sales -c "SELECT COUNT(*) FROM orders;"
```
> **Hasil:** Menghasilkan nilai 1000 data, membuktikan read-replica dapat mengakses multi-node shard.

---

## 🧪 PENGUJIAN 3: Routing Read/Write via HAProxy

Tujuan: Membuktikan pemisahan traffic Write (ke Master) dan Read (Load balanced ke Slaves).

### 3.1 Buka Web Dashboard HAProxy
Buka browser Anda dan akses:
👉 **[http://localhost:7000](http://localhost:7000)**
*(Seluruh node backend berstatus HIJAU / UP).*

### 3.2 Uji Routing WRITE (Port 5000)
Kirim query `INSERT` transaksi baru melalui port **5000**:
```bash
docker exec -it postgres-primary psql -h haproxy -p 5000 -U postgres -d sales -c "
INSERT INTO orders (order_id, order_number, customer_id, order_date, status, total_amount)
VALUES (9999, 'ORD-TEST-HAPROXY', 1, '2026-10-18 10:00:00', 'Delivered', 125000);"
```
> **Hasil:** `INSERT 0 1` berhasil! Karena `order_date` adalah Oktober 2026, data ini otomatis diteruskan oleh HAProxy ke Master, lalu Master meneruskannya ke container `postgres-shard2`.

### 3.3 Uji Routing READ (Port 5001)
Baca transaksi tersebut melalui port **5001**:
```bash
docker exec -it postgres-primary psql -h haproxy -p 5001 -U postgres -d sales -c "
SELECT order_id, order_number, order_date, total_amount FROM orders WHERE order_id = 9999;"
```
> **Hasil:** Data terbaca dari salah satu node replica secara otomatis (*Round-Robin load balanced*).

### 3.4 Uji Keamanan Port READ (Harus Menolak Write)
```bash
docker exec -it postgres-primary psql -h haproxy -p 5001 -U postgres -d sales -c "
INSERT INTO categories (category_name) VALUES ('Test Gagal');"
```
> **Hasil:** Menghasilkan error:
> `ERROR: cannot execute INSERT in a read-only transaction`

---

## 🧪 PENGUJIAN 4: Pengujian Auto Failover

Tujuan: Membuktikan cluster otomatis mempromosikan Standby 1 menjadi Master baru saat Primary crash/down.

### 4.1 Buka Log Failover Manager di Terminal 1
Buka satu terminal untuk memantau log watchdog:
```bash
docker logs -f failover-manager
```

### 4.2 Matikan Node Master (Simulasi Crash)
Di terminal utama, hentikan container `postgres-primary`:
```bash
docker stop postgres-primary
```

### 4.3 Amati Deteksi & Promosi Otomatis
Pada terminal log `failover-manager`, amati pesan otomatis:
```text
[Failover Manager] DETEKSI KEGAGALAN: Primary tidak merespons!
[Failover Manager] Memulai PROSES AUTO FAILOVER...
[Failover Manager] Mengirim perintah pg_promote() ke postgres-standby...
[Failover Manager] BERHASIL: postgres-standby sukses dipromosikan menjadi PRIMARY BARU!
```

### 4.4 Uji Kirim WRITE ke Port 5000 Pasca-Failover
Kirim data baru ke port HAProxy **5000**:
```bash
docker exec -it postgres-standby psql -h haproxy -p 5000 -U postgres -d sales -c "
INSERT INTO categories (category_name, description) 
VALUES ('Kategori Saat Primary Down', 'Berhasil masuk ke Master baru!');"
```
> **Hasil:** `INSERT 0 1` (Berhasil). HAProxy otomatis mengalihkan koneksi ke `postgres-standby` yang kini menjadi Master baru.

### 4.5 Cek Perubahan Status di Web GUI HAProxy
Buka kembali **`http://localhost:7000`**:
* Node `pg_primary` berstatus **MERAH (DOWN)**.
* Node `pg_standby1` otomatis mengambil alih traffic write.

---

## 🧹 Langkah Pembersihan
```bash
docker compose down -v
```
