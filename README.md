# PBL Keamanan Siber - Kelompok 5 - Skenario 05 Internal Database Fortress

**Mata kuliah:** TEK1314 Keamanan Siber, Kelas A
**Program studi:** D4 Teknologi Rekayasa Komputer, IPB University
**Semester:** 5, Tahun Akademik 2026-2027
**Segmen jaringan:** `pbl5-lan`, 192.168.5.0/24

## Anggota dan Peran

| Nama | NIM | Peran |
| --- | --- | --- |
| Fattih Algie Maulana | J0404241002 | Lead Analyst, dashboard web, MQTT, red team |
| Syamil Abdillah | J0404241139 | Security Engineer, hardening OS, jaringan, akun |
| Ratu Festiza Alya Ichsan | J0404241174 | Analyst, Security Onion, pengelolaan repositori |
| Al Fariz Muhammad Zibril | J0404241036 | Documentation, logbook, penyusunan laporan insiden |

## Ringkasan Proyek

Kelompok 5 menguji replika sistem monitoring kandang ayam berbasis ESP32. Pada produk aslinya, sensor mengirim pembacaan ke Firebase Realtime Database. Untuk keperluan pengujian, replika dibangun dengan layanan yang berdiri sendiri pada satu host Linux:

| Komponen | Port | Keterangan |
| --- | --- | --- |
| SSH OpenSSH | 22 | akses administrasi, hanya kunci publik |
| Dashboard Flask | 3000 | endpoint `/sensor` membaca basis data |
| Broker Mosquitto | 1883 | topik `sensors/#`, jalur data sensor |
| MySQL 8.4 | 3306 | hanya mendengar di loopback |

Tiga node pada satu segmen layer 2 tanpa router: Target Node 192.168.5.5, Attacker Node 192.168.5.100, Monitoring Node 192.168.5.200.

Proyek berjalan dalam tiga fase. Fase 1 memperketat sistem dengan sepuluh kontrol dan bukti before serta after. Fase 2 menyerang sistem yang sudah diperketat, bukan mesin mentah, sehingga hasilnya memisahkan kontrol yang bekerja dari celah yang benar-benar terbuka. Fase 3 menutup celah yang ditemukan, lalu mengulang payload yang sama untuk membuktikan perbaikan berlaku.

Hasil akhir: dari tiga skenario, satu menembus dan dua tertutup sejak awal. SQL injection pada dashboard berhasil ditutup dan diverifikasi ulang dengan payload identik. Akses anonim pada broker MQTT sudah dikonfigurasi untuk ditutup tetapi belum berlaku, karena satu berkas konfigurasi lama masih menimpa, dan status itu ditulis apa adanya pada laporan bagian 6.3.

## Struktur Repositori

```
.
├── README.md                                  berkas ini, ringkasan proyek
├── .gitignore
├── CARA-COMMIT.md                             langkah commit ke GitHub
├── documentation                              folder lama, dipertahankan agar tautan lama tetap hidup
│   ├── ip_plan.md
│   └── topologi.jpeg
└── docs
    ├── logbook.md                             logbook per pekan, Minggu 1-13
    ├── design                                 Minggu 1-4
    │   ├── topology.png
    │   ├── topologi.jpeg
    │   ├── ip_plan.md
    │   └── asset-inventory.csv
    ├── reports
    │   └── security-baseline-document.pdf
    ├── presentation-minggu9                    Minggu 9
    │   ├── Slides.pdf
    │   ├── slide-6-baseline-demo.md
    │   ├── tabel-slide-5-6.md
    │   └── tech_stack_declaration.md
    ├── blueteam
    │   ├── hardening_checklist.md              10 kontrol kategori A, B, C
    │   └── evidence
    │       ├── before                         bukti keadaan sebelum hardening
    │       └── after                          bukti keadaan sesudah hardening
    ├── redteam
    │   ├── attack_plan.md                      3 skenario serangan
    │   ├── rules-of-engagement.md
    │   ├── laporan-redteam-fase-2.docx
    │   └── evidence
    │       ├── skenario-1-recon               SS-01 sampai SS-07b
    │       ├── skenario-2-exploit             SS-08 sampai SS-12b
    │       └── skenario-3-web-mqtt            SS-13 sampai SS-20
    ├── purple-team-log.md                      3 skenario x 5 tahap
    ├── final
    │   ├── incident_report.pdf                 laporan insiden, 25 halaman
    │   ├── incident_report.md                  sumber markdown
    │   ├── lampiran                            25 berkas gambar
    │   └── bukti-verifikasi                    bukti sesudah mitigasi
    └── presentation-final
        ├── slides.pdf                          13 slide
        └── slides.pptx
```

## Tautan Artefak Utama

| Artefak | Berkas | Bobot |
| --- | --- | --- |
| Incident Report Final, 8 bagian NIST SP 800-61r2 | [`docs/final/incident_report.pdf`](docs/final/incident_report.pdf) | 25 persen |
| Video demo Purple Team Loop | tautan menyusul di bagian Video Demo | 25 persen |
| Analisis forensik dan akar masalah | bagian 4 laporan | 20 persen |
| Kelengkapan artefak repositori | seluruh folder pada struktur di atas | 15 persen |
| Bahan presentasi akhir, 13 slide | [`docs/presentation-final/slides.pdf`](docs/presentation-final/slides.pdf) | bagian penilaian lisan |

## Video Demo

Berkas video tidak disimpan di repositori karena ukurannya. Tautan akan dicantumkan di sini setelah rekaman final selesai.

> **Video demo:** `[tautan menyusul]`

Isi yang wajib tampak pada rekaman: satu siklus penuh, yaitu serangan berjalan, terdeteksi atau tidak di Security Onion, mitigasi diterapkan, lalu serangan yang sama diulang dan gagal. Nama host dan alamat IP harus terlihat sepanjang rekaman untuk membuktikan infrastruktur milik kelompok sendiri. Kredensial tidak boleh masuk ke dalam bingkai.

## Log Aktivitas Mingguan

### Minggu 1-3: Fase Setup

**Target:** instalasi mesin virtual, penetapan topologi dan rencana alamat.

- Menyusun `ip_plan.md` dengan tiga node pada 192.168.5.0/24: Target 192.168.5.5, Attacker 192.168.5.100, Monitoring 192.168.5.200.
- Star topology pada satu segmen layer 2 tanpa router, seluruh alamat statis, tanpa gateway.
- VM Target memakai Ubuntu Server 26.04 LTS dari image yang dipakai ulang, RAM 2048 MB, CPU 2, disk 10 GB dinamis.
- Kendala: RAM host tidak cukup untuk tiga mesin virtual bersamaan. Solusi: alokasi memori dikecilkan dan Security Onion dijalankan hanya saat dibutuhkan.
- Artefak: `docs/design/`.

### Minggu 4-7: Fase Hardening dan Baseline

**Target:** penguatan sistem operasi dan dokumentasi keadaan normal.

- Pemindaian keadaan awal `nmap -sS -p- -T4` menemukan lima port terbuka: 22 SSH, 80 Apache, 1883 MQTT, 3000 dashboard, dan 3306 MySQL.
- Deteksi versi mencatat OpenSSH 10.2p1, Apache 2.4.66, dan MySQL 8.4.11 yang terbuka ke jaringan.
- Sepuluh kontrol hardening diterapkan dan diuji satu per satu, dengan bukti before dan after untuk setiap kontrol.
- Kategori A: SSH hanya menerima kunci publik, izin home 700, fail2ban maxretry 3 dengan bantime 1800.
- Kategori B: Apache dimatikan sehingga port 80 tertutup, ufw aktif dengan kebijakan tolak masuk, paket menunggu pembaruan turun dari 26 menjadi 0.
- Kategori C: MySQL dibatasi ke 127.0.0.1, akun `webapp` dengan ALL PRIVILEGES dihapus dan diganti `app_iot` berhak terbatas, kredensial dipindah ke `/etc/iot/iot.env` mode 600, log diteruskan ke Security Onion lewat rsyslog.
- Pemindaian ulang: port terbuka turun dari lima menjadi dua pada pemindaian SYN, dengan 65533 port tersaring.
- Status: **Fase 1 selesai**, sepuluh dari sepuluh kontrol berstatus Selesai.
- Artefak: `docs/blueteam/`, `docs/reports/`.

### Minggu 9-11: Fase Serangan

**Target:** eksekusi tiga skenario pada kondisi yang sudah diperketat.

- Skenario 1, pengintaian: pemindaian seluruh 65535 port menemukan tiga port terbuka yaitu 22, 1883, dan 3000, dengan 65532 port tersaring. Sidik sistem operasi gagal, tebakan tertinggi 91 persen mengarah ke perangkat yang salah. Penangkapan lalu lintas menghasilkan 300 paket dalam berkas 33 kilobyte.
- Skenario 2, percobaan kredensial: enumerasi NSE pada 3306 berakhir filtered, uji koneksi langsung timeout, Hydra MySQL mencoba 20 kandidat tanpa pernah membentuk koneksi, Hydra SSH ditolak pada tahap negosiasi metode.
- fail2ban mencatat lima kegagalan dan memblokir 192.168.5.100 selama 1800 detik, dua kali pada 13.50.22 dan 14.26.26.
- Skenario 3, web dan MQTT: permintaan normal mengembalikan dua baris `sensor-01` dalam repr tuple. Payload OR mengembalikan empat baris, yaitu seluruh isi tabel. Payload AND mengembalikan nol baris. Payload UNION empat kolom berakhir galat 500 dengan jejak internal.
- Broker MQTT menerima klien anonim dengan `CONNACK 0`, langganan ke `sensors/#` berhasil, dan pesan palsu diteruskan ke subscriber.
- Subscriber menulis baris baru dengan identitas `sensor-99`, suhu 99.90, kelembapan 0.0, dan baris itu tampil di posisi teratas dashboard tanpa penanda.
- Catatan operasional: baris palsu sempat muncul tiga kali karena tiga proses subscriber berjalan bersamaan, bukan tiga kali pengiriman.
- Skenario 3 tidak terdeteksi Security Onion. Alert yang tercatat hanya ICMP karena sensor berjalan dalam mode import dan tidak ada aturan untuk pola aplikasi.
- Artefak: `docs/redteam/evidence/`, `docs/redteam/laporan-redteam-fase-2.docx`.

### Minggu 11-13: Fase Mitigasi, Verifikasi, dan Dokumentasi

**Target:** menutup celah, membuktikan perbaikan berlaku, menyusun seluruh artefak akhir.

- Dashboard diganti versi aman: query menjadi parameterized, keluaran memakai `jsonify`, mode debug dimatikan. Berkas asli disimpan sebagai `app.py.asli`.
- Broker MQTT dikonfigurasi dengan `allow_anonymous false` dan `password_file`.
- Kendala pertama: layanan gagal dengan `status=13`, log menunjukkan `Unable to open pwfile`. Penyebabnya berkas kata sandi dimiliki root mode 600 sedangkan broker berjalan sebagai pengguna `mosquitto`. Solusi: `chown mosquitto:mosquitto` dan `chmod 640`, layanan kembali active.
- Kendala kedua: setelah konfigurasi benar, broker masih menerima klien anonim. Pencarian isi `conf.d` menemukan `pb15-awal.conf` dari 18 Oktober yang masih memuat `allow_anonymous true`. Karena Mosquitto memuat berkas sesuai urutan abjad dan yang terakhir dibaca menang, berkas lama menimpa konfigurasi baru. Perbaikan yang dirancang: berkas dipindahkan keluar direktori konfigurasi, bukan dihapus, lalu layanan dimulai ulang. Langkah itu belum dijalankan sampai repo ini ditutup, sehingga autentikasi MQTT masih berstatus belum berlaku.
- Verifikasi SQL injection dengan payload identik: permintaan normal tetap mengembalikan dua baris dalam bentuk JSON, payload OR mengembalikan array kosong, payload UNION mengembalikan HTTP 200 dengan badan kosong, bukan lagi galat 500.
- Verifikasi MQTT tidak berhasil: publish dari mesin target masih dijawab `CONNACK (0)`, artinya broker hidup dan masih menerima klien anonim. Status ini dicatat terbuka, tidak dibulatkan menjadi berhasil.
- Data palsu `sensor-99` dihapus. Akun `app_iot` tidak punya hak DELETE sehingga muncul `ERROR 1142`, penghapusan dilakukan dengan akun berhak lebih tinggi.
- Purple team log dilengkapi, lima tahap untuk tiga skenario, seluruh sel terisi termasuk tahap yang gagal.
- Incident Report Final disusun mengikuti NIST SP 800-61r2, delapan bagian, 25 halaman.
- Bahan presentasi akhir disusun, tiga belas slide, diekspor ke PDF.
- Status: **Fase 3 selesai** untuk SQL injection, **sebagian** untuk MQTT.

## Kendala yang Tercatat

| Kendala | Dampak | Penanganan |
| --- | --- | --- |
| Berkas konfigurasi lama menimpa konfigurasi baru | perubahan MQTT tidak berlaku meski isinya benar | rencana perbaikan dipindahkan keluar direktori konfigurasi, belum dijalankan |
| Izin berkas kata sandi tidak sesuai pengguna layanan | broker gagal start dengan status 13 | kepemilikan diubah ke mosquitto, mode 640 |
| Folder bersama VirtualBox tidak terpasang | berkas perbaikan tidak pernah sampai ke target | perbaikan dilakukan langsung di mesin target |
| Alamat 192.168.5.100 hilang setiap reboot | pengujian berulang terganggu | alamat ditambahkan manual per sesi |
| Sensor Security Onion berjalan mode import | kelengkapan bukti bergantung berkas tangkapan | keterbatasan dinyatakan di laporan |
| Tidak ada aturan deteksi lapisan aplikasi | serangan web dan MQTT lolos tanpa peringatan | masuk daftar rekomendasi lanjutan |
| Akun aplikasi tanpa hak DELETE | data palsu tidak bisa dihapus dari akun aplikasi | penghapusan memakai akun berhak lebih tinggi |

## Pembelajaran

**Keamanan bukan daftar alat, melainkan cara membaca kondisi.** Alat yang dipakai semuanya standar. Yang membedakan hasil adalah kemampuan menafsirkan keluaran. Timeout pada MySQL dan penolakan pada SSH terlihat seperti kegagalan, padahal keduanya bukti bahwa kontrol bekerja.

**Kegagalan yang jujur lebih berharga daripada keberhasilan yang dibulatkan.** Dua hal dicatat terbuka: serangan skenario 3 tidak terdeteksi, dan verifikasi MQTT belum berhasil. Keduanya bisa dihilangkan agar laporan terlihat rapi, tetapi menghilangkannya berarti menutup bagian yang paling perlu diperbaiki.

**Perbedaan antara tidak bisa dan tidak mencoba harus dibedakan.** Hydra melaporkan nol kata sandi valid. Angka itu mudah dibaca sebagai kata sandi kuat, padahal Hydra tidak pernah membentuk koneksi sehingga tidak ada satu pun kata sandi yang diuji.

**Konfigurasi diperiksa pada nilai efektif, bukan pada berkas yang ditulis.** Berkas konfigurasi baru sudah benar isinya tetapi tidak berlaku karena ada berkas lain yang menimpa.

## Dokumentasi Pendukung

Catatan instalasi CyberOps dan Security Onion, di luar lingkup laporan ini:

`https://docs.google.com/document/d/1kLTl9QgCAbP9AlRmZ7LeZou6PkfrzocWbvTxVEbz9e0/edit`

Logbook lengkap per pekan ada di [`docs/logbook.md`](docs/logbook.md). Ringkasan tiap fase tetap ada di README ini agar pembaca tidak perlu membuka dua berkas.

## Batas Pengujian

Seluruh pengujian berjalan pada segmen `pbl5-lan` yang terisolasi dan tidak menyentuh jaringan kampus, WiFi publik, infrastruktur laboratorium, maupun sistem produksi Mitra. Seluruh data bersifat dummy. Kredensial tidak dicantumkan di repositori ini dan ditutup pada setiap tangkapan layar.
