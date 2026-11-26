# Script Video Demo Purple Team

Narasi presentasi. Urutan ikut `demo-dari-awal.md`.

---

## SCENE 1 - Pembuka

**Layar:** tiga jendela VM.

**Narasi:**

Selamat malam. Saya Fattih, dari Kelompok 5, skenario 05, Internal Database Fortress.

Sistem yang kami bangun adalah sprinkler otomatis untuk kandang sapi perah. Sensor membaca suhu dan kelembapan, data masuk ke basis data, lalu ditampilkan di dashboard.

Jika data sensor dipalsukan, penyiram dapat menyala pada waktu yang salah. Untuk ternak, dampaknya bukan gangguan kecil.

Karena itu, yang kami uji bukan sensornya, melainkan jalur datanya.

Pengujian berlangsung pada tiga mesin. Target di 192.168.5.5, penyerang di 192.168.5.100, dan pemantau di 192.168.5.200.

Metodenya purple team. Setelah serangan, kami menyiapkan mitigasi, lalu mengulang serangan yang sama. Tanpa pengulangan, itu hanya red team.

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

Pertama, ketiga mesin dinyalakan. Urutannya target, penyerang, lalu pemantau, karena pemantau paling lama mencapai kondisi siap.

Setelah itu, kami pastikan ketiganya berjalan.

---

## SCENE 3 - Mengembalikan kondisi target

**Layar:** jendela AYAM.

**Aksi:**

```
sudo bash /tmp/purple.sh reset
```

**Narasi:**

Sebelum pengujian, mesin target dikembalikan ke kondisi sebelum mitigasi. Tanpa langkah ini, serangan tidak akan berhasil, dan tidak ada yang bisa dibuktikan.

Prosesnya mengembalikan berkas aplikasi versi rentan, membuka layanan pesan, membersihkan data uji dari sesi sebelumnya, dan melepas blokir yang tertinggal.

Satu hal yang paling sering terlewat: proses lama harus dihentikan lebih dahulu. Jika berkas diganti sementara aplikasi masih berjalan, aplikasi tetap memakai kode yang sudah dimuat ke memori. Berkasnya benar, perilakunya tidak berubah.

Di akhir, skrip memastikan aplikasi benar-benar berjalan dalam kondisi rentan.

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

Pertama, kami pastikan antarmuka yang terhubung ke segmen target. Alamat pemantau adalah 192.168.5.200 pada antarmuka eth2.

Setelah itu, perekaman dijalankan. Seluruh lalu lintas antara penyerang dan target melewati antarmuka ini, sehingga tidak perlu memasang apa pun di mesin penyerang.

Rekaman dimulai sebelum serangan pertama, bukan sesudahnya. Sensor di lab ini bekerja dengan menganalisis berkas tangkapan, bukan memantau kabel secara langsung. Jika rekaman tidak dimulai dari awal, tahap deteksi tidak akan memiliki data.

Selama proses berjalan, layar tidak menampilkan apa pun. Rekaman tetap berjalan, hanya saja hasilnya masuk ke berkas.

---

## SCENE 5 - Pemetaan layanan

**Layar:** jendela penyerang.

**Aksi:**

```
nmap -sS -sV -p- 192.168.5.5
```

**Narasi:**

Tahap pertama adalah pemetaan layanan. Kami ingin mengetahui permukaan serangan yang tersisa setelah hardening.

Hasilnya tiga port. 22 untuk SSH, 1883 untuk MQTT, dan 3000 untuk dashboard. Port 3306, basis data, tidak muncul.

Sebelum hardening, lima port terbuka lengkap dengan versinya. Yang penting di sini bukan yang muncul, melainkan yang hilang.

Waktu pemindaian juga meningkat dari sekitar dua puluh detik menjadi hampir delapan ratus detik. Paket ke port yang tidak diizinkan dibuang tanpa jawaban.

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

Tahap kedua menyasar jalur autentikasi.

Sambungan langsung ke basis data berakhir timeout, bukan refused. Perbedaannya penting: refused berarti ada layanan yang menolak, sedangkan timeout berarti paket dibuang tanpa jawaban. Dari sisi penyerang, tidak ada apa pun di sana.

Percobaan tebak kata sandi SSH berhenti pada tahap negosiasi, karena layanan hanya menerima kunci. Tidak ada satu kata sandi pun yang benar-benar diuji, sehingga kami tidak menyimpulkan apa pun tentang kekuatan kata sandi.

Di sisi pertahanan, ada pencatatan dan pemblokiran otomatis terhadap alamat yang gagal berulang.

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

Tiga permintaan berikut menunjukkan satu hal: masukan dari URL dapat mengubah perintah yang dikirim ke basis data.

Permintaan normal mengembalikan dua baris. Dengan kondisi yang selalu benar, seluruh isi tabel terbuka. Dengan kondisi yang selalu salah, hasilnya kosong.

Jika hanya kasus pertama yang ditampilkan, hasilnya masih dapat diperdebatkan sebagai kebetulan. Hasil kosong pada kasus ketiga menutup perdebatan itu. Yang berubah adalah logika query, bukan tampilan.

Bentuk keluarannya juga masih format mentah bahasa pemrograman, sehingga struktur dan tipe kolom ikut terbaca.

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

Setelah rangkaian serangan selesai, perekaman dihentikan. Jumlah paket diperiksa lebih dahulu; jika nol, rekaman gagal dan tidak ada yang bisa dianalisis.

Berkas tangkapan kemudian dimasukkan ke sensor. Proses ini memerlukan waktu, karena berkas dibaca ulang oleh Suricata dan Zeek, lalu hasilnya dimasukkan ke basis data pencarian.

Konsekuensinya, analisis berjalan setelah serangan, bukan saat serangan berlangsung.

---

## SCENE 10 - Deteksi

**Layar:** Kibana, Discover.

**Aksi:** index pattern `logstash`, rentang 24 jam, lalu:

```
"192.168.5.100" AND "192.168.5.5"
```

**Narasi:**

Hasil analisis menampilkan lalu lintas antara mesin penyerang dan mesin target. Yang tercatat adalah pola koneksi: port tujuan, jumlah data, dan status penyelesaian. Status yang terbaca menunjukkan koneksi selesai normal, artinya server membalas.

Ada dua batas yang perlu kami sampaikan.

Pertama, karena sensor bekerja dari berkas tangkapan, ada jeda antara serangan dan hasil analisis.

Kedua, yang terekam adalah bentuk lalu lintas, bukan isi serangan. Tidak ada aturan yang mengenali injeksi pada parameter, dan tidak ada yang mengenali penyisipan pesan. Kedua serangan tadi tidak muncul sebagai peringatan.

Deteksi kami kuat di lapisan jaringan dan lemah di lapisan aplikasi. Itu kami catat sebagai kekurangan.

---

## SCENE 11 - Mitigasi

**Layar:** jendela AYAM.

**Aksi:**

```
sudo bash /tmp/purple.sh mitigasi
```

**Narasi:**

Mitigasi dilakukan pada lapisan aplikasi. Aplikasi dihentikan lebih dahulu, berkasnya diganti, lalu dijalankan kembali.

Urutan ini bukan formalitas. Proses yang berjalan menyimpan kode di memori, sehingga penggantian berkas saat aplikasi masih hidup tidak mengubah perilakunya.

Setelah penggantian, masukan tidak lagi disambung ke dalam query, melainkan dikirim sebagai nilai terpisah. Keluarannya diubah menjadi format terstruktur, dan mode pengembangan dimatikan.

---

## SCENE 12 - Verifikasi

**Layar:** jendela penyerang.

**Aksi:**

```
curl "http://192.168.5.5:3000/sensor?device=x%27%20OR%20%271%27%3D%271"
curl "http://192.168.5.5:3000/sensor?device=sensor-01"
```

**Narasi:**

Untuk membuktikan mitigasi, serangan yang sama diulang tanpa perubahan.

Hasilnya kosong. Karena serangannya identik, perubahan hasil hanya dapat disebabkan oleh perubahan pada aplikasi.

Pengujian juga dilakukan pada permintaan normal, untuk memastikan aplikasi tetap berfungsi dan tidak rusak oleh mitigasi.

---

## SCENE 13 - Penutup

**Layar:** tiga jendela VM.

**Narasi:**

Kesimpulannya.

Pemetaan layanan tertutup. Tersisa tiga port, dan basis data tidak terlihat dari jaringan.

Jalur autentikasi tertutup. Basis data hanya menerima sambungan dari dalam mesin, SSH hanya menerima kunci, dan percobaan berulang diblokir otomatis.

Injeksi pada lapisan aplikasi tertutup, dan terbukti melalui pengulangan serangan yang sama.

Penyisipan data melalui layanan pesan belum tuntas. Konfigurasinya sudah disiapkan, tetapi belum terbukti berlaku penuh, sehingga kami catat sebagai temuan terbuka.

Kami memilih mencatatnya apa adanya, karena konfigurasi yang belum terbukti bukan mitigasi.

Sekian, terima kasih.

---

# Catatan Produksi

Rekam dua sesi jika ingin hemat waktu. Sesi pertama Scene 1 sampai 8, berhenti saat dashboard menampilkan data palsu. Sesi kedua Scene 9 sampai 13. Perekaman di mesin pemantau jangan dihentikan di antara dua sesi.

Jangan dipotong: Scene 3, 7, dan 12.

Boleh dipotong: bagian menunggu pemindaian dan bagian menunggu analisis.

Jika ada yang gagal, jangan disunting seolah berhasil. Kembalikan kondisi target, lalu ulangi dari Scene 7.
