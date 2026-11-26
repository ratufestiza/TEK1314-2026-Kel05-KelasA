# Script Video Demo Purple Team

Narasi presentasi. Urutan ikut `demo-dari-awal.md`.

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
