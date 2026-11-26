# Script Video Demo Purple Team

Narasi formal, menjelaskan setiap opsi pada tiap perintah. Urutan ikut `demo-dari-awal.md`.

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

Tahap pertama adalah penyiapan lingkungan pengujian, yang dijalankan dari host melalui VBoxManage.

Perintah `startvm` dipanggil tiga kali dengan argumen nama mesin yang berbeda, yaitu AYAM sebagai target, Cybersecurity LabVM Worksation sebagai penyerang, dan CyberOps Security Onion sebagai pemantau. Opsi `--type headless` menandakan bahwa mesin dijalankan tanpa jendela grafis, sehingga sumber daya host tidak dialokasikan untuk antarmuka visual. Urutan pemanggilan adalah target, penyerang, kemudian pemantau, karena pemantau memerlukan waktu inisialisasi paling lama.

Perintah terakhir, `list runningvms`, tidak menyalakan apa pun. Perintah ini menampilkan daftar mesin yang sedang beroperasi, dan digunakan untuk memverifikasi bahwa ketiga mesin telah benar-benar aktif sebelum pengujian dimulai.

---

## SCENE 3 - Mengembalikan kondisi target

**Layar:** jendela AYAM.

**Aksi:**

```
sudo bash /tmp/purple.sh reset
```

**Narasi:**

Sebelum pengujian dilaksanakan, mesin target dikembalikan pada kondisi sebelum mitigasi. Tahap ini bersifat prasyarat. Apabila target berada pada kondisi yang telah dimitigasi, serangan tidak akan berhasil, sehingga tidak ada fenomena yang dapat diobservasi.

Perintah tersebut terdiri atas tiga bagian. `sudo` menjalankan perintah berikutnya dengan hak administrator, karena proses yang dihentikan berjalan sebagai layanan sistem. `bash` mengeksekusi berkas skrip, bukan perintah tunggal. Argumen terakhir, `reset`, adalah mode yang dipilih dari skrip tersebut, yang membedakannya dari mode `mitigasi` dan mode `cek` pada berkas yang sama.

Pada mode `reset`, skrip menjalankan tujuh tindakan berurutan: menghentikan proses aplikasi dan subscriber yang sedang beroperasi, memasang berkas aplikasi versi rentan, memasang berkas aplikasi versi aman sebagai pembanding, menulis ulang konfigurasi layanan pesan agar menerima koneksi dari jaringan, menghapus baris data uji dari sesi sebelumnya, melepas blokir alamat penyerang pada mekanisme pemblokiran otomatis, kemudian menjalankan kembali kedua proses tersebut.

Terdapat satu aspek teknis yang perlu ditekankan. Proses lama harus dihentikan terlebih dahulu. Apabila berkas aplikasi diganti sementara prosesnya masih beroperasi, aplikasi tetap menggunakan kode yang telah dimuat ke memori. Berkas pada disk telah diperbarui, namun perilaku sistem tidak berubah.

Pada akhirnya, skrip melakukan verifikasi mandiri dengan mengirim satu permintaan normal dan satu permintaan berisi payload injeksi. Apabila permintaan kedua tidak mengembalikan seluruh isi tabel, skrip menyatakan bahwa kondisi belum rentan, dan pengujian tidak dilanjutkan.

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

Perintah pertama, `ip -br a`, menampilkan daftar antarmuka jaringan pada mesin pemantau. Opsi `-br` mempersingkat keluaran menjadi satu baris per antarmuka, dan `a` berarti seluruh antarmuka ditampilkan, bukan hanya yang aktif. Perintah ini dijalankan untuk memastikan nama antarmuka yang terhubung ke segmen target, bukan untuk mengubah konfigurasi apa pun. Berdasarkan hasilnya, alamat pemantau adalah 192.168.5.200 pada antarmuka eth2.

Perintah kedua, `tcpdump`, adalah perekam lalu lintas. Opsi `-i eth2` menentukan antarmuka yang direkam, yaitu antarmuka yang baru saja diidentifikasi. Opsi `-n` menonaktifkan penerjemahan alamat menjadi nama host, sehingga keluaran tetap berupa alamat numerik dan proses rekam tidak tertahan oleh permintaan DNS. Opsi `-w /tmp/pbl5-demo.pcap` mengubah keluarannya dari tampilan layar menjadi berkas dalam format pcap. Opsi `-U` memaksa penulisan langsung ke berkas tanpa menunggu buffer penuh, sehingga paket tetap tersimpan apabila proses dihentikan secara mendadak.

Karena keluaran diarahkan ke berkas, terminal tidak menampilkan apa pun selama perekaman. Kondisi tersebut bukan indikasi kegagalan. Perekaman sengaja dimulai sebelum serangan pertama, karena sensor pada lingkungan ini bekerja dengan menganalisis berkas tangkapan, bukan dengan pemantauan langsung pada media transmisi. Apabila perekaman dimulai setelah serangan, tidak terdapat data yang dapat dianalisis.

---

## SCENE 5 - Pemetaan layanan

**Layar:** jendela penyerang.

**Aksi:**

```
nmap -sS -sV -p- 192.168.5.5
```

**Narasi:**

Tahap pertama pengujian adalah pemetaan layanan, yang dijalankan dari mesin penyerang dengan satu perintah `nmap`.

Opsi `-sS` menentukan teknik pemindaian setengah terbuka. Koneksi tidak diselesaikan sampai tahap akhir, sehingga pemindaian lebih cepat dan tidak meninggalkan catatan sesi pada layanan yang dipindai. Opsi `-sV` menambahkan pembacaan versi layanan pada setiap port yang terbuka, sehingga hasilnya bukan hanya daftar port, tetapi juga identitas perangkat lunak di baliknya. Opsi `-p-` memperluas cakupan dari port yang umum digunakan menjadi seluruh enam puluh lima ribu lima ratus tiga puluh lima port. Alamat terakhir adalah sasaran pemindaian.

Hasilnya tiga port terbuka: 22 untuk SSH, 1883 untuk layanan pesan, dan 3000 untuk dashboard. Port 3306, yaitu layanan basis data, tidak terdeteksi.

Perlu ditegaskan bahwa layanan basis data tetap beroperasi dan tetap menyimpan seluruh data. Yang berubah adalah keterlihatannya dari jaringan. Dari perspektif penyerang, port tersebut tidak tersedia. Dari perspektif aplikasi, koneksi berjalan sebagaimana mestinya. Objek yang tidak dapat diidentifikasi tidak dapat dijadikan sasaran serangan.

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

Tahap kedua diarahkan pada mekanisme autentikasi, dan terdiri atas tiga perintah yang berbeda.

Perintah pertama menggunakan `nc` untuk menguji keterjangkauan port basis data. Opsi `-z` menempatkan alat ini pada mode tanpa pengiriman data: koneksi dibuka, statusnya dicatat, lalu ditutup, tanpa ada muatan protokol yang dikirim. Opsi `-v` menampilkan proses koneksi secara rinci. Dua argumen terakhir adalah alamat dan port yang diuji, yaitu 192.168.5.5 pada port 3306. Hasilnya timeout, bukan refused. Perbedaan tersebut signifikan: refused menunjukkan adanya layanan yang menjawab dan menolak, sedangkan timeout menunjukkan paket dibuang tanpa respons.

Perintah kedua menggunakan `hydra` untuk menguji daftar kata sandi terhadap layanan SSH. Opsi `-l root` menetapkan satu nama pengguna tunggal, bukan daftar nama pengguna, sehingga seluruh percobaan diarahkan pada akun root. Opsi `-P` menunjuk berkas daftar kata sandi yang digunakan, yaitu kumpulan kata sandi yang umum dipakai. Argumen `ssh://192.168.5.5` menetapkan protokol dan sasaran, sehingga alat ini berbicara dalam protokol SSH dan bukan protokol lain. Opsi `-t 4` membatasi empat percobaan paralel, agar layanan tidak dibanjiri dan pemblokiran otomatis tidak terpicu terlalu cepat. Proses tersebut terhenti pada tahap negosiasi, karena layanan hanya menerima autentikasi berbasis kunci. Tidak ada satu pun kata sandi yang benar-benar diuji, sehingga pengujian ini tidak menghasilkan kesimpulan mengenai kekuatan kata sandi.

Perintah ketiga dijalankan pada mesin target, bukan pada mesin penyerang. Perintah `fail2ban-client` dengan argumen `status sshd` menampilkan keadaan mekanisme pemblokiran untuk layanan SSH: jumlah percobaan yang gagal, jumlah alamat yang sedang diblokir, dan daftar alamat tersebut. Perintah ini tidak mengubah konfigurasi, hanya membaca status. Hasilnya menunjukkan bahwa percobaan yang gagal berulang dicatat, kemudian alamat sumbernya diblokir secara otomatis.

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

Ketiga perintah menggunakan `curl`, yang mengirimkan permintaan HTTP ke alamat yang ditulis dan menampilkan respons yang diterima di terminal. Yang membedakan ketiganya bukan alatnya, melainkan nilai parameter `device` pada alamat yang diminta.

Perintah pertama mengirim nilai `sensor-01`, yaitu identitas perangkat yang memang terdaftar. Permintaan ini berfungsi sebagai pembanding, untuk menunjukkan bentuk respons yang normal. Hasilnya dua baris data.

Perintah kedua mengirim nilai `x%27%20OR%20%271%27%3D%271`. Tanda `%27` adalah representasi terenkode dari karakter kutip tunggal, dan `%20` adalah representasi dari spasi, karena karakter tersebut tidak dapat ditulis langsung pada alamat. Apabila diterjemahkan, nilai tersebut berbunyi `x' OR '1'='1`. Kutip pertama menutup pembatas teks pada query, kemudian klausa `OR` menambahkan kondisi yang selalu bernilai benar. Nilai `x` di awal dipilih karena tidak merujuk pada perangkat mana pun, sehingga seluruh baris yang muncul berasal dari klausa tambahan tersebut, bukan dari pencocokan identitas. Hasilnya seluruh isi tabel terbuka.

Perintah ketiga mengirim nilai yang serupa, tetapi dengan kondisi `AND '1'='2`, yaitu kondisi yang selalu bernilai salah. Hasilnya kosong.

Hasil kosong pada perintah ketiga merupakan bukti yang menentukan. Apabila hanya perintah kedua yang disajikan, masih terbuka kemungkinan bahwa yang terjadi adalah kesalahan penyajian. Dengan hasil kosong pada perintah ketiga, dapat disimpulkan bahwa yang berubah adalah logika query, bukan tampilan.

Terdapat kebocoran tambahan. Format keluaran pada ketiga respons tersebut masih berupa representasi mentah bahasa pemrograman, sehingga struktur dan tipe kolom ikut terbaca. Penyerang tidak hanya memperoleh isi data, tetapi juga skema tabel.

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

Bagian kedua diarahkan pada injeksi data melalui layanan pesan, dan melibatkan tiga perintah pada dua mesin.

Perintah pertama dijalankan pada mesin penyerang, di terminal kiri. `mosquitto_sub` adalah klien yang berlangganan pesan. Opsi `-h 192.168.5.5` menetapkan alamat broker yang dituju. Opsi `-t 'sensors/#'` menetapkan topik yang diikuti, dengan karakter `#` sebagai wildcard yang mencakup seluruh subtopik di bawah `sensors`, sehingga tidak hanya satu perangkat yang terpantau. Opsi `-v` menampilkan nama topik di samping isi pesan, agar asal setiap pesan dapat diketahui. Perintah ini berjalan terus dan tidak berhenti sendiri; fungsinya memastikan pesan benar-benar sampai ke broker.

Perintah kedua dijalankan pada terminal kanan. `mosquitto_pub` adalah klien yang mengirim pesan. Opsi `-h` menetapkan broker yang sama. Opsi `-t sensors/sensor-99` menetapkan topik tujuan, dan di sinilah identitas perangkat ditentukan, bukan oleh perangkat itu sendiri. Opsi `-m 99.90` menetapkan isi pesan, yaitu satu nilai suhu. Pesan diterima tanpa proses autentikasi dan tanpa penolakan.

Perintah ketiga dijalankan pada mesin target. `tail` menampilkan bagian akhir sebuah berkas, dan opsi `-3` membatasi keluarannya pada tiga baris terakhir. Berkas yang dibaca adalah log layanan penerima pesan. Perintah ini tidak mengubah apa pun, hanya memastikan bahwa pesan yang dikirim benar-benar tercatat di sisi penerima, bukan hanya lewat di jaringan.

Hasilnya, data tersimpan dengan identitas sensor-99 dan nilai suhu 99,9. Perangkat dengan identitas tersebut tidak pernah ada, melainkan diciptakan pada pengujian ini. Namun layanan penerima memperlakukannya sebagai data yang valid.

Pada dashboard, data tersebut tampil pada posisi teratas. Suhu normal sapi perah berada pada kisaran 38 derajat, sehingga sistem akan mengaktifkan penyiram secara terus-menerus. Dashboard juga tidak memberikan penanda bahwa data tersebut tidak sah.

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

Setelah rangkaian serangan selesai, perekaman dihentikan, dan hasilnya diperiksa sebelum dianalisis.

Perintah pertama menjalankan `tcpdump` dengan opsi `-r /tmp/pbl5-demo.pcap`, yang berarti membaca kembali berkas tangkapan alih-alih merekam antarmuka. Keluarannya disalurkan melalui pipa `|` ke perintah `wc -l`, yang menghitung jumlah baris. Satu baris pada keluaran tersebut mewakili satu paket. Perintah ini dijalankan untuk memastikan berkas berisi data; apabila hasilnya nol, perekaman dinyatakan gagal dan analisis tidak akan menghasilkan temuan apa pun.

Perintah kedua, `so-import-pcap`, memasukkan berkas tangkapan ke dalam sensor. Argumennya adalah berkas yang sama. Perintah ini menjalankan dua mesin analisis terhadap berkas tersebut, yaitu Suricata untuk pencocokan aturan dan Zeek untuk pembentukan catatan koneksi, kemudian hasilnya dimasukkan ke basis data pencarian.

Proses tersebut memerlukan waktu. Konsekuensinya, analisis pada metode ini berlangsung setelah serangan, bukan pada saat serangan berlangsung. Hal tersebut merupakan keterbatasan yang dicatat, bukan yang disembunyikan.

---

## SCENE 10 - Deteksi

**Layar:** Kibana, Discover.

**Aksi:** index pattern `logstash`, rentang 24 jam, lalu:

```
"192.168.5.100" AND "192.168.5.5"
```

**Narasi:**

Hasil analisis disajikan melalui antarmuka pencarian pada mesin pemantau.

Langkah pertama adalah memilih index pattern, yaitu kumpulan indeks yang akan dicari. Pola yang dipakai adalah yang memuat penanda `logstash`, sesuai dengan penamaan pada versi sensor yang digunakan di lab ini.

Langkah kedua adalah menetapkan rentang waktu. Data hasil impor membawa waktu asli perekaman, bukan waktu impor, sehingga rentang diperlebar menjadi dua puluh empat jam. Apabila rentang terlalu sempit, hasil pencarian akan kosong meskipun impor berhasil.

Langkah ketiga adalah mengisi kolom pencarian dengan `"192.168.5.100" AND "192.168.5.5"`. Pencarian ini menggunakan teks bebas, bukan filter berdasarkan nama kolom. Alasannya, penamaan kolom berbeda antar versi sensor, sehingga pencarian teks lebih tahan terhadap perbedaan tersebut. Dua alamat yang digabungkan dengan `AND` akan menampilkan catatan yang memuat keduanya sekaligus, yaitu koneksi antara penyerang dan target.

Data yang muncul mencakup port tujuan, jumlah byte, dan status penyelesaian. Status yang terbaca menunjukkan koneksi selesai secara normal, yang berarti server memberikan respons.

Terdapat dua batas yang perlu disampaikan.

Pertama, karena sensor bekerja dari berkas tangkapan, selalu terdapat jeda antara pelaksanaan serangan dan ketersediaan hasil analisis. Deteksi dengan pendekatan ini tidak dapat digunakan untuk menghentikan serangan yang sedang berlangsung.

Kedua, yang terekam adalah bentuk lalu lintas, bukan isi serangan. Tidak terdapat aturan yang mengenali injeksi pada parameter URL, dan tidak terdapat aturan yang mengenali penyisipan pesan. Kedua serangan tersebut tidak muncul sebagai peringatan, melainkan hanya sebagai koneksi yang selesai normal.

Dengan demikian, deteksi yang tersedia kuat pada lapisan jaringan dan lemah pada lapisan aplikasi.

---

## SCENE 11 - Mitigasi

**Layar:** jendela AYAM.

**Aksi:**

```
sudo bash /tmp/purple.sh mitigasi
```

**Narasi:**

Mitigasi dilakukan pada lapisan aplikasi, menggunakan skrip yang sama dengan tahap pengembalian kondisi, tetapi dengan mode yang berbeda.

Argumen `mitigasi` pada perintah ini memilih rangkaian tindakan yang berbeda dari mode `reset`. Pada mode ini skrip hanya menyentuh aplikasi, dan tidak mengubah konfigurasi layanan pesan, basis data, maupun mekanisme pemblokiran. Tujuannya agar perubahan yang diuji terbatas pada satu variabel, sehingga perbedaan hasil dapat diatribusikan secara jelas.

Skrip bekerja dalam tiga urutan: menghentikan proses aplikasi, mengganti berkasnya dengan versi yang telah diperbaiki, kemudian menjalankannya kembali.

Urutan tersebut bukan formalitas. Proses yang beroperasi menyimpan kode di memori, sehingga penggantian berkas pada saat aplikasi masih berjalan tidak mengubah perilakunya. Kondisi tersebut pernah teramati pada tahap latihan: berkas telah diperbarui, namun hasil pengujian tetap gagal karena proses yang beroperasi masih menggunakan kode lama.

Setelah penggantian, terdapat tiga perubahan pada aplikasi. Masukan tidak lagi disambungkan ke dalam query, melainkan dikirimkan sebagai nilai terpisah, sehingga basis data membacanya sebagai data dan tidak sebagai perintah. Keluaran diubah menjadi format terstruktur, sehingga struktur tabel tidak lagi terbaca. Mode pengembangan dinonaktifkan, agar pesan kesalahan tidak menampilkan informasi internal aplikasi.

---

## SCENE 12 - Verifikasi

**Layar:** jendela penyerang.

**Aksi:**

```
curl "http://192.168.5.5:3000/sensor?device=x%27%20OR%20%271%27%3D%271"
curl "http://192.168.5.5:3000/sensor?device=sensor-01"
```

**Narasi:**

Verifikasi dilakukan dengan dua perintah `curl` yang identik dengan tahap sebelumnya, baik alamat, parameter, maupun payload-nya. Tidak ada satu karakter pun yang diubah. Perbedaannya hanya satu: aplikasi pada mesin target telah diganti.

Perintah pertama mengirim payload yang sebelumnya membuka seluruh isi tabel. Hasilnya sekarang kosong.

Perintah kedua mengirim permintaan normal dengan identitas perangkat yang terdaftar. Hasilnya tetap dua baris, tetapi bentuknya telah berubah menjadi format terstruktur. Perintah ini dijalankan untuk memastikan bahwa mitigasi tidak merusak fungsi aplikasi, karena penutupan celah yang membuat layanan berhenti bekerja bukanlah perbaikan.

Karena masukan yang diberikan identik, perubahan hasil hanya dapat disebabkan oleh perubahan pada aplikasi. Pernyataan bahwa sistem telah dimitigasi, tanpa pengujian ulang, masih merupakan klaim. Dengan pengulangan serangan yang sama, hasil tersebut menjadi bukti.

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
