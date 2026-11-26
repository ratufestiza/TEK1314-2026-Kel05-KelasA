# TEK1314-2026-Kel05-KelasA
Repository Mata Kuliah Keamanan Siber Kelas A – Kelompok 5 | TEK1314 2026

Fattih Algie Maulana (J0404241002)

Syamil Abdillah (J0404241139

Ratu Festiza Alya Ichsan (J0404241174)

Al Fariz Muhammad Zibril (J0404241036)

1. Dokumentasi Instalasi CyberOPS dan Security Union
2. https://docs.google.com/document/d/1kLTl9QgCAbP9AlRmZ7LeZou6PkfrzocWbvTxVEbz9e0/edit?tab=t.0

# PBL Keamanan Siber - Kelompok 5
# Skenario Proyek
Proyek PBL Kelompok 4 mengangkat skenario Simulasi Pengujian Keamanan Server Rentan Menggunakan Metasploitable. Lingkungan proyek terdiri dari tiga node utama:

Kali Linux sebagai Attacker Node yang digunakan oleh Red Team.
Ubunru Server CLI + DVWA sebagai Target Server atau korban.
Security Onion sebagai Monitoring Node yang digunakan oleh Blue Team untuk memantau aktivitas jaringan.

# Peran Team

Blue Team - Fattih

Blue Team bertugas menggambar diagram topologi jaringan yang menghubungkan Attacker Node, Target Node, dan Monitoring Node. Selain itu, Blue Team menyusun skema IP Address beserta tabel routing sederhana yang sesuai dengan segmen unik kelompok. Tim ini juga menentukan posisi penempatan Security Onion agar dapat memantau seluruh lalu lintas di dalam segmen jaringan kelompok. 

Red Team - Syamil & Al Fariz

Red Team bertanggung jawab melakukan riset mengenai port dan service yang berpotensi dibuka atau dieksploitasi dalam skenario serangan. Mereka memberikan masukan terkait pemilihan OS Target berdasarkan celah keamanan atau versi rentan yang ingin didemonstrasikan. Hasil analisis berupa daftar port dan catatan potensi celah tersebut kemudian diserahkan kepada Blue Team untuk dimasukkan ke dalam desain topologi.  

Lead - Ratu

Lead bertugas mengoordinasikan diskusi pemilihan OS Target dan memastikan seluruh keputusan tim tercatat dengan baik. Lead juga memastikan rancangan topologi serta tabel IP sudah final dan disepakati oleh Red Team maupun Blue Team. Terakhir, Lead bertanggung jawab mengunggah gambar topologi dan dokumen pendukung ke repositori GitHub kelompok

# Network

Topologi jaringan dirancang menggunakan segmen:

- Network: 192.168.5.0/24
- Target Server: 192.168.5.5
- Attacker Node: 192.168.5.100
- Monitoring Node: 192.168.5.200

# Port yang Menjadi Fokus Pengujian

| Port | Protokol | Service | Keterangan |
|------|----------|---------|------------|
| 80 | TCP | HTTP | Web server DVWA — target utama |
| 443 | TCP | HTTPS | Web server versi TLS |
| 22 | TCP | SSH | Remote login Ubuntu Server |
| 3306 | TCP | MySQL | Database backend DVWA |

# Struktur Design

[Folder Dokumentasi](./documentation)

folder ini berisi topologi dan skema IP, port dan penjelasannya. 

## Log Aktivitas Mingguan

### Minggu 1-2: Fase Setup

- **Target:** Repositori GitHub dan VM Target siap dipakai.
- **Update 24 Agustus 2026:**
  - Repositori kelompok dibuat, berisi dokumentasi proyek, berkas bukti, dan laporan.
  - VM Target disiapkan dari image Ubuntu Server, RAM 2048 MB, CPU 2, disk 10 GB dinamis.
  - VM Target dinilai cocok dipakai ulang sehingga tidak perlu dibuat dari nol.
  - Kendala: kapasitas disk host tersisa di bawah sepuluh persen. Solusi: VM dibuat tipis dengan disk dinamis, ditambah pembersihan cache dan penghapusan VM yang tidak dipakai.
  - Artefak: `README.md`, `docs/design/ip_plan.md`.

### Minggu 3: Checkpoint 1 - Proof of Concept

- **Target:** VM Target bisa di-ping dari VM Attacker.
- **Update 7 September 2026:**
  - Jaringan internal VirtualBox `pbl5-lan` dipasang pada tiga VM, promiscuous mode Allow All khusus untuk Security Onion.
  - Alamat dipasang sesuai rencana: Attacker 192.168.5.100, Target 192.168.5.5, Monitoring 192.168.5.200.
  - Target memakai netplan, dilanjutkan `netplan apply` dan diperiksa dengan `ip a`.
  - Hasil: ping dari Attacker ke Target berhasil, checkpoint lulus.
  - Kendala: alamat Attacker hilang setiap VM dimulai ulang. Solusi: alamat ditambahkan manual pada setiap sesi pengujian.
  - Artefak: tangkapan layar ping, `docs/design/ip_plan.md`.

### Minggu 4-5: Checkpoint 2 - Logging Check

- **Target:** Security Onion merekam lalu lintas pada segmen kelompok.
- **Update 21 September 2026:**
  - Antarmuka monitoring Security Onion dipasang pada `pbl5-lan`, antarmuka manajemen pada NAT.
  - Uji awal memakai `tcpdump` memastikan paket ICMP dari Attacker ke Target terbaca.
  - Hasil: rekaman lalu lintas berjalan, layanan penerima syslog pada port 514 siap dipakai pada Fase 2.
  - Kendala: tangkapan tidak muncul sebelum promiscuous mode dinyalakan. Solusi: adapter Security Onion diatur ke Allow All.
  - Artefak: keluaran `tcpdump`, `docs/design/ip_plan.md` versi final.

### Minggu 6-7: Checkpoint 3 - Hardening Review

- **Target:** Sistem sudah diamankan sebelum diserang.
- **Update 5 Oktober 2026:**
  - Audit baseline dikerjakan pada Target Node: daftar port mendengar, status firewall, daftar akun, layanan berjalan.
  - Snapshot VM dibuat sebelum konfigurasi diubah.
  - Sepuluh kontrol hardening diterapkan pada SSH, akun dan hak sudo, fail2ban, pemadaman layanan tidak terpakai, ufw, patch, pembatasan basis data ke loopback, hak akses akun basis data, pemindahan kredensial ke berkas env, dan pengiriman log ke Security Onion.
  - Audit ulang dikerjakan dan dibandingkan dengan baseline. Progres diperlihatkan pada Pertemuan 7.
  - Kendala: berkas kredensial terbaca oleh pengguna lain. Solusi: kredensial dipindah ke `/etc/iot/iot.env` dengan izin 600.
  - Artefak: `docs/blueteam/hardening_checklist.md`, `docs/reports/security-baseline-document.pdf`, `docs/blueteam/evidence/`.

### Minggu 8-9: Penutupan Fase 1 dan Persiapan Fase 2

- **Target:** Dokumen Fase 1 lengkap dan rencana serangan siap dibahas.
- **Update 19 Oktober 2026:**
  - Pemindaian penutup dari mesin penyerang dikerjakan sebelum dan sesudah seluruh hardening aktif.
  - Seluruh tangkapan layar pengujian dirapikan dan diberi nama sesuai kode kontrol, lalu dikumpulkan ke folder bukti.
  - Rencana serangan Fase 2 disusun dalam tiga skenario: reconnaissance, exploitation, serta web dan protokol IoT.
  - Deklarasi tech stack diisi dengan membandingkan teknologi proyek IoT asli dan bentuk replikasinya.
  - Kelengkapan berkas pendukung: peta aset, diagram topologi, dan aturan keterlibatan.
  - Kendala: berkas bukti tersebar tanpa penamaan. Solusi: penamaan ulang mengikuti kode kontrol dan kode bukti.
  - Artefak: `docs/redteam/attack_plan.md`, `docs/rules-of-engagement.md`, `docs/presentation-minggu9/tech_stack_declaration.md`.

### Minggu 10: Mulai Fase 2

- **Target:** Eksekusi skenario 1 dan skenario 2.
- **Update 26 Oktober 2026:**
  - Pengintaian dijalankan dari 192.168.5.100 dengan `nmap -sS -sV -O -p-` menuju 192.168.5.5.
  - Hasil: tiga port terbuka yaitu 22, 1883, dan 3000, dengan 65532 port tersaring. Deteksi versi mencatat OpenSSH 10.2p1. Sidik sistem operasi tidak menemukan kecocokan, tebakan tertinggi 91 persen mengarah ke perangkat yang salah.
  - Lalu lintas pengintaian ditangkap dengan `tcpdump`, menghasilkan 300 paket dalam berkas 33 kilobyte.
  - Skenario 2: enumerasi NSE pada 3306 berakhir filtered, uji koneksi langsung timeout, Hydra MySQL mencoba 20 kandidat tanpa pernah membentuk koneksi, Hydra SSH ditolak pada tahap negosiasi metode.
  - fail2ban mencatat lima kegagalan dan memblokir alamat penyerang dua kali, masing-masing 1800 detik.
  - Kendala: Hydra melaporkan nol kata sandi valid tanpa satu pun percobaan terkirim. Solusi: hasil itu dicatat sebagai bukti kontrol bekerja, bukan sebagai bukti kata sandi kuat.
  - Artefak: `docs/redteam/evidence/skenario-1-recon/`, `docs/redteam/evidence/skenario-2-exploit/`.

### Minggu 11: Skenario 3 dan Pengisian Log

- **Target:** Serangan lapisan aplikasi dan protokol IoT, lalu pengisian catatan lima tahap.
- **Update 9 November 2026:**
  - Permintaan normal ke endpoint `/sensor` mengembalikan dua baris `sensor-01` dalam bentuk repr tuple Python.
  - Payload OR `x' OR '1'='1` mengembalikan empat baris, yaitu seluruh isi tabel. Payload AND mengembalikan nol baris. Payload UNION empat kolom berakhir galat 500 yang membocorkan jejak internal.
  - Broker MQTT menerima klien anonim dengan `CONNACK 0`, langganan ke `sensors/#` berhasil, dan pesan palsu diteruskan ke subscriber.
  - Subscriber menulis baris `sensor-99` dengan suhu 99.90 dan kelembapan 0.0, lalu baris itu tampil di posisi teratas dashboard tanpa penanda.
  - Pencarian di Kibana menghasilkan 50 hits dengan satu alert ICMP. Tidak ada peringatan untuk payload HTTP maupun pesan MQTT.
  - Kendala: baris palsu muncul tiga kali. Solusi: ditelusuri, ternyata tiga proses subscriber berjalan bersamaan, bukan tiga kali pengiriman.
  - Artefak: `docs/redteam/evidence/skenario-3-web-mqtt/`, `docs/redteam/laporan-redteam-fase-2.docx`.

### Minggu 12: Mitigasi

- **Target:** Menutup celah yang ditemukan pada Fase 2.
- **Update 23 November 2026:**
  - Dashboard diganti versi aman: query memakai parameter, keluaran memakai `jsonify`, mode debug dimatikan. Berkas asli disimpan sebagai `app.py.asli`.
  - Broker MQTT dikonfigurasi dengan `allow_anonymous false` dan `password_file /etc/mosquitto/passwd`, lalu akun `iotuser` dibuat.
  - Data palsu `sensor-99` dihapus memakai akun berhak lebih tinggi.
  - Kendala pertama: layanan gagal dengan `status=13`, log menunjukkan `Unable to open pwfile` karena berkas kata sandi dimiliki root mode 600 sedangkan broker berjalan sebagai pengguna `mosquitto`. Solusi: `chown mosquitto:mosquitto` dan `chmod 640`, layanan kembali active.
  - Kendala kedua: broker masih menerima klien anonim karena `pb15-awal.conf` dari 18 Oktober masih memuat `allow_anonymous true` dan dibaca setelah `default.conf`. Solusi dirancang dengan memindahkan berkas lama keluar direktori konfigurasi, belum dijalankan sampai logbook ditutup.
  - Kendala ketiga: akun `app_iot` tidak punya hak DELETE sehingga muncul `ERROR 1142`. Solusi: penghapusan dilakukan dengan akun berhak lebih tinggi.
  - Artefak: `docs/final/bukti-verifikasi/`.

### Minggu 13: Verifikasi dan Dokumen Akhir

- **Target:** Membuktikan perbaikan berlaku, lalu menyusun laporan dan bahan presentasi.
- **Update 25 November 2026:**
  - Payload yang sama diulang dari mesin yang sama. Permintaan normal tetap mengembalikan dua baris dalam bentuk JSON, sehingga aplikasi terbukti masih hidup.
  - Payload OR mengembalikan array kosong. Payload UNION mengembalikan HTTP 200 dengan badan kosong, bukan lagi galat 500.
  - Verifikasi MQTT tidak berhasil: publish dari mesin target dijawab `CONNACK 0`, artinya broker hidup dan masih menerima klien anonim.
  - Tangkapan lalu lintas sesi verifikasi menghasilkan 45 paket.
  - Lima belas sel `docs/purple-team-log.md` selesai diisi, termasuk sel yang mencatat kegagalan.
  - `docs/final/incident_report.pdf` disusun mengikuti NIST SP 800-61r2, delapan bagian, 25 halaman.
  - `docs/presentation-final/slides.pdf` disusun, tiga belas slide.
  - Repositori dirapikan: bukti disusun per skenario dan `.gitignore` dipasang.
  - Kendala: video demonstrasi belum direkam pada saat logbook ditutup. Solusi: tautan akan dicantumkan pada README setelah rekaman selesai.
  - Artefak: `docs/final/`, `docs/presentation-final/`, `docs/purple-team-log.md`.


