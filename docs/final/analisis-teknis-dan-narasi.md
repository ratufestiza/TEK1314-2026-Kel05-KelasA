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

Naskah ini dibaca sambil merekam. Urutannya mengikuti `demo-dari-awal.md`, dari Bagian A sampai K.

Gayanya seperti menjelaskan ke teman, bukan membaca laporan. Kalimat pendek. Tiap perintah dijelaskan buat apa, bukan cuma disebut.

---

## SCENE 1 - Pembuka

**Layar:** tiga jendela VM, belum ada perintah.

**Aksi:** diam 5 detik.

**Narasi:**

Selamat malam, kami dari Kelompok 5, skenario 05, Internal Database Fortress.

Jadi yang kami bikin ini sistem sprinkler otomatis buat kandang sapi perah. Sensornya baca suhu dan kelembapan, datanya dikirim ke server, terus ditampilin di dashboard. Kalau panas, penyiram nyala sendiri.

Masalahnya kalau data sensornya dipalsukan. Sistem bisa nyiram padahal enggak panas, atau enggak nyiram padahal sapinya kepanasan. Buat ternak, itu bahaya.

Jadi yang kami tes di sini bukan sensornya, tapi jalur datanya. Dari sensor, masuk ke database, terus tampil di dashboard.

Ada tiga mesin. Target di 192.168.5.5, penyerang di 192.168.5.100, pemantau di 192.168.5.200.

Metodenya purple team. Jadi setelah nyerang, kami siapin mitigasinya, terus nyerang lagi buat buktiin mitigasinya jalan. Kalau cuma nyerang doang, itu red team. Bedanya di pengulangan terakhir.

---

## SCENE 2 - Nyalakan tiga VM

**Layar:** terminal di host Windows.

**Aksi:**

```
"/c/Program Files/Oracle/VirtualBox/VBoxManage.exe" startvm "AYAM" --type headless
"/c/Program Files/Oracle/VirtualBox/VBoxManage.exe" startvm "Cybersecurity LabVM Worksation 20230210" --type headless
"/c/Program Files/Oracle/VirtualBox/VBoxManage.exe" startvm "CyberOps Security Onion" --type headless
"/c/Program Files/Oracle/VirtualBox/VBoxManage.exe" list runningvms
```

**Narasi:**

Pertama saya nyalain tiga VM-nya. Saya pakai VBoxManage biar headless, jadi enggak perlu buka jendela satu-satu.

Urutannya target dulu, terus penyerang, terakhir Onion. Onion paling akhir karena bootingnya paling lama.

Terakhir saya cek pakai `list runningvms`, harusnya keluar tiga.

---

## SCENE 3 - Balikin target ke kondisi rentan

**Layar:** jendela VM AYAM. Rekam sampai selesai, jangan dipotong.

**Aksi:**

```
sudo bash /tmp/purple.sh reset
```

**Narasi:**

Sebelum mulai, saya balikin dulu mesin target ke kondisi sebelum dimitigasi.

Ini penting. Kalau enggak dimulai dari kondisi rentan, serangannya enggak bakal jalan, dan enggak ada yang bisa dibuktiin.

Saya pakai script `purple.sh reset`. Isinya enam langkah.

Pertama, matiin dulu aplikasi sama subscriber yang mungkin masih jalan. Ini yang sering kelupaan. Kalau file-nya diganti tapi prosesnya masih hidup, aplikasi tetep pakai kode lama.

Kedua, pasang file aplikasi versi rentan.

Ketiga, buka konfigurasi MQTT biar bisa nerima client tanpa password.

Keempat, hapus data palsu yang mungkin ketinggalan dari latihan sebelumnya.

Kelima, buka blokiran fail2ban buat IP penyerang. Kalau enggak, percobaan berikutnya ditolak duluan sebelum sampai ke SSH.

Keenam, nyalain lagi aplikasinya.

Di akhir dia nampilin status. Saya cek tiga baris. Ukuran file harus 1483 byte, itu versi rentan. Query normal harus 2 baris. Terus payload injeksi harus keluar 4 baris dengan tulisan mode rentan.

Kalau tulisan terakhirnya mode aman, berarti ada yang salah dan saya enggak boleh lanjut.

---

## SCENE 4 - Mulai merekam di Onion

**Layar:** jendela VM Onion. Bukan SSH, jendela VirtualBox langsung.

**Aksi:**

```
ip -br a
```

Pause sebentar biar kelihatan.

```
sudo tcpdump -i eth2 -n -w /tmp/pbl5-demo.pcap -U
```

**Narasi:**

Oke, sekarang pindah ke VM Onion. Semua yang saya lakuin di sini lewat jendela VirtualBox langsung, bukan SSH.

Pertama saya cek interface dulu. `ip -br a`. Ini buat tau nama interface yang nyambung ke jaringan 192.168.5.0. Hasilnya eth2, soalnya yang punya IP 192.168.5.200 itu eth2.

Terus saya mulai rekam.

`sudo tcpdump -i eth2 -n -w /tmp/pbl5-demo.pcap -U`

Jadi `-i eth2` itu milih interface yang tadi. `-w` artinya hasilnya disimpan ke file, bukan ditampilin di layar. `-n` biar enggak ribet resolve nama. `-U` biar paketnya langsung ditulis ke disk, enggak nunggu buffer penuh dulu.

Karena pakai `-w`, layarnya bakal kosong. Itu normal. Paketnya masuk ke file, bukan ke layar. Jadi jangan dikira gagal.

Rekaman ini yang nanti dianalisis di Kibana. Sensor di lab ini mode import, jadi dia enggak nonton kabel langsung. Dia cuma bisa analisis file yang diimport. Makanya harus direkam dari sekarang, sebelum serangan. Kalau enggak direkam, Kibana bakal kosong.

---

## SCENE 5 - Skenario 1, scanning

**Layar:** jendela Attacker.

**Aksi:**

```
nmap -sS -sV -p- 192.168.5.5
```

Biarkan jalan. Bagian nunggunya boleh dipotong, sisakan hasilnya.

**Narasi:**

Masuk ke VM penyerang. Pertama saya scanning dulu.

`nmap -sS -sV -p- 192.168.5.5`

`-sS` itu SYN scan, jadi enggak bikin koneksi penuh, lebih cepet dan lebih susah keliatan di log. `-sV` buat deteksi versi layanan. `-p-` artinya semua port, 1 sampai 65535, bukan cuma port yang umum.

Yang saya cari, port apa aja yang kebuka dan versinya apa.

Hasilnya tiga port. 22 SSH, 1883 MQTT, 3000 dashboard. Port 3306 MySQL enggak muncul.

Sebelum hardening dulu kebuka lima port, lengkap sama versinya. Sekarang tinggal tiga. Yang penting bukan yang muncul, tapi yang hilang. MySQL-nya masih jalan, cuma dari luar udah enggak keliatan.

Waktunya juga beda jauh. Dulu sekitar 20 detik, sekarang hampir 800 detik. Karena port yang enggak kepake ditutup, dan ufw buang paket ke port yang enggak diizinin. Jadi penyerang buang waktu buat tiap port.

---

## SCENE 6 - Skenario 2, kredensial

**Layar:** jendela Attacker.

**Aksi:**

```
nc -vz 192.168.5.5 3306
```

Tunggu sampai timed out.

**Narasi:**

Sekarang saya tes port MySQL-nya langsung.

`nc -vz 192.168.5.5 3306`

`-z` artinya cuma ngecek koneksi terus tutup, enggak ngirim apa-apa.

Hasilnya timeout. Ini beda sama refused. Refused artinya ada yang nolak, jadi kita tau di situ ada layanan. Timeout artinya paketnya dibuang diem-diem, jadi dari sisi penyerang kayak enggak ada apa-apa.

Itu efek dari MySQL yang cuma denger di localhost. Layanannya hidup, tapi cuma bisa diakses dari dalam mesinnya sendiri.

**Aksi:**

```
hydra -l root -P /usr/share/wordlists/rockyou.txt ssh://192.168.5.5 -t 4
```

Tunggu sekitar satu menit, lalu `Ctrl+C`.

**Narasi:**

Terus saya coba brute force SSH.

`hydra -l root -P /usr/share/wordlists/rockyou.txt ssh://192.168.5.5 -t 4`

`-l root` itu user yang dicoba, `-P` daftar password-nya, `-t 4` empat koneksi jalan bareng.

Hasilnya ditolak sebelum sempet nyoba password. Bukan karena password-nya kuat, tapi karena SSH-nya cuma nerima key. Password sama sekali enggak diterima.

Saya stop di sini. Diterusin juga enggak ada gunanya, dan saya enggak mau ngaku-ngaku password-nya kuat padahal yang diuji aja enggak pernah kejadian.

**Aksi:** pindah ke jendela AYAM.

```
sudo fail2ban-client status sshd
```

**Narasi:**

Terakhir saya cek fail2ban di mesin target.

Ini nunjukin ada berapa IP yang diblokir dan berapa yang gagal. Jadi selain SSH-nya cuma nerima key, ada juga yang nyatet percobaan gagal terus ngeblokir IP-nya. Dua lapis.

---

## SCENE 7 - Skenario 3a, SQL injection

**Layar:** jendela Attacker. Teksnya dibesarin biar kebaca.

**Aksi:**

```
curl "http://192.168.5.5:3000/sensor?device=sensor-01"
```

**Narasi:**

Masuk ke skenario tiga. Ini yang paling penting.

Pertama saya lakuin yang normal dulu.

Query ke `device=sensor-01`. Hasilnya dua baris, dua pembacaan sensor satu. Bener, enggak ada yang aneh.

**Aksi:**

```
curl "http://192.168.5.5:3000/sensor?device=x%27%20OR%20%271%27%3D%271"
```

**Narasi:**

Sekarang saya masukin payload.

`device=x%27%20OR%20%271%27%3D%271`

`%27` itu tanda kutip, `%20` itu spasi. Jadi kalau dibaca, isinya `x' OR '1'='1`.

Hasilnya empat baris. Semua isi tabel keluar.

Kenapa? Karena aplikasinya nyambungin input saya langsung ke dalam query. Jadi tanda kutip saya nutup string yang diquery, terus `OR '1'='1'` dibaca sebagai perintah, bukan sebagai nama perangkat.

**Aksi:**

```
curl "http://192.168.5.5:3000/sensor?device=x%27%20AND%20%271%27%3D%272"
```

**Narasi:**

Yang ketiga saya ganti OR jadi AND, dan 1=1 jadi 1=2.

Hasilnya nol.

Nah tiga hasil ini yang saya mau tunjukin. Normal dua baris, OR empat baris, AND nol baris.

Kalau cuma nunjukin yang OR doang, bisa dibilang kebetulan atau bug tampilan. Tapi begitu AND hasilnya nol, argumen itu mati. Soalnya nol enggak bisa dijelasin sama bug tampilan. Nol artinya logika query-nya yang kita ubah.

Satu lagi, coba perhatiin bentuk outputnya. Bukan JSON, tapi kayak gini, ada kurung, kutip, sama nama tipe datanya. Itu format mentah Python. Artinya struktur tabelnya kebaca dari luar, penyerang jadi tau urutan sama tipe kolomnya.

---

## SCENE 8 - Skenario 3b, data palsu lewat MQTT

**Layar:** dua terminal di jendela Attacker, dua-duanya kelihatan.

**Aksi, terminal kiri:**

```
mosquitto_sub -h 192.168.5.5 -t 'sensors/#' -v
```

**Aksi, terminal kanan:**

```
mosquitto_pub -h 192.168.5.5 -t sensors/sensor-99 -m 99.90
```

**Narasi:**

Sekarang bagian kedua. Bukan nyuri data, tapi ngerusak kepercayaan ke datanya.

Terminal kiri buat mantau. `mosquitto_sub -h 192.168.5.5 -t 'sensors/#' -v`. `-t` itu topic, `#` artinya semua subtopic, `-v` biar nama topicnya ikut kelihatan.

Terminal kanan buat ngirim. `mosquitto_pub -h 192.168.5.5 -t sensors/sensor-99 -m 99.90`. `-m` itu isi pesannya.

Enggak ada password, enggak ada penolakan. Langsung masuk.

**Aksi:** pindah ke jendela AYAM.

```
tail -3 /var/log/iot/subscriber.log
```

**Narasi:**

Terus saya cek di mesin target. Ada tulisan tersimpan, sensor-99, suhu 99.9.

Sensor-99 itu enggak ada. Saya ngarang namanya. Tapi subscriber percaya aja, langsung disimpen kayak data beneran.

**Aksi:** browser di jendela Attacker.

```
http://192.168.5.5:3000/
```

Refresh pakai `Ctrl+Shift+R`.

**Narasi:**

Terakhir saya buka dashboard-nya.

Ada baris baru di paling atas, suhu 99.9.

Buat sapi itu enggak masuk akal, suhu normalnya sekitar 38 derajat. Kalau sistem ini dipakai beneran, penyiramnya bakal nyala terus tanpa alasan.

Dan yang paling bahaya, di dashboard enggak ada tanda apa-apa. Datanya kelihatan sama persis kayak data asli. Jadi orang yang jaga kandang enggak bakal tau itu data palsu.

Itu inti masalahnya. Bukan datanya dicuri, tapi datanya udah enggak bisa dipercaya. Sistem yang ngambil keputusan dari data salah bisa lebih bahaya daripada sistem yang mati.

---

## SCENE 9 - Stop rekaman, import

**Layar:** jendela Onion.

**Aksi:** `Ctrl+C` di terminal tcpdump.

```
tcpdump -r /tmp/pbl5-demo.pcap | wc -l
```

**Narasi:**

Serangannya udah selesai, jadi rekamannya saya stop pakai `Ctrl+C`.

Terus saya cek paketnya ada berapa.

`tcpdump -r /tmp/pbl5-demo.pcap | wc -l`

`-r` itu baca file. Kalau hasilnya nol, berarti rekamannya gagal, dan enggak ada gunanya diimport.

**Aksi:**

```
sudo so-import-pcap /tmp/pbl5-demo.pcap
```

Tunggu. Kalau layarnya diem lama, jangan dipotong kalau bisa.

**Narasi:**

Terus saya import ke sensor.

`sudo so-import-pcap /tmp/pbl5-demo.pcap`

Ini yang makan waktu. Bisa 5 sampai 15 menit, tergantung gede file-nya. Di belakang dia mecah pcap-nya, baca ulang pakai Suricata sama Zeek, terus masukin hasilnya ke Elasticsearch. Jadi kalau layarnya diem lama, itu normal.

**Aksi:** setelah selesai, browser di Onion.

```
https://localhost
```

**Narasi:**

Habis itu buka Kibana di browser dalam VM Onion. Bukan dari mesin penyerang, karena penyerang enggak mantau pertahanannya sendiri.

---

## SCENE 10 - Deteksi di Kibana

**Layar:** Kibana, menu Discover.

**Aksi:** pilih pola indeks `*:logstash-*`, set rentang waktu Last 24 hours. Ketik di search bar:

```
"192.168.5.100" AND "192.168.5.5"
```

**Narasi:**

Di Kibana saya pilih Discover, terus pilih index pattern yang ada tulisan `logstash`-nya, yang pakai titik dua.

Rentang waktunya saya lebarkan ke 24 jam terakhir. Ini penting, karena data import bawa waktu asli rekamannya, bukan waktu import. Kalau rentangnya kesempitan, hasilnya kosong padahal import-nya berhasil.

Terus saya saring pakai search bar: `"192.168.5.100" AND "192.168.5.5"`. Saya pakai tanda kutip biar dibaca satu kesatuan.

Saya sengaja enggak pakai filter kolom, karena nama kolom di versi ini beda sama versi baru. Kalau salah ngetik, Kibana malah error, bukan ngasih hasil kosong.

**Layar:** hasil keluar, log Zeek.

**Narasi:**

Yang keluar log Zeek. Isinya catatan koneksi, port, jumlah byte yang dikirim dan diterima. Statusnya SF, artinya koneksinya selesai normal, server beneran bales.

Sekarang yang perlu saya sampein, ini batasnya.

Sensor kami mode import, jadi ada jeda antara serangan sama hasil analisisnya. Rekamannya juga harus diambil sebelum serangan, kalau enggak ya enggak ada yang bisa dianalisis.

Terus yang kelihatan di sini bentuk lalu lintasnya, bukan isi serangannya. SQL injection di URL enggak keliatan sebagai alert, karena enggak ada rule yang ngenalin. MQTT juga hampir enggak keliatan.

Jadi deteksi kami bagus di jaringan, lemah di aplikasi. Itu yang kami catat sebagai kekurangan, bukan kami diemin.

---

## SCENE 11 - Mitigasi

**Layar:** jendela AYAM.

**Aksi:**

```
sudo bash /tmp/purple.sh mitigasi
```

**Narasi:**

Sekarang mitigasinya.

`sudo bash /tmp/purple.sh mitigasi`

Isinya tiga langkah, dan urutannya penting.

Pertama matiin aplikasi yang jalan. Kedua timpa file-nya pakai versi aman. Ketiga nyalain lagi.

Kenapa harus mati dulu? Karena Python nyimpen kode di memori. Kalau file-nya diganti pas aplikasi masih jalan, dia tetep pakai kode lama. File-nya udah bener tapi kelakuannya masih rentan. Itu pernah kejadian waktu latihan, bikin bingung soalnya hasil tesnya gagal padahal file-nya udah bener.

**Layar:** output status.

**Narasi:**

Terus apa aja yang berubah di versi aman? Ada tiga.

Query-nya enggak nyambungin string lagi, tapi pakai parameter. Jadi input saya dikirim terpisah, dibaca sebagai data, bukan sebagai perintah.

Outputnya sekarang JSON, jadi struktur tabelnya enggak kebocor lagi.

Terakhir debug-nya dimatiin, jadi kalau ada error enggak nampilin isi internal aplikasi.

---

## SCENE 12 - Verifikasi

**Layar:** jendela Attacker.

**Aksi:**

```
curl "http://192.168.5.5:3000/sensor?device=x%27%20OR%20%271%27%3D%271"
```

**Narasi:**

Sekarang saya ulang serangannya. Payload-nya sama persis, enggak saya ubah sedikit pun.

Hasilnya nol.

Ini inti purple team-nya. Saya enggak ngubah serangannya. Yang berubah cara aplikasi nerima input. Jadi kalau hasilnya beda, berarti mitigasinya yang ngaruh.

Kalau saya cuma bilang udah dimitigasi, itu klaim. Dengan ngulang serangan yang sama dan nunjukin hasilnya berubah, itu bukti.

**Aksi:**

```
curl "http://192.168.5.5:3000/sensor?device=sensor-01"
```

**Narasi:**

Terus saya tes yang normal juga, buat mastiin aplikasinya masih jalan dan enggak rusak gara-gara mitigasi.

Hasilnya dua baris, sekarang bentuknya JSON. Aplikasinya hidup, datanya bener, injeksinya tertutup.

---

## SCENE 13 - Penutup

**Layar:** balik ke tiga jendela VM, atau slide ringkasan.

**Narasi:**

Jadi kesimpulannya.

Skenario satu, scanning. Tertutup. Tinggal tiga port, MySQL enggak keliatan dari jaringan.

Skenario dua, kredensial. Tertutup. MySQL cuma localhost, SSH cuma nerima key, fail2ban ngeblokir percobaan berulang.

Skenario tiga bagian pertama, SQL injection. Tertutup, dan udah dibuktiin dengan ngulang payload yang sama.

Bagian kedua, MQTT, belum selesai. Konfigurasi buat nutupnya udah disiapin, tapi belum kami pastiin berlaku penuh. Jadi kami catat sebagai temuan terbuka.

Kami sengaja enggak bilang selesai, karena konfigurasi yang belum kebukti itu bukan mitigasi.

Sekian, terima kasih.

---

# Catatan Produksi

## Urutan rekam

Kalau mau hemat waktu, rekam dua sesi.

**Sesi 1, Scene 1 sampai 8.** Berhenti saat dashboard nampilin 99.9. Ini kondisi rentan penuh.

**Sesi 2, Scene 9 sampai 13.** Mulai setelah serangan selesai. Tapi tcpdump jangan distop di antara dua sesi.

## Jangan dipotong

- Scene 3, reset. Ini bukti videonya mulai dari kondisi rentan.
- Scene 7, tiga payload berurutan. Harus kelihatan berbanding.
- Scene 12, verifikasi. Ini intinya.

## Boleh dipotong

- Bagian nunggu nmap, sisakan hasilnya.
- Bagian nunggu import, cukup awal sama akhir.
- Scene 2, cukup perintahnya sama hasil `listrunningvms`.

## Kalau gagal waktu rekam

Jangan disunting seolah berhasil. Kalau payload OR enggak keluar empat baris, stop, jalanin `sudo bash /tmp/purple.sh reset`, ulang dari Scene 7. Lebih baik daripada hasilnya dipalsuin.

## Judul video

Demo Purple Team, Sistem Sprinkler Otomatis Peternakan Sapi Perah, Skenario 05 Internal Database Fortress.

Kelompok 5, TEK1314 Keamanan Siber, Semester 5.
