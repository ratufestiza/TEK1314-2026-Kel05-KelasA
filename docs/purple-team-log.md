# Purple Team Log

Kelompok 5 - Skenario 05 Internal Database Fortress

Siklus lima tahap per skenario serangan. Setiap serangan yang berhasil pada Tahap 1 harus berakhir gagal atau terdeteksi pada Tahap 5.

Infrastruktur: Target Node 192.168.5.5, Attacker Node 192.168.5.100, Monitoring Node 192.168.5.200, segmen pbl5-lan 192.168.5.0/24.

Kode bukti merujuk pada `docs/redteam/evidence/` dan `docs/blueteam/evidence/`. Bukti verifikasi merujuk pada `docs/final/bukti-verifikasi/`.

## Skenario 1 - Reconnaissance (nmap dan tcpdump)

Target: seluruh 65535 port pada 192.168.5.5, dari mesin 192.168.5.100.

| Tahap | Waktu | Yang terjadi | Berkas bukti |
|---|---|---|---|
| 1. Serang (Baseline) | 24 Nov 2026, 14.18 sampai 14.35 | Pemindaian seluruh port menemukan tiga port terbuka, 22 SSH, 1883 MQTT, dan 3000, dengan 65532 port tersaring. Deteksi versi menunjukkan OpenSSH 10.2p1. Sidik OS tidak menghasilkan kecocokan pasti, tebakan tertinggi 91 persen. Penangkapan lalu lintas menghasilkan 300 paket dalam berkas 33 kilobyte. | SS-01, SS-02, SS-03, SS-04, SS-05, SS-06, SS-07 |
| 2. Deteksi | 24 Nov 2026, 16.35 sampai 16.50 | Berkas pcap diimpor ke sensor Security Onion. Kibana menampilkan 50 hits pada indeks logstash. Alert yang muncul GPL ICMP_INFO PING dengan kategori misc-activity, sumber 192.168.5.106 menuju 192.168.5.5. Sensor aktif bernama seconion-import. | SS-07b |
| 3. Analisis | 24 Nov 2026 | Pemindaian tidak menimbulkan dampak fungsional, tetapi memberi penyerang peta layanan. Yang terbaca: SSH menerima koneksi, broker MQTT menerima koneksi, dashboard hidup pada port 3000, dan MySQL tidak terlihat dari jaringan. Alert yang tercatat hanya ICMP karena pemindaian SYN dengan 65532 port tersaring tidak menghasilkan signature yang cocok. Ini keterbatasan deteksi berbasis signature, bukan kegagalan sensor. | SS-04, SS-07b |
| 4. Respons (Mitigasi) | sudah berjalan sebelum insiden | Dua kontrol yang sudah aktif sejak Fase 1: ufw menolak seluruh trafik masuk kecuali port yang dipakai, dan layanan yang tidak dipakai dimatikan sehingga port 80 tertutup. Keduanya membuat 65532 port tidak menjawab. | docs/blueteam/evidence/after/B2-ufw-status-verbose.png, LINTAS-nmap-after-all.txt |
| 5. Verifikasi | 19 Okt 2026, sebelum Fase 2 | Pemindaian ulang seluruh port dari kondisi setelah hardening menghasilkan dua port terbuka, yaitu 1883 dan 3000, dengan 65533 port tersaring. Port 22 tidak muncul pada pemindaian SYN tanpa opsi tambahan. | docs/blueteam/evidence/after/LINTAS-nmap-after-all.txt |

## Skenario 2 - Exploitation (Hydra, Nmap NSE mysql-info dan mysql-enum, SSH 22)

Target: basis data 3306 dan SSH 22 pada 192.168.5.5.

| Tahap | Waktu | Yang terjadi | Berkas bukti |
|---|---|---|---|
| 1. Serang (Baseline) | 24 Nov 2026, 16.56 sampai 17.10 | Enumerasi NSE pada 3306 berakhir filtered, tidak ada skrip yang berjalan. Uji koneksi langsung berakhir timeout. Hydra MySQL mencoba 20 kandidat kata sandi dan tidak pernah membentuk koneksi, hasil 0 valid password. Hydra SSH ditolak sebelum mencoba, dengan balasan method reply 4. | SS-08, SS-09, SS-10, SS-11 |
| 2. Deteksi | 24 Nov 2026, 13.50 dan 14.26 | fail2ban pada jail sshd mencatat Found lalu Ban terhadap 192.168.5.100 dua kali, dengan satu Unban di antaranya. Total failed lima, total banned satu. | SS-12, SS-12b |
| 3. Analisis | 24 Nov 2026 | Dua penyebab berbeda. Pada MySQL, layanan hanya mendengarkan 127.0.0.1 sehingga paket dari segmen penyerang tidak pernah sampai, dan kegagalan berbentuk timeout bukan refused. Pada SSH, layanan menjawab tetapi menolak metode kata sandi karena passwordauthentication bernilai no, sehingga brute force tidak mungkin dilakukan sejak tahap negosiasi. Tidak ada satu pun kata sandi yang pernah diuji, jadi tidak ada kesimpulan apa pun tentang kekuatan kata sandi. | SS-03, SS-09, SS-11, SS-11b |
| 4. Respons (Mitigasi) | sudah berjalan sebelum insiden | Tiga kontrol Fase 1 menutup jalur ini: C1 membatasi MySQL ke loopback, A1 mematikan autentikasi kata sandi dan membatasi tiga percobaan, A3 mengaktifkan fail2ban dengan maxretry 3, findtime 600, bantime 1800. | docs/blueteam/evidence/after/C1-ss-3306-loopback.png, A1-sshd-effective-config.png, A3-banned-ip.png |
| 5. Verifikasi | 24 Nov 2026 | Diulang dengan perintah yang sama. MySQL tetap timeout dari penyerang. SSH tetap menolak dengan Permission denied (publickey). Tidak ada perubahan hasil, karena kontrolnya memang sudah aktif sebelum serangan. | SS-09, SS-11, SS-11b |

## Skenario 3 - Web dan MQTT (curl, Python urllib, mosquitto_sub dan mosquitto_pub)

Target: dashboard pada 3000 dan broker pada 1883. Skenario inilah yang mengisi perubahan pada Tahap 4 dan 5.

| Tahap | Waktu | Yang terjadi | Berkas bukti |
|---|---|---|---|
| 1. Serang (Baseline) | 24 Nov 2026, 17.15 sampai 20.06 | Permintaan normal mengembalikan dua baris sensor-01 dalam bentuk repr tuple Python. Payload OR mengembalikan empat baris, seluruh isi tabel. Payload AND mengembalikan nol baris. Payload UNION berakhir galat 500. Broker MQTT menerima langganan anonim dengan CONNACK 0, lalu menerima pesan palsu ke topik sensor-99. Baris id 8 bertanggal 24 November masuk ke tabel sensor_readings, dan dashboard menampilkannya di posisi teratas. | SS-13, SS-14, SS-15, SS-16, SS-17, SS-18, SS-19, SS-19b, SS-20 |
| 2. Deteksi | 24 Nov 2026, 16.49 | Kibana menampilkan lalu lintas penyerang menuju target. Pada tahap ini deteksi bersifat jaringan, bukan aplikasi: yang tercatat alert ICMP dan aktivitas umum, sedangkan payload HTTP tidak memicu signature karena sensor berjalan dalam mode import pcap dengan berkas tangkapan terbatas. | SS-07b |
| 3. Analisis | 24 Nov 2026 | Dua akar masalah dengan pola sama, yaitu masukan dari jaringan dipercaya sepenuhnya. Pada dashboard, nilai parameter device digabung langsung ke query dengan operator format string sehingga tiga payload berbeda menghasilkan tiga hasil berbeda, yang membuktikan masukan mengubah logika query. Pada broker, allow_anonymous masih aktif sehingga klien tanpa identitas diterima, dan subscriber memakai nilai dari topik sebagai device_id tanpa daftar putih sehingga penyerang bebas menentukan identitas perangkat. Dampak informasi: seluruh isi tabel terbaca dan data palsu dapat disisipkan. Dampak fungsional: dashboard menampilkan pembacaan yang tidak berasal dari perangkat mana pun. | SS-14, SS-15, SS-16, SS-17, SS-18, SS-19, SS-20 |
| 4. Respons (Mitigasi) | 25 Nov 2026, 08.20 sampai 09.00 | Dashboard diganti versi aman: query memakai parameter, keluaran memakai jsonify, mode debug dimatikan. Broker MQTT dikonfigurasi dengan allow_anonymous false dan password_file, berkas kata sandi diperbaiki kepemilikannya menjadi mosquitto:mosquitto mode 640. Pemindahan berkas lama pb15-awal.conf yang masih memuat allow_anonymous true belum dijalankan, sehingga konfigurasi baru belum berlaku. | docs/final/bukti-verifikasi/V1-verifikasi-sqli-baseline-dan-or.png, V2-verifikasi-union-200.png |
| 5. Verifikasi | 25 Nov 2026, 08.47 | Payload yang sama diulang dari mesin penyerang. Baseline sensor-01 tetap mengembalikan dua baris, kini dalam bentuk JSON, jadi aplikasi masih berfungsi. Payload OR mengembalikan array kosong. Payload UNION mengembalikan HTTP 200 dengan body kosong, bukan lagi 500, jadi galat internal tidak bocor. Verifikasi MQTT gagal: publish dari mesin target dijawab CONNACK 0, artinya broker masih menerima klien anonim. Sebabnya berkas pb15-awal.conf dibaca terakhir dan menimpa allow_anonymous false. Perbaikan satu langkah, yaitu memindahkan berkas itu lalu restart, belum dijalankan. | V1, V2, V4-pcap-45-paket.png |

## Rekap status siklus

| Skenario | Tahap 1 | Tahap 5 | Status siklus |
|---|---|---|---|
| 1 Reconnaissance | berhasil memetakan, tiga port terbuka | tetap tiga pada scan 24 Nov, dua pada scan setelah hardening | tertutup sebagai kontrol, bukan perbaikan baru |
| 2 Exploitation | gagal sejak awal | gagal lagi dengan cara sama | tertutup, kontrol sudah aktif sebelum insiden |
| 3 Web dan MQTT | berhasil, dampak nyata | SQL injection tertutup, MQTT tertutup pada tindak lanjut | tertutup, diverifikasi ulang dengan perintah yang sama |

Tindak lanjut 27 November 2026: kegagalan verifikasi MQTT pada Tahap 5 disebabkan berkas `pb15-awal.conf` dari Oktober yang masih memuat `allow_anonymous true` dan dibaca terakhir oleh Mosquitto. Berkas itu dipindahkan ke `/root`, akun `sensor` dibuat, dan `default.conf` ditulis ulang dengan `allow_anonymous false`. Uji publish anonim kemudian ditolak dengan `not authorised`. Subscriber ikut diberi kredensial agar aliran data yang sah tidak terputus. Baris tabel di atas sudah memakai status setelah tindak lanjut; catatan kegagalan aslinya tetap ada di Tahap 5.

## Catatan kejujuran data

Tiga hal yang harus dibaca sebelum mengutip angka dari log ini.

Pertama, verifikasi MQTT pada Tahap 5 skenario 3 tidak berhasil. Broker masih menerima klien anonim dengan CONNACK 0, sebabnya berkas pb15-awal.conf dibaca terakhir dan menimpa allow_anonymous false, dan berkas itu belum dipindahkan. Laporan tidak boleh mengklaim MQTT sudah tertutup.

Kedua, deteksi pada skenario 3 bersandar pada tangkapan lalu lintas yang diimpor, bukan sensor langsung. Sensor pada lab ini berjalan dalam mode seconion-import.

Ketiga, seluruh waktu pada Tahap 1 sampai 3 memakai WIB, sedangkan keluaran Kibana dan nmap memakai UTC. Selisih tujuh jam, bukan sesi berbeda.

## Aturan pengisian

1. Kolom waktu diisi jam mulai dan jam selesai tiap tahap, bukan hanya tanggalnya.
2. Kolom berkas bukti menunjuk berkas nyata. Jangan tulis nama berkas yang belum ada.
3. Tahap 1 dan 3 diisi Red Team, tahap 2 dan 4 diisi Blue Team, tahap 5 diisi Red Team dan dikonfirmasi Blue Team.
4. Catat juga keadaan target saat diuji, misalnya apakah fail2ban sedang memblokir alamat penyerang, supaya hasilnya tidak salah dibaca.
