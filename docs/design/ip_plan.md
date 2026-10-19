# IP Plan — Kelompok 5

**Mata Kuliah:** TEK1314 Keamanan Siber (D4 Teknologi Rekayasa Komputer)
**Proyek:** PBL Pertemuan 4 — Perancangan Arsitektur & Skema IP (Design Phase)
**Segmen Kelompok:** 192.168.5.0/24 (sesuai Kontrak Kuliah Poin 3a)
**Tanggal:** September 2026

---

## 1. Skenario

Kelompok 5 merancang lingkungan uji keamanan jaringan yang terdiri dari tiga entitas utama: **Attacker Node**, **Target Node (Korban)**, dan **Monitoring Node**. Target Node menggunakan aplikasi web yang disengaja rentan (DVWA) sehingga dapat dijadikan objek demonstrasi eksploitasi, sementara seluruh trafik antara Attacker dan Target direkam oleh Monitoring Node untuk dianalisis.

Topologi yang digunakan adalah **star topology** dengan satu switch sebagai titik pusat. Seluruh node berada pada satu segmen LAN 192.168.5.0/24 dan tidak terhubung ke jaringan luar, sehingga pengujian berlangsung pada lingkungan yang terisolasi dan aman.

---

## 2. Tabel IP Plan

| No | Hostname | Device | IP Address | Subnet Mask | Gateway | OS Direncanakan |
|----|----------|--------|------------|-------------|---------|-----------------|
| 1 | SW-K05 | Switch 2960-24TT | 192.168.5.2 | 255.255.255.0 | - | Cisco IOS 15.0 |
| 2 | Target-Node-K05 | Server-PT | 192.168.5.5 | 255.255.255.0 | - | Ubuntu Server CLI + DVWA |
| 3 | Attacker-Node-K05 | PC-PT | 192.168.5.100 | 255.255.255.0 | - | Kali Linux |
| 4 | Monitoring-Node-K05 | Server-PT | 192.168.5.200 | 255.255.255.0 | - | Security Onion |

**Subnet Mask:** 255.255.255.0
**Alokasi:** Statis seluruhnya (tanpa DHCP), agar alamat tidak berubah saat proses monitoring berlangsung.
**Gateway:** Dikosongkan karena topologi tidak menggunakan router. Seluruh node berada pada satu segmen LAN dan dapat berkomunikasi langsung melalui switch.

---

## 3. Blok Alokasi Alamat

Pembagian blok dibuat berdasarkan fungsi perangkat, sehingga jenis perangkat dapat langsung dikenali dari alamat IP-nya tanpa membuka tabel ini.

| Rentang | Peruntukan |
|---------|------------|
| 192.168.5.1 – 192.168.5.9 | Infrastruktur jaringan (switch, gateway bila ditambahkan) |
| 192.168.5.10 – 192.168.5.49 | Server target dan layanan |
| 192.168.5.50 – 192.168.5.99 | Cadangan / node tambahan |
| 192.168.5.100 – 192.168.5.199 | Perangkat penyerang (attacker tools) |
| 192.168.5.200 – 192.168.5.249 | Perangkat monitoring dan sensor |

---

## 4. Tabel Routing

Tidak diperlukan tabel routing pada desain ini. Seluruh node berada dalam satu subnet 192.168.5.0/24 yang sama, sehingga pengiriman paket antar-node cukup dilakukan pada layer 2 melalui switch tanpa melewati router.

Apabila di tahap implementasi ditambahkan router untuk memisahkan segmen pengujian dengan segmen lain, akan digunakan konfigurasi berikut:

| Destination | Next Hop | Interface | Keterangan |
|-------------|----------|-----------|------------|
| 192.168.5.0/24 | Connected | Gi0/0 | LAN lokal kelompok 5 |
| 0.0.0.0/0 | ISP / gateway kampus | Gi0/1 | Default route (jika akses internet ditambahkan) |

---

## 5. Port Berpotensi Diuji

Daftar ini merupakan hasil riset Red Team dan menjadi acuan penempatan layanan pada desain topologi.

| Port | Protokol | Service | Keterangan |
|------|----------|---------|------------|
| 80 | TCP | HTTP | Web server DVWA — target utama |
| 443 | TCP | HTTPS | Web server versi TLS |
| 22 | TCP | SSH | Remote login Ubuntu Server |
| 3306 | TCP | MySQL | Database backend DVWA |

---

## 6. Survey Spesifikasi Target (Pemilihan OS)

### Opsi yang dipertimbangkan

| Opsi | Perkiraan Kebutuhan Sumber Daya | Keputusan |
|------|--------------------------------|-----------|
| Ubuntu Server CLI + DVWA | OS ±128 MB RAM (tanpa GUI), disk ±3 GB | **Dipilih** |
| Metasploitable 2 | Ukuran image 2,7 GB (belum termasuk ekstraksi), RAM min 512 MB | Tidak dipilih |
| Metasploitable 3 | Membutuhkan 65 GB ruang disk + 4,5 GB RAM untuk build | Tidak dipilih |

### Keputusan

Target Node menggunakan **Ubuntu Server CLI** sebagai sistem operasi, dengan **DVWA (Damn Vulnerable Web Application)** terpasang di atasnya sebagai aplikasi web yang disengaja rentan.

Pemilihan ini didasarkan pada pertimbangan keterbatasan sumber daya laptop anggota. Ubuntu Server tanpa antarmuka grafis hanya memerlukan sekitar 128 MB RAM, jauh lebih ringan dibandingkan image Metasploitable. Metasploitable 2 dipertimbangkan namun tidak dipilih karena ukuran image mencapai 2,7 GB sebelum ekstraksi, sedangkan Metasploitable 3 memerlukan 65 GB ruang disk sehingga tidak memungkinkan pada perangkat yang tersedia.

DVWA dipilih sebagai aplikasi target karena menyediakan celah keamanan yang terukur dalam tiga tingkat kesulitan (low, medium, high), sehingga demonstrasi eksploitasi dapat dilakukan secara bertahap dan hasilnya terdokumentasi dengan rapi.

**Catatan mengenai istilah "DVWA ISO":** distribusi resmi DVWA tidak menyediakan image ISO. DVWA bersifat aplikasi yang berjalan di atas sistem operasi, dan didistribusikan dalam bentuk source code maupun container Docker. Yang pernah tersedia sebagai ISO adalah DVWA v1.0.7 LiveCD dari tahun 2010 dan sudah tidak digunakan lagi. Karena itu, DVWA ditempatkan sebagai aplikasi di atas Ubuntu Server, bukan sebagai sistem operasi tersendiri.

### Konfigurasi Layanan pada Target Node

| Layanan | Port | Status |
|---------|------|--------|
| HTTP (DVWA) | 80 | Aktif |
| HTTPS | 443 | Aktif |
| SSH | 22 | Aktif |
| MySQL | 3306 | Aktif |

---

## 7. Penempatan Monitoring Node

Monitoring Node (Security Onion) ditempatkan pada segmen 192.168.5.0/24 yang sama dengan Attacker dan Target, agar dapat menerima seluruh trafik pada segmen tersebut.

Karena switch bekerja pada layer 2 dan hanya meneruskan frame ke port tujuan, trafik unicast antara Attacker dan Target tidak akan sampai ke port Monitoring secara otomatis. Agar Monitoring Node menerima salinan trafik tersebut, digunakan **port mirroring (SPAN)** pada switch:

```
enable
conf t
monitor session 1 source interface fa0/1 both
monitor session 1 destination interface fa0/3
end
show monitor
```

Keterangan: `fa0/1` menuju Attacker Node, `fa0/3` menuju Monitoring Node. Seluruh trafik dua arah dari port Attacker disalin ke port Monitoring tanpa mengganggu jalur data utama.

**Opsi alternatif:** apabila perintah SPAN tidak dapat dijalankan pada versi Packet Tracer atau perangkat yang digunakan, switch pada segmen pengujian dapat digantikan dengan **Hub-PT**. Hub merupakan perangkat layer 1 yang meneruskan setiap frame yang diterima ke seluruh port lainnya, sehingga Monitoring Node otomatis menerima seluruh trafik secara pasif. Konsekuensinya, seluruh port berada pada satu collision domain dan beroperasi half-duplex sehingga throughput segmen lebih rendah.

---

## 8. Catatan

- Topologi pada dokumen ini hanya mencakup tahap **desain**. Instalasi OS dan aplikasi target belum dilakukan pada tahap ini.
- Seluruh alamat bersifat statis dan sudah final; perubahan hanya dilakukan bila disepakati ulang oleh Red Team dan Blue Team.
- Segmen 192.168.5.0/24 digunakan khusus untuk kelompok 5 dan tidak boleh tumpang tindih dengan segmen kelompok lain.
