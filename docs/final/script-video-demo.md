# Script Video Demo Purple Team

Narasi formal akademik. Urutan ikut `demo-dari-awal.md`.

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
