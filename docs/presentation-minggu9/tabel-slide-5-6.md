# Tabel Slide 5 dan Slide 6

Dokumen kerja untuk menyusun dua slide progres hardening. Isi di bawah ini yang seharusnya tampil, bukan ringkasan laporan.

## Slide 5: Progres Hardening

Judul slide: Progres Hardening

Tabel tiga kolom, dua belas baris data, dikelompokkan per kategori. Di PowerPoint atau Canva, sel kolom Kategori digabung vertikal per kategori supaya hemat tempat.

| Kategori | Kontrol | Status |
| --- | --- | --- |
| A. Access dan Authentication | A1. SSH hanya menerima kunci publik, login root dilarang, MaxAuthTries 3 | Selesai |
| A. Access dan Authentication | A2. Akun dan hak sudo dirapikan, direktori home 700, akun root terkunci | Selesai |
| A. Access dan Authentication | A3. fail2ban jail sshd, maxretry 3, bantime 1800 detik | Selesai |
| B. Service dan Attack Surface | B1. Layanan tidak terpakai dimatikan, apache berhenti, port 80 tertutup | Selesai |
| B. Service dan Attack Surface | B2. ufw whitelist, hanya port 22, 1883, dan 3000 dari jaringan lab | Selesai |
| B. Service dan Attack Surface | B3. Patch sistem, paket menunggu pembaruan dari 26 menjadi 0 | Selesai |
| C. Data dan Application | C1. MySQL hanya mendengar di loopback | Selesai |
| C. Data dan Application | C2. Least privilege user basis data, akun default webapp dihapus | Selesai |
| C. Data dan Application | C3. Kredensial di berkas env dengan izin 600, tidak hardcoded | Selesai |
| C. Data dan Application | C4. Logging aktivitas dikirim ke Security Onion | Selesai |
| C. Data dan Application | C5. Validasi input pada endpoint dashboard dan topik MQTT | Belum |
| C. Data dan Application | C6. Autentikasi broker MQTT, akses anonim dimatikan | Belum |

Catatan kecil di bawah tabel: C5 dan C6 dijadwalkan Minggu 11 sebagai mitigasi setelah uji serang Fase 2.

Kalimat pembicara: sepuluh kontrol selesai dan tersebar di tiga kategori, jadi syarat minimum delapan kontrol terpenuhi. Dua kontrol terakhir sengaja ditahan karena menjadi bahan mitigasi setelah serangan dijalankan.

### Tabel bukti, dipakai kalau ditanya

| Kode | Bukti |
| --- | --- |
| A1 | sshd effective config sebelum dan sesudah, berkas konfigurasi sshd |
| A2 | Izin direktori home 700, isi grup sudo, akun root terkunci |
| A3 | fail2ban maxretry dan bantime, daftar alamat yang diblokir, uji login gagal |
| B1 | Daftar layanan berjalan, port 80 tidak lagi mendengar |
| B2 | ufw status verbose dalam keadaan aktif |
| B3 | apt daftar paket menunggu pembaruan kosong |
| C1 | Keluaran ss yang menunjukkan MySQL hanya di 127.0.0.1 |
| C2 | Grants user aplikasi dan penolakan login akun default |
| C3 | Berkas env dengan izin 600, potongan kode aplikasi tanpa kredensial |
| C4 | Sambungan syslog ke Security Onion berstatus ESTABLISHED |
| C5 | Potongan kode endpoint yang masih menyambung parameter langsung ke query |
| C6 | Konfigurasi broker yang masih mengizinkan akses anonim |

## Slide 6: Baseline Traffic dan Live Demo

Judul slide: Baseline Traffic dan Live Demo

| Ukuran | Sebelum hardening, 18 Oktober | Setelah hardening, 19 Oktober |
| --- | --- | --- |
| Port terbuka hasil pemindaian seluruh port | 5 | 2 |
| Daftar port terbuka | 22, 80, 1883, 3000, 3306 | 1883, 3000 |
| Port tersaring | 0 | 65.533 |
| Port tertutup | 65.530 | 0 |
| Durasi pemindaian seluruh port | 20,52 detik | 780,26 detik |
| Port 9090 | tertutup | tersaring |

Baris tambahan untuk pemindaian terarah pada port 22, 80, 1883, 3000, 3306, dan 9090:

| Port | Sebelum | Sesudah |
| --- | --- | --- |
| 22 | terbuka, OpenSSH 10.2p1 Ubuntu 2ubuntu3.8 | terbuka |
| 80 | terbuka, Apache 2.4.66 | tersaring |
| 1883 | terbuka, mqtt | terbuka |
| 3000 | terbuka, Werkzeug 3.1.5 Python 3.14.4 | terbuka |
| 3306 | terbuka, MySQL 8.4.11 | tersaring |
| 9090 | tertutup | tersaring |

Strip paling bawah slide: demo langsung, Security Onion menangkap lalu lintas ping dari 192.168.5.100 menuju 192.168.5.5 melalui tcpdump dan menu Hunt.

Kalimat pembicara: sebelumnya lima port terbuka dan pemindaian selesai dalam dua puluh detik. Sekarang tinggal dua port, sedangkan enam puluh lima ribu port lain tidak menolak koneksi, hanya membuang paket. Itu sebabnya durasi pemindaian naik menjadi tiga belas menit.

Catatan pembicara yang perlu disiapkan: port 22 tidak muncul pada hasil pemindaian seluruh port bukan karena tertutup, melainkan karena mesin pemindai terblokir fail2ban di tengah proses. Kejadian itu justru bukti bahwa kontrol berjalan, dan sudah tercatat di logbook.
