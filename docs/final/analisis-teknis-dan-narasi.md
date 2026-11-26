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
# BAGIAN 2 - NASKAH NARASI VIDEO

---

## SCENE 1 - Pembuka

**Layar:** tiga jendela VM.

**Narasi:**

Selamat malam. Saya Fattih, dari Kelompok 5, skenario 05, Internal Database Fortress.

Sistem yang kami bangun adalah sprinkler otomatis untuk kandang sapi perah. Sensor membaca suhu dan kelembapan, data dikirim ke basis data, lalu ditampilkan di dashboard. Keputusan penyiraman diambil dari data itu.

Artinya, kalau datanya salah, tindakan yang diambil juga salah. Penyiram bisa menyala saat kandang sebenarnya tidak panas, atau diam saat suhu benar-benar naik.

Karena itu, yang kami uji bukan sensornya, melainkan jalur datanya, dari sensor sampai dashboard.

Pengujian berlangsung pada tiga mesin dalam satu segmen tertutup. Target di 192.168.5.5, penyerang di 192.168.5.100, dan pemantau di 192.168.5.200.

Metodenya purple team. Kami menyerang, menyiapkan mitigasi, lalu mengulang serangan yang sama untuk membuktikan hasilnya.

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

Pertama, ketiga mesin dinyalakan dengan urutan target, penyerang, lalu pemantau. Pemantau dinyalakan terakhir karena memerlukan waktu paling lama untuk mencapai kondisi siap.

Setelah itu kami pastikan ketiganya benar-benar berjalan sebelum pengujian dimulai.

---

## SCENE 3 - Mengembalikan kondisi target

**Layar:** jendela AYAM.

**Aksi:**

```
sudo bash /tmp/purple.sh reset
```

**Narasi:**

Sebelum pengujian, mesin target dikembalikan ke kondisi sebelum mitigasi. Langkah ini wajib. Kalau target sudah dalam kondisi aman, serangan tidak akan berhasil, dan tidak ada yang bisa dibuktikan.

Proses pengembaliannya mencakup pemasangan aplikasi versi rentan, pembukaan layanan pesan, pembersihan data uji dari sesi sebelumnya, dan pelepasan blokir yang tertinggal.

Ada satu hal yang sering terlewat di tahap ini. Proses lama harus dihentikan lebih dahulu. Jika berkas aplikasi diganti sementara aplikasinya masih berjalan, aplikasi tetap memakai kode yang sudah dimuat ke memori. Berkasnya sudah benar, tetapi perilakunya tidak berubah.

Di akhir, skrip memeriksa sendiri hasilnya. Kalau statusnya masih terbaca aman, pengujian tidak dilanjutkan.

---

## SCENE 4 - Titik pemantauan

**Layar:** jendela onion.

**Aksi:**

```
ip -br a
sudo tcpdump -i eth2 -n -w /tmp/pbl5-demo.pcap -U
```

**Narasi:**

Pengujian dimulai dari titik pemantauan, karena seluruh rangkaian serangan harus terekam.

Pertama kami pastikan antarmuka mana yang terhubung ke segmen target. Alamat pemantau adalah 192.168.5.200, dan antarmukanya eth2. Seluruh lalu lintas antara penyerang dan target melewati antarmuka ini, jadi kami tidak perlu memasang alat apa pun di mesin penyerang.

Perekaman dimulai sebelum serangan pertama, bukan sesudahnya. Ini bukan pilihan gaya. Sensor di lab ini bekerja dengan menganalisis berkas tangkapan, bukan memantau kabel secara langsung. Kalau rekaman baru dimulai setelah serangan, tidak ada data yang bisa dianalisis, dan tahap deteksi otomatis kosong.

Selama proses berjalan, layar tidak menampilkan apa pun. Rekaman tetap berjalan, hanya saja hasilnya ditulis ke berkas. Layar kosong bukan berarti gagal.

---

## SCENE 5 - Pemetaan layanan

**Layar:** jendela penyerang.

**Aksi:**

```
nmap -sS -sV -p- 192.168.5.5
```

**Narasi:**

Tahap pertama adalah pemetaan layanan. Tujuannya sederhana: mengetahui permukaan serangan yang tersisa setelah hardening.

Hasilnya tiga port. 22 untuk SSH, 1883 untuk layanan pesan, dan 3000 untuk dashboard. Port 3306, yaitu basis data, tidak muncul sama sekali.

Yang perlu ditegaskan, basis datanya tetap berjalan dan tetap menyimpan seluruh data. Yang berubah hanya keterlihatannya dari jaringan. Dari sisi penyerang, port itu tidak ada. Dari sisi aplikasi, sambungan tetap berjalan normal.

Ini yang membuat pemetaan menjadi langkah penting. Penyerang tidak bisa menyerang apa yang tidak bisa dilihatnya.

---

## SCENE 6 - Jalur autentikasi

**Layar:** jendela penyerang, lalu AYAM.

**Aksi:**

```
nc -vz 192.168.5.5 3306
hydra -l root -P /usr/share/wordlists/rockyou.txt ssh://192.168.5.5 -t 4
sudo fail2ban-client status sshd
```

**Narasi:**

Tahap kedua menyasar jalur autentikasi, karena biasanya di situlah jalan masuk paling murah.

Sambungan langsung ke basis data berakhir timeout, bukan refused. Perbedaannya penting. Refused berarti ada layanan yang menjawab dan menolak, sedangkan timeout berarti paketnya dibuang tanpa jawaban. Dari sisi penyerang, tidak ada apa pun di alamat itu.

Untuk SSH, percobaan tebak kata sandi berhenti pada tahap negosiasi, karena layanan hanya menerima kunci. Tidak ada satu kata sandi pun yang benar-benar diuji. Karena itu kami tidak menyimpulkan apa pun tentang kekuatan kata sandi di mesin ini, dan itu memang bukan bagian dari pengujian kami.

Di sisi pertahanan, percobaan yang gagal berulang dicatat, lalu alamatnya diblokir otomatis.

---

## SCENE 7 - Lapisan aplikasi

**Layar:** jendela penyerang.

**Aksi:**

```
curl "http://192.168.5.5:3000/sensor?device=sensor-01"
curl "http://192.168.5.5:3000/sensor?device=x%27%20OR%20%271%27%3D%271"
curl "http://192.168.5.5:3000/sensor?device=x%27%20AND%20%271%27%3D%272"
```

**Narasi:**

Tahap ketiga menyasar lapisan aplikasi, dan ini temuan utama kami.

Tiga permintaan berikut menunjukkan satu hal: masukan dari URL dapat mengubah perintah yang dikirim ke basis data.

Permintaan normal mengembalikan dua baris, sesuai perangkat yang diminta. Ketika parameternya diubah menjadi kondisi yang selalu benar, seluruh isi tabel terbuka. Ketika diubah menjadi kondisi yang selalu salah, hasilnya kosong.

Hasil kosong itulah yang menutup perdebatan. Kalau hanya kasus pertama yang ditampilkan, masih ada ruang untuk berargumen bahwa itu bug tampilan. Dengan hasil nol pada kasus ketiga, jelas yang berubah adalah logika query, bukan halaman.

Ada kebocoran tambahan. Bentuk keluarannya masih format mentah bahasa pemrograman, sehingga struktur dan tipe kolom ikut terbaca dari luar. Penyerang tidak hanya mendapat isi data, tetapi juga peta tabelnya.

---

## SCENE 8 - Data palsu melalui MQTT

**Layar:** dua terminal penyerang, lalu AYAM, lalu browser.

**Aksi:**

```
mosquitto_sub -h 192.168.5.5 -t 'sensors/#' -v
mosquitto_pub -h 192.168.5.5 -t sensors/sensor-99 -m 99.90
tail -3 /var/log/iot/subscriber.log
```

**Narasi:**

Sekarang masuk ke bagian kedua: injeksi data palsu melalui MQTT.

Terminal kiri memantau seluruh pesan yang masuk, terminal kanan mengirim satu pesan palsu. Pesan langsung diterima tanpa autentikasi dan tanpa penolakan.

Pada mesin target, data tersimpan: sensor-99 dengan suhu 99,9. Sensor ini sebenarnya tidak ada, kami yang membuatnya. Namun subscriber menerimanya begitu saja sebagai data valid.

Pada dashboard, baris tersebut muncul di posisi teratas dengan suhu 99,9. Untuk sapi, suhu normal sekitar 38 derajat, sehingga sistem penyiram akan terus menyala. Dashboard juga tidak memberi tanda bahwa data ini palsu, tampilannya identik dengan data asli.

Dampaknya bukan pencurian data, melainkan hilangnya integritas data. Keputusan yang diambil dari data yang salah akan menghasilkan tindakan yang salah.

Selanjutnya, kita analisis di Security Onion.

---

## SCENE 9 - Analisis

**Layar:** jendela onion.

**Aksi:**

```
tcpdump -r /tmp/pbl5-demo.pcap | wc -l
sudo so-import-pcap /tmp/pbl5-demo.pcap
```

**Narasi:**

Setelah rangkaian serangan selesai, perekaman dihentikan. Jumlah paket diperiksa lebih dahulu. Kalau nol, rekaman dianggap gagal dan tidak ada yang bisa dianalisis.

Berkas tangkapan kemudian dimasukkan ke sensor. Proses ini memerlukan waktu, karena berkas dibaca ulang oleh dua mesin analisis, yaitu Suricata dan Zeek, lalu hasilnya dimasukkan ke basis data pencarian.

Konsekuensinya, analisis dalam metode kami berjalan setelah serangan, bukan saat serangan berlangsung. Itu keterbatasan yang kami catat, bukan yang kami sembunyikan.

---

## SCENE 10 - Deteksi

**Layar:** Kibana, Discover.

**Aksi:** index pattern `logstash`, rentang 24 jam, lalu:

```
"192.168.5.100" AND "192.168.5.5"
```

**Narasi:**

Hasil analisis menampilkan lalu lintas antara mesin penyerang dan mesin target. Yang tercatat adalah bentuk koneksi: port tujuan, jumlah data, dan status penyelesaian. Status yang terbaca menunjukkan koneksi selesai normal, artinya server memang membalas.

Ada dua batas yang perlu kami sampaikan.

Pertama, karena sensor bekerja dari berkas tangkapan, selalu ada jeda antara serangan dan hasil analisis. Deteksi seperti ini tidak bisa dipakai untuk menghentikan serangan yang sedang berjalan.

Kedua, yang terekam adalah bentuk lalu lintas, bukan isi serangan. Tidak ada aturan yang mengenali injeksi pada parameter URL, dan tidak ada yang mengenali penyisipan pesan. Jadi dua serangan tadi tidak muncul sebagai peringatan, hanya sebagai koneksi yang selesai normal.

Deteksi kami kuat di lapisan jaringan, dan lemah tepat di lapisan yang paling kami sorot. Itu kami catat sebagai kekurangan.

---

## SCENE 11 - Mitigasi

**Layar:** jendela AYAM.

**Aksi:**

```
sudo bash /tmp/purple.sh mitigasi
```

**Narasi:**

Mitigasi dilakukan pada lapisan aplikasi. Aplikasinya dihentikan lebih dahulu, berkasnya diganti, baru dijalankan kembali.

Urutan ini bukan formalitas. Proses yang berjalan menyimpan kode di memori, jadi mengganti berkas saat aplikasi masih hidup tidak mengubah perilakunya. Kami sempat mengalami itu saat latihan: berkasnya sudah benar, tetapi hasil pengujian tetap gagal, karena yang berjalan masih kode lama.

Setelah penggantian, ada tiga perubahan. Masukan tidak lagi disambung ke dalam query, melainkan dikirim sebagai nilai terpisah, sehingga basis data membacanya sebagai data dan tidak pernah sebagai perintah. Keluarannya diubah menjadi format terstruktur, sehingga struktur tabel tidak lagi terbaca. Dan mode pengembangan dimatikan, supaya pesan kesalahan tidak menampilkan isi internal aplikasi.

---

## SCENE 12 - Verifikasi

**Layar:** jendela penyerang.

**Aksi:**

```
curl "http://192.168.5.5:3000/sensor?device=x%27%20OR%20%271%27%3D%271"
curl "http://192.168.5.5:3000/sensor?device=sensor-01"
```

**Narasi:**

Untuk membuktikan mitigasi, serangan yang sama diulang tanpa perubahan apa pun.

Hasilnya kosong.

Karena serangannya identik, perubahan hasil hanya dapat disebabkan oleh perubahan pada aplikasi. Kalau kami hanya menyatakan sudah dimitigasi, itu klaim. Dengan mengulang serangan yang sama, itu bukti.

Kami juga menguji permintaan normal, untuk memastikan aplikasi tetap berfungsi dan mitigasinya tidak merusak layanan.

---

## SCENE 13 - Penutup

**Layar:** tiga jendela VM.

**Narasi:**

Kesimpulannya.

Pemetaan layanan tertutup. Tersisa tiga port, dan basis data tidak terlihat dari jaringan meski layanannya tetap berjalan.

Jalur autentikasi tertutup. Basis data hanya menerima sambungan dari dalam mesin, SSH hanya menerima kunci, dan percobaan berulang diblokir otomatis.

Injeksi pada lapisan aplikasi tertutup, dan terbukti melalui pengulangan serangan yang sama.

Penyisipan data melalui layanan pesan belum tuntas. Konfigurasinya sudah disiapkan, tetapi belum terbukti berlaku penuh, sehingga kami catat sebagai temuan terbuka.

Kami memilih mencatatnya apa adanya. Konfigurasi yang belum terbukti bukan mitigasi, dan menyebutnya selesai hanya akan menutupi masalah yang masih ada.

Sekian, terima kasih.

---

# Catatan Produksi

Rekam dua sesi. Sesi pertama Scene 1 sampai 8, berhenti saat dashboard menampilkan data palsu. Sesi kedua Scene 9 sampai 13. Perekaman di mesin pemantau jangan dihentikan di antara dua sesi.

Jangan dipotong: Scene 3, 7, dan 12.

Boleh dipotong: bagian menunggu pemindaian dan menunggu analisis.
