# Script Video Demo Purple Team

Narasi formal, menjelaskan fungsi setiap perintah. Urutan ikut `demo-dari-awal.md`.

---

## SCENE 1 - Pembuka

**Layar:** tiga jendela VM.

**Narasi:**

Selamat malam. Saya Fattih, dari Kelompok 5, skenario 05, Internal Database Fortress.

Sistem yang kami bangun adalah sprinkler otomatis untuk kandang sapi perah. Sensor membaca suhu dan kelembapan, data dikirim ke basis data, lalu ditampilkan pada dashboard. Keputusan penyiraman diambil dari data tersebut.

Konsekuensinya, apabila data yang masuk tidak benar, tindakan yang diambil juga tidak benar. Penyiram dapat menyala pada saat kandang sebenarnya tidak panas, atau diam pada saat suhu benar-benar meningkat.

Karena itu, yang kami uji bukan sensornya, melainkan jalur datanya, mulai dari sensor sampai dashboard.

Pengujian berlangsung pada tiga mesin dalam satu segmen tertutup. Target berada pada 192.168.5.5, penyerang pada 192.168.5.100, dan pemantau pada 192.168.5.200.

Metodenya purple team. Kami melakukan serangan, menyiapkan mitigasi, kemudian mengulang serangan yang sama untuk membuktikan bahwa mitigasi tersebut berfungsi.

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

Tahap pertama adalah menyalakan ketiga mesin. Perintah `startvm` digunakan untuk menjalankan mesin virtual dalam mode headless, yaitu tanpa jendela grafis, sehingga sumber daya host tidak terpakai untuk tampilan.

Urutannya target, penyerang, lalu pemantau. Pemantau dinyalakan terakhir karena memerlukan waktu paling lama untuk mencapai kondisi siap.

Perintah `list runningvms` digunakan untuk memastikan ketiga mesin benar-benar berjalan sebelum pengujian dimulai.

---

## SCENE 3 - Mengembalikan kondisi target

**Layar:** jendela AYAM.

**Aksi:**

```
sudo bash /tmp/purple.sh reset
```

**Narasi:**

Sebelum pengujian, mesin target dikembalikan ke kondisi sebelum mitigasi. Langkah ini wajib. Apabila target sudah berada dalam kondisi aman, serangan tidak akan berhasil, dan tidak ada yang dapat dibuktikan.

Perintah ini menjalankan skrip pengembalian kondisi. Skrip tersebut menghentikan proses yang sedang berjalan, memasang aplikasi versi rentan, membuka layanan pesan, membersihkan data uji dari sesi sebelumnya, dan melepas blokir yang tertinggal.

Terdapat satu hal yang sering terlewat pada tahap ini. Proses lama harus dihentikan lebih dahulu. Apabila berkas aplikasi diganti sementara aplikasinya masih berjalan, aplikasi tetap memakai kode yang sudah dimuat ke memori. Berkasnya sudah benar, tetapi perilakunya tidak berubah.

Di akhir, skrip memeriksa hasilnya sendiri. Apabila statusnya masih terbaca aman, pengujian tidak dilanjutkan.

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

Perintah `ip -br a` digunakan untuk menampilkan daftar antarmuka jaringan beserta alamatnya dalam format ringkas, satu baris per antarmuka. Dari hasilnya terlihat bahwa alamat pemantau adalah 192.168.5.200 pada antarmuka eth2. Seluruh lalu lintas antara penyerang dan target melewati antarmuka tersebut, sehingga kami tidak perlu memasang alat apa pun di mesin penyerang.

Perintah `tcpdump` digunakan untuk merekam lalu lintas pada antarmuka tersebut dan menyimpannya ke dalam berkas. Perekaman dimulai sebelum serangan pertama, bukan sesudahnya. Sensor di lab ini bekerja dengan menganalisis berkas tangkapan, bukan memantau kabel secara langsung. Apabila rekaman baru dimulai setelah serangan, tidak ada data yang dapat dianalisis, dan tahap deteksi akan kosong.

Selama proses berjalan, layar tidak menampilkan apa pun. Rekaman tetap berjalan, hanya saja hasilnya ditulis ke berkas. Layar yang kosong bukan berarti proses gagal.

---

## SCENE 5 - Pemetaan layanan

**Layar:** jendela penyerang.

**Aksi:**

```
nmap -sS -sV -p- 192.168.5.5
```

**Narasi:**

Tahap pertama dari pengujian adalah pemetaan layanan. Tujuannya mengetahui permukaan serangan yang tersisa setelah hardening.

Perintah `nmap` digunakan untuk memindai port pada mesin target, memeriksa seluruh rentang port, sekaligus membaca versi layanan yang menjawab. Hasilnya tiga port. 22 untuk SSH, 1883 untuk layanan pesan, dan 3000 untuk dashboard. Port 3306, yaitu basis data, tidak muncul sama sekali.

Yang perlu ditegaskan, basis datanya tetap berjalan dan tetap menyimpan seluruh data. Yang berubah hanya keterlihatannya dari jaringan. Dari sisi penyerang, port tersebut tidak ada. Dari sisi aplikasi, sambungan tetap berjalan normal.

Inilah yang membuat pemetaan menjadi langkah penting. Penyerang tidak dapat menyerang sesuatu yang tidak dapat dilihatnya.

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

Tahap kedua menyasar jalur autentikasi, karena pada umumnya di situlah jalan masuk paling murah.

Perintah `nc` digunakan untuk menguji apakah sebuah port dapat dihubungi, tanpa mengirim data apa pun. Hasilnya berakhir timeout, bukan refused. Perbedaannya penting. Refused berarti ada layanan yang menjawab dan menolak, sedangkan timeout berarti paketnya dibuang tanpa jawaban. Dari sisi penyerang, tidak ada apa pun pada alamat tersebut.

Perintah `hydra` digunakan untuk mencoba daftar kata sandi secara berurutan terhadap layanan SSH. Percobaan tersebut berhenti pada tahap negosiasi, karena layanan hanya menerima kunci. Tidak ada satu kata sandi pun yang benar-benar diuji. Karena itu kami tidak menyimpulkan apa pun mengenai kekuatan kata sandi pada mesin ini, dan hal itu memang bukan bagian dari pengujian kami.

Perintah `fail2ban-client` digunakan untuk menampilkan status blokir pada layanan tersebut. Hasilnya menunjukkan bahwa percobaan yang gagal berulang dicatat, kemudian alamatnya diblokir secara otomatis.

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

Tahap ketiga menyasar lapisan aplikasi, dan ini merupakan temuan utama kami.

Perintah `curl` digunakan untuk mengirim permintaan HTTP langsung dari terminal dan menampilkan respons yang diterima, sehingga isi respons dapat dibaca tanpa perantara peramban.

Tiga permintaan berikut menunjukkan satu hal: masukan dari URL dapat mengubah perintah yang dikirim ke basis data.

Permintaan normal mengembalikan dua baris, sesuai perangkat yang diminta. Ketika parameternya diubah menjadi kondisi yang selalu benar, seluruh isi tabel terbuka. Ketika diubah menjadi kondisi yang selalu salah, hasilnya kosong.

Hasil kosong itulah yang menutup perdebatan. Apabila hanya kasus pertama yang ditampilkan, masih terdapat ruang untuk berargumen bahwa hal tersebut merupakan kesalahan tampilan. Dengan hasil nol pada kasus ketiga, menjadi jelas bahwa yang berubah adalah logika query, bukan halaman.

Terdapat kebocoran tambahan. Bentuk keluarannya masih berupa format mentah bahasa pemrograman, sehingga struktur dan tipe kolom ikut terbaca dari luar. Penyerang tidak hanya memperoleh isi data, tetapi juga peta tabelnya.

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

Sekarang masuk ke bagian kedua, yaitu injeksi data palsu melalui layanan pesan.

Perintah `mosquitto_sub` digunakan untuk berlangganan seluruh topik sensor dan menampilkan setiap pesan yang masuk. Perintah `mosquitto_pub` digunakan untuk mengirim satu pesan ke topik tertentu, seolah-olah pesan tersebut berasal dari perangkat sensor.

Pesan langsung diterima tanpa autentikasi dan tanpa penolakan.

Pada mesin target, data tersimpan: sensor-99 dengan suhu 99,9. Sensor ini sebenarnya tidak ada, kami yang membuatnya. Namun subscriber menerimanya begitu saja sebagai data valid.

Pada dashboard, baris tersebut muncul di posisi teratas dengan suhu 99,9. Untuk sapi, suhu normal berada sekitar 38 derajat, sehingga sistem penyiram akan terus menyala. Dashboard juga tidak memberi tanda bahwa data ini palsu, tampilannya identik dengan data asli.

Perintah `tail` digunakan untuk menampilkan beberapa baris terakhir pada berkas log, guna memastikan bahwa pesan tersebut benar-benar tercatat oleh layanan penerima.

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

Setelah rangkaian serangan selesai, perekaman dihentikan. Perintah `tcpdump` dengan opsi baca digunakan untuk membaca kembali berkas tangkapan, sedangkan `wc -l` digunakan untuk menghitung jumlah barisnya. Apabila hasilnya nol, rekaman dianggap gagal dan tidak ada yang dapat dianalisis.

Perintah `so-import-pcap` digunakan untuk memasukkan berkas tangkapan tersebut ke dalam sensor, agar diproses oleh mesin analisis yang tersedia.

Proses ini memerlukan waktu, karena berkas dibaca ulang oleh dua mesin analisis, yaitu Suricata dan Zeek, kemudian hasilnya dimasukkan ke basis data pencarian.

Konsekuensinya, analisis dalam metode kami berjalan setelah serangan, bukan pada saat serangan berlangsung. Hal tersebut merupakan keterbatasan yang kami catat, bukan yang kami sembunyikan.

---

## SCENE 10 - Deteksi

**Layar:** Kibana, Discover.

**Aksi:** index pattern `logstash`, rentang 24 jam, lalu:

```
"192.168.5.100" AND "192.168.5.5"
```

**Narasi:**

Hasil analisis ditampilkan melalui antarmuka pencarian pada mesin pemantau. Yang tercatat adalah bentuk koneksi, yaitu port tujuan, jumlah data, dan status penyelesaian. Status yang terbaca menunjukkan koneksi selesai secara normal, yang berarti server memang membalas permintaan tersebut.

Terdapat dua batas yang perlu kami sampaikan.

Pertama, karena sensor bekerja dari berkas tangkapan, selalu terdapat jeda antara serangan dan hasil analisis. Deteksi dengan cara ini tidak dapat dipakai untuk menghentikan serangan yang sedang berlangsung.

Kedua, yang terekam adalah bentuk lalu lintas, bukan isi serangan. Tidak ada aturan yang mengenali injeksi pada parameter URL, dan tidak ada yang mengenali penyisipan pesan. Kedua serangan tersebut tidak muncul sebagai peringatan, melainkan hanya sebagai koneksi yang selesai normal.

Deteksi kami kuat pada lapisan jaringan, dan lemah tepat pada lapisan yang paling kami sorot. Hal itu kami catat sebagai kekurangan.

---

## SCENE 11 - Mitigasi

**Layar:** jendela AYAM.

**Aksi:**

```
sudo bash /tmp/purple.sh mitigasi
```

**Narasi:**

Mitigasi dilakukan pada lapisan aplikasi. Perintah ini menjalankan skrip mitigasi, yang bekerja dalam tiga urutan: menghentikan aplikasi, mengganti berkasnya, kemudian menjalankannya kembali.

Urutan tersebut bukan formalitas. Proses yang berjalan menyimpan kode di memori, sehingga mengganti berkas pada saat aplikasi masih hidup tidak mengubah perilakunya. Kami sempat mengalami hal itu pada saat latihan: berkasnya sudah benar, tetapi hasil pengujian tetap gagal, karena yang berjalan masih kode lama.

Setelah penggantian, terdapat tiga perubahan. Masukan tidak lagi disambung ke dalam query, melainkan dikirim sebagai nilai terpisah, sehingga basis data membacanya sebagai data dan tidak pernah sebagai perintah. Keluarannya diubah menjadi format terstruktur, sehingga struktur tabel tidak lagi terbaca. Dan mode pengembangan dimatikan, agar pesan kesalahan tidak menampilkan isi internal aplikasi.

---

## SCENE 12 - Verifikasi

**Layar:** jendela penyerang.

**Aksi:**

```
curl "http://192.168.5.5:3000/sensor?device=x%27%20OR%20%271%27%3D%271"
curl "http://192.168.5.5:3000/sensor?device=sensor-01"
```

**Narasi:**

Untuk membuktikan mitigasi, serangan yang sama diulang tanpa perubahan apa pun, menggunakan perintah dan payload yang identik dengan tahap sebelumnya.

Hasilnya kosong.

Karena serangannya identik, perubahan hasil hanya dapat disebabkan oleh perubahan pada aplikasi. Apabila kami hanya menyatakan bahwa sistem sudah dimitigasi, hal itu masih berupa klaim. Dengan mengulang serangan yang sama, hasilnya menjadi bukti.

Kami juga menguji permintaan normal, untuk memastikan aplikasi tetap berfungsi dan mitigasi tidak merusak layanan.

---

## SCENE 13 - Penutup

**Layar:** tiga jendela VM.

**Narasi:**

Kesimpulannya.

Pemetaan layanan tertutup. Tersisa tiga port, dan basis data tidak terlihat dari jaringan meskipun layanannya tetap berjalan.

Jalur autentikasi tertutup. Basis data hanya menerima sambungan dari dalam mesin, SSH hanya menerima kunci, dan percobaan berulang diblokir secara otomatis.

Injeksi pada lapisan aplikasi tertutup, dan telah terbukti melalui pengulangan serangan yang sama.

Penyisipan data melalui layanan pesan belum tuntas. Konfigurasinya sudah disiapkan, tetapi belum terbukti berlaku penuh, sehingga kami catat sebagai temuan terbuka.

Kami memilih mencatatnya apa adanya. Konfigurasi yang belum terbukti bukan mitigasi, dan menyebutnya selesai hanya akan menutupi masalah yang masih ada.

Sekian, terima kasih.

---

# Catatan Produksi

Rekam dua sesi. Sesi pertama Scene 1 sampai 8, berhenti saat dashboard menampilkan data palsu. Sesi kedua Scene 9 sampai 13. Perekaman di mesin pemantau jangan dihentikan di antara dua sesi.

Jangan dipotong: Scene 3, 7, dan 12.

Boleh dipotong: bagian menunggu pemindaian dan menunggu analisis.
