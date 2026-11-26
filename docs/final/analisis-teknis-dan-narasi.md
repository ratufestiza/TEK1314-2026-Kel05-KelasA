# Analisis Teknis dan Naskah Narasi

Dua bagian dalam satu berkas. Bagian pertama bahan analisis, dipakai kalau ditanya dosen atau waktu menyusun laporan. Bagian kedua naskah yang dibaca waktu merekam video.

---

# BAGIAN 1 - ANALISIS TEKNIS SQL INJECTION

## 1. Perjalanan satu request, dari browser sampai MySQL

**Lapisan 1, browser.** Yang diketik:

`http://192.168.5.5:3000/sensor?device=x%27%20OR%20%271%27%3D%271`

Browser mengirim baris permintaan:

`GET /sensor?device=x%27%20OR%20%271%27%3D%271 HTTP/1.1`

Isinya masih `%27` dan `%20`, karena browser meng-encode karakter khusus supaya struktur URL tidak rusak. `%27` adalah satu byte `0x27`, yaitu tanda kutip tunggal.

**Lapisan 2, Flask.** Flask memecah query string, lalu mendekode `%27` menjadi `'`. Di sini `request.args.get("device")` menghasilkan string:

```
x' OR '1'='1
```

Sampai titik ini belum ada yang salah. Itu memang tugasnya, menerima masukan dari luar.

**Lapisan 3, aplikasi. Di sinilah keamanannya hilang.** Baris 47 versi rentan:

```python
cur.execute("SELECT * FROM sensor_readings WHERE device_id = '%s'" % dev)
```

Python mengevaluasi operator `%` lebih dulu, sebelum pymysql melihat apa pun. Hasilnya satu string:

```
SELECT * FROM sensor_readings WHERE device_id = 'x' OR '1'='1'
```

Pada detik itu, batas antara perintah dan data sudah tidak ada. Yang tersisa hanya satu potong teks.

**Lapisan 4, pymysql.** String itu dikirim ke server sebagai paket `COM_QUERY`. Isinya teks query tadi, apa adanya, tanpa metadata yang menandai bagian mana perintah dan bagian mana nilai. Protokol MySQL memang hanya punya satu tempat untuk teks query.

**Lapisan 5, MySQL.** Parser membaca dari kiri ke kanan:

```
SELECT * FROM sensor_readings WHERE device_id = 'x' OR '1'='1'
                                               └──┬──┘ └────┬────┘
                                              literal    kondisi
```

Parser menemukan literal string `'x'`, menutupnya, lalu menemukan `OR`, dan menganggap sisanya bagian sah dari klausa `WHERE`. Secara grammar itu query yang valid. Tidak ada yang error, tidak ada yang mencurigakan.

MySQL menjalankan `OR '1'='1'` yang selalu benar. Semua baris lolos filter.

---

## 2. Kenapa parser tidak curiga

Parser SQL tidak punya informasi untuk curiga. Dia tidak melihat siapa yang mengetik. Yang diterima hanya satu string. Dia tidak tahu bahwa potongan `OR '1'='1'` datang dari URL, bukan dari programmer yang menulis kode.

Bandingkan dua cara memanggil fungsi:

| Cara | Yang dikirim | Bisa dipalsukan |
| --- | --- | --- |
| Sambung string | satu teks, sudah tercampur | ya, data bisa jadi perintah |
| Kirim parameter | teks query final + nilai terpisah | tidak, nilai tidak pernah jadi perintah |

Pada cara pertama, database menerima satu saluran. Pada cara kedua, dua saluran.

Itu seluruh rahasianya. Bukan fungsi ajaib, tapi jumlah saluran.

---

## 3. Anatomi payload, per bagian

Payload `x' OR '1'='1` bukan teks acak. Tiap bagian punya tugas.

| Bagian | Fungsi |
| --- | --- |
| `x` | isi biasa, supaya query terlihat normal |
| `'` | penutup literal string, ini kuncinya |
| `OR` | operator logika, mengubah arti klausa |
| `'1'='1'` | kondisi yang selalu benar |

Kenapa harus ada `x` di depan? Tanpa itu, query menjadi `WHERE device_id = '' OR '1'='1'`, yang juga jalan. Tapi `x` membuat bentuknya mirip nama perangkat, jadi lebih mudah lolos dari filter kasar yang hanya mencari kata `OR`.

Kenapa harus ada `'1'='1'` di akhir? Tanpa itu query berakhir dengan `OR` menggantung, MySQL langsung error sintaks, dan payload yang error adalah payload yang gagal.

---

## 4. Tiga payload, tiga bukti

Demonstrasi menjadi kuat karena tidak hanya menunjukkan satu hasil aneh, tapi tiga hasil yang saling mengunci.

| Payload | Hasil | Arti |
| --- | --- | --- |
| `sensor-01` | 2 baris | perilaku normal |
| `x' OR '1'='1` | 4 baris | seluruh tabel |
| `x' AND '1'='2` | 0 baris | tabel kosong |

Kalau hanya menunjukkan yang OR, orang bisa menjawab "itu kebetulan atau bug tampilan". Begitu payload AND mengembalikan nol, argumen itu mati. Nol tidak bisa dijelaskan oleh bug tampilan, karena nol berarti logika database yang diubah, bukan halaman.

Satu parameter, tiga hasil berbeda, semuanya masuk akal secara logika SQL. Itu bukti mekanisme, bukan bukti gejala.

---

## 5. Kenapa validasi masukan bukan solusi

Percobaan pertama biasanya menambahkan filter sederhana:

```python
if "OR" in dev:
    tolak
```

Bypass-nya banyak:

| Trik | Contoh | Lolos filter `OR` |
| --- | --- | --- |
| huruf kecil | `x' or '1'='1` | ya |
| komentar | `x'/**/OR/**/'1'='1` | ya |
| operator lain | `x' || '1'='1` | ya |
| tanpa kutip | `device=1 OR 1=1` pada kolom angka | ya |
| encoding | `x%27%20OR%20%271%27%3D%271` | tergantung |
| substring | `x' O/**/R '1'='1` | ya |

Yang dikejar terus berubah. Namanya blacklist, dan blacklist selalu kalah, karena penyerang bisa mencoba ribuan variasi sementara programmer hanya bisa memikirkan beberapa.

Yang benar adalah memindahkan nilai keluar dari teks query. Bukan memeriksa isinya, tapi memastikan isinya tidak pernah bisa menjadi perintah, mau isinya apa pun.

---

## 6. Bagaimana versi aman menutupnya

Baris 54 versi aman:

```python
ambil("SELECT * FROM sensor_readings WHERE device_id = %s", (dev,))
```

Dua hal yang berubah.

**Pertama, `%s` tanpa kutip.** Versi rentan memakai `'%s'`, versi aman hanya `%s`. Ini bukan gaya penulisan, ini penanda bahwa posisi tersebut akan diisi nilai terikat, bukan ditempel sebagai teks.

**Kedua, `(dev,)` pada argumen kedua.** Nilai dikirim terpisah. Koma di dalamnya penting, itu yang membuat Python membacanya sebagai tuple satu elemen, bukan string di dalam kurung.

Lalu di dalam fungsi `ambil`, baris 23:

```python
cur.execute(sql, nilai)
```

pymysql mengambil nilai `dev` dan meng-escape karakter yang punya arti khusus di MySQL: `\0`, `\n`, `\r`, `\`, `'`, `"`, dan `\x1a`.

`x' OR '1'='1` berubah menjadi:

```
x\' OR \'1\'=\'1
```

Lalu dimasukkan ke dalam kutip yang sudah disiapkan query:

```
WHERE device_id = 'x\' OR \'1\'=\'1'
```

Semua kutip di dalam nilai sekarang menjadi `\'`, yang berarti kutip literal, bukan penutup string. MySQL membacanya sebagai permintaan mencari perangkat bernama persis `x' OR '1'='1`. Tidak ada perangkat dengan nama itu, hasilnya nol.

**Catatan teknis.** Ini client side escaping, bukan prepared statement sejati. Escaping terjadi di Python, bukan di server. Efeknya sama untuk injeksi, tapi secara arsitektur berbeda. Prepared statement sejati mengirim query dan nilai lewat dua paket protokol terpisah, dan query di-parse sekali di server tanpa nilai. Kalau ingin yang sejati, pymysql menyediakan `cursor(prepared=True)`.

Kalau ditanya, jawab jujur: parameterized query dengan escaping di sisi klien. Jangan mengklaim prepared statement.

---

## 7. Kenapa keluaran repr itu masalah terpisah

Ini bukan soal injeksi, tapi soal kebocoran. Dan kebocoran ini menaikkan tingkat serangan.

`str(rows)` menghasilkan:

```
((1, 'sensor-01', 28.5, 65.0, datetime.datetime(2026, 10, 18, 9, 0)), ...)
```

Dari situ penyerang mendapat peta:

| Posisi | Contoh isi | Tipe |
| --- | --- | --- |
| 0 | 1 | int |
| 1 | sensor-01 | str |
| 2 | 28.5 | float |
| 3 | 65.0 | float |
| 4 | 2026-10-18 09:00 | datetime |

Kenapa penting? Karena `UNION SELECT` mensyaratkan jumlah kolom yang sama. Tanpa bocoran ini, penyerang harus menebak satu per satu: satu kolom gagal, dua gagal, tiga gagal, sampai lima berhasil. Dengan bocoran, dia langsung tahu harus lima, dan tahu tipe tiap posisi supaya tidak error konversi.

Jadi kebocoran bentuk keluaran bukan sekadar kurang rapi. Itu mempersingkat kerja penyerang.

Versi aman menggantinya dengan JSON, yang hanya mengirim nama kolom dan nilai, tanpa jejak tipe Python.

---

## 8. Seberapa jauh kerusakannya

**Yang bisa:**

Membaca semua baris tabel lewat `OR`. Membaca tabel lain lewat `UNION SELECT` kalau jumlah kolom cocok dan user database punya hak ke tabel itu. Membaca struktur database lewat `information_schema.tables` dan `information_schema.columns`, yang hampir selalu bisa diakses semua user.

**Yang tidak bisa:**

Menumpuk perintah dengan titik koma. Payload `x'; DROP TABLE sensor_readings; --` ditolak, karena pymysql tidak mengaktifkan flag `MULTI_STATEMENTS`. Satu `COM_QUERY` hanya boleh satu statement.

Jadi dampaknya baca dan ubah data dalam satu query, bukan eksekusi perintah berantai.

**Yang menentukan seberapa parah:** hak akses user MySQL yang dipakai aplikasi. Kalau user itu hanya punya `SELECT` di satu tabel, kerusakan terbatas di situ. Kalau dia punya `ALL PRIVILEGES`, bisa sampai hapus data. Ini prinsip least privilege, dan alasan user aplikasi tidak boleh memakai `root` database.

---

## 9. Kenapa hardening tidak menolong

Sebelum hardening, MySQL mendengarkan di `0.0.0.0:3306` dan penyerang bisa langsung menyambung.

Setelah hardening, MySQL hanya mendengarkan di loopback. Dari luar, timeout.

Kelihatannya aman. Tapi lihat dari sudut pandang aplikasi:

```
Penyerang -> port 3000 (terbuka) -> aplikasi -> loopback -> MySQL
```

Jalurnya hanya berpindah, bukan tertutup. Aplikasi berada di dalam mesin yang sama, jadi dia boleh menyambung ke loopback. Dan aplikasi meneruskan query apa pun yang disuruh, memakai izinnya sendiri.

Ini disebut confused deputy: penyerang tidak punya izin ke database, tapi dia bisa menyuruh sesuatu yang punya izin untuk mengambilkan data.

Yang menutup jalur ini bukan firewall, bukan loopback, tapi satu baris kode. Dan itu baru terbukti kalau serangannya diulang setelah mitigasi.

---

## 10. Ringkasan satu paragraf

Aplikasi menyambung masukan pengguna ke teks query memakai `%`, sehingga batas antara perintah dan data hilang sebelum sampai ke database. MySQL menerima satu teks yang sudah tercampur, mem-parse-nya sebagai query sah, dan menjalankannya dengan izin yang dimiliki aplikasi. Menutup port 3306 hanya memindahkan jalur, karena aplikasi tetap menjadi perantara yang punya izin ke database. Perbaikannya bukan memfilter masukan, tapi mengirim nilai sebagai parameter terpisah, sehingga apa pun isinya tidak pernah bisa dibaca sebagai perintah.

---

## Tabel ringkas seluruh perubahan versi aman

| Baris | Versi rentan | Versi aman | Jenis |
| --- | --- | --- | --- |
| query `/sensor` | `'%s'` disambung dengan `%` | `%s` dengan argumen `(dev,)` | keamanan, inti |
| keluaran `/sensor` | `str(rows)` | `jsonify` | keamanan, kebocoran |
| sel tabel `/` | ditempel langsung | `html.escape` | keamanan, XSS |
| header tabel `/` | ditulis manual | dari `cur.description` | ketahanan |
| mode debug | default | `debug=False` eksplisit | penegasan |
| petunjuk di `/` | ada | dihapus | kebersihan |

Dari seluruh perubahan itu, yang benar-benar menutup SQL injection hanya satu: `cur.execute(sql, nilai)`.

Yang tidak disentuh sama sekali: MQTT tetap tanpa autentikasi, tidak ada rate limit, tidak ada validasi panjang masukan, kredensial database tetap di `/etc/iot/iot.env` dengan izin yang sama.

---

# BAGIAN 2 - NASKAH NARASI VIDEO

Ini narasi presentasi, bukan tutorial. Audiens tidak perlu tahu fungsi setiap opsi perintah. Yang mereka perlu tahu: apa yang kami lakukan, kenapa, dan apa arti hasilnya.

Perintahnya tetap terlihat di layar. Narasinya bicara di atas perintah itu, bukan membacakannya.

---

## SCENE 1 - Pembuka

**Layar:** tiga jendela VM.

**Narasi:**

Selamat malam. Kami Kelompok 5, skenario 05, Internal Database Fortress.

Sistem yang kami bangun adalah sprinkler otomatis untuk kandang sapi perah. Sensor membaca suhu dan kelembapan, data masuk ke basis data, lalu ditampilkan di dashboard.

Kalau data itu dipalsukan, penyiram bisa menyala di waktu yang salah. Untuk ternak, itu bukan gangguan kecil.

Karena itu, yang kami uji bukan sensornya, melainkan jalur datanya.

Pengujian berlangsung di tiga mesin dalam satu segmen tertutup: target, penyerang, dan pemantau.

Metodenya purple team. Setelah serangan, kami menyiapkan mitigasi, lalu mengulang serangan yang sama. Kalau hanya menyerang, itu red team. Yang membedakan ada di pengulangan terakhir.

---

## SCENE 2 - Menyalakan mesin

**Layar:** terminal host.

**Aksi:**

```
"/c/Program Files/Oracle/VirtualBox/VBoxManage.exe" startvm "AYAM" --type headless
"/c/Program Files/Oracle/VirtualBox/VBoxManage.exe" startvm "Cybersecurity LabVM Worksation 20230210" --type headless
"/c/Program Files/Oracle/VirtualBox/VBoxManage.exe" startvm "CyberOps Security Onion" --type headless
"/c/Program Files/Oracle/VirtualBox/VBoxManage.exe" list runningvms
```

**Narasi:**

Ketiga mesin dinyalakan dengan urutan target lebih dulu, pemantau terakhir, karena mesin pemantau paling lama mencapai kondisi siap.

Semuanya berada di satu segmen internal tanpa akses internet, jadi seluruh pengujian berlangsung tertutup.

---

## SCENE 3 - Mengembalikan kondisi target

**Layar:** jendela AYAM.

**Aksi:**

```
sudo bash /tmp/purple.sh reset
```

**Narasi:**

Sebelum pengujian, mesin target dikembalikan ke kondisi sebelum mitigasi.

Tanpa langkah ini, serangan tidak akan berhasil, dan tidak ada yang bisa dibuktikan. Pengujian harus dimulai dari kondisi yang memang rentan.

Prosesnya mengembalikan berkas aplikasi versi lama, membuka layanan pesan, membersihkan data uji dari sesi sebelumnya, dan memastikan tidak ada blokir yang tertinggal.

Satu hal yang paling sering terlewat: proses lama harus dihentikan lebih dulu. Kalau berkas diganti sementara aplikasi masih berjalan, aplikasi tetap memakai kode yang sudah masuk ke memori. Berkasnya benar, perilakunya tidak berubah.

Di akhir, skrip memastikan aplikasi benar-benar berjalan dalam kondisi rentan. Kalau statusnya masih terbaca aman, pengujian tidak dilanjutkan.

---

## SCENE 4 - Titik pemantauan

**Layar:** jendela Onion.

**Aksi:**

```
ip -br a
sudo tcpdump -i eth2 -n -w /tmp/pbl5-demo.pcap -U
```

**Narasi:**

Pengujian dimulai dari titik pemantauan, karena seluruh rangkaian serangan harus terekam.

Perekaman dijalankan pada antarmuka yang terhubung ke segmen yang sama dengan target dan penyerang. Dengan begitu, semua lalu lintas di antara keduanya ikut terlihat, tanpa perlu memasang apa pun di mesin penyerang.

Rekaman ini dimulai sebelum serangan pertama, bukan sesudahnya. Alasannya, sensor di lab ini bekerja dengan menganalisis berkas tangkapan, bukan memantau kabel secara langsung. Kalau rekaman tidak dimulai dari awal, tahap deteksi tidak akan punya data apa pun.

Selama proses berjalan, layar tidak menampilkan apa pun. Rekamannya tetap berjalan, hanya saja hasilnya masuk ke berkas, bukan ke tampilan. Kami biarkan sampai seluruh rangkaian serangan selesai.

---

## SCENE 5 - Pemetaan layanan

**Layar:** jendela Attacker.

**Aksi:**

```
nmap -sS -sV -p- 192.168.5.5
```

**Narasi:**

Tahap pertama adalah pemetaan layanan. Kami ingin tahu permukaan serangan yang tersisa setelah hardening: port apa yang masih terbuka, dan versi apa yang dipakai.

Hasilnya tiga port. Dua untuk administrasi dan pertukaran data, satu untuk dashboard. Basis data tidak muncul sama sekali.

Yang perlu dicatat, basis datanya tetap berjalan. Yang berubah hanya keterlihatannya dari jaringan.

Waktu pemindaian juga meningkat dari sekitar dua puluh detik menjadi hampir delapan ratus detik. Paket ke port yang tidak diizinkan dibuang tanpa jawaban, jadi penyerang menghabiskan waktu tanpa memperoleh apa pun.

---

## SCENE 6 - Jalur autentikasi

**Layar:** jendela Attacker, lalu AYAM.

**Aksi:**

```
nc -vz 192.168.5.5 3306
hydra -l root -P /usr/share/wordlists/rockyou.txt ssh://192.168.5.5 -t 4
sudo fail2ban-client status sshd
```

**Narasi:**

Tahap kedua menyasar jalur autentikasi.

Sambungan langsung ke basis data berakhir tanpa jawaban. Ini berbeda dari penolakan. Penolakan berarti ada layanan yang menjawab, sedangkan tanpa jawaban berarti dari sisi penyerang tidak ada apa pun di sana.

Untuk SSH, percobaan tebak kata sandi berhenti pada tahap negosiasi, karena layanan hanya menerima kunci. Artinya tidak ada satu kata sandi pun yang benar-benar diuji, sehingga kami tidak menyimpulkan apa pun tentang kekuatan kata sandi di mesin ini.

Di sisi pertahanan, ada pencatatan dan pemblokiran otomatis terhadap alamat yang gagal berulang kali. Jadi ada dua lapis: jalur masuknya ditutup, dan percobaan yang tetap datang dicatat.

---

## SCENE 7 - Lapisan aplikasi

**Layar:** jendela Attacker.

**Aksi:**

```
curl "http://192.168.5.5:3000/sensor?device=sensor-01"
curl "http://192.168.5.5:3000/sensor?device=x%27%20OR%20%271%27%3D%271"
curl "http://192.168.5.5:3000/sensor?device=x%27%20AND%20%271%27%3D%272"
```

**Narasi:**

Tahap ketiga menyasar lapisan aplikasi, dan ini temuan utama kami.

Permintaan normal mengembalikan dua baris, sesuai perangkat yang diminta.

Ketika parameter diubah menjadi kondisi yang selalu benar, seluruh isi tabel terbuka.

Ketika diubah menjadi kondisi yang selalu salah, hasilnya kosong.

Tiga respons berbeda dari satu parameter yang sama. Ini menunjukkan bahwa masukannya mengubah logika query, bukan sekadar tampilan halaman.

Kalau hanya ditunjukkan kasus pertama, hasilnya masih bisa diperdebatkan sebagai kebetulan. Hasil kosong pada kasus ketiga menutup perdebatan itu.

Ada satu kebocoran tambahan. Bentuk keluarannya masih format mentah bahasa pemrograman, sehingga struktur dan tipe kolom ikut terbaca dari luar.

---

## SCENE 8 - Kepercayaan pada data

**Layar:** dua terminal Attacker, lalu AYAM, lalu browser.

**Aksi:**

```
mosquitto_sub -h 192.168.5.5 -t 'sensors/#' -v
mosquitto_pub -h 192.168.5.5 -t sensors/sensor-99 -m 99.90
tail -3 /var/log/iot/subscriber.log
```

**Narasi:**

Skenario yang sama juga membuka jalur kedua: penyisipan data.

Layanan pesan menerima pengirim tanpa identitas, sehingga satu pesan bisa masuk seolah berasal dari perangkat yang sah.

Kami mengirim pembacaan atas nama perangkat yang tidak pernah ada. Data itu tercatat, dan langsung tampil di dashboard tanpa penanda apa pun.

Suhu yang dikirim mustahil untuk ternak, tetapi sistem memperlakukannya sama seperti data asli.

Di titik ini, masalahnya bukan pencurian data, melainkan hilangnya kepercayaan pada data. Sistem yang mengambil keputusan dari data palsu bisa lebih berbahaya daripada sistem yang berhenti.

---

## SCENE 9 - Analisis

**Layar:** jendela Onion.

**Aksi:**

```
tcpdump -r /tmp/pbl5-demo.pcap | wc -l
sudo so-import-pcap /tmp/pbl5-demo.pcap
```

**Narasi:**

Setelah rangkaian serangan selesai, perekaman dihentikan dan berkas tangkapan dimasukkan ke sensor.

Proses ini memerlukan waktu, karena berkas dibaca ulang oleh dua mesin analisis, lalu hasilnya dimasukkan ke basis data pencarian.

Konsekuensinya, analisis dalam metode kami berjalan setelah serangan, bukan saat serangan berlangsung. Itu keterbatasan yang kami catat, bukan yang kami sembunyikan.

---

## SCENE 10 - Deteksi

**Layar:** Kibana, Discover.

**Aksi:** index pattern `logstash`, rentang 24 jam, lalu:

```
"192.168.5.100" AND "192.168.5.5"
```

**Narasi:**

Hasil analisis menampilkan lalu lintas antara mesin penyerang dan mesin target.

Yang tercatat adalah pola koneksi: port tujuan, jumlah data, dan status penyelesaian. Status yang terbaca menunjukkan koneksi selesai dengan normal, artinya server memang membalas.

Ada dua batas yang perlu kami sampaikan.

Pertama, karena sensor bekerja dari berkas tangkapan, ada jeda antara serangan dan hasil analisis.

Kedua, yang terekam adalah bentuk lalu lintas, bukan isi serangan. Tidak ada aturan yang mengenali injeksi pada parameter, dan tidak ada yang mengenali penyisipan pesan. Jadi kedua serangan tadi tidak muncul sebagai peringatan.

Deteksi kami kuat di lapisan jaringan dan lemah di lapisan aplikasi. Itu kami catat sebagai kekurangan, dan menjadi pekerjaan berikutnya.

---

## SCENE 11 - Mitigasi

**Layar:** jendela AYAM.

**Aksi:**

```
sudo bash /tmp/purple.sh mitigasi
```

**Narasi:**

Mitigasi dilakukan pada lapisan aplikasi.

Aplikasi dihentikan lebih dulu, berkasnya diganti, baru dijalankan kembali. Urutan ini bukan formalitas. Proses yang berjalan menyimpan kode di memori, jadi penggantian berkas saat aplikasi masih hidup tidak mengubah perilakunya.

Setelah penggantian, masukan tidak lagi disambung ke dalam query, melainkan dikirim sebagai nilai terpisah. Basis data menerimanya sebagai data, dan tidak akan pernah membacanya sebagai perintah.

Keluarannya juga diubah menjadi format terstruktur, sehingga struktur tabel tidak lagi terbaca dari luar.

---

## SCENE 12 - Verifikasi

**Layar:** jendela Attacker.

**Aksi:**

```
curl "http://192.168.5.5:3000/sensor?device=x%27%20OR%20%271%27%3D%271"
curl "http://192.168.5.5:3000/sensor?device=sensor-01"
```

**Narasi:**

Untuk membuktikan mitigasi, serangan yang sama diulang tanpa perubahan apa pun.

Hasilnya kosong.

Karena serangannya identik, perubahan hasil hanya bisa disebabkan oleh perubahan pada aplikasi. Kalau kami hanya menyatakan sudah dimitigasi, itu klaim. Dengan mengulang serangan yang sama, itu bukti.

Pengujian juga dilakukan pada permintaan normal, untuk memastikan aplikasi tetap berfungsi dan tidak rusak oleh mitigasi.

---

## SCENE 13 - Penutup

**Layar:** tiga jendela VM.

**Narasi:**

Kesimpulannya.

Pemetaan layanan tertutup. Yang tersisa tiga port, dan basis data tidak terlihat dari jaringan.

Jalur autentikasi tertutup. Basis data hanya menerima sambungan dari dalam mesin, SSH hanya menerima kunci, dan percobaan berulang diblokir otomatis.

Injeksi pada lapisan aplikasi tertutup, dan terbukti lewat pengulangan serangan yang sama.

Penyisipan data lewat layanan pesan belum tuntas. Konfigurasi untuk menutupnya sudah disiapkan, tetapi belum terbukti berlaku penuh. Karena itu kami catat sebagai temuan terbuka.

Kami memilih mencatatnya apa adanya, karena konfigurasi yang belum terbukti berlaku bukan mitigasi.

Sekian, terima kasih.

---

# Catatan Produksi

Rekam dua sesi kalau mau hemat waktu. Sesi 1 Scene 1 sampai 8, berhenti saat dashboard menampilkan data palsu. Sesi 2 Scene 9 sampai 13. Perekaman di mesin pemantau jangan dihentikan di antara dua sesi.

Jangan dipotong: Scene 3, Scene 7, Scene 12.

Boleh dipotong: bagian menunggu pemindaian dan bagian menunggu analisis.

Kalau ada yang gagal, jangan disunting seolah berhasil. Kembalikan kondisi target, ulangi dari Scene 7.
