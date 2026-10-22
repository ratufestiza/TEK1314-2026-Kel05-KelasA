# IP Plan - Kelompok 5

**Mata Kuliah:** TEK1314 Keamanan Siber (D4 Teknologi Rekayasa Komputer)
**Proyek:** PBL Skenario 05 Internal Database Fortress
**Segmen Kelompok:** 192.168.5.0/24
**Tanggal:** September 2026, diperbarui 19 Oktober 2026 setelah implementasi

---

## 1. Skenario

Kelompok 5 membangun lingkungan uji keamanan yang terdiri dari tiga entitas: **Attacker Node**, **Target Node**, dan **Monitoring Node**.

Target Node bukan sistem produksi mitra, melainkan **replika tech stack** produk IoT kelompok, yaitu sistem monitoring kandang ayam berbasis ESP32 yang pada aslinya memakai Firebase Realtime Database. Pada replika, layanan tersebut berdiri sendiri sehingga dapat diperiksa dan diperketat: SSH, dashboard web Flask, broker MQTT, dan basis data MySQL. Seluruh data bersifat dummy.

Topologi yang dipakai adalah star topology dalam satu segmen LAN 192.168.5.0/24 yang terisolasi, sehingga pengujian tidak menyentuh jaringan kampus maupun sistem mitra.

---

## 2. Tabel IP Plan

| No | Hostname | Peran | IP Address | Subnet Mask | OS |
|----|----------|-------|------------|-------------|-----|
| 1 | Target-Node-K05 | Target Node | 192.168.5.5 | 255.255.255.0 | Ubuntu Server 26.04 LTS, kernel 7.0.0-38-generic |
| 2 | Attacker-Node-K05 | Attacker Node | 192.168.5.100 | 255.255.255.0 | Cybersecurity LabVM, Ubuntu 22.04 dengan tools pengujian |
| 3 | Monitoring-Node-K05 | Monitoring Node | 192.168.5.200 | 255.255.255.0 | CyberOps Security Onion |

**Subnet Mask:** 255.255.255.0
**Alokasi:** Statis seluruhnya, tanpa DHCP, agar alamat tidak berubah saat pengujian dan pemantauan.
**Gateway:** Dikosongkan karena topologi tidak memakai router. Ketiga node berada pada satu segmen layer 2.
**Switch:** pada implementasi VirtualBox, segmen dibentuk oleh jaringan internal `pbl5-lan`. Switch 2960 pada diagram hanya representasi visual, tidak memiliki alamat IP.

---

## 3. Blok Alokasi Alamat

| Rentang | Peruntukan |
|---------|------------|
| 192.168.5.1 - 192.168.5.9 | Infrastruktur jaringan |
| 192.168.5.10 - 192.168.5.49 | Server target dan layanan |
| 192.168.5.50 - 192.168.5.99 | Cadangan dan node tambahan |
| 192.168.5.100 - 192.168.5.199 | Perangkat penyerang |
| 192.168.5.200 - 192.168.5.249 | Perangkat monitoring dan sensor |

---

## 4. Tabel Routing

Tidak diperlukan tabel routing. Seluruh node berada dalam satu subnet 192.168.5.0/24 sehingga pengiriman paket cukup pada layer 2.

| Destination | Next Hop | Interface | Keterangan |
|-------------|----------|-----------|------------|
| 192.168.5.0/24 | Connected | pbl5-lan | LAN lokal kelompok 5 |
| 0.0.0.0/0 | NAT VirtualBox | adapter NAT | hanya untuk pembaruan paket, bukan jalur pengujian |

---

## 5. Port dan Layanan pada Target Node

Angka pada tabel ini berasal dari hasil pemindaian sebelum dan sesudah hardening, tersimpan di `docs/blueteam/evidence`.

| Port | Protokol | Layanan | Sebelum hardening | Sesudah hardening |
|------|----------|---------|-------------------|-------------------|
| 22 | TCP | SSH | terbuka, OpenSSH 10.2p1 | terbuka, hanya kunci publik |
| 80 | TCP | HTTP, Apache | terbuka | tersaring, layanan dimatikan |
| 1883 | TCP | MQTT | terbuka | terbuka, sasaran pengujian Fase 2 |
| 3000 | TCP | HTTP, dashboard Flask | terbuka | terbuka, sasaran pengujian Fase 2 |
| 3306 | TCP | MySQL | terbuka | tersaring, hanya mendengar di loopback |
| 9090 | TCP | tidak dipakai | tertutup | tersaring |

Port yang sebelumnya direncanakan untuk aplikasi latihan generik tidak dipakai lagi, karena target harus menyerupai tech stack produk IoT kelompok, bukan aplikasi rentan siap pakai.

---

## 6. Spesifikasi dan Pemilihan OS

### Opsi yang dipertimbangkan

| Opsi | Perkiraan Kebutuhan | Keputusan |
|------|---------------------|-----------|
| Ubuntu Server tanpa GUI | RAM sekitar 128 MB, disk 3 GB | **Dipilih** |
| Metasploitable 2 | image 2,7 GB, RAM minimum 512 MB | Tidak dipilih |
| Metasploitable 3 | 65 GB disk dan 4,5 GB RAM untuk build | Tidak dipilih |

### Keputusan

Target Node memakai **Ubuntu Server 26.04 LTS** tanpa antarmuka grafis. Pemilihan ini didasarkan pada keterbatasan sumber daya laptop anggota, karena lingkungan uji harus menjalankan tiga mesin virtual sekaligus.

Layanan yang dipasang: SSH, dashboard Flask pada port 3000, broker MQTT pada port 1883, dan MySQL 8.4 pada port 3306 yang dibatasi ke loopback.

Aplikasi latihan generik seperti DVWA tidak dipakai, karena tujuan replika adalah menyerupai tech stack produk IoT kelompok. Dashboard pada replika menampilkan data suhu dan kelembapan dummy dan menerima data dari sensor virtual melalui MQTT serta HTTP.

### Konfigurasi Layanan pada Target Node

| Layanan | Port | Status |
|---------|------|--------|
| SSH | 22 | Aktif, hanya kunci publik |
| Dashboard Flask | 3000 | Aktif |
| MQTT Mosquitto | 1883 | Aktif, autentikasi belum diaktifkan |
| MySQL | 3306 | Aktif, hanya loopback |
| HTTP Apache | 80 | Dimatikan |

---

## 7. Penempatan Monitoring Node

Monitoring Node berada pada segmen 192.168.5.0/24 yang sama dengan Attacker dan Target.

Pada VirtualBox, segmen dibentuk dengan jaringan internal `pbl5-lan` dan adapter Monitoring Node diset **promiscuous mode Allow All**. Dengan cara ini seluruh frame pada segmen diterima, termasuk lalu lintas unicast antara Attacker dan Target. Pendekatan ini menggantikan port mirroring pada switch, karena switch hanya representasi diagram.

Jalur log kedua adalah pengiriman syslog dari Target Node ke Monitoring Node pada port 514 TCP, dengan aturan izin dibuat di sisi penerima.

Pembuktian tangkapan dilakukan dengan tcpdump pada antarmuka segmen, lalu dibaca melalui menu Hunt pada Security Onion.

---

## 8. Catatan dan Riwayat Perubahan

- 12 September 2026: desain awal, masih memakai aplikasi latihan generik sebagai target.
- 19 Oktober 2026: dokumen diperbarui sesuai implementasi. Target memakai dashboard Flask, MQTT, dan MySQL yang mereplikasi tech stack produk IoT kelompok. Tabel port disesuaikan dengan hasil pemindaian.
- Seluruh alamat bersifat statis dan hanya berubah bila disepakati Red Team dan Blue Team.
- Segmen 192.168.5.0/24 khusus kelompok 5 dan tidak tumpang tindih dengan kelompok lain.
