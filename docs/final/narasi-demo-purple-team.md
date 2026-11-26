# Narasi Demo Purple Team, naskah voice over

Naskah ini dibaca sambil mengerjakan demo. Kolom kiri menandai apa yang sedang terjadi di layar, bagian NARASI itu yang diucapkan.

Kalimatnya sudah disusun untuk diucapkan, bukan dibaca. Kalau ada yang terasa terlalu panjang, potong di tengah, jangan dipercepat.

---

## BUKA

### Tampilan: tiga jendela VM, belum ada perintah

NARASI

Selamat malam. Kami dari Kelompok 5, dengan skenario Internal Database Fortress.

Yang kami bangun adalah replika sistem sprinkler otomatis untuk peternakan sapi perah. Sistem ini menyalakan penyiram berdasarkan indeks suhu dan kelembapan, dibantu visi komputer untuk membaca kondisi ternak. Kalau data sensornya dipalsukan, penyiram bisa menyala atau mati di waktu yang salah. Untuk ternak, itu bukan gangguan kecil.

Yang kami uji malam ini bukan sensornya. Yang kami uji adalah jalur datanya. Sensor mengirim lewat MQTT, disimpan di MySQL, lalu ditampilkan di dashboard.

Tiga mesin yang kami pakai. Target pada 192.168.5.5, penyerang pada 192.168.5.100, dan pemantau pada 192.168.5.200.

Metodenya purple team. Bukan tim ketiga, tapi satu siklus lima tahap untuk setiap skenario. Serang, deteksi, analisis, mitigasi, verifikasi. Yang membedakan purple dari red team ada di tahap terakhir. Setelah dimitigasi, serangan yang sama kami ulang. Kalau hasilnya berubah, mitigasinya terbukti. Kalau tidak berubah, berarti kami cuma mengklaim.

---

## BAGIAN 1 - PENGINTAIAN

### Tampilan: mengetik nmap di VM penyerang

NARASI

Skenario pertama, pengintaian. Yang kami cari adalah peta layanan. Berapa port yang terbuka, dan versi apa yang dipakai.

`nmap -sS -sV -p- 192.168.5.5`

Pemindaian ini menyisir seluruh 65535 port. Sebelum hardening, tahap ini memakan waktu sekitar dua puluh detik dan menemukan lima port terbuka, lengkap dengan versi setiap layanan. Informasi versi itu yang dipakai penyerang untuk memilih serangan berikutnya.

### Tampilan: hasil nmap keluar

Sekarang hasilnya berbeda. Yang terbuka tinggal tiga. Dua puluh dua untuk SSH, seribu delapan ratus delapan puluh tiga untuk MQTT, dan tiga ribu untuk dashboard.

Yang penting justru yang tidak muncul. Port 3306, MySQL, tidak ada di daftar. Bukan ditolak, tapi tidak terlihat sama sekali.

Waktunya juga berubah. Dari dua puluh detik menjadi hampir delapan ratus detik. Penyebabnya dua. Port yang tidak dipakai sudah ditutup, dan ufw membuang paket ke port yang tidak diizinkan. Penyerang jadi menghabiskan waktu tanpa mendapat apa pun.

---

## BAGIAN 2 - AKSES KREDENSIAL

### Tampilan: nc ke port 3306, menunggu

NARASI

Skenario kedua, akses kredensial. Ada dua sasaran, basis data dan SSH.

`nc -vz 192.168.5.5 3306`

Perhatikan hasilnya nanti. Yang keluar adalah timeout, bukan connection refused.

### Tampilan: hasil timed out

Bedanya penting. Connection refused berarti ada layanan yang menolak, jadi penyerang tahu di situ ada sesuatu. Timeout berarti paketnya dibuang tanpa jawaban. Dari sisi penyerang, tidak ada apa pun di sana.

Ini efek langsung dari MySQL yang hanya mendengarkan di loopback. Layanannya hidup, tapi hanya bisa dihubungi dari dalam mesin itu sendiri.

### Tampilan: mengetik hydra

`hydra -l root -P /usr/share/wordlists/rockyou.txt ssh://192.168.5.5 -t 4`

Sekarang kami coba menebak kata sandi SSH. Ini cara yang paling murah dan paling sering dipakai.

### Tampilan: hydra ditolak, lalu Ctrl+C

Ditolak sebelum sempat mencoba. Bukan karena kata sandinya kuat, tapi karena layanannya tidak menerima kata sandi sama sekali. SSH di mesin ini hanya menerima kunci.

Saya hentikan di sini karena melanjutkan percobaan tidak ada gunanya. Tidak ada satu pun kata sandi yang pernah diuji, jadi kami tidak bisa dan tidak akan menyimpulkan apa pun soal kekuatan kata sandi di mesin ini.

### Tampilan: fail2ban-client status sshd di mesin target

Di sisi biru, ada lapisan tambahan. fail2ban mencatat setiap percobaan yang gagal, dan memblokir alamat IP-nya setelah tiga kali gagal. Di catatan kami, pemblokiran berlangsung tiga puluh menit.

Jadi ada dua lapis. Lapis pertama menutup jalur masuknya. Lapis kedua mencatat dan memblokir kalau ada yang tetap mencoba.

---

## BAGIAN 3 - SQL INJECTION

### Tampilan: curl permintaan normal

NARASI

Skenario ketiga, dan ini yang paling penting malam ini. Lapisan aplikasi.

Saya mulai dari yang normal dulu.

`curl "http://192.168.5.5:3000/sensor?device=sensor-01"`

Hasilnya dua baris. Dua pembacaan untuk sensor satu. Ini perilaku yang benar, tidak ada yang aneh.

### Tampilan: curl payload OR

Sekarang saya ubah satu bagian, parameternya.

`curl "http://192.168.5.5:3000/sensor?device=x%27%20OR%20%271%27%3D%271"`

### Tampilan: hasil keluar, seluruh tabel

Sekarang keluar seluruh isi tabel. Empat baris, bukan dua.

Yang saya masukkan bukan nama perangkat. Yang saya masukkan adalah potongan perintah SQL. Tanda kutip menutup string, lalu `OR` dengan kondisi yang selalu benar. Aplikasi menggabungkan nilai itu langsung ke dalam teks query, jadi database membacanya sebagai perintah, bukan sebagai data.

### Tampilan: curl payload AND

Dan ini pembuktian terakhir.

`curl "http://192.168.5.5:3000/sensor?device=x%27%20AND%20%271%27%3D%272"`

### Tampilan: hasil kosong

Hasilnya kosong. Nol baris.

Saya minta kalian memperhatikan tiga hasil ini. Normal dua baris. Dengan kondisi selalu benar, empat baris. Dengan kondisi selalu salah, nol baris.

Tiga hasil berbeda dari satu parameter yang sama. Ini bukan bug tampilan, bukan kesalahan tampilan halaman. Ini masukannya benar-benar mengubah logika query di database.

Ada satu kebocoran tambahan. Perhatikan bentuk keluarannya. Bukan JSON, tapi bentuk mentah bawaan Python, lengkap dengan nama tipe datanya. Artinya urutan kolom dan tipe data di database ikut terbaca dari luar. Penyerang jadi tahu struktur tabel tanpa perlu menyentuh databasenya.

---

## BAGIAN 4 - DATA PALSU LEWAT MQTT

### Tampilan: dua terminal di mesin penyerang

NARASI

Sekarang bagian kedua dari skenario tiga. Bukan mencuri data, tapi merusak kepercayaan pada data.

Di terminal pertama saya pantau lalu lintas sensor.

`mosquitto_sub -h 192.168.5.5 -t 'sensors/#' -v`

### Tampilan: publish dari terminal kedua

Lalu di terminal kedua saya kirim satu pesan.

`mosquitto_pub -h 192.168.5.5 -t sensors/sensor-99 -m 99.90`

Tidak ada kata sandi. Tidak ada penolakan. Tidak ada yang meminta saya membuktikan bahwa saya memang perangkat yang berhak mengirim.

### Tampilan: log subscriber di mesin target

Di mesin target, pesan itu masuk dan langsung dicatat sebagai data sensor yang sah.

Perhatikan namanya, sensor sembilan sembilan. Perangkat itu tidak pernah ada. Saya hanya menuliskan namanya di topik, dan subscriber mempercayainya begitu saja.

### Tampilan: dashboard di browser

Sekarang saya buka dashboard.

Suhu sembilan puluh sembilan koma sembilan, di posisi paling atas. Untuk peternakan sapi perah, angka itu mustahil. Suhu tubuh sapi sekitar tiga puluh delapan derajat. Kalau sistem ini benar-benar dipakai, penyiram akan menyala terus tanpa alasan.

Dan tidak ada satu pun penanda bahwa data ini palsu. Tidak ada tanda tanya, tidak ada peringatan. Dashboard menampilkannya sama persis seperti data asli.

Inilah inti insidennya. Bukan datanya dicuri, tapi datanya tidak bisa dipercaya lagi. Sistem yang mengambil keputusan dari data yang salah bisa lebih berbahaya daripada sistem yang mati.

---

## BAGIAN 5 - DETEKSI

### Tampilan: Kibana, Discover

NARASI

Sebelum masuk ke mitigasi, saya tunjukkan dulu apa yang tercatat di sisi pemantauan.

Security Onion merekam lalu lintas di segmen ini. Yang tampil di sini adalah log Zeek, yaitu catatan koneksi dan permintaan HTTP.

`"192.168.5.100" AND "192.168.5.5"`

Yang kelihatan, semua koneksi dari mesin penyerang ke mesin target. Ada status koneksi, ada jumlah byte yang dikirim dan diterima.

Saya perlu jujur soal batasnya. Sensor di lab ini bekerja dengan mengimpor berkas tangkapan, bukan memantau kabel secara langsung. Jadi ada jeda antara serangan dan hasil analisis. Rekaman harus diambil sebelum serangan, kalau tidak, tidak ada yang bisa dianalisis.

Dan yang lebih penting: yang tercatat adalah bentuk lalu lintasnya, bukan isi serangannya. Tidak ada aturan yang mengenali SQL injection di parameter URL. Tidak ada aturan yang mengenali penyisipan pesan MQTT. Jadi serangan tadi tidak muncul sebagai peringatan.

Yang muncul lebih banyak soal pola koneksi umum. Ini kesenjangan yang kami catat, bukan yang kami sembunyikan. Deteksi kami kuat di lapisan jaringan, dan lemah di lapisan aplikasi.

---

## BAGIAN 6 - MITIGASI

### Tampilan: menjalankan skrip mitigasi di mesin target

NARASI

Sekarang bagian yang menentukan. Mitigasi.

`sudo bash /tmp/purple.sh mitigasi`

Yang skrip ini lakukan ada tiga, dan urutannya penting. Matikan aplikasi yang sedang jalan. Timpa berkasnya dengan versi yang sudah diperbaiki. Baru nyalakan lagi.

Urutan itu bukan gaya-gayaan. Kalau berkas ditimpa sambil aplikasi masih jalan, Python tetap memakai kode lama yang sudah masuk ke memori. Berkasnya benar, tapi perilakunya tidak berubah. Itu sudah pernah terjadi waktu kami berlatih, dan hasilnya membingungkan.

### Tampilan: skrip selesai, status keluar

Sekarang aplikasinya memakai versi yang diperbaiki. Ada tiga perubahan.

Pertama, query-nya tidak lagi menggabungkan teks. Nilai dari pengguna dikirim terpisah sebagai parameter. Database menerimanya sebagai data, dan tidak akan pernah membacanya sebagai perintah.

Kedua, keluarannya sekarang JSON, bukan bentuk mentah Python. Urutan kolom dan tipe data tidak lagi bocor.

Ketiga, mode debug dimatikan. Kalau ada galat, halaman galatnya tidak lagi menampilkan struktur internal aplikasi.

---

## BAGIAN 7 - VERIFIKASI

### Tampilan: mengulang payload yang sama di mesin penyerang

NARASI

Dan ini bagian yang membedakan purple team dari red team. Saya ulangi serangan yang sama, persis, tanpa perubahan apa pun.

`curl "http://192.168.5.5:3000/sensor?device=x%27%20OR%20%271%27%3D%271"`

### Tampilan: hasil JSON jumlah nol

Hasilnya nol.

Payload yang tadi membuka seluruh tabel, sekarang tidak mengembalikan apa pun. Saya tidak mengubah serangannya. Yang berubah adalah cara aplikasi memperlakukan masukan.

Ini buktinya. Kalau saya hanya bilang sudah dimitigasi, itu klaim. Dengan mengulang serangan yang sama dan menunjukkan hasilnya berubah, itu bukti.

Saya juga pastikan aplikasinya masih berfungsi, bukan mati karena salah konfigurasi.

`curl "http://192.168.5.5:3000/sensor?device=sensor-01"`

### Tampilan: hasil normal, sekarang berbentuk JSON

Dua baris, dalam bentuk JSON. Aplikasinya hidup, datanya benar, dan injeksinya tertutup.

---

## PENUTUP

### Tampilan: tiga jendela VM

NARASI

Saya rangkum apa adanya.

Skenario satu, pengintaian. Tertutup. Yang terbuka tinggal tiga port, dan MySQL tidak terlihat dari jaringan.

Skenario dua, akses kredensial. Tertutup. MySQL hanya di loopback, SSH hanya menerima kunci, dan fail2ban memblokir percobaan berulang.

Skenario tiga bagian pertama, SQL injection. Tertutup, dan terbukti lewat pengulangan payload yang sama.

Skenario tiga bagian kedua, penyisipan data lewat MQTT, belum tuntas. Konfigurasi untuk menutupnya sudah disiapkan, tapi belum kami pastikan berlaku penuh. Karena itu kami catat sebagai temuan terbuka, bukan kami nyatakan selesai.

Alasannya sederhana. Konfigurasi yang belum terbukti berlaku bukan mitigasi. Kami memilih mencatat apa adanya daripada mengklaim lebih dari yang bisa kami tunjukkan.

Dan satu hal soal deteksi. Sensor kami lemah di lapisan aplikasi. Itu bukan sesuatu yang kami sembunyikan, itu yang kami catat sebagai pekerjaan berikutnya.

Terima kasih.
