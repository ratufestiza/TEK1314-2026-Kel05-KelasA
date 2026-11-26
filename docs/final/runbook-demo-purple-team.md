# Runbook Demo Purple Team

Dokumen ini dipakai dari persiapan sampai demo selesai. Untuk membersihkan sisa rekaman sebelumnya, lihat juga `bersih-bersih-sebelum-demo.md`.

Ditulis ulang 26 November 2026 setelah pengecekan langsung ke VM.

---

# Bagian 0 - Persiapan, 30 menit sebelum demo

Kerjakan ini sebelum penonton datang. Kalau semuanya sudah hijau, buka Bagian 4 dan demo langsung.

## 0.1 Nyalakan tiga VM, urutannya penting

Di host, Target dulu, Onion terakhir karena paling lama siap.

`"/c/Program Files/Oracle/VirtualBox/VBoxManage.exe" startvm "AYAM" --type headless`

`"/c/Program Files/Oracle/VirtualBox/VBoxManage.exe" startvm "Cybersecurity LabVM Worksation 20230210" --type headless`

`"/c/Program Files/Oracle/VirtualBox/VBoxManage.exe" startvm "CyberOps Security Onion" --type headless`

`"/c/Program Files/Oracle/VirtualBox/VBoxManage.exe" list runningvms`

Kalau salah satu gagal dengan `VERR_NO_PAGE_MEMORY`, host kehabisan memori. Tutup Spotify dan Chrome dulu, atau kecilkan RAM VM Attacker.

## 0.2 Target, cek alamat dan layanan

Di VM AYAM:

`ip -4 a | grep 192.168.5`

Harus `192.168.5.5/24`. Kalau kosong, `sudo netplan apply`, cek lagi.

`ss -tln | grep -e ':3000' -e ':1883' -e ':3306'`

Harus muncul 3000 di `0.0.0.0`, 1883 di `0.0.0.0`, dan 3306 di `127.0.0.1`.

## 0.3 Target, cek aplikasi dan subscriber hidup

`ps aux | grep -e app.py -e subscriber | grep -v grep`

Harus ada `python3 app.py` dan `python3 subscriber.py`, masing-masing satu.

Kalau mati:

`cd /opt/iot-dashboard`

`sudo -b nohup python3 app.py > /tmp/dashboard.log 2>&1 &`

`sudo -b nohup python3 subscriber.py > /tmp/subscriber.log 2>&1 &`

Cek log subscriber, harus ada `menunggu pesan di sensors/#`:

`tail -5 /tmp/subscriber.log`

## 0.4 Target, pastikan versi berkas benar

`ls -l /opt/iot-dashboard/app.py /opt/iot-dashboard/app.py.aman`

`app.py` harus 1483 byte, versi rentan dengan halaman tabel. `app.py.aman` harus 1791 byte, versi aman.

Kalau `app.py.aman` ukurannya sama dengan `app.py`, versi amannya hilang dan sesi mitigasi tidak punya tujuan. Ambil ulang dari repo, berkasnya ada di `docs/final/lampiran-kode/`, lalu pasang dengan `sudo cp`.

## 0.5 Target, pastikan MQTT terbuka

`cat /etc/mosquitto/conf.d/default.conf`

Harus memuat `listener 1883 0.0.0.0` dan `allow_anonymous true`.

## 0.6 Target, kosongkan ban dan data palsu

`sudo fail2ban-client status sshd`

Daftar banned harus kosong. Kalau ada `192.168.5.100`:

`sudo fail2ban-client unban 192.168.5.100`

Data palsu dari rekaman sebelumnya, kalau masih ada:

`sudo mysql -u root -p` lalu `USE iot_db;` lalu `DELETE FROM sensor_readings WHERE device_id='sensor-99';` lalu `exit`

## 0.7 Attacker, cek alat

Di VM Attacker:

`which nmap hydra curl mosquitto_pub mosquitto_sub`

Semua harus keluar path-nya. Kalau salah satu tidak ada, pasang sebelum demo, jangan saat demo.

Tes sekali koneksi ke target:

`curl -s -m 5 "http://192.168.5.5:3000/sensor?device=sensor-01"`

Harus keluar dua baris.

## 0.8 Onion, nyalakan Kibana

Detailnya di Bagian 4b. Ringkasnya: `sudo so-status`, nyalakan Elasticsearch lalu Kibana, tunggu, buka `https://localhost` di browser dalam VM Onion.

## 0.9 Tabel go atau no-go

| Cek | Harus | Kalau gagal |
| --- | --- | --- |
| Tiga VM nyala | ya | nyalakan, tutup aplikasi host kalau memori kurang |
| IP `192.168.5.5` | ada | `sudo netplan apply` |
| Dashboard 3000 | nyala | jalankan ulang dengan `nohup` |
| Subscriber | satu proses | `killall -f subscriber` lalu jalankan satu |
| Payload OR | 4 baris | `app.py` bukan versi rentan, tukar |
| MQTT terbuka | ya | perbaiki `default.conf` |
| Kibana | kebuka | lanjut tanpa Kibana, jangan buang waktu |

Kalau semua hijau, demo siap. Kalau ada yang merah dan tidak bisa dibereskan dalam 10 menit, tetap demo dan sebutkan apa adanya.

---

# Bagian 1 - Kita ini sedang apa

## Apa yang dibangun

Replika sistem sprinkler otomatis untuk peternakan sapi perah. Sistem ini menyalakan penyiram berdasarkan indeks suhu dan kelembapan, dibantu visi komputer untuk membaca kondisi ternak. Kalau data sensornya dipalsukan, penyiram bisa menyala atau mati di waktu yang salah, dan itu berbahaya untuk hewan.

Yang dipakai sebagai replika bukan sensor asli, melainkan empat layanan di satu mesin Linux:

| Layanan | Port | Fungsi |
| --- | --- | --- |
| SSH | 22 | administrasi jarak jauh |
| Mosquitto | 1883 | jalur masuk data dari perangkat sensor |
| Flask dashboard | 3000 | menampilkan pembacaan sensor |
| MySQL | 3306 | menyimpan riwayat pembacaan |

Alurnya: sensor mengirim lewat MQTT, subscriber menangkap lalu menulis ke tabel `sensor_readings`, dashboard membacanya kembali dan menampilkannya.

## Siapa berperan apa

| Peran | Tugas dalam demo |
| --- | --- |
| Red Team | menyerang. Semua perintah dari VM Attacker |
| Blue Team | mendeteksi dan memitigasi. Perintah dijalankan di VM Target dan VM Onion |
| Lead | membuka, menjelaskan alur, menutup |

Red Team **tidak pernah** membuka Kibana. Kalau ada yang bertanya, tegaskan itu: penyerang tidak memantau pertahanan sendiri.

## Istilah yang harus jelas di awal

**Purple Team** bukan tim ketiga. Ini cara kerja dua tim di satu meja dengan satu catatan bersama. Setiap skenario punya lima tahap:

1. Serang, dikerjakan Red Team.
2. Deteksi, dikerjakan Blue Team.
3. Analisis, dikerjakan bersama.
4. Mitigasi, dikerjakan Blue Team.
5. Verifikasi, Red Team mengulang serangan yang sama, Blue Team mengonfirmasi.

Inti demonya ada di tahap 5. Tanpa pengulangan setelah mitigasi, itu bukan purple team, itu cuma red team yang lapor.

---

# Bagian 2 - Tiga skenario, apa yang diserang

## Ringkasan

| Skenario | Yang diserang | Kenapa bisa | Mitigasi |
| --- | --- | --- | --- |
| 1. Pengintaian | permukaan layanan di Target | banyak port terbuka dan terbaca versinya | ufw, kurangi layanan, tutup port tidak perlu |
| 2. Akses kredensial | SSH dan MySQL | MySQL terbuka ke jaringan, SSH menerima kata sandi, tidak ada pembatas percobaan | MySQL ke loopback, SSH kunci saja, fail2ban |
| 3. Lapisan aplikasi | dashboard dan broker MQTT | query digabung dengan format string, broker menerima klien anonim, identitas perangkat diambil mentah dari nama topik | parameterized query, keluaran JSON, autentikasi broker, daftar putih `device_id` |

## Skenario 1 - Pengintaian

**Yang diserang:** port dan versi layanan di `192.168.5.5`.

**Kenapa berhasil:** sebelum hardening ada lima port terbuka dan setiap banner membocorkan versi. Informasi itu yang dipakai penyerang untuk memilih serangan berikutnya.

**Bentuk serangan di demo:** `nmap -sS -sV -p- 192.168.5.5`.

**Yang ditunjukkan:** hanya tiga port terbuka, yaitu 22, 1883, dan 3000. MySQL tidak muncul karena sudah di loopback.

**Angka pembanding yang bisa disebut:** pemindaian penuh butuh 20,52 detik sebelum hardening, dan 780,26 detik sesudahnya. Perlambatan itu efek langsung dari pembatasan port dan rate limit.

## Skenario 2 - Akses kredensial

**Yang diserang:** autentikasi SSH dan keterjangkauan MySQL.

**Kenapa berhasil sebelum hardening:** MySQL mendengarkan di `0.0.0.0`, SSH menerima kata sandi, dan tidak ada yang membatasi jumlah percobaan.

**Bentuk serangan di demo:** `nc -vz 192.168.5.5 3306` lalu `hydra` ke SSH.

**Yang ditunjukkan:** koneksi ke 3306 timeout, bukan refused. Bedanya penting: timeout berarti paketnya dibuang, jadi penyerang tidak tahu ada layanan atau tidak. Hydra ditolak pada tahap negosiasi metode, karena SSH hanya menerima kunci.

**Peran Blue Team:** `fail2ban` mencatat percobaan dan memblokir IP. Di laporan tercatat lima kegagalan sebelum IP diblokir, dengan masa blokir 1800 detik.

## Skenario 3 - Lapisan aplikasi

Ini skenario utama, dan yang paling layak didemokan karena hasilnya kelihatan langsung di layar.

**3a. SQL injection pada dashboard**

Yang diserang: parameter `device` di `http://192.168.5.5:3000/sensor`.

Kenapa berhasil: nilai dari pengguna digabung langsung ke dalam teks query dengan operator format string. Tidak ada pemisahan antara perintah dan data.

Bukti mekanismenya bukan satu payload, tapi tiga yang hasilnya beda:

| Payload | Hasil | Artinya |
| --- | --- | --- |
| `sensor-01` | 2 baris | perilaku normal |
| `x' OR '1'='1` | 4 baris | seluruh tabel terbaca |
| `x' AND '1'='2` | nol baris | kondisi bisa dipaksa selalu salah |

Tiga hasil berbeda dari satu parameter membuktikan masukannya mengubah logika query, bukan cuma diteruskan.

**3b. Penyisipan data palsu lewat MQTT**

Yang diserang: broker di port 1883.

Kenapa berhasil: `allow_anonymous true`, jadi klien tanpa identitas diterima. Subscriber juga memakai nama topik sebagai `device_id` tanpa daftar putih, jadi penyerang bebas mengaku sebagai perangkat mana pun.

Bentuk serangan: publish ke topik `sensors/sensor-99` dengan suhu 99.90. Karena tidak ada daftar putih, subscriber menuliskannya sebagai perangkat sah.

Dampaknya bukan pencurian data, tapi rusaknya kepercayaan pada data operasional. Dashboard menampilkan angka yang tidak berasal dari perangkat mana pun, tanpa penanda apa pun.

## Mitigasi yang diperagakan

| Perubahan | Alamat | Alasan |
| --- | --- | --- |
| Query jadi parameterized | `app.py` | memisahkan perintah dan data, menutup injeksi di akarnya |
| Keluaran jadi JSON | `app.py` | repr tuple membocorkan urutan kolom dan tipe data |
| Debug dimatikan | `app.py` | halaman galat membocorkan struktur internal |
| Autentikasi broker | `default.conf` | klien tanpa identitas tidak boleh menulis data |

Yang **tidak** diklaim selesai: skenario 3b belum tuntas. Konfigurasi aman untuk broker sudah disiapkan tetapi belum dipastikan berlaku penuh. Di laporan ini dicatat sebagai temuan terbuka, bukan dinyatakan beres. Jangan menutupinya saat demo.

---

# Bagian 3 - Kondisi VM, hasil pengecekan 26 November 2026

| Item | Nilai | Status |
| --- | --- | --- |
| Target | `192.168.5.5`, user `fattih` | siap |
| Attacker | `192.168.5.100`, user `analyst@secOps` | siap |
| Monitoring | `192.168.5.200` | layanan web belum menyala |
| `app.py` | 806 byte, versi rentan | siap |
| `app.py.aman` | 1155 byte, versi aman | siap |
| Dashboard | `0.0.0.0:3000` | nyala |
| Subscriber | satu proses | nyala, menunggu pesan |
| MQTT | `allow_anonymous true` | terbuka |
| MySQL | `127.0.0.1:3306` | sesuai hardening |
| Query normal | 2 baris | benar |
| Payload OR | 4 baris | benar |
| Payload AND | nol baris | benar |

Dashboard dan subscriber dijalankan di latar belakang dengan `nohup`. Log ada di `/tmp/dashboard.log` dan `/tmp/subscriber.log`. Kalau salah satu mati, nyalakan lagi seperti di Bagian 5.

---

# Bagian 4 - Urutan demo

Total sekitar 35 menit. Kalau waktu mepet, lewati skenario 1 dan langsung ke 2 dan 3.

## Menit 0-3, pembuka

Yang ditunjukkan: tiga jendela VM, tabel alamat.

`ip -4 a | grep 192.168.5` di Target, hasilnya `192.168.5.5/24`.

Kalimat pembuka: "Kami membangun replika sistem sprinkler otomatis untuk peternakan sapi perah. Yang kami uji bukan sensornya, tapi jalur datanya: dari perangkat masuk lewat MQTT, disimpan di MySQL, lalu ditampilkan di dashboard."

## Menit 3-9, skenario 1

**Di VM Attacker:**

`nmap -sS -sV -p- 192.168.5.5`

Yang diucapkan saat menunggu: "Sebelum hardening ada lima port terbuka dan versi setiap layanan terbaca. Sekarang tinggal tiga."

Setelah selesai: tunjukkan 22, 1883, 3000. Tekankan 3306 tidak muncul.

## Menit 9-15, skenario 2

**Di VM Attacker:**

`nc -vz 192.168.5.5 3306`

Tunggu sampai timeout. Yang diucapkan: "Timeout, bukan refused. Artinya paketnya dibuang, jadi dari sisi penyerang layanannya tidak terlihat sama sekali."

`hydra -l root -P /usr/share/wordlists/rockyou.txt ssh://192.168.5.5 -t 4`

Tunggu sekitar satu menit, lalu hentikan dengan `Ctrl+C` kalau terlalu lama.

Yang ditunjukkan: percobaan ditolak karena SSH hanya menerima kunci.

**Di VM Target, peran Blue Team:**

`sudo fail2ban-client status sshd`

Tunjukkan daftar `Banned IP list` berisi `192.168.5.100` dan angka kegagalan. Kalau kosong, jelaskan saja bahwa pembatasannya aktif di level SSH dan tunjukkan konfigurasinya:

`sudo sshd -T | grep -e passwordauthentication -e permitrootlogin`

## Menit 15-25, skenario 3a, SQL injection

**Di VM Attacker, tiga perintah berurutan:**

`curl "http://192.168.5.5:3000/sensor?device=sensor-01"`

Hasil: dua baris.

`curl "http://192.168.5.5:3000/sensor?device=x%27%20OR%20%271%27%3D%271"`

Hasil: empat baris, seluruh tabel.

`curl "http://192.168.5.5:3000/sensor?device=x%27%20AND%20%271%27%3D%272"`

Hasil: nol baris, `()`.

Yang diucapkan: "Tiga payload, tiga hasil berbeda. Ini bukti masukannya mengubah logika query. Kalau cuma bug tampilan, hasilnya akan sama."

Sebut juga: keluaran berbentuk repr tuple, jadi urutan kolom dan tipe datanya ikut terbaca. Itu kebocoran tambahan.

## Menit 25-32, skenario 3b, penyisipan data palsu

**Terminal pertama, di VM Attacker:**

`mosquitto_sub -h 192.168.5.5 -t 'sensors/#' -v`

Biarkan terbuka.

**Terminal kedua, di VM Attacker:**

`mosquitto_pub -h 192.168.5.5 -t sensors/sensor-99 -m 99.90`

Yang diucapkan: "Tidak ada kata sandi, tidak ada penolakan. Broker menerima siapa saja."

Catatan penting: subscriber hanya menerima angka polos atau JSON dengan kunci `suhu` dan `kelembapan`. Format berkoma seperti `99.90,0.00` akan ditolak dan muncul di log sebagai `dilewati, payload bukan angka atau JSON`. Jadi pakai angka polos, sekaligus bebas dari masalah tanda kutip.

**Di VM Target,** tunjukkan baris masuk:

`sudo mysql -u root -p` lalu `USE iot_db;` lalu `SELECT * FROM sensor_readings ORDER BY id DESC LIMIT 3;`

**Di browser VM Attacker,** buka `http://192.168.5.5:3000/`. Halaman itu menampilkan tabel pembacaan terbaru, dan baris suhu 99.90 muncul di posisi teratas karena diurutkan dari id terbesar. Angka itu mustahil untuk peternakan sapi perah, dan itulah inti insidennya: data operasional tidak bisa dipercaya lagi.

## Menit 32-40, mitigasi dan verifikasi

**Di VM Target, peran Blue Team:**

`cd /opt/iot-dashboard`

`sudo cp app.py.aman app.py`

`killall -f app.py`

`sudo -b nohup python3 app.py > /tmp/dashboard.log 2>&1 &`

Tunggu, lalu pastikan:

`ss -tln | grep 3000`

**Di VM Attacker, ulangi payload yang sama persis:**

`curl "http://192.168.5.5:3000/sensor?device=x%27%20OR%20%271%27%3D%271"`

Hasil yang diharapkan: JSON dengan `"jumlah": 0`, bukan empat baris.

Yang diucapkan: "Payload sama, hasil nol. Yang berubah bukan serangannya, tapi cara aplikasi memperlakukan masukan."

## Menit 40-45, penutup

Sebutkan apa adanya:

1. Skenario 1 tertutup oleh pembatasan port.
2. Skenario 2 tertutup oleh MySQL loopback, SSH kunci, dan fail2ban.
3. Skenario 3a tertutup oleh parameterized query, terbukti lewat pengulangan payload.
4. Skenario 3b belum tuntas. Autentikasi broker sudah disiapkan tetapi belum dipastikan berlaku penuh. Ini dicatat terbuka di laporan.

Kalau ditanya kenapa masih terbuka: "Karena kami memilih mencatat apa adanya daripada mengklaim selesai. Konfigurasi yang belum terbukti berlaku bukan mitigasi."

---

# Bagian 4b - Peran Onion, deteksi dan Kibana

Onion bukan mesin penyerang dan bukan mesin target. Ini posisi Blue Team. Semua yang berhubungan dengan pantauan dilakukan di sini.

## Aturan tampilan

Kibana dibuka **di dalam VM Onion**, pakai browser yang ada di VM itu, alamatnya `https://localhost` atau `https://127.0.0.1`.

Jangan buka dari VM Attacker. Itu salah alur, dan kalau ditanya dosen alasannya tidak ada.

Kalau mau ditampilkan di layar yang sama dengan penonton, tampilkan jendela Onion, bukan jendela Attacker.

## Menyalakan layanan sebelum demo

Di VM Onion:

`sudo so-status`

Cari baris `so-elasticsearch` dan `so-kibana`. Kalau `stopped`:

`sudo so-elasticsearch-start`

`sudo so-kibana-start`

Kalau perintah itu tidak ada di image, pakai Docker:

`sudo docker ps -a | grep -e kibana -e elastic`

`sudo docker start so-elasticsearch`

`sudo docker start so-kibana`

Tunggu satu sampai dua menit. Kibana butuh Elasticsearch siap dulu, jadi jangan nyalakan dua-duanya lalu langsung buka browser.

Cek dari VM Onion sendiri:

`curl -k -s -o /dev/null -w '%{http_code}\n' https://localhost`

Kalau keluar `302` atau `200`, sudah siap.

## Menit 15-18, demo deteksi

Yang ditunjukkan di Kibana:

1. Buka menu **Discover**.
2. Set rentang waktu ke 30 menit terakhir.
3. Tambahkan kolom `source.ip` dan `destination.port`.
4. Filter: `source.ip : "192.168.5.100"` dan `destination.ip : "192.168.5.5"`.

Yang akan kelihatan: lalu lintas pemindaian dan percobaan koneksi dari Attacker ke Target. Di catatan proyek tercatat 50 hit untuk pola ini.

Kalimat yang diucapkan: "Yang terekam di sini adalah pola jaringan, yaitu percobaan koneksi berulang ke banyak port. Sensor menangkap bentuknya, bukan isi payload-nya."

## Batas deteksi yang harus disebut

Ini bagian yang membuat presentasi terlihat jujur, jadi jangan dilewati.

1. Tidak ada signature yang mengenali payload SQL injection di parameter URL. Jadi serangan 3a tidak muncul sebagai alert khusus, hanya sebagai permintaan HTTP biasa.
2. Tidak ada signature yang mengenali penyisipan pesan MQTT. Serangan 3b praktis tidak terlihat dari sisi jaringan.
3. Alert yang muncul lebih banyak soal ICMP dan aktivitas umum, bukan pola serangan aplikasi.
4. Sensor berjalan dalam mode import, jadi kelengkapan bukti bergantung pada benar atau tidaknya berkas tangkapan diambil.

Kalimat penutupnya: "Deteksi kami kuat di lapisan jaringan dan lemah di lapisan aplikasi. Itu kesenjangan yang kami catat, bukan yang kami sembunyikan."

## Kalau Kibana tidak mau terbuka

Jangan habiskan waktu di depan penonton. Cukup katakan layanan monitoring sedang tidak aktif, lalu lanjut ke skenario 3. Tiga skenario tetap bisa diperagakan penuh tanpa Kibana, dan bagian deteksi bisa dijelaskan lewat tangkapan layar bukti yang sudah ada di lampiran laporan.

## Selisih waktu

Kibana memakai UTC, catatan tim memakai WIB. Selisihnya tujuh jam. Kalau ada yang bertanya kenapa jamnya beda dengan jam di HP, jawabannya itu.

---

# Bagian 5 - Kalau ada yang mati di tengah demo

**Dashboard tidak menjawab.** Di VM Target:

`ps aux | grep app.py | grep -v grep`

Kalau kosong:

`cd /opt/iot-dashboard`

`sudo -b nohup python3 app.py > /tmp/dashboard.log 2>&1 &`

`tail -20 /tmp/dashboard.log`

**Data MQTT tidak masuk tabel.** Cek subscriber:

`ps aux | grep subscriber | grep -v grep`

Kalau kosong:

`cd /opt/iot-dashboard`

`sudo -b nohup python3 subscriber.py > /tmp/subscriber.log 2>&1 &`

`tail -5 /tmp/subscriber.log`

Harus muncul `menunggu pesan di sensors/#`.

**IP hilang setelah VM restart.** Di VM Target:

`ip a | grep 192.168.5`

`sudo netplan apply`

**Kibana tidak mau terbuka.** Jangan buang waktu di depan penonton. Katakan bahwa layanan monitoring sedang tidak aktif, lalu lanjut ke skenario berikutnya. Tiga skenario tetap bisa diperagakan tanpa Kibana.

---

# Bagian 6 - Jebakan yang sudah terbukti

1. Alamat localhost di VM Attacker berarti Attacker itu sendiri. Semua serangan memakai `192.168.5.5`.
2. `pkill` tidak ada di image Target, pakai `killall -f`.
3. `mosquitto_sub -5` bukan opsi yang sah. Cukup `-t 'sensors/#' -C 1 -W 3`. Hasil `Timed out` berarti koneksi diterima, bukan gagal.
4. Tanpa baris `listener` di `default.conf`, Mosquitto hanya mendengarkan di loopback dan semua klien jaringan dapat `Connection refused`.
5. Salinan berkas memakai `cp`, jangan menimpa `app.py.aman` dengan `app.py` yang sedang rentan. Itu yang bikin versi aman hilang kemarin.
6. Menghapus data butuh akun root. `app_iot` tidak punya hak DELETE dan akan menghasilkan `ERROR 1142`.
7. Kibana memakai UTC, catatan tim memakai WIB, selisih tujuh jam. Jangan mengira itu sesi berbeda.
8. Menuliskan perintah dengan tanda kutip lewat chat berisiko terpotong saat disalin. Ketik SQL langsung di prompt mysql.
9. Subscriber menolak payload berkoma. `99.90,0.00` masuk log sebagai `dilewati, payload bukan angka atau JSON`. Pakai angka polos `99.90` atau JSON `{"suhu": 99.90, "kelembapan": 0}`.
10. `killall -f` tidak dikenal di image Target, dan `killall app.py` tidak menemukan apa pun karena nama prosesnya `python3`. Matikan pakai `sudo kill <PID>` dari hasil `ps -eo pid,cmd | grep app.py`.

---

# Bagian 7 - Contekan satu halaman

Semua perintah yang dipakai demo, dikelompokkan per mesin. Buka bagian ini kalau lupa urutannya.

## Di VM Target, AYAM

| Keperluan | Perintah |
| --- | --- |
| cek alamat | `ip -4 a \| grep 192.168.5` |
| pasang alamat | `sudo netplan apply` |
| cek port | `ss -tln \| grep -e ':3000' -e ':1883'` |
| cek proses | `ps aux \| grep -e app.py -e subscriber \| grep -v grep` |
| nyalakan dashboard | `sudo -b nohup python3 app.py > /tmp/dashboard.log 2>&1 &` |
| nyalakan subscriber | `sudo -b nohup python3 subscriber.py > /tmp/subscriber.log 2>&1 &` |
| matikan dashboard | `killall -f app.py` |
| cek versi berkas | `ls -l /opt/iot-dashboard/app.py /opt/iot-dashboard/app.py.aman` |
| tukar ke aman | `sudo cp app.py.aman app.py` |
| cek MQTT | `cat /etc/mosquitto/conf.d/default.conf` |
| cek ban | `sudo fail2ban-client status sshd` |
| unban | `sudo fail2ban-client unban 192.168.5.100` |
| hapus data palsu | `sudo mysql -u root -p` lalu `USE iot_db;` lalu `DELETE FROM sensor_readings WHERE device_id='sensor-99';` |

## Di VM Attacker

| Keperluan | Perintah |
| --- | --- |
| skenario 1 | `nmap -sS -sV -p- 192.168.5.5` |
| tes MySQL | `nc -vz 192.168.5.5 3306` |
| tes SSH | `hydra -l root -P /usr/share/wordlists/rockyou.txt ssh://192.168.5.5 -t 4` |
| query normal | `curl "http://192.168.5.5:3000/sensor?device=sensor-01"` |
| payload OR | `curl "http://192.168.5.5:3000/sensor?device=x%27%20OR%20%271%27%3D%271"` |
| payload AND | `curl "http://192.168.5.5:3000/sensor?device=x%27%20AND%20%271%27%3D%272"` |
| pantau MQTT | `mosquitto_sub -h 192.168.5.5 -t 'sensors/#' -v` |
| kirim data palsu | `mosquitto_pub -h 192.168.5.5 -t sensors/sensor-99 -m 99.90` |
| buka dashboard | browser ke `http://192.168.5.5:3000` |

## Di VM Onion

| Keperluan | Perintah |
| --- | --- |
| cek layanan | `sudo so-status` |
| nyalakan elastic | `sudo so-elasticsearch-start` |
| nyalakan kibana | `sudo so-kibana-start` |
| fallback docker | `sudo docker ps -a \| grep -e kibana -e elastic` |
| buka kibana | browser dalam VM ke `https://localhost` |

## Hasil yang harus keluar

| Perintah | Hasil benar |
| --- | --- |
| query normal | 2 baris `sensor-01` |
| payload OR | 4 baris, seluruh tabel |
| payload AND | `()`, nol baris |
| `nc` ke 3306 | timeout, bukan refused |
| `hydra` | ditolak pada negosiasi metode |
| `mosquitto_sub` sendirian | `Timed out`, bukan `not authorised` |
| setelah mitigasi, payload OR | JSON `"jumlah": 0` |

Kalau salah satu hasilnya tidak sesuai, jangan improvisasi di depan penonton. Sebut apa adanya, lalu lanjut ke bagian berikutnya.

