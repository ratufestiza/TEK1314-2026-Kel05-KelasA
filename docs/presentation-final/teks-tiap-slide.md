# Teks Tiap Slide Presentasi Final

Mengikuti kisi-kisi Bagian VII Panduan PBL Minggu 14-15. Tujuh komponen wajib, total 12 slide termasuk cover dan penutup. Setiap blok di bawah bisa disalin apa adanya ke slide.

---

## Slide 1 - Cover

**Judul:** Internal Database Fortress

**Subjudul:** Siklus Lengkap Merah, Biru, dan Ungu pada Replika Sistem Sprinkler Otomatis Sapi Perah

**Baris bawah:** Kelompok 5 | Skenario 05 | TEK1314 Keamanan Siber 2026

**Keterangan pembicara:** Perkenalkan anggota dan peran masing-masing dalam satu tarikan napas, jangan lebih dari tiga puluh detik.

---

## Slide 2 - Ringkasan Proyek dan Perjalanan Fase 1 sampai 3

**Judul:** Dari Replika ke Siklus Pertahanan Utuh

**Poin isi:**

- Objek uji: replika sistem sprinkler otomatis untuk mitigasi stres panas sapi perah, dibangun di atas empat layanan pada satu host Linux.
- Fase 1, minggu 1 sampai 9: bangun infrastruktur, ukur baseline, terapkan sepuluh kontrol hardening, susun rencana serangan.
- Fase 2, minggu 10 sampai 11: jalankan tiga skenario serangan dari mesin penyerang di segmen yang sama.
- Fase 3, minggu 12 sampai 13: mitigasi, verifikasi ulang dengan payload identik, sintesis laporan.
- Prinsip yang dipegang sejak awal: pengukuran dilakukan pada kondisi yang sudah diperketat, bukan pada mesin mentah.

**Keterangan pembicara:** Slide ini rekap saja. Jangan ulangi detail teknis minggu 4 atau 9, karena dosen sudah membaca artefaknya.

---

## Slide 3 - Arsitektur dan Pembagian Peran

**Judul:** Tiga Node, Satu Segmen Terisolasi

**Poin isi:**

- Segmen `pbl5-lan` 192.168.5.0/24, virtual switch internal, tanpa jalur ke internet.
- Target Node 192.168.5.5 menjalankan empat layanan: SSH 22, MQTT 1883, dashboard Flask 3000, MySQL 3306.
- Attacker Node 192.168.5.100, Monitoring Node 192.168.5.200 menjalankan Security Onion.
- Alur data: sensor mengirim lewat MQTT, subscriber menulis ke tabel `sensor_readings`, dashboard membacanya kembali.
- Pembagian peran: Lead Analyst, System/Network Engineer, Security Analyst, Documentation.

**Keterangan pembicara:** Tunjukkan bahwa alamat dan nama host sesuai IP Plan kelompok sendiri, bukan cuplikan dari sumber lain.

---

## Slide 4 - Ringkasan Eksekutif Insiden

**Judul:** Satu Parameter, Satu Broker, Satu Berkas Lama

**Poin isi:**

- Insiden yang disimulasikan: pengambilalihan jalur data, bukan pencurian data masif.
- Dari tiga skenario, hanya skenario ketiga yang menembus. Dua skenario pertama gagal karena kontrol Fase 1 bekerja.
- SQL injection pada endpoint `/sensor` membaca seluruh isi tabel dan membocorkan galat internal.
- Broker MQTT menerima klien anonim, sehingga data palsu `sensor-99` suhu 99.90 masuk dan tampil di posisi teratas dashboard tanpa penanda.
- Inti kerugiannya bukan data hilang, melainkan data operasional tidak lagi bisa dipercaya.

**Keterangan pembicara:** Tekankan bahwa nilai proyek ini bukan pada banyaknya serangan yang berhasil.

---

## Slide 5 - Klasifikasi Insiden

**Judul:** Kategori, Dampak, Prioritas

**Poin isi:**

| Atribut | Nilai | Alasan |
| --- | --- | --- |
| Kategori | Unauthorized Access dan Data Integrity Violation | akses tanpa hak plus perubahan isi data |
| Dampak fungsional | rendah sampai sedang | layanan tetap berjalan, tetapi menampilkan data tidak sah |
| Dampak informasi | sedang | seluruh isi tabel terbaca, struktur galat terbocorkan |
| Kemampuan pulih | tinggi | perbaikan berupa kode dan konfigurasi, tanpa kehilangan data |
| Prioritas | tinggi | keputusan operasional bergantung pada angka yang ditampilkan |

**Keterangan pembicara:** Jelaskan mengapa dampak informasi dinilai sedang, yaitu karena seluruh data dummy dan tanpa identitas pribadi. Bila bertemu data peternakan nyata, naik menjadi tinggi.

---

## Slide 6 - Status Akhir Hardening

**Judul:** Sepuluh Kontrol, Tiga Kategori

**Poin isi:**

- Kategori A, akses dan autentikasi: A1 SSH hanya kunci publik tanpa root, batas tiga percobaan. A2 izin home 700 dan root terkunci. A3 fail2ban aktif dengan bantime 1800 detik.
- Kategori B, permukaan serangan: B1 layanan tak terpakai dimatikan, port 80 tertutup. B2 ufw menolak seluruh trafik masuk kecuali port yang dipakai. B3 paket menunggu pembaruan turun dari 26 menjadi 0.
- Kategori C, data dan aplikasi: C1 MySQL hanya di loopback. C2 akun `webapp` dihapus, tersisa `app_iot` dengan hak terbatas. C3 kredensial pindah ke `/etc/iot/iot.env` mode 600. C4 log diteruskan ke Security Onion port 514.
- Pemenuhan melebihi standar minimum di ketiga kategori.

**Keterangan pembicara:** Sebut angka perbandingan port: lima port terbuka menjadi dua setelah hardening, dan 65533 port tersaring.

---

## Slide 7 - Perbandingan Sebelum dan Sesudah

**Judul:** Yang Berubah dan yang Tidak

**Poin isi:**

| Pengukuran | Sebelum | Sesudah |
| --- | --- | --- |
| Port terbuka dari enam port terpilih | 5 | 3 |
| Port tertutup | 1 | 0 |
| Port tersaring | 0 | 3 |
| Port terbuka dari 65535 port | 5 | 2 |
| Lama pemindaian penuh | 20,52 detik | 780,26 detik |
| Paket menunggu pembaruan | 26 | 0 |

**Keterangan pembicara:** Angka waktu pemindaian yang naik hampir empat puluh kali lipat adalah efek samping yang diinginkan, karena penyerang kehilangan informasi tentang port mana yang tertutup dan mana yang tersaring.

---

## Slide 8 - Demo atau Pemutaran Video

**Judul:** Satu Siklus Purple Team Loop Penuh

**Poin isi:**

- Alur yang ditunjukkan: serangan dijalankan, terdeteksi atau tidak di Security Onion, mitigasi diterapkan, serangan diulang, hasil dibandingkan.
- Bagian yang ditampilkan: payload OR membuka seluruh tabel, lalu payload yang sama menghasilkan array kosong setelah mitigasi.
- Nama host dan alamat IP ditampilkan di layar sebagai bukti infrastruktur kelompok sendiri.
- Durasi rekaman lima sampai delapan menit, diunggah sebagai unlisted dan tautannya dicantumkan di README.

**Keterangan pembicara:** Kalau video belum siap, jalankan demo langsung. Urutannya sama, cukup satu skenario.

---

## Slide 9 - Hasil Deteksi dan Mitigasi: Skenario 1 dan 2

**Judul:** Dua Serangan yang Gagal karena Kontrol Sudah Bekerja

**Poin isi:**

| Tahap | Skenario 1 Pengintaian | Skenario 2 Kredensial |
| --- | --- | --- |
| Serang | nmap seluruh 65535 port, tiga port terbuka, 65532 tersaring | NSE dan koneksi langsung ke 3306 timeout, Hydra MySQL tidak pernah membentuk koneksi |
| Deteksi | Kibana 50 hits, hanya alert ICMP, tanpa signature pemindaian | fail2ban mencatat lima kegagalan dan dua blokir 1800 detik |
| Analisis | tidak ada dampak fungsional, tetapi peta layanan terbuka | timeout pada MySQL bukan refused, artinya paket dijatuhkan sebelum sampai layanan |
| Mitigasi | ufw dan penutupan layanan tak terpakai | C1 loopback, A1 tanpa kata sandi, A3 fail2ban |
| Verifikasi | pemindaian ulang menyisakan dua port terbuka, yaitu 1883 dan 3000; pemindaian ini dilakukan setelah seluruh hardening, sehingga angkanya berbeda dari tiga port pada tahap serang | hasil identik, kontrol memang sudah aktif sebelum insiden |

**Keterangan pembicara:** Kalau ada yang menanyakan selisih angka tiga dan dua, jelaskan bahwa itu dua waktu pengukuran berbeda, bukan dua hasil yang bertentangan.

**Keterangan pembicara:** Hydra melaporkan nol kata sandi valid tanpa satu pun percobaan terkirim. Itu bukan bukti kata sandi kuat, melainkan bukti jalur sudah tertutup.

---

## Slide 10 - Hasil Deteksi dan Mitigasi: Skenario 3

**Judul:** Satu-satunya Jalur yang Menembus

**Poin isi:**

| Tahap | Isi |
| --- | --- |
| Serang | payload OR mengembalikan empat baris, seluruh isi tabel. Payload UNION galat 500 dengan jejak internal. Publish MQTT diterima dengan `CONNACK 0` |
| Deteksi | tidak terdeteksi. Kibana hanya mencatat alert ICMP, tanpa signature untuk payload URL maupun pesan MQTT |
| Analisis | akar masalah sama: masukan dari jaringan dipercaya sepenuhnya. Query digabung dengan format string, dan `device_id` diambil mentah dari nama topik |
| Mitigasi | parameterized query, keluaran JSON, nilai disandikan di HTML. Broker memakai `allow_anonymous false` dan berkas kata sandi, berkas konfigurasi lama dipindahkan, subscriber diberi kredensial |
| Verifikasi | payload OR menghasilkan array kosong, payload UNION menghasilkan HTTP 200 dengan badan kosong. Publish MQTT anonim ditolak dengan `not authorised`, data sah tetap tercatat |

**Keterangan pembicara:** Bagian MQTT disampaikan dengan riwayatnya. Percobaan pertama gagal karena berkas `pb15-awal.conf` dari Oktober masih memuat `allow_anonymous true` dan dibaca terakhir. Setelah berkas itu dipindahkan, autentikasi berlaku dan publish anonim ditolak. Jangan menyebut MQTT masih terbuka, karena kondisinya sudah tertutup.

---

## Slide 11 - Kendala dan Pembelajaran

**Judul:** Yang Mahal Justru yang Tidak Terlihat

**Poin isi:**

- Berkas konfigurasi lama tidak pernah dibersihkan. Pelajaran: periksa nilai efektif, bukan berkas yang baru ditulis.
- Izin berkas kata sandi tidak diperhitungkan. Broker gagal dengan kode 13 tanpa penjelasan di layar.
- Berkas perbaikan tidak pernah sampai ke target karena folder bersama tidak terpasang.
- Deteksi tidak dirancang untuk lapisan aplikasi, sehingga insiden skenario ketiga baru diketahui karena tim menjalankan serangannya sendiri.
- Pembelajaran utama: kegagalan yang jujur lebih berharga daripada keberhasilan yang dibulatkan.

**Keterangan pembicara:** Ini slide yang paling mungkin ditanya. Siapkan satu contoh konkret untuk setiap poin.

---

## Slide 12 - Rekomendasi Lanjutan dan Penutup

**Judul:** Yang Dibawa Pulang ke Sistem Asli

**Poin isi:**

- Pindahkan validasi ke aturan akses, pada Firebase padanannya Security Rules.
- Beri identitas per perangkat, bukan per sistem, agar satu kunci bocor tidak memalsukan seluruh perangkat.
- Validasi di sisi penerima, jangan percaya identitas yang datang bersama data.
- Tetapkan rentang nilai wajar, tolak suhu 99.90 sebelum masuk basis data.
- Bangun jalur deteksi sejak hari pertama, bukan setelah insiden.
- Pisahkan data uji dari data operasional.

**Penutup:** Sistem yang dinilai aman berdasarkan laporan yang tidak jujur akan gagal pada pengujian pertama di dunia nyata.

**Keterangan pembicara:** Akhiri dengan satu kalimat, lalu buka tanya jawab. Jangan menambah slide baru.

---

## Catatan Teknis

- Batas slide menurut panduan adalah 10 sampai 12. Susunan di atas tepat 12 termasuk cover.
- Format unggahan wajib PDF, bukan pptx. Ekspor PDF itu yang diunggah, berkas sumber .pptx tidak disertakan di repositori karena dibuat di Canva dan tidak bisa diedit ulang di PowerPoint.
- Slide 8 memakai pemutaran video. Tautan rekaman https://youtu.be/b0riabC46ik sudah tercantum di README.
- Slide arsitektur tidak ada pada versi final. Bila dosen meminta peta jaringan, tampilkan `documentation/topologi.jpeg` secara terpisah, jangan menambah slide baru di tengah presentasi.
- Jangan menambah em dash di teks mana pun.
