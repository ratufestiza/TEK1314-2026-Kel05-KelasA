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

Naskah ini dibaca sambil merekam. Urutannya mengikuti `demo-dari-awal.md`, dari Bagian A sampai K, jadi kalau rekaman putus di tengah, tinggal lanjut dari scene terakhir.

Setiap scene punya tiga bagian. **Layar** apa yang terlihat, **Aksi** yang diketik, **Narasi** yang diucapkan.

Total durasi sekitar 12 sampai 15 menit kalau tidak banyak menunggu.
## SCENE 1 - Pembuka

**Layar:** tiga jendela VM tersusun, belum ada perintah apa pun. Target di kiri, Attacker di tengah, Onion di kanan.

**Aksi:** tidak ada. Rekam layar diam 5 detik.

**Narasi:**

Selamat malam. Kami dari Kelompok 5, skenario Internal Database Fortress.

Yang kami bangun adalah replika sistem sprinkler otomatis untuk peternakan sapi perah. Sistem ini menyalakan penyiram berdasarkan indeks suhu dan kelembapan, dibantu visi komputer untuk membaca kondisi ternak. Kalau data sensornya dipalsukan, penyiram bisa menyala atau mati di waktu yang salah. Untuk ternak, itu bukan gangguan kecil.

Yang kami uji di video ini bukan sensornya. Yang kami uji adalah jalur datanya. Sensor mengirim lewat MQTT, disimpan di MySQL, lalu ditampilkan di dashboard.

Tiga mesin yang kami pakai. Target pada 192.168.5.5, penyerang pada 192.168.5.100, dan pemantau pada 192.168.5.200.

Metodenya purple team. Bukan tim ketiga, tapi satu siklus lima tahap untuk setiap skenario. Serang, deteksi, analisis, mitigasi, verifikasi. Yang membedakan purple dari red team ada di tahap terakhir. Setelah dimitigasi, serangan yang sama kami ulang. Kalau hasilnya berubah, mitigasinya terbukti. Kalau tidak berubah, berarti kami cuma mengklaim.

---

## SCENE 2 - Menyalakan tiga VM

**Layar:** terminal di host Windows.

**Aksi:**

```
"/c/Program Files/Oracle/VirtualBox/VBoxManage.exe" startvm "AYAM" --type headless
"/c/Program Files/Oracle/VirtualBox/VBoxManage.exe" startvm "Cybersecurity LabVM Worksation 20230210" --type headless
"/c/Program Files/Oracle/VirtualBox/VBoxManage.exe" startvm "CyberOps Security Onion" --type headless
"/c/Program Files/Oracle/VirtualBox/VBoxManage.exe" list runningvms
```

**Narasi:**

Saya nyalakan tiga mesin dengan urutan Target dulu, Onion terakhir, karena Onion paling lama siap.

Ketiganya berada di satu segmen internal, 192.168.5.0 per dua puluh empat, jadi tidak ada satu pun yang tersentuh internet selama pengujian.

---

## SCENE 3 - Mengembalikan Target ke kondisi rentan

**Layar:** jendela VM AYAM. Ini momen penting, jangan dipotong.

**Aksi:**

```
sudo bash /tmp/purple.sh reset
```

Tunggu sampai selesai. Rekam seluruh prosesnya, termasuk baris-baris yang muncul.

**Narasi:**

Sebelum mulai, saya kembalikan mesin target ke kondisi sebelum mitigasi. Videonya harus dimulai dari kondisi rentan, kalau tidak, serangannya tidak akan berhasil dan tidak ada yang bisa dibuktikan.

Saya pakai skrip supaya urutannya konsisten dan tidak ada langkah yang terlewat. Skripnya melakukan enam hal, berurutan.

Pertama, mematikan proses dashboard dan subscriber yang masih jalan dari sesi sebelumnya. Ini bagian yang paling sering dilupakan orang. Kalau berkasnya ditukar tapi proses lamanya masih hidup, aplikasi tetap memakai kode lama yang sudah masuk ke memori.

Kedua, memasang berkas aplikasi versi rentan, dan menyimpan versi amannya sebagai pembanding.

Ketiga, menulis ulang konfigurasi broker MQTT supaya menerima klien tanpa identitas. Ini yang nanti membuka jalan penyisipan data palsu.

Keempat, menghapus data palsu yang mungkin tertinggal dari rekaman sebelumnya, supaya tabelnya bersih dan hasilnya bisa dibandingkan.

Kelima, melepaskan blokir fail2ban terhadap mesin penyerang. Tanpa ini, percobaan SSH berikutnya akan ditolak sebelum sampai ke layanan.

Keenam, menyalakan ulang aplikasi dan subscriber.

**Layar:** bagian akhir output, status.

**Narasi:**

Di bagian bawah skrip mencetak status. Yang saya perhatikan tiga baris.

Ukuran berkas aplikasi seribu empat ratus delapan puluh tiga byte, itu versi rentan. Query normal mengembalikan dua baris. Dan payload injeksi tertulis mode rentan dengan empat baris.

Kalau baris terakhir tertulis mode aman, berarti ada yang salah dan saya tidak boleh lanjut.

---

## SCENE 4 - Mulai merekam di Onion

**Layar:** konsol VM Onion. Bukan SSH, langsung jendela VirtualBox.

**Aksi:**

```
ip -br a
```

Tunggu sebentar supaya penonton sempat membaca.

```
sudo tcpdump -i eth2 -n -w /tmp/pbl5-demo.pcap -U
```

**Narasi:**

Sebelum serangan dimulai, saya nyalakan perekaman di mesin pemantau.

Ini bagian yang paling mudah salah. Penonton sering mengira mesin penyerang yang merekam. Bukan. Yang merekam adalah Onion sendiri, di antarmuka segmennya. Penyerang tidak tahu ada perekaman, dan tidak perlu tahu. Semua paket di segmen ini lewat kartu jaringan Onion, jadi otomatis terlihat.

Saya pilih antarmuka yang punya alamat 192.168.5.200.

Opsi `-w` berarti tulis ke berkas, bukan tampilkan ke layar. Jadi layarnya akan diam dan kosong. Itu normal, bukan gagal. Saya sengaja tidak menghentikannya.

Satu hal soal sensor yang perlu saya sebut di awal. Sensor di lab ini berjalan dalam mode import. Dia tidak memantau kabel secara langsung. Yang dianalisis nanti adalah berkas tangkapan ini, jadi kalau tidak ada yang merekam, tidak ada yang bisa dianalisis.

---

## SCENE 5 - Skenario 1, pengintaian

**Layar:** jendela Attacker.

**Aksi:**

```
nmap -sS -sV -p- 192.168.5.5
```

Biarkan berjalan. Kalau terlalu lama, potong bagian menunggunya, tapi sisakan hasilnya.

**Narasi:**

Skenario pertama, pengintaian. Yang dicari adalah peta layanan. Berapa port terbuka, dan versi apa yang dipakai.

Saya sisir seluruh enam puluh lima ribu lima ratus tiga puluh lima port.

Sebelum hardening, tahap ini selesai dalam sekitar dua puluh detik dan menemukan lima port terbuka, lengkap dengan versi setiap layanan. Informasi versi itu yang dipakai penyerang untuk memilih serangan berikutnya.

**Layar:** hasil nmap.

**Narasi:**

Sekarang hasilnya berbeda. Yang terbuka tinggal tiga. Dua puluh dua untuk SSH, seribu delapan ratus delapan puluh tiga untuk MQTT, dan tiga ribu untuk dashboard.

Yang penting justru yang tidak muncul. Port tiga tiga nol enam, MySQL, tidak ada di daftar. Bukan ditolak, tapi tidak terlihat sama sekali.

Waktunya juga berubah, dari dua puluh detik menjadi hampir delapan ratus detik. Penyebabnya dua. Port yang tidak dipakai sudah ditutup, dan ufw membuang paket ke port yang tidak diizinkan. Penyerang jadi menghabiskan waktu tanpa mendapat apa pun.

---

## SCENE 6 - Skenario 2, akses kredensial

**Layar:** jendela Attacker.

**Aksi:**

```
nc -vz 192.168.5.5 3306
```

Tunggu sampai keluar timed out.

**Narasi:**

Skenario kedua, akses kredensial. Ada dua sasaran, basis data dan SSH.

Perhatikan hasilnya. Yang keluar timeout, bukan connection refused.

Bedanya penting. Connection refused berarti ada layanan yang menolak, jadi penyerang tahu di situ ada sesuatu. Timeout berarti paketnya dibuang tanpa jawaban. Dari sisi penyerang, tidak ada apa pun di sana.

Ini efek langsung dari MySQL yang hanya mendengarkan di loopback. Layanannya hidup, tapi hanya bisa dihubungi dari dalam mesin itu sendiri.

**Aksi:**

```
hydra -l root -P /usr/share/wordlists/rockyou.txt ssh://192.168.5.5 -t 4
```

Tunggu sekitar satu menit, lalu `Ctrl+C`.

**Narasi:**

Sekarang saya coba menebak kata sandi SSH. Ini cara paling murah dan paling sering dipakai.

Ditolak sebelum sempat mencoba. Bukan karena kata sandinya kuat, tapi karena layanannya tidak menerima kata sandi sama sekali. SSH di mesin ini hanya menerima kunci.

Saya hentikan di sini karena melanjutkan percobaan tidak ada gunanya. Tidak ada satu pun kata sandi yang pernah diuji, jadi kami tidak menyimpulkan apa pun soal kekuatan kata sandi di mesin ini.

**Layar:** pindah ke jendela AYAM.

**Aksi:**

```
sudo fail2ban-client status sshd
```

**Narasi:**

Di sisi biru ada lapisan tambahan. fail2ban mencatat setiap percobaan yang gagal, dan memblokir alamat IP-nya setelah tiga kali gagal, selama tiga puluh menit.

Jadi ada dua lapis. Yang pertama menutup jalur masuknya. Yang kedua mencatat dan memblokir kalau ada yang tetap mencoba.

---

## SCENE 7 - Skenario 3a, SQL injection

**Layar:** jendela Attacker. Pastikan teksnya besar dan terbaca.

**Aksi:**

```
curl "http://192.168.5.5:3000/sensor?device=sensor-01"
```

**Narasi:**

Skenario ketiga, dan ini yang paling penting. Lapisan aplikasi.

Saya mulai dari yang normal.

Hasilnya dua baris. Dua pembacaan untuk sensor satu. Ini perilaku yang benar, tidak ada yang aneh.

**Aksi:**

```
curl "http://192.168.5.5:3000/sensor?device=x%27%20OR%20%271%27%3D%271"
```

**Narasi:**

Sekarang saya ubah satu bagian, parameternya.

Dan keluar seluruh isi tabel. Empat baris, bukan dua.

Yang saya masukkan bukan nama perangkat. Yang saya masukkan adalah potongan perintah SQL. Tanda kutip menutup string, lalu OR dengan kondisi yang selalu benar. Aplikasi menggabungkan nilai itu langsung ke dalam teks query, jadi database membacanya sebagai perintah, bukan sebagai data.

**Aksi:**

```
curl "http://192.168.5.5:3000/sensor?device=x%27%20AND%20%271%27%3D%272"
```

**Narasi:**

Dan ini pembuktian terakhir. Saya minta kondisi yang selalu salah.

Hasilnya kosong. Nol baris.

Saya minta kalian memperhatikan tiga hasil ini. Normal dua baris. Dengan kondisi selalu benar, empat baris. Dengan kondisi selalu salah, nol baris.

Tiga hasil berbeda dari satu parameter yang sama. Ini bukan bug tampilan. Ini masukannya benar-benar mengubah logika query di database.

Ada satu kebocoran tambahan. Perhatikan bentuk keluarannya. Bukan JSON, tapi bentuk mentah bawaan Python, lengkap dengan nama tipe datanya. Artinya urutan kolom dan tipe data di database ikut terbaca dari luar. Penyerang jadi tahu struktur tabel tanpa menyentuh databasenya.

---

## SCENE 8 - Skenario 3b, data palsu lewat MQTT

**Layar:** dua terminal di jendela Attacker. Atur supaya dua-duanya kelihatan sekaligus.

**Aksi, terminal kiri:**

```
mosquitto_sub -h 192.168.5.5 -t 'sensors/#' -v
```

**Aksi, terminal kanan:**

```
mosquitto_pub -h 192.168.5.5 -t sensors/sensor-99 -m 99.90
```

**Narasi:**

Sekarang bagian kedua dari skenario tiga. Bukan mencuri data, tapi merusak kepercayaan pada data.

Di terminal kiri saya pantau lalu lintas sensor. Di terminal kanan saya kirim satu pesan.

Tidak ada kata sandi. Tidak ada penolakan. Tidak ada yang meminta saya membuktikan bahwa saya memang perangkat yang berhak mengirim.

**Layar:** pindah ke jendela AYAM.

**Aksi:**

```
tail -3 /var/log/iot/subscriber.log
```

**Narasi:**

Di mesin target, pesan itu masuk dan langsung dicatat sebagai data sensor yang sah.

Perhatikan namanya, sensor sembilan sembilan. Perangkat itu tidak pernah ada. Saya hanya menuliskan namanya di topik, dan subscriber mempercayainya begitu saja.

**Layar:** browser di jendela Attacker, buka alamat dashboard.

**Aksi:**

```
http://192.168.5.5:3000/
```

Refresh dengan `Ctrl+Shift+R`.

**Narasi:**

Sekarang saya buka dashboard.

Suhu sembilan puluh sembilan koma sembilan, di posisi paling atas. Untuk peternakan sapi perah, angka itu mustahil. Suhu tubuh sapi sekitar tiga puluh delapan derajat. Kalau sistem ini benar-benar dipakai, penyiram akan menyala terus tanpa alasan.

Dan tidak ada satu pun penanda bahwa data ini palsu. Tidak ada tanda tanya, tidak ada peringatan. Dashboard menampilkannya sama persis seperti data asli.

Inilah inti insidennya. Bukan datanya dicuri, tapi datanya tidak bisa dipercaya lagi. Sistem yang mengambil keputusan dari data yang salah bisa lebih berbahaya daripada sistem yang mati.

---

## SCENE 9 - Hentikan rekaman dan impor

**Layar:** jendela Onion.

**Aksi:** `Ctrl+C` di terminal tcpdump.

```
tcpdump -r /tmp/pbl5-demo.pcap | wc -l
```

**Narasi:**

Serangan sudah selesai, jadi saya hentikan rekaman.

Jumlah paketnya saya cek dulu. Kalau nol, berarti rekamannya gagal dan tidak ada gunanya diimpor.

**Aksi:**

```
sudo so-import-pcap /tmp/pbl5-demo.pcap
```

Tunggu. Kalau layarnya diam lama, itu normal, jangan dipotong kalau memungkinkan.

**Narasi:**

Sekarang saya masukkan rekaman ini ke sensor.

Prosesnya bisa lima sampai lima belas menit. Yang terjadi di belakang layar, berkasnya dipecah, dibaca ulang oleh Suricata dan Zeek, lalu hasilnya dimasukkan ke Elasticsearch.

**Aksi:** setelah selesai, buka browser di Onion.

```
https://localhost
```

**Narasi:**

Setelah impor selesai, saya buka Kibana di dalam mesin pemantau. Bukan dari mesin penyerang. Penyerang tidak memantau pertahanannya sendiri.

---

## SCENE 10 - Deteksi

**Layar:** Kibana, menu Discover.

**Aksi:** pilih pola indeks `*:logstash-*`, set rentang waktu ke Last 24 hours atau Last 7 days. Ketik di search bar:

```
"192.168.5.100" AND "192.168.5.5"
```

**Narasi:**

Pertama saya pilih pola indeksnya, lalu saya longgarkan rentang waktunya. Ini penting, karena data impor membawa cap waktu asli rekaman, bukan waktu impor. Kalau rentangnya terlalu sempit, hasilnya kosong walaupun impornya berhasil.

Saya saring pakai pencarian teks biasa, bukan filter kolom. Di versi ini, nama kolom untuk alamat IP berbeda dari versi baru, dan kalau salah mengetik, Kibana melempar error alih-alih memberi hasil kosong.

**Layar:** hasil pencarian, log Zeek terlihat.

**Narasi:**

Yang keluar adalah log Zeek. Catatan koneksi dan permintaan HTTP.

Ada status koneksi, ada jumlah byte yang dikirim dan diterima. Yang penting di sini, statusnya SF, artinya koneksi selesai dengan normal. Server membalas, dan dashboard memang hidup.

Sekarang saya perlu jujur soal batasnya.

Sensor di lab ini bekerja dengan mengimpor berkas tangkapan, bukan memantau kabel secara langsung. Jadi ada jeda antara serangan dan hasil analisis. Rekaman harus diambil sebelum serangan, kalau tidak, tidak ada yang bisa dianalisis.

Dan yang lebih penting, yang tercatat adalah bentuk lalu lintasnya, bukan isi serangannya. Tidak ada aturan yang mengenali SQL injection di parameter URL. Tidak ada aturan yang mengenali penyisipan pesan MQTT. Jadi serangan tadi tidak muncul sebagai peringatan.

Yang muncul lebih banyak soal pola koneksi umum. Ini kesenjangan yang kami catat, bukan yang kami sembunyikan. Deteksi kami kuat di lapisan jaringan, dan lemah di lapisan aplikasi.

---

## SCENE 11 - Mitigasi

**Layar:** jendela AYAM.

**Aksi:**

```
sudo bash /tmp/purple.sh mitigasi
```

**Narasi:**

Sekarang bagian yang menentukan. Mitigasi.

Skrip ini melakukan tiga hal, dan urutannya penting.

Pertama, mematikan aplikasi yang sedang jalan. Kedua, menimpa berkasnya dengan versi yang sudah diperbaiki. Ketiga, menyalakan lagi.

Urutan itu bukan gaya-gayaan. Kalau berkas ditimpa sambil aplikasi masih jalan, Python tetap memakai kode lama yang sudah masuk ke memori. Berkasnya benar, tapi perilakunya tidak berubah. Itu sudah pernah terjadi waktu kami berlatih, dan hasilnya membingungkan.

**Layar:** output status akhir.

**Narasi:**

Sekarang aplikasinya memakai versi yang diperbaiki. Ada tiga perubahan.

Pertama, query-nya tidak lagi menggabungkan teks. Nilai dari pengguna dikirim terpisah sebagai parameter. Database menerimanya sebagai data, dan tidak akan pernah membacanya sebagai perintah.

Kedua, keluarannya sekarang JSON, bukan bentuk mentah Python. Urutan kolom dan tipe data tidak lagi bocor.

Ketiga, mode debug dimatikan. Kalau ada galat, halaman galatnya tidak lagi menampilkan struktur internal aplikasi.

---

## SCENE 12 - Verifikasi

**Layar:** jendela Attacker.

**Aksi:**

```
curl "http://192.168.5.5:3000/sensor?device=x%27%20OR%20%271%27%3D%271"
```

**Narasi:**

Dan ini bagian yang membedakan purple team dari red team. Saya ulangi serangan yang sama, persis, tanpa mengubah apa pun.

Hasilnya nol.

Payload yang tadi membuka seluruh tabel, sekarang tidak mengembalikan apa pun. Saya tidak mengubah serangannya. Yang berubah adalah cara aplikasi memperlakukan masukan.

Ini buktinya. Kalau saya hanya bilang sudah dimitigasi, itu klaim. Dengan mengulang serangan yang sama dan menunjukkan hasilnya berubah, itu bukti.

**Aksi:**

```
curl "http://192.168.5.5:3000/sensor?device=sensor-01"
```

**Narasi:**

Saya juga pastikan aplikasinya masih berfungsi, bukan mati karena salah konfigurasi. Dua baris, dalam bentuk JSON. Aplikasinya hidup, datanya benar, dan injeksinya tertutup.

---

## SCENE 13 - Penutup

**Layar:** kembali ke tiga jendela VM, atau tampilkan slide ringkasan.

**Aksi:** tidak ada.

**Narasi:**

Saya rangkum apa adanya.

Skenario satu, pengintaian. Tertutup. Yang terbuka tinggal tiga port, dan MySQL tidak terlihat dari jaringan.

Skenario dua, akses kredensial. Tertutup. MySQL hanya di loopback, SSH hanya menerima kunci, dan fail2ban memblokir percobaan berulang.

Skenario tiga bagian pertama, SQL injection. Tertutup, dan terbukti lewat pengulangan payload yang sama.

Skenario tiga bagian kedua, penyisipan data lewat MQTT, belum tuntas. Konfigurasi untuk menutupnya sudah disiapkan, tapi belum kami pastikan berlaku penuh. Karena itu kami catat sebagai temuan terbuka, bukan kami nyatakan selesai.

Alasannya sederhana. Konfigurasi yang belum terbukti berlaku bukan mitigasi. Kami memilih mencatat apa adanya daripada mengklaim lebih dari yang bisa kami tunjukkan.

Dan satu hal soal deteksi. Sensor kami lemah di lapisan aplikasi. Itu bukan sesuatu yang kami sembunyikan, itu yang kami catat sebagai pekerjaan berikutnya.

Terima kasih.

---

# Catatan Produksi

## Urutan rekam

Kalau mau hemat waktu, rekam dalam dua sesi.

**Sesi 1, dari Scene 1 sampai Scene 8.** Berakhir saat dashboard menampilkan 99.90. Ini kondisi rentan penuh.

**Sesi 2, dari Scene 9 sampai Scene 13.** Dimulai saat serangan sudah selesai. Tapi rekaman tcpdump dan impor pcap tetap harus utuh, jadi jangan menghentikan tcpdump di antara dua sesi.

Kalau harus rekam sekali jalan, paling aman memang begitu.

## Yang sebaiknya tidak dipotong

- Scene 3, reset. Ini yang membuktikan videonya dimulai dari kondisi rentan.
- Scene 7, tiga payload berurutan. Potongannya harus memperlihatkan ketiganya berbanding.
- Scene 12, verifikasi. Ini inti purple team.

## Yang boleh dipotong

- Bagian menunggu nmap, sisakan hasilnya saja.
- Bagian menunggu impor, cukup tampilkan awal dan akhir.
- Scene 2, cukup tampilkan perintah dan hasil `listrunningvms`.

## Kalau ada yang gagal saat rekam

Jangan disunting seolah berhasil. Kalau payload OR tidak keluar empat baris, hentikan, jalankan `sudo bash /tmp/purple.sh reset`, lalu ulangi dari Scene 7. Itu lebih baik daripada hasilnya dipalsukan.

## Judul untuk video

Demo Purple Team, Sistem Sprinkler Otomatis Peternakan Sapi Perah, Skenario 05 Internal Database Fortress.

Kelompok 5, TEK1314 Keamanan Siber, Semester 5.
