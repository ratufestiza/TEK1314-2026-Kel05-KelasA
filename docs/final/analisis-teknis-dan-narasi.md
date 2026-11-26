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

Narasi pendek, langsung ke intinya. Tiap perintah dijelaskan fungsinya satu kalimat, terus lanjut.

---

## SCENE 1 - Pembuka

**Layar:** tiga jendela VM.

**Narasi:**

Selamat malam, kami Kelompok 5, skenario 05 Internal Database Fortress.

Sistem kami sprinkler otomatis buat kandang sapi perah. Sensor baca suhu dan kelembapan, datanya masuk database, terus tampil di dashboard.

Kalau data sensornya dipalsukan, penyiram bisa nyala di waktu yang salah. Buat ternak itu bahaya.

Jadi yang kami tes jalur datanya, bukan sensornya.

Tiga mesin. Target 192.168.5.5, penyerang 192.168.5.100, pemantau 192.168.5.200.

Metodenya purple team. Setelah nyerang, kami mitigasi, terus nyerang lagi buat buktiin. Kalau cuma nyerang, itu red team.

---

## SCENE 2 - Nyalakan VM

**Layar:** terminal host.

**Aksi:**

```
"/c/Program Files/Oracle/VirtualBox/VBoxManage.exe" startvm "AYAM" --type headless
"/c/Program Files/Oracle/VirtualBox/VBoxManage.exe" startvm "Cybersecurity LabVM Worksation 20230210" --type headless
"/c/Program Files/Oracle/VirtualBox/VBoxManage.exe" startvm "CyberOps Security Onion" --type headless
"/c/Program Files/Oracle/VirtualBox/VBoxManage.exe" list runningvms
```

**Narasi:**

Nyalain tiga VM, headless pakai VBoxManage. Target dulu, Onion terakhir karena bootingnya paling lama.

Cek pakai `list runningvms`, harusnya keluar tiga.

---

## SCENE 3 - Balikin ke kondisi rentan

**Layar:** jendela AYAM.

**Aksi:**

```
sudo bash /tmp/purple.sh reset
```

**Narasi:**

Target saya balikin dulu ke kondisi rentan. Kalau enggak, serangannya enggak jalan.

Enam langkah. Matiin proses lama, pasang app.py versi rentan, buka MQTT, hapus data palsu, unban fail2ban, nyalain lagi.

Yang penting matiin proses dulu. Kalau file diganti tapi prosesnya masih hidup, aplikasi tetep pakai kode lama.

Cek hasilnya. Harus 1483 byte, query normal 2 baris, payload OR 4 baris dengan tulisan mode rentan.

---

## SCENE 4 - Mulai rekam di Onion

**Layar:** jendela Onion.

**Aksi:**

```
ip -br a
sudo tcpdump -i eth2 -n -w /tmp/pbl5-demo.pcap -U
```

**Narasi:**

Pindah ke Onion, lewat jendela VirtualBox, bukan SSH.

`ip -br a` buat cari interface yang IP-nya 192.168.5.200. Hasilnya eth2.

Terus rekam. `-i` pilih interface, `-w` simpan ke file, `-U` langsung tulis ke disk.

Layarnya bakal kosong, itu normal. Paketnya masuk file, bukan ke layar.

Harus direkam sekarang, karena sensor di sini mode import. Yang dianalisis nanti cuma file yang diimport.

---

## SCENE 5 - Scanning

**Layar:** jendela Attacker.

**Aksi:**

```
nmap -sS -sV -p- 192.168.5.5
```

**Narasi:**

Masuk penyerang. `-sS` SYN scan, `-sV` deteksi versi, `-p-` semua port.

Hasilnya tiga port. 22 SSH, 1883 MQTT, 3000 dashboard. 3306 MySQL enggak muncul.

Sebelum hardening lima port kebuka. Yang penting yang hilang, bukan yang muncul.

Waktunya juga naik dari 20 detik jadi hampir 800 detik, karena port ditutup dan ufw buang paket.

---

## SCENE 6 - Kredensial

**Layar:** jendela Attacker.

**Aksi:**

```
nc -vz 192.168.5.5 3306
hydra -l root -P /usr/share/wordlists/rockyou.txt ssh://192.168.5.5 -t 4
```

**Narasi:**

Timeout, bukan refused.

Refused artinya ada yang nolak, jadi kita tau ada layanan. Timeout artinya paket dibuang diem-diem. Dari luar kayak enggak ada apa-apa. Efek MySQL cuma denger di localhost.

Terus brute force SSH. Ditolak sebelum nyoba password, karena SSH cuma nerima key.

Saya stop. Enggak ada password yang beneran diuji, jadi enggak bisa nyimpulin soal kekuatan password.

**Aksi:** di AYAM.

```
sudo fail2ban-client status sshd
```

**Narasi:**

Cek fail2ban di target. Ini lapis kedua, nyatet percobaan gagal terus ngeblokir IP-nya.

---

## SCENE 7 - SQL injection

**Layar:** jendela Attacker.

**Aksi:**

```
curl "http://192.168.5.5:3000/sensor?device=sensor-01"
curl "http://192.168.5.5:3000/sensor?device=x%27%20OR%20%271%27%3D%271"
curl "http://192.168.5.5:3000/sensor?device=x%27%20AND%20%271%27%3D%272"
```

**Narasi:**

Normal dulu. Dua baris.

Sekarang payload. `%27` itu kutip, `%20` spasi, jadi isinya `x' OR '1'='1`. Hasilnya empat baris, semua isi tabel.

Karena aplikasinya nyambungin input langsung ke query. Kutip saya nutup string, `OR '1'='1'` dibaca sebagai perintah.

Ketiga, `AND '1'='2'`. Hasilnya nol.

Dua, empat, nol. Kalau cuma OR, bisa dibilang kebetulan. Nol enggak bisa. Berarti logika query-nya yang berubah.

Satu lagi, outputnya bukan JSON tapi format mentah Python. Struktur tabelnya kebaca dari luar.

---

## SCENE 8 - Data palsu MQTT

**Layar:** dua terminal Attacker.

**Aksi:**

```
mosquitto_sub -h 192.168.5.5 -t 'sensors/#' -v
mosquitto_pub -h 192.168.5.5 -t sensors/sensor-99 -m 99.90
```

**Narasi:**

Terminal kiri mantau, terminal kanan ngirim.

Enggak ada password, langsung masuk.

**Aksi:** di AYAM.

```
tail -3 /var/log/iot/subscriber.log
```

**Narasi:**

Cek log subscriber. Tersimpan sensor-99. Perangkat itu enggak ada, saya ngarang.

**Aksi:** browser Attacker.

```
http://192.168.5.5:3000/
```

**Narasi:**

Buka dashboard. Suhu 99.9 di paling atas. Buat sapi enggak masuk akal, normalnya 38.

Dan enggak ada tanda apa-apa. Datanya kelihatan sama kayak asli.

Jadi masalahnya bukan data dicuri, tapi data udah enggak bisa dipercaya.

---

## SCENE 9 - Stop rekam, import

**Layar:** jendela Onion.

**Aksi:** `Ctrl+C`, lalu:

```
tcpdump -r /tmp/pbl5-demo.pcap | wc -l
sudo so-import-pcap /tmp/pbl5-demo.pcap
```

**Narasi:**

Rekaman stop pakai Ctrl+C. Cek jumlah paket dulu, kalau nol berarti gagal.

Impor ke sensor. Makan 5 sampai 15 menit, layarnya diem. Di belakang dia proses pakai Suricata sama Zeek, terus masuk Elasticsearch.

---

## SCENE 10 - Deteksi

**Layar:** Kibana, Discover.

**Aksi:** index pattern `logstash`, rentang 24 jam, lalu ketik:

```
"192.168.5.100" AND "192.168.5.5"
```

**Narasi:**

Discover, pilih index pattern `logstash`, rentang waktu 24 jam.

Rentangnya jangan sempit. Data import pakai waktu asli rekaman, kalau sempit hasilnya kosong padahal impornya berhasil.

Yang keluar log Zeek. Ada port, jumlah byte, status SF artinya server beneran bales.

Batasnya dua. Sensor kami mode import, jadi ada jeda. Dan yang kelihatan bentuk lalu lintasnya, bukan isi serangan. SQL injection enggak keliatan sebagai alert, MQTT juga.

Jadi deteksi bagus di jaringan, lemah di aplikasi. Itu kami catat, bukan kami diemin.

---

## SCENE 11 - Mitigasi

**Layar:** jendela AYAM.

**Aksi:**

```
sudo bash /tmp/purple.sh mitigasi
```

**Narasi:**

Tiga langkah. Matiin, timpa, nyalain.

Harus mati dulu, karena Python nyimpen kode di memori. Kalau ditimpa pas masih jalan, dia tetep pakai kode lama.

Yang berubah: query pakai parameter, output jadi JSON, debug dimatiin.

---

## SCENE 12 - Verifikasi

**Layar:** jendela Attacker.

**Aksi:**

```
curl "http://192.168.5.5:3000/sensor?device=x%27%20OR%20%271%27%3D%271"
curl "http://192.168.5.5:3000/sensor?device=sensor-01"
```

**Narasi:**

Ulang payload yang sama. Hasilnya nol.

Saya enggak ngubah serangannya. Yang berubah cara aplikasi nerima input. Itu buktinya.

Tes normal juga. Dua baris, sekarang JSON. Aplikasinya masih jalan.

---

## SCENE 13 - Penutup

**Layar:** tiga jendela VM.

**Narasi:**

Kesimpulannya.

Scanning, tertutup. Tinggal tiga port.

Kredensial, tertutup. MySQL localhost, SSH key, fail2ban.

SQL injection, tertutup, dibuktiin lewat pengulangan.

MQTT, belum selesai. Konfigurasi udah disiapin tapi belum kebukti berlaku. Kami catat sebagai temuan terbuka.

Konfigurasi yang belum kebukti itu bukan mitigasi.

Sekian, terima kasih.

---

# Catatan Produksi

Rekam dua sesi kalau mau hemat waktu. Sesi 1 Scene 1 sampai 8, berhenti saat dashboard nampilin 99.9. Sesi 2 Scene 9 sampai 13. Tapi tcpdump jangan distop di antaranya.

Jangan dipotong: Scene 3 (reset), Scene 7 (tiga payload), Scene 12 (verifikasi).

Boleh dipotong: nunggu nmap, nunggu import.

Kalau gagal, jangan disunting seolah berhasil. Reset, ulang dari Scene 7.
