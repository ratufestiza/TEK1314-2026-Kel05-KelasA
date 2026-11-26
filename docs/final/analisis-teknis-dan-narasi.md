# PCAP Import Teknis dan Naskah Narasi

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
# BAGIAN 2 - NASKAH NARASI VIDEO

---

## SCENE 1 - Introduction

**Layar:** tiga jendela VM.

**Narasi:**

Selamat malam. Saya Fattih, mewakili Kelompok 5, skenario 05, Internal Database Fortress.

Sistem yang dikembangkan adalah sprinkler otomatis untuk kandang sapi perah. Sensor membaca suhu dan kelembapan, data dikirim ke basis data, lalu disajikan pada dashboard. Keputusan penyiraman diturunkan dari data tersebut.

Apabila data yang diterima tidak akurat, keputusan yang dihasilkan juga tidak akurat. Karena itu, objek evaluasi pada pengujian ini adalah jalur datanya, mulai dari sensor hingga dashboard, bukan perangkat sensornya.

Pengujian dilaksanakan pada tiga mesin dalam satu segmen tertutup. Target pada 192.168.5.5, penyerang pada 192.168.5.100, dan pemantau pada 192.168.5.200.

Metodenya purple team: serangan dilaksanakan, mitigasi disiapkan, kemudian serangan yang sama diulang untuk memverifikasi efektivitas mitigasi.

---

## SCENE 2 - Starting the Virtual Machines

**Layar:** terminal host.

**Aksi:**

```
"/c/Program Files/Oracle/VirtualBox/VBoxManage.exe" startvm "AYAM" --type headless
"/c/Program Files/Oracle/VirtualBox/VBoxManage.exe" startvm "Cybersecurity LabVM Worksation 20230210" --type headless
"/c/Program Files/Oracle/VirtualBox/VBoxManage.exe" startvm "CyberOps Security Onion" --type headless
"/c/Program Files/Oracle/VirtualBox/VBoxManage.exe" list runningvms
```

**Narasi:**

Penyiapan lingkungan dijalankan dari host. Ketiga mesin dinyalakan tanpa jendela grafis, dengan urutan target, penyerang, kemudian pemantau, karena pemantau paling lama mencapai kondisi siap.

Perintah terakhir menampilkan daftar mesin yang sedang beroperasi, untuk memastikan ketiganya aktif sebelum pengujian dimulai.

---

## SCENE 3 - Restoring the Vulnerable State

**Layar:** jendela AYAM.

**Aksi:**

```
sudo bash /tmp/purple.sh reset
```

**Narasi:**

Sebelum pengujian, target dikembalikan ke kondisi sebelum mitigasi. Tahap ini prasyarat: apabila target sudah berada pada kondisi aman, serangan tidak akan berhasil, sehingga tidak ada fenomena yang dapat diobservasi.

Perintah ini menjalankan skrip pengembalian kondisi dengan hak administrator. Skrip menghentikan proses yang sedang berjalan, memasang aplikasi versi rentan, membuka layanan pesan, menghapus data uji dari sesi sebelumnya, melepas blokir alamat penyerang, lalu menjalankan kembali seluruh proses.

Proses lama harus dihentikan lebih dahulu. Apabila berkas diganti sementara aplikasi masih berjalan, aplikasi tetap memakai kode yang telah dimuat ke memori: berkas pada disk sudah benar, tetapi perilakunya tidak berubah.

Di akhir, skrip memverifikasi hasilnya sendiri. Apabila kondisi rentan belum tercapai, pengujian tidak dilanjutkan.

---

## SCENE 4 - Packet Capture

**Layar:** jendela onion.

**Aksi:**

```
ip -br a
sudo tcpdump -i eth2 -n -w /tmp/pbl5-demo.pcap -U
```

**Narasi:**

Pengujian dimulai dari titik pemantauan, karena seluruh rangkaian serangan harus terdokumentasi.

Perintah pertama menampilkan daftar antarmuka jaringan pada mesin pemantau. Perintah ini hanya membaca, tidak mengubah konfigurasi. Dari hasilnya diketahui bahwa antarmuka yang terhubung ke segmen target adalah eth2, dengan alamat 192.168.5.200.

Perintah kedua merekam seluruh lalu lintas pada antarmuka tersebut dan menyimpannya ke dalam berkas, bukan menampilkannya di layar. Karena keluarannya berupa berkas, terminal akan tampak kosong selama proses berjalan. Perintah ini dijalankan dengan hak administrator karena perekaman pada antarmuka jaringan memerlukannya.

Perekaman dimulai sebelum serangan pertama, karena sensor pada lingkungan ini menganalisis berkas tangkapan, bukan memantau media transmisi secara langsung. Apabila perekaman dimulai setelah serangan, tidak ada data yang dapat dianalisis.

---

## SCENE 5 - Service Enumeration

**Layar:** jendela penyerang.

**Aksi:**

```
nmap -sS -sV -p- 192.168.5.5
```

**Narasi:**

Tahap pertama adalah pemetaan layanan, untuk mengidentifikasi permukaan serangan yang tersisa setelah hardening.

Perintah ini memindai seluruh rentang port pada mesin target, sekaligus membaca versi layanan yang memberikan respons. Teknik yang dipakai bersifat setengah terbuka, sehingga pemindaian berlangsung cepat dan tidak meninggalkan catatan sesi pada layanan yang dipindai.

Hasilnya tiga port: 22 untuk SSH, 1883 untuk layanan pesan, dan 3000 untuk dashboard. Port 3306, layanan basis data, tidak terdeteksi.

Basis datanya tetap beroperasi dan tetap menyimpan seluruh data. Yang berubah hanya keterlihatannya dari jaringan. Dari sisi penyerang port itu tidak ada, dari sisi aplikasi koneksinya normal. Objek yang tidak dapat diidentifikasi tidak dapat dijadikan sasaran.

---

## SCENE 6 - Authentication Mechanism

**Layar:** jendela penyerang, lalu AYAM.

**Aksi:**

```
nc -vz 192.168.5.5 3306
hydra -l root -P /usr/share/wordlists/rockyou.txt ssh://192.168.5.5 -t 4
sudo fail2ban-client status sshd
```

**Narasi:**

Tahap kedua diarahkan pada mekanisme autentikasi, dengan tiga perintah berbeda.

Perintah pertama menguji apakah port basis data dapat dihubungi, tanpa mengirimkan data apa pun. Hasilnya timeout, bukan refused. Refused berarti ada layanan yang menjawab dan menolak, sedangkan timeout berarti paket dibuang tanpa respons.

Perintah kedua mencoba daftar kata sandi umum terhadap layanan SSH, dengan akun root sebagai sasaran dan jumlah percobaan paralel dibatasi agar layanan tidak dibanjiri. Prosesnya terhenti pada tahap negosiasi, karena layanan hanya menerima autentikasi berbasis kunci. Tidak ada kata sandi yang benar-benar diuji, sehingga tidak ada kesimpulan mengenai kekuatan kata sandi.

Perintah ketiga dijalankan pada mesin target, bukan penyerang, dan hanya membaca keadaan mekanisme pemblokiran otomatis untuk layanan SSH. Hasilnya menunjukkan percobaan gagal berulang dicatat, lalu alamat sumbernya diblokir.

---

## SCENE 7 - SQL Injection

**Layar:** jendela penyerang.

**Aksi:**

```
curl "http://192.168.5.5:3000/sensor?device=sensor-01"
curl "http://192.168.5.5:3000/sensor?device=x%27%20OR%20%271%27%3D%271"
curl "http://192.168.5.5:3000/sensor?device=x%27%20AND%20%271%27%3D%272"
```

**Narasi:**

Tahap ketiga diarahkan pada lapisan aplikasi, dan pada tahap inilah temuan utama diperoleh.

Ketiga perintah mengirim permintaan HTTP ke dashboard lalu menampilkan responsnya di terminal. Yang membedakan ketiganya bukan alatnya, melainkan nilai yang dikirim pada parameter perangkat.

Perintah pertama meminta data perangkat yang memang terdaftar, sebagai pembanding bentuk respons normal. Hasilnya dua baris.

Perintah kedua mengirim nilai yang, setelah diterjemahkan dari bentuk terenkodenya, berisi kutip penutup diikuti klausa kondisi yang selalu bernilai benar. Kutip itu memutus batas antara perintah dan data, sehingga klausa tambahan dibaca sebagai bagian dari query. Hasilnya seluruh isi tabel terbuka.

Perintah ketiga mengirim pola yang sama, tetapi dengan kondisi yang selalu bernilai salah. Hasilnya kosong.

Hasil kosong itulah buktinya. Apabila hanya perintah kedua yang disajikan, masih terbuka kemungkinan bahwa yang terjadi adalah kesalahan penyajian. Dengan hasil nol pada perintah ketiga, yang berubah jelas logika query, bukan tampilan.

Ada kebocoran tambahan: format keluarannya masih representasi mentah bahasa pemrograman, sehingga struktur dan tipe kolom ikut terbaca.

---

## SCENE 8 - MQTT Data Injection

**Layar:** dua terminal penyerang, lalu AYAM, lalu browser.

**Aksi:**

```
mosquitto_sub -h 192.168.5.5 -t 'sensors/#' -v
mosquitto_pub -h 192.168.5.5 -t sensors/sensor-99 -m 99.90
tail -3 /var/log/iot/subscriber.log
```

**Narasi:**

Bagian kedua diarahkan pada injeksi data melalui layanan pesan, dengan tiga perintah pada dua mesin.

Perintah pertama dijalankan di terminal kiri mesin penyerang, dan berfungsi memantau seluruh pesan yang masuk ke broker pada semua topik sensor, sambil menampilkan asal setiap pesan. Perintah ini berjalan terus sampai dihentikan.

Perintah kedua dijalankan di terminal kanan, dan mengirim satu pesan ke topik perangkat yang ditentukan, dengan isi berupa satu nilai suhu. Identitas perangkat ditentukan oleh pengirim, bukan oleh perangkatnya. Pesan diterima tanpa autentikasi dan tanpa penolakan.

Perintah ketiga dijalankan pada mesin target, dan menampilkan bagian akhir log layanan penerima. Fungsinya memastikan pesan benar-benar tercatat di sisi penerima, bukan sekadar lewat di jaringan.

Hasilnya, data tersimpan dengan identitas sensor-99 dan suhu 99,9. Perangkat itu tidak pernah ada, diciptakan pada pengujian ini, namun layanan penerima memperlakukannya sebagai data valid.

Pada dashboard, data tampil di posisi teratas. Suhu normal sapi perah sekitar 38 derajat, sehingga penyiram akan aktif terus-menerus. Dashboard juga tidak memberi penanda bahwa data itu tidak sah.

Dampaknya bukan pencurian data, melainkan hilangnya integritas data. Keputusan yang diturunkan dari data yang tidak akurat akan menghasilkan tindakan yang tidak akurat.

Selanjutnya, analisis dilakukan pada Security Onion.

---

## SCENE 9 - PCAP Import

**Layar:** jendela onion.

**Aksi:**

```
tcpdump -r /tmp/pbl5-demo.pcap | wc -l
sudo so-import-pcap /tmp/pbl5-demo.pcap
```

**Narasi:**

Setelah serangan selesai, perekaman dihentikan dan hasilnya diperiksa sebelum dianalisis.

Perintah pertama membaca kembali berkas tangkapan yang telah dibuat, lalu menghitung jumlah paket di dalamnya. Apabila hasilnya nol, perekaman dinyatakan gagal.

Perintah kedua memasukkan berkas yang sama ke dalam sensor. Dua mesin analisis dijalankan terhadap berkas itu: Suricata untuk pencocokan aturan, dan Zeek untuk pembentukan catatan koneksi. Hasilnya kemudian dimasukkan ke basis data pencarian milik sensor.

Prosesnya memerlukan waktu. Konsekuensinya, analisis berlangsung setelah serangan, bukan pada saat serangan berlangsung.

---

## SCENE 10 - Detection in Kibana

**Layar:** Kibana, Discover.

**Aksi:** index pattern `logstash`, rentang 24 jam, lalu:

```
"192.168.5.100" AND "192.168.5.5"
```

**Narasi:**

Hasil analisis disajikan pada antarmuka pencarian mesin pemantau.

Langkah pertama memilih kumpulan indeks yang akan dicari, sesuai penamaan pada versi sensor yang digunakan di lab ini.

Langkah kedua menetapkan rentang waktu. Data hasil impor membawa waktu asli perekaman, bukan waktu impor, sehingga rentangnya diperlebar menjadi dua puluh empat jam. Apabila terlalu sempit, hasil pencarian akan kosong meskipun impor berhasil.

Langkah ketiga mencari dua alamat sekaligus dengan pencarian teks bebas, bukan filter berdasarkan nama kolom, karena penamaan kolom berbeda antar versi sensor. Hasilnya catatan yang memuat keduanya, yaitu koneksi antara penyerang dan target.

Data yang muncul mencakup port tujuan, jumlah byte, dan status penyelesaian. Statusnya menunjukkan koneksi selesai normal, yang berarti server memberi respons.

Ada dua batas. Pertama, karena sensor bekerja dari berkas tangkapan, selalu ada jeda antara serangan dan hasil analisis, sehingga deteksi ini tidak dapat menghentikan serangan yang sedang berlangsung. Kedua, yang terekam adalah bentuk lalu lintas, bukan isi serangan. Tidak ada aturan yang mengenali injeksi pada parameter URL, dan tidak ada yang mengenali penyisipan pesan. Kedua serangan itu tidak muncul sebagai peringatan.

---

## SCENE 11 - Mitigation

**Layar:** jendela AYAM.

**Aksi:**

```
sudo bash /tmp/purple.sh mitigasi
```

**Narasi:**

Mitigasi dilakukan pada lapisan aplikasi, memakai skrip yang sama dengan tahap pengembalian kondisi, tetapi dengan mode yang berbeda.

Mode ini hanya menyentuh aplikasi. Konfigurasi layanan pesan, basis data, dan mekanisme pemblokiran tidak diubah, agar perubahan yang diuji terbatas pada satu variabel dan perbedaan hasil dapat diatribusikan dengan jelas.

Skrip bekerja dalam tiga urutan: menghentikan aplikasi, mengganti berkasnya dengan versi yang diperbaiki, lalu menjalankannya kembali.

Urutan ini bukan formalitas. Proses yang beroperasi menyimpan kode di memori, sehingga penggantian berkas saat aplikasi masih berjalan tidak mengubah perilakunya. Kondisi itu pernah teramati saat latihan: berkas sudah diperbarui, tetapi pengujian tetap gagal karena yang berjalan masih kode lama.

Setelah penggantian, ada tiga perubahan. Masukan tidak lagi disambungkan ke dalam query, melainkan dikirim sebagai nilai terpisah, sehingga basis data membacanya sebagai data dan tidak sebagai perintah. Keluaran diubah menjadi format terstruktur, sehingga struktur tabel tidak terbaca. Mode pengembangan dinonaktifkan, agar pesan kesalahan tidak menampilkan informasi internal.

---

## SCENE 12 - Verification

**Layar:** jendela penyerang.

**Aksi:**

```
curl "http://192.168.5.5:3000/sensor?device=x%27%20OR%20%271%27%3D%271"
curl "http://192.168.5.5:3000/sensor?device=sensor-01"
```

**Narasi:**

Verifikasi memakai dua perintah yang identik dengan tahap sebelumnya, baik alamat, parameter, maupun payload. Tidak ada karakter yang diubah. Perbedaannya hanya satu: aplikasinya telah diganti.

Perintah pertama mengirim payload yang sebelumnya membuka seluruh tabel. Hasilnya sekarang kosong.

Perintah kedua mengirim permintaan normal dengan identitas perangkat terdaftar. Hasilnya tetap dua baris, tetapi bentuknya sudah terstruktur. Perintah ini memastikan mitigasi tidak merusak fungsi aplikasi, karena penutupan celah yang membuat layanan berhenti bekerja bukanlah perbaikan.

Karena masukannya identik, perubahan hasil hanya dapat disebabkan oleh perubahan pada aplikasi. Pernyataan bahwa sistem telah dimitigasi, tanpa pengujian ulang, masih berupa klaim. Dengan pengulangan serangan yang sama, hasilnya menjadi bukti.

---

## SCENE 13 - Closing

**Layar:** tiga jendela VM.

**Narasi:**

Kesimpulannya.

Pemetaan layanan tertutup: tersisa tiga port, dan basis data tidak terlihat dari jaringan meskipun tetap beroperasi.

Mekanisme autentikasi diperkuat: basis data hanya menerima koneksi dari dalam mesin, SSH hanya menerima autentikasi berbasis kunci, dan percobaan berulang diblokir otomatis.

Injeksi pada lapisan aplikasi tertutup, dan terbukti melalui pengulangan serangan yang identik.

Penyisipan data melalui layanan pesan belum sepenuhnya tertangani. Konfigurasi sudah disiapkan, tetapi belum terbukti berlaku penuh, sehingga dicatat sebagai temuan terbuka.

Temuan itu dicatat apa adanya. Konfigurasi yang belum terbukti bukan mitigasi, dan pernyataan bahwa persoalan telah selesai hanya akan menutupi masalah yang masih ada.

Demikian yang dapat kami sampaikan. Terima kasih.

---

# Production Notes

Rekam dua sesi. Sesi pertama Scene 1 sampai 8, sesi kedua Scene 9 sampai 13. Perekaman di mesin pemantau jangan dihentikan di antara dua sesi.

Jangan dipotong: Scene 3, 7, dan 12.

Boleh dipotong: bagian menunggu pemindaian dan menunggu analisis.
