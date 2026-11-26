# Script Video Demo Purple Team

Naskah narasi presentasi. Urutan ikut `demo-dari-awal.md`.

Perintah tampil di layar, narasi bicara di atasnya. Audiens tidak perlu tahu fungsi tiap opsi.

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
