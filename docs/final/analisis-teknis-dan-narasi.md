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
# BAGIAN 2 - NASKAH NARASI VIDEO

---

## SCENE 1 - Pembuka

**Layar:** tiga jendela VM.

**Narasi:**

Selamat malam. Saya Fattih, mewakili Kelompok 5, pada skenario 05, Internal Database Fortress.

Sistem yang dikembangkan pada proyek ini adalah sprinkler otomatis untuk kandang sapi perah. Sensor melakukan pembacaan suhu dan kelembapan, data dikirimkan ke basis data, kemudian disajikan pada dashboard. Keputusan penyiraman diturunkan dari data tersebut.

Dengan demikian, apabila data yang diterima tidak akurat, keputusan yang dihasilkan juga tidak akurat. Penyiram berpotensi aktif pada kondisi yang tidak memerlukan, atau tidak aktif pada kondisi yang justru memerlukan tindakan.

Oleh karena itu, objek evaluasi pada pengujian ini bukan perangkat sensornya, melainkan jalur data, mulai dari sensor hingga dashboard.

Pengujian dilaksanakan pada tiga mesin dalam satu segmen jaringan tertutup. Target berada pada 192.168.5.5, penyerang pada 192.168.5.100, dan pemantau pada 192.168.5.200.

Metode yang digunakan adalah purple team. Rangkaian serangan dilaksanakan, mitigasi disiapkan, kemudian serangan yang sama diulang untuk memverifikasi efektivitas mitigasi tersebut.

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

Tahap pertama adalah penyiapan lingkungan pengujian. Perintah `startvm` digunakan untuk menjalankan mesin virtual dalam mode headless, sehingga sumber daya host tidak dialokasikan untuk antarmuka grafis.

Urutan penyalaan adalah target, penyerang, kemudian pemantau. Pemantau dinyalakan terakhir karena memerlukan waktu inisialisasi paling lama.

Perintah `list runningvms` digunakan untuk memverifikasi bahwa ketiga mesin telah beroperasi sebelum pengujian dimulai.

---

## SCENE 3 - Mengembalikan kondisi target

**Layar:** jendela AYAM.

**Aksi:**

```
sudo bash /tmp/purple.sh reset
```

**Narasi:**

Sebelum pengujian dilaksanakan, mesin target dikembalikan pada kondisi sebelum mitigasi. Tahap ini bersifat prasyarat. Apabila target berada pada kondisi yang telah dimitigasi, serangan tidak akan berhasil, sehingga tidak ada fenomena yang dapat diobservasi.

Perintah tersebut menjalankan skrip pengembalian kondisi, yang mencakup penghentian proses yang sedang beroperasi, pemasangan aplikasi versi rentan, aktivasi layanan pesan, pembersihan data uji dari sesi sebelumnya, serta pelepasan blokir yang tersisa.

Terdapat satu aspek teknis yang perlu ditekankan. Proses lama harus dihentikan terlebih dahulu. Apabila berkas aplikasi diganti sementara prosesnya masih beroperasi, aplikasi tetap menggunakan kode yang telah dimuat ke memori. Berkas pada disk telah diperbarui, namun perilaku sistem tidak berubah.

Pada akhirnya, skrip melakukan verifikasi mandiri. Apabila status yang terbaca masih menunjukkan kondisi aman, pengujian tidak dilanjutkan.

---

## SCENE 4 - Titik pemantauan

**Layar:** jendela onion.

**Aksi:**

```
ip -br a
sudo tcpdump -i eth2 -n -w /tmp/pbl5-demo.pcap -U
```

**Narasi:**

Pengujian dimulai dari titik pemantauan, karena seluruh rangkaian serangan harus terdokumentasi.

Perintah `ip -br a` digunakan untuk menampilkan daftar antarmuka jaringan beserta alamatnya dalam format ringkas. Berdasarkan hasilnya, alamat pemantau adalah 192.168.5.200 pada antarmuka eth2. Seluruh lalu lintas antara penyerang dan target melewati antarmuka tersebut, sehingga tidak diperlukan pemasangan instrumen tambahan pada mesin penyerang.

Perintah `tcpdump` digunakan untuk merekam lalu lintas pada antarmuka tersebut dan menyimpannya dalam berkas. Perekaman dimulai sebelum serangan pertama dilaksanakan. Sensor pada lingkungan ini bekerja dengan menganalisis berkas tangkapan, bukan dengan pemantauan langsung pada media transmisi. Apabila perekaman dimulai setelah serangan, tidak terdapat data yang dapat dianalisis, dan tahap deteksi tidak akan menghasilkan temuan.

Selama proses berlangsung, terminal tidak menampilkan keluaran. Perekaman tetap berjalan, dengan hasil dituliskan ke berkas. Tidak adanya tampilan bukan merupakan indikasi kegagalan.

---

## SCENE 5 - Pemetaan layanan

**Layar:** jendela penyerang.

**Aksi:**

```
nmap -sS -sV -p- 192.168.5.5
```

**Narasi:**

Tahap pertama pengujian adalah pemetaan layanan. Tujuan tahap ini adalah mengidentifikasi permukaan serangan yang tersisa setelah penerapan hardening.

Perintah `nmap` digunakan untuk memindai port pada mesin target, mencakup seluruh rentang port, sekaligus mengidentifikasi versi layanan yang memberikan respons. Hasil pemindaian menunjukkan tiga port terbuka: 22 untuk SSH, 1883 untuk layanan pesan, dan 3000 untuk dashboard. Port 3306, yaitu layanan basis data, tidak terdeteksi.

Perlu ditegaskan bahwa layanan basis data tetap beroperasi dan tetap menyimpan seluruh data. Yang berubah adalah keterlihatannya dari jaringan. Dari perspektif penyerang, port tersebut tidak tersedia. Dari perspektif aplikasi, koneksi berjalan sebagaimana mestinya.

Kondisi inilah yang menjadikan pemetaan sebagai tahap yang penting. Objek yang tidak dapat diidentifikasi tidak dapat dijadikan sasaran serangan.

---

## SCENE 6 - Mekanisme autentikasi

**Layar:** jendela penyerang, lalu AYAM.

**Aksi:**

```
nc -vz 192.168.5.5 3306
hydra -l root -P /usr/share/wordlists/rockyou.txt ssh://192.168.5.5 -t 4
sudo fail2ban-client status sshd
```

**Narasi:**

Tahap kedua diarahkan pada mekanisme autentikasi, karena pada arsitektur yang umum digunakan, mekanisme tersebut menjadi permukaan yang paling sering dieksploitasi.

Perintah `nc` digunakan untuk menguji keterjangkauan sebuah port tanpa mengirimkan data. Hasilnya berupa timeout, bukan refused. Perbedaan tersebut signifikan. Respons refused menunjukkan adanya layanan yang menjawab dan menolak permintaan, sedangkan timeout menunjukkan paket dibuang tanpa respons. Dari perspektif penyerang, tidak terdapat layanan pada alamat tersebut.

Perintah `hydra` digunakan untuk menguji daftar kata sandi secara berurutan terhadap layanan SSH. Proses tersebut terhenti pada tahap negosiasi, karena layanan hanya menerima autentikasi berbasis kunci. Tidak ada satu pun kata sandi yang benar-benar diuji. Oleh karena itu, pengujian ini tidak menghasilkan kesimpulan mengenai kekuatan kata sandi pada mesin tersebut, dan hal itu memang berada di luar cakupan evaluasi.

Perintah `fail2ban-client` digunakan untuk menampilkan status pemblokiran pada layanan tersebut. Hasilnya menunjukkan bahwa percobaan yang gagal secara berulang dicatat, kemudian alamat sumbernya diblokir secara otomatis.

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

Tahap ketiga diarahkan pada lapisan aplikasi, dan pada tahap inilah temuan utama diperoleh.

Perintah `curl` digunakan untuk mengirimkan permintaan HTTP langsung dari terminal dan menampilkan respons yang diterima, sehingga isi respons dapat dianalisis tanpa perantara peramban.

Tiga permintaan berikut menunjukkan satu kesimpulan: masukan melalui URL dapat mengubah perintah yang dikirimkan ke basis data.

Permintaan normal mengembalikan dua baris, sesuai perangkat yang diminta. Ketika parameter diubah menjadi kondisi yang selalu bernilai benar, seluruh isi tabel terbuka. Ketika parameter diubah menjadi kondisi yang selalu bernilai salah, hasil yang dikembalikan kosong.

Hasil kosong pada kasus ketiga merupakan bukti yang menentukan. Apabila hanya kasus pertama yang disajikan, masih terbuka kemungkinan bahwa yang terjadi adalah kesalahan penyajian. Dengan hasil kosong pada kasus ketiga, dapat disimpulkan bahwa yang berubah adalah logika query, bukan tampilan.

Terdapat kebocoran tambahan. Format keluaran masih berupa representasi mentah bahasa pemrograman, sehingga struktur dan tipe kolom ikut terbaca. Penyerang tidak hanya memperoleh isi data, tetapi juga skema tabel.

---

## SCENE 8 - Data palsu melalui layanan pesan

**Layar:** dua terminal penyerang, lalu AYAM, lalu browser.

**Aksi:**

```
mosquitto_sub -h 192.168.5.5 -t 'sensors/#' -v
mosquitto_pub -h 192.168.5.5 -t sensors/sensor-99 -m 99.90
tail -3 /var/log/iot/subscriber.log
```

**Narasi:**

Bagian kedua diarahkan pada injeksi data melalui layanan pesan.

Perintah `mosquitto_sub` digunakan untuk berlangganan seluruh topik sensor dan menampilkan setiap pesan yang diterima. Perintah `mosquitto_pub` digunakan untuk mengirimkan satu pesan ke topik tertentu, sehingga pesan tersebut tampak berasal dari perangkat sensor yang sah.

Pesan diterima tanpa proses autentikasi dan tanpa penolakan.

Pada mesin target, data tersimpan dengan identitas sensor-99 dan nilai suhu 99,9. Perangkat dengan identitas tersebut tidak pernah ada, melainkan diciptakan pada pengujian ini. Namun layanan penerima memperlakukannya sebagai data yang valid.

Pada dashboard, data tersebut tampil pada posisi teratas dengan nilai suhu 99,9. Suhu normal sapi perah berada pada kisaran 38 derajat, sehingga sistem akan mengaktifkan penyiram secara terus-menerus. Dashboard juga tidak memberikan penanda bahwa data tersebut tidak sah, sehingga tampilannya identik dengan data asli.

Perintah `tail` digunakan untuk menampilkan sejumlah baris terakhir pada berkas log, guna memastikan bahwa pesan tersebut tercatat oleh layanan penerima.

Dampak yang timbul bukan pencurian data, melainkan hilangnya integritas data. Keputusan yang diturunkan dari data yang tidak akurat akan menghasilkan tindakan yang tidak akurat.

Selanjutnya, analisis dilakukan pada Security Onion.

---

## SCENE 9 - Analisis

**Layar:** jendela onion.

**Aksi:**

```
tcpdump -r /tmp/pbl5-demo.pcap | wc -l
sudo so-import-pcap /tmp/pbl5-demo.pcap
```

**Narasi:**

Setelah rangkaian serangan selesai, perekaman dihentikan. Perintah `tcpdump` dengan mode baca digunakan untuk membaca kembali berkas tangkapan, sedangkan `wc -l` digunakan untuk menghitung jumlah baris di dalamnya. Apabila hasilnya nol, perekaman dinyatakan gagal dan tidak terdapat data yang dapat dianalisis.

Perintah `so-import-pcap` digunakan untuk memasukkan berkas tangkapan ke dalam sensor, agar diproses oleh mesin analisis yang tersedia.

Proses tersebut memerlukan waktu, karena berkas dibaca ulang oleh dua mesin analisis, yaitu Suricata dan Zeek, kemudian hasilnya dimasukkan ke basis data pencarian.

Konsekuensinya, analisis pada metode ini berlangsung setelah serangan, bukan pada saat serangan berlangsung. Hal tersebut merupakan keterbatasan yang dicatat, bukan yang disembunyikan.

---

## SCENE 10 - Deteksi

**Layar:** Kibana, Discover.

**Aksi:** index pattern `logstash`, rentang 24 jam, lalu:

```
"192.168.5.100" AND "192.168.5.5"
```

**Narasi:**

Hasil analisis disajikan melalui antarmuka pencarian pada mesin pemantau. Data yang tercatat mencakup bentuk koneksi, yaitu port tujuan, jumlah byte, dan status penyelesaian. Status yang terbaca menunjukkan koneksi selesai secara normal, yang berarti server memberikan respons.

Terdapat dua batas yang perlu disampaikan.

Pertama, karena sensor bekerja dari berkas tangkapan, selalu terdapat jeda antara pelaksanaan serangan dan ketersediaan hasil analisis. Deteksi dengan pendekatan ini tidak dapat digunakan untuk menghentikan serangan yang sedang berlangsung.

Kedua, yang terekam adalah bentuk lalu lintas, bukan isi serangan. Tidak terdapat aturan yang mengenali injeksi pada parameter URL, dan tidak terdapat aturan yang mengenali penyisipan pesan. Kedua serangan tersebut tidak muncul sebagai peringatan, melainkan hanya sebagai koneksi yang selesai normal.

Dengan demikian, deteksi yang tersedia kuat pada lapisan jaringan dan lemah pada lapisan aplikasi. Kondisi tersebut dicatat sebagai kekurangan.

---

## SCENE 11 - Mitigasi

**Layar:** jendela AYAM.

**Aksi:**

```
sudo bash /tmp/purple.sh mitigasi
```

**Narasi:**

Mitigasi dilakukan pada lapisan aplikasi. Perintah tersebut menjalankan skrip mitigasi dengan tiga urutan kerja: menghentikan aplikasi, mengganti berkas, kemudian menjalankannya kembali.

Urutan tersebut bukan formalitas. Proses yang beroperasi menyimpan kode di memori, sehingga penggantian berkas pada saat aplikasi masih berjalan tidak mengubah perilakunya. Kondisi tersebut pernah teramati pada tahap latihan: berkas telah diperbarui, namun hasil pengujian tetap gagal karena proses yang beroperasi masih menggunakan kode lama.

Setelah penggantian, terdapat tiga perubahan. Masukan tidak lagi disambungkan ke dalam query, melainkan dikirimkan sebagai nilai terpisah, sehingga basis data membacanya sebagai data dan tidak sebagai perintah. Keluaran diubah menjadi format terstruktur, sehingga struktur tabel tidak lagi terbaca. Mode pengembangan dinonaktifkan, agar pesan kesalahan tidak menampilkan informasi internal aplikasi.

---

## SCENE 12 - Verifikasi

**Layar:** jendela penyerang.

**Aksi:**

```
curl "http://192.168.5.5:3000/sensor?device=x%27%20OR%20%271%27%3D%271"
curl "http://192.168.5.5:3000/sensor?device=sensor-01"
```

**Narasi:**

Untuk memverifikasi mitigasi, serangan yang sama diulang tanpa perubahan, menggunakan perintah dan payload yang identik dengan tahap sebelumnya.

Hasilnya kosong.

Karena serangan yang diberikan identik, perubahan hasil hanya dapat disebabkan oleh perubahan pada aplikasi. Pernyataan bahwa sistem telah dimitigasi, tanpa pengujian ulang, masih merupakan klaim. Dengan pengulangan serangan yang sama, hasil tersebut menjadi bukti.

Pengujian juga dilakukan pada permintaan normal, untuk memastikan aplikasi tetap berfungsi dan mitigasi tidak mengganggu layanan.

---

## SCENE 13 - Penutup

**Layar:** tiga jendela VM.

**Narasi:**

Kesimpulannya.

Pemetaan layanan telah tertutup. Tersisa tiga port, dan layanan basis data tidak terlihat dari jaringan meskipun tetap beroperasi.

Mekanisme autentikasi telah diperkuat. Basis data hanya menerima koneksi dari dalam mesin, SSH hanya menerima autentikasi berbasis kunci, dan percobaan berulang diblokir secara otomatis.

Injeksi pada lapisan aplikasi telah tertutup, dan hal tersebut terbukti melalui pengulangan serangan yang identik.

Penyisipan data melalui layanan pesan belum sepenuhnya tertangani. Konfigurasi telah disiapkan, tetapi belum terbukti berlaku secara penuh, sehingga dicatat sebagai temuan terbuka.

Temuan tersebut dicatat apa adanya. Konfigurasi yang belum terbukti bukan merupakan mitigasi, dan pernyataan bahwa persoalan telah selesai hanya akan menutupi masalah yang masih ada.

Demikian yang dapat kami sampaikan. Terima kasih.

---

# Catatan Produksi

Rekam dua sesi. Sesi pertama Scene 1 sampai 8, berhenti saat dashboard menampilkan data palsu. Sesi kedua Scene 9 sampai 13. Perekaman di mesin pemantau jangan dihentikan di antara dua sesi.

Jangan dipotong: Scene 3, 7, dan 12.

Boleh dipotong: bagian menunggu pemindaian dan menunggu analisis.
