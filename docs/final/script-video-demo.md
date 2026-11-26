# Script Video Demo Purple Team

Narasi formal. Tiap perintah dijelaskan fungsinya secara utuh sebagai satu perintah, tanpa merinci opsi. Urutan ikut `demo-dari-awal.md`.

---

## SCENE 1 - Introduction

**Layar:** tiga jendela VM.

**Narasi:**

Selamat malam. Saya Fattih, mewakili Kelompok 5, skenario 05, Internal Database Fortress.

Sistem yang dikembangkan adalah sprinkler otomatis untuk kandang sapi perah. Sensor membaca suhu dan kelembapan, data dikirim ke basis data, lalu disajikan pada dashboard. Keputusan penyiraman diturunkan dari data tersebut.

Apabila data yang diterima tidak akurat, keputusan yang dihasilkan juga tidak akurat. Karena itu, objek evaluasi pada pengujian ini adalah jalur datanya, mulai dari sensor hingga dashboard, bukan perangkat sensornya.

Pengujian dilaksanakan pada tiga mesin dalam satu segmen tertutup. Target pada 192.168.5.5, penyerang pada 192.168.5.100, dan pemantau pada 192.168.5.200.

Metodenya purple team: serangan dilaksanakan, mitigasi disiapkan, kemudian serangan yang sama diulang untuk memverifikasi efektivitas mitigasi.

---

## SCENE 2 - Starting the Virtual Machines

**Layar:** terminal host.

**Aksi:**

```
"/c/Program Files/Oracle/VirtualBox/VBoxManage.exe" startvm "AYAM" --type headless
"/c/Program Files/Oracle/VirtualBox/VBoxManage.exe" startvm "Cybersecurity LabVM Worksation 20230210" --type headless
"/c/Program Files/Oracle/VirtualBox/VBoxManage.exe" startvm "CyberOps Security Onion" --type headless
"/c/Program Files/Oracle/VirtualBox/VBoxManage.exe" list runningvms
```

**Narasi:**

Penyiapan lingkungan dijalankan dari host. Ketiga mesin dinyalakan tanpa jendela grafis, dengan urutan target, penyerang, kemudian pemantau, karena pemantau paling lama mencapai kondisi siap.

Perintah terakhir menampilkan daftar mesin yang sedang beroperasi, untuk memastikan ketiganya aktif sebelum pengujian dimulai.

---

## SCENE 3 - Restoring the Vulnerable State

**Layar:** jendela AYAM.

**Aksi:**

```
sudo bash /tmp/purple.sh reset
```

**Narasi:**

Sebelum pengujian, target dikembalikan ke kondisi sebelum mitigasi. Tahap ini prasyarat: apabila target sudah berada pada kondisi aman, serangan tidak akan berhasil, sehingga tidak ada fenomena yang dapat diobservasi.

Perintah ini menjalankan skrip pengembalian kondisi dengan hak administrator. Skrip menghentikan proses yang sedang berjalan, memasang aplikasi versi rentan, membuka layanan pesan, menghapus data uji dari sesi sebelumnya, melepas blokir alamat penyerang, lalu menjalankan kembali seluruh proses.

Proses lama harus dihentikan lebih dahulu. Apabila berkas diganti sementara aplikasi masih berjalan, aplikasi tetap memakai kode yang telah dimuat ke memori: berkas pada disk sudah benar, tetapi perilakunya tidak berubah.

Di akhir, skrip memverifikasi hasilnya sendiri. Apabila kondisi rentan belum tercapai, pengujian tidak dilanjutkan.

---

## SCENE 4 - Packet Capture

**Layar:** jendela onion.

**Aksi:**

```
ip -br a
sudo tcpdump -i eth2 -n -w /tmp/pbl5-demo.pcap -U
```

**Narasi:**

Pengujian dimulai dari titik pemantauan, karena seluruh rangkaian serangan harus terdokumentasi.

Perintah pertama menampilkan daftar antarmuka jaringan pada mesin pemantau. Perintah ini hanya membaca, tidak mengubah konfigurasi. Dari hasilnya diketahui bahwa antarmuka yang terhubung ke segmen target adalah eth2, dengan alamat 192.168.5.200.

Perintah kedua merekam seluruh lalu lintas pada antarmuka tersebut dan menyimpannya ke dalam berkas, bukan menampilkannya di layar. Karena keluarannya berupa berkas, terminal akan tampak kosong selama proses berjalan. Perintah ini dijalankan dengan hak administrator karena perekaman pada antarmuka jaringan memerlukannya.

Perekaman dimulai sebelum serangan pertama, karena sensor pada lingkungan ini menganalisis berkas tangkapan, bukan memantau media transmisi secara langsung. Apabila perekaman dimulai setelah serangan, tidak ada data yang dapat dianalisis.

---

## SCENE 5 - Service Enumeration

**Layar:** jendela penyerang.

**Aksi:**

```
nmap -sS -sV -p- 192.168.5.5
```

**Narasi:**

Tahap pertama adalah pemetaan layanan, untuk mengidentifikasi permukaan serangan yang tersisa setelah hardening.

Perintah ini memindai seluruh rentang port pada mesin target, sekaligus membaca versi layanan yang memberikan respons. Teknik yang dipakai bersifat setengah terbuka, sehingga pemindaian berlangsung cepat dan tidak meninggalkan catatan sesi pada layanan yang dipindai.

Hasilnya tiga port: 22 untuk SSH, 1883 untuk layanan pesan, dan 3000 untuk dashboard. Port 3306, layanan basis data, tidak terdeteksi.

Basis datanya tetap beroperasi dan tetap menyimpan seluruh data. Yang berubah hanya keterlihatannya dari jaringan. Dari sisi penyerang port itu tidak ada, dari sisi aplikasi koneksinya normal. Objek yang tidak dapat diidentifikasi tidak dapat dijadikan sasaran.

---

## SCENE 6 - Authentication Mechanism

**Layar:** jendela penyerang, lalu AYAM.

**Aksi:**

```
nc -vz 192.168.5.5 3306
hydra -l root -P /usr/share/wordlists/rockyou.txt ssh://192.168.5.5 -t 4
sudo fail2ban-client status sshd
```

**Narasi:**

Tahap kedua diarahkan pada mekanisme autentikasi, dengan tiga perintah berbeda.

Perintah pertama menguji apakah port basis data dapat dihubungi, tanpa mengirimkan data apa pun. Hasilnya timeout, bukan refused. Refused berarti ada layanan yang menjawab dan menolak, sedangkan timeout berarti paket dibuang tanpa respons.

Perintah kedua mencoba daftar kata sandi umum terhadap layanan SSH, dengan akun root sebagai sasaran dan jumlah percobaan paralel dibatasi agar layanan tidak dibanjiri. Prosesnya terhenti pada tahap negosiasi, karena layanan hanya menerima autentikasi berbasis kunci. Tidak ada kata sandi yang benar-benar diuji, sehingga tidak ada kesimpulan mengenai kekuatan kata sandi.

Perintah ketiga dijalankan pada mesin target, bukan penyerang, dan hanya membaca keadaan mekanisme pemblokiran otomatis untuk layanan SSH. Hasilnya menunjukkan percobaan gagal berulang dicatat, lalu alamat sumbernya diblokir.

---

## SCENE 7 - SQL Injection

**Layar:** jendela penyerang.

**Aksi:**

```
curl "http://192.168.5.5:3000/sensor?device=sensor-01"
curl "http://192.168.5.5:3000/sensor?device=x%27%20OR%20%271%27%3D%271"
curl "http://192.168.5.5:3000/sensor?device=x%27%20AND%20%271%27%3D%272"
```

**Narasi:**

Tahap ketiga diarahkan pada lapisan aplikasi, dan pada tahap inilah temuan utama diperoleh.

Ketiga perintah mengirim permintaan HTTP ke dashboard lalu menampilkan responsnya di terminal. Yang membedakan ketiganya bukan alatnya, melainkan nilai yang dikirim pada parameter perangkat.

Perintah pertama meminta data perangkat yang memang terdaftar, sebagai pembanding bentuk respons normal. Hasilnya dua baris.

Perintah kedua mengirim nilai yang, setelah diterjemahkan dari bentuk terenkodenya, berisi kutip penutup diikuti klausa kondisi yang selalu bernilai benar. Kutip itu memutus batas antara perintah dan data, sehingga klausa tambahan dibaca sebagai bagian dari query. Hasilnya seluruh isi tabel terbuka.

Perintah ketiga mengirim pola yang sama, tetapi dengan kondisi yang selalu bernilai salah. Hasilnya kosong.

Hasil kosong itulah buktinya. Apabila hanya perintah kedua yang disajikan, masih terbuka kemungkinan bahwa yang terjadi adalah kesalahan penyajian. Dengan hasil nol pada perintah ketiga, yang berubah jelas logika query, bukan tampilan.

Ada kebocoran tambahan: format keluarannya masih representasi mentah bahasa pemrograman, sehingga struktur dan tipe kolom ikut terbaca.

---

## SCENE 8 - MQTT Data Injection

**Layar:** dua terminal penyerang, lalu AYAM, lalu browser.

**Aksi:**

```
mosquitto_sub -h 192.168.5.5 -t 'sensors/#' -v
mosquitto_pub -h 192.168.5.5 -t sensors/sensor-99 -m 99.90
tail -3 /var/log/iot/subscriber.log
```

**Narasi:**

Bagian kedua diarahkan pada injeksi data melalui layanan pesan, dengan tiga perintah pada dua mesin.

Perintah pertama dijalankan di terminal kiri mesin penyerang, dan berfungsi memantau seluruh pesan yang masuk ke broker pada semua topik sensor, sambil menampilkan asal setiap pesan. Perintah ini berjalan terus sampai dihentikan.

Perintah kedua dijalankan di terminal kanan, dan mengirim satu pesan ke topik perangkat yang ditentukan, dengan isi berupa satu nilai suhu. Identitas perangkat ditentukan oleh pengirim, bukan oleh perangkatnya. Pesan diterima tanpa autentikasi dan tanpa penolakan.

Perintah ketiga dijalankan pada mesin target, dan menampilkan bagian akhir log layanan penerima. Fungsinya memastikan pesan benar-benar tercatat di sisi penerima, bukan sekadar lewat di jaringan.

Hasilnya, data tersimpan dengan identitas sensor-99 dan suhu 99,9. Perangkat itu tidak pernah ada, diciptakan pada pengujian ini, namun layanan penerima memperlakukannya sebagai data valid.

Pada dashboard, data tampil di posisi teratas. Suhu normal sapi perah sekitar 38 derajat, sehingga penyiram akan aktif terus-menerus. Dashboard juga tidak memberi penanda bahwa data itu tidak sah.

Dampaknya bukan pencurian data, melainkan hilangnya integritas data. Keputusan yang diturunkan dari data yang tidak akurat akan menghasilkan tindakan yang tidak akurat.

Selanjutnya, analisis dilakukan pada Security Onion.

---

## SCENE 9 - PCAP Import

**Layar:** jendela onion.

**Aksi:**

```
tcpdump -r /tmp/pbl5-demo.pcap | wc -l
sudo so-import-pcap /tmp/pbl5-demo.pcap
```

**Narasi:**

Setelah serangan selesai, perekaman dihentikan dan hasilnya diperiksa sebelum dianalisis.

Perintah pertama membaca kembali berkas tangkapan yang telah dibuat, lalu menghitung jumlah paket di dalamnya. Apabila hasilnya nol, perekaman dinyatakan gagal.

Perintah kedua memasukkan berkas yang sama ke dalam sensor. Dua mesin analisis dijalankan terhadap berkas itu: Suricata untuk pencocokan aturan, dan Zeek untuk pembentukan catatan koneksi. Hasilnya kemudian dimasukkan ke basis data pencarian milik sensor.

Prosesnya memerlukan waktu. Konsekuensinya, analisis berlangsung setelah serangan, bukan pada saat serangan berlangsung.

---

## SCENE 10 - Detection in Kibana

**Layar:** Kibana, Discover.

**Aksi:** index pattern `logstash`, rentang 24 jam, lalu:

```
"192.168.5.100" AND "192.168.5.5"
```

**Narasi:**

Hasil analisis disajikan pada antarmuka pencarian mesin pemantau.

Langkah pertama memilih kumpulan indeks yang akan dicari, sesuai penamaan pada versi sensor yang digunakan di lab ini.

Langkah kedua menetapkan rentang waktu. Data hasil impor membawa waktu asli perekaman, bukan waktu impor, sehingga rentangnya diperlebar menjadi dua puluh empat jam. Apabila terlalu sempit, hasil pencarian akan kosong meskipun impor berhasil.

Langkah ketiga mencari dua alamat sekaligus dengan pencarian teks bebas, bukan filter berdasarkan nama kolom, karena penamaan kolom berbeda antar versi sensor. Hasilnya catatan yang memuat keduanya, yaitu koneksi antara penyerang dan target.

Data yang muncul mencakup port tujuan, jumlah byte, dan status penyelesaian. Statusnya menunjukkan koneksi selesai normal, yang berarti server memberi respons.

Ada dua batas. Pertama, karena sensor bekerja dari berkas tangkapan, selalu ada jeda antara serangan dan hasil analisis, sehingga deteksi ini tidak dapat menghentikan serangan yang sedang berlangsung. Kedua, yang terekam adalah bentuk lalu lintas, bukan isi serangan. Tidak ada aturan yang mengenali injeksi pada parameter URL, dan tidak ada yang mengenali penyisipan pesan. Kedua serangan itu tidak muncul sebagai peringatan.

---

## SCENE 11 - Mitigation

**Layar:** jendela AYAM.

**Aksi:**

```
sudo bash /tmp/purple.sh mitigasi
```

**Narasi:**

Mitigasi mencakup dua bagian yang berbeda: injeksi pada lapisan aplikasi, dan penyisipan data melalui layanan pesan. Keduanya ditangani pada satu tahap ini.

## Mitigasi SQL Injection

Mitigasi pada lapisan aplikasi memakai skrip yang sama dengan tahap pengembalian kondisi, tetapi dengan mode yang berbeda.

Skrip bekerja dalam tiga urutan: menghentikan aplikasi, mengganti berkasnya dengan versi yang diperbaiki, lalu menjalankannya kembali. Urutan ini bukan formalitas. Proses yang beroperasi menyimpan kode di memori, sehingga penggantian berkas saat aplikasi masih berjalan tidak mengubah perilakunya. Kondisi itu pernah teramati saat latihan: berkas sudah diperbarui, tetapi pengujian tetap gagal karena yang berjalan masih kode lama.

Perubahan yang dilakukan terbatas pada satu berkas, yaitu berkas aplikasi. Terdapat empat perubahan di dalamnya.

Perubahan pertama menyangkut cara aplikasi menyusun query. Pada versi lama, nilai yang dikirim pengguna disambungkan langsung ke dalam teks query memakai pemformatan string. Pada versi baru, teks query dan nilai dikirim secara terpisah sebagai dua argumen. Basis data menerima nilai itu sebagai data, sehingga tanda kutip yang dikirim pengguna tidak lagi dapat memutus batas antara perintah dan data.

Perubahan kedua menyangkut bentuk keluaran. Pada versi lama, hasil query dikembalikan apa adanya sebagai representasi objek bahasa pemrograman, sehingga nama kolom, urutan kolom, dan tipe datanya ikut terbaca. Pada versi baru, hasilnya disusun menjadi struktur data berlabel yang bentuknya tetap, sehingga informasi skema tidak lagi terbuka.

Perubahan ketiga menyangkut penyajian data pada halaman dashboard. Pada versi lama, nilai dari basis data disisipkan langsung ke dalam HTML. Pada versi baru, setiap nilai dilewatkan melalui fungsi penyandian terlebih dahulu, sehingga karakter yang berpotensi dibaca sebagai penanda HTML ditampilkan sebagai teks biasa.

Perubahan keempat menghapus satu baris pada halaman dashboard yang menampilkan contoh alamat pemanggilan endpoint sensor, karena baris tersebut memberi petunjuk langsung mengenai parameter yang dapat diuji.

Perlu ditegaskan bahwa hanya perubahan pertama yang menutup injeksi SQL. Tiga perubahan lainnya bersifat pengerasan tambahan. Perubahan pada mode pengembangan tidak memengaruhi hasil pengujian, karena mode tersebut sejak awal tidak aktif.

## Mitigasi MQTT Injection

Mitigasi pada layanan pesan tidak dapat diselesaikan dengan mengganti berkas aplikasi. Masalahnya berada pada konfigurasi broker, sehingga yang harus diubah adalah konfigurasi tersebut.

Pada kondisi rentan, broker menerima klien tanpa identitas. Siapa pun yang dapat menjangkau port 1883 dapat membaca seluruh topik sensor, dan dapat mengirim pesan yang mengaku berasal dari perangkat mana pun.

Langkah pertama adalah memeriksa isi direktori konfigurasi. Terdapat lebih dari satu berkas konfigurasi, dan broker membacanya berurutan menurut abjad. Nilai yang dibaca terakhir yang berlaku.

Di sinilah penyebab kegagalan mitigasi sebelumnya ditemukan. Berkas konfigurasi lama masih memuat akses anonim aktif, dan namanya berada setelah berkas konfigurasi baru. Akibatnya konfigurasi baru ditulis, tetapi nilai lama tetap menang. Berkas lama tersebut dipindahkan keluar dari direktori konfigurasi lebih dahulu, sebelum perubahan lain dilakukan.

Langkah kedua adalah membuat akun untuk perangkat sensor. Kata sandi akun tersebut disimpan pada berkas tersendiri, yang kepemilikannya diserahkan kepada layanan broker dan izinnya dibatasi hanya untuk pemilik dan grup. Berkas kata sandi tidak dapat dibaca oleh pengguna lain pada mesin tersebut.

Langkah ketiga adalah menulis ulang konfigurasi broker: akses anonim dimatikan, dan berkas kata sandi ditunjuk sebagai sumber autentikasi. Setelah itu layanan broker dijalankan ulang.

Langkah keempat menyangkut pihak yang justru terdampak oleh perubahan ini, yaitu layanan penerima data pada mesin target. Layanan tersebut selama ini terhubung tanpa identitas, sehingga setelah akses anonim ditutup, ia akan ikut ditolak. Karena itu layanan tersebut diberi kredensial yang sama sebelum dijalankan kembali. Ini konsekuensi yang perlu disadari: menutup akses anonim tanpa menyesuaikan klien yang sah akan menghentikan aliran data, bukan mengamankannya.

Langkah terakhir adalah verifikasi pada tiga titik. Pengiriman pesan tanpa identitas harus ditolak broker. Permintaan dashboard yang normal harus tetap berjalan. Dan berkas log layanan penerima harus menunjukkan bahwa data masih tercatat, sebagai bukti bahwa penutupan akses tidak memutus aliran data yang sah.

---

## SCENE 12 - Verification

**Layar:** jendela penyerang.

**Aksi:**

```
curl "http://192.168.5.5:3000/sensor?device=x%27%20OR%20%271%27%3D%271"
curl "http://192.168.5.5:3000/sensor?device=sensor-01"
mosquitto_pub -h 192.168.5.5 -t sensors/sensor-99 -m 99.90
```

**Narasi:**

Verifikasi memakai perintah yang identik dengan tahap sebelumnya, baik alamat, parameter, maupun payload. Tidak ada karakter yang diubah. Perbedaannya hanya satu: konfigurasi sistem telah diganti.

Perintah pertama mengirim payload yang sebelumnya membuka seluruh tabel. Hasilnya sekarang kosong.

Perintah kedua mengirim permintaan normal dengan identitas perangkat terdaftar. Hasilnya tetap dua baris, tetapi bentuknya sudah terstruktur. Perintah ini memastikan mitigasi tidak merusak fungsi aplikasi, karena penutupan celah yang membuat layanan berhenti bekerja bukanlah perbaikan.

Perintah ketiga mengirim pesan palsu dengan identitas perangkat yang tidak ada, sama seperti pada tahap serangan. Hasilnya sekarang penolakan dari broker, karena pengirim tidak menyertakan identitas yang sah.

Ketiga hasil ini menunjukkan satu hal: serangan yang sama, dengan masukan yang sama persis, tidak lagi berhasil. Karena masukannya identik, perubahan hasil hanya dapat disebabkan oleh perubahan pada sistem. Pernyataan bahwa sistem telah dimitigasi, tanpa pengujian ulang, masih berupa klaim. Dengan pengulangan serangan yang sama, hasilnya menjadi bukti.

Perlu dicatat satu hal yang tidak terlihat pada layar ini. Setelah akses anonim ditutup, layanan penerima data pada mesin target juga kehilangan hak aksesnya, sehingga ia perlu diberi kredensial sebelum dijalankan kembali. Tanpa langkah itu, penutupan akses akan menghentikan aliran data yang sah, dan sistem menjadi aman karena tidak lagi berfungsi.

---

## SCENE 13 - Closing

**Layar:** tiga jendela VM.

**Narasi:**

Kesimpulannya.

Pemetaan layanan tertutup: tersisa tiga port, dan basis data tidak terlihat dari jaringan meskipun tetap beroperasi.

Mekanisme autentikasi diperkuat: basis data hanya menerima koneksi dari dalam mesin, SSH hanya menerima autentikasi berbasis kunci, dan percobaan berulang diblokir otomatis.

Injeksi pada lapisan aplikasi tertutup, dan terbukti melalui pengulangan serangan yang identik.

Penyisipan data melalui layanan pesan juga tertutup. Akses anonim pada broker dihentikan, dan pengiriman pesan tanpa identitas kini ditolak. Pada upaya pertama, langkah ini sempat gagal karena berkas konfigurasi lama masih berlaku dan menimpa konfigurasi baru. Kegagalan itu tercatat, ditelusuri, lalu diperbaiki dengan memindahkan berkas lama tersebut sebelum konfigurasi baru diterapkan.

Satu hal yang perlu dicatat dari langkah itu: menutup akses anonim juga memutus layanan penerima data yang sah, sehingga layanan tersebut harus diberi kredensial terlebih dahulu. Mitigasi yang membuat sistem berhenti bekerja bukanlah mitigasi, melainkan gangguan. Karena itu verifikasi tidak berhenti pada penolakan terhadap penyerang, tetapi juga memastikan data yang sah masih mengalir dan tercatat.

Dengan demikian, tiga temuan pada tahap serangan telah ditangani: kebocoran data melalui parameter aplikasi, kebocoran informasi skema, dan penyisipan data melalui layanan pesan. Seluruh perubahan diverifikasi dengan pengulangan serangan yang sama, bukan dengan pernyataan bahwa konfigurasi telah diubah.

Demikian yang dapat kami sampaikan. Terima kasih.

---

# Production Notes

Rekam dua sesi. Sesi pertama Scene 1 sampai 8, sesi kedua Scene 9 sampai 13. Perekaman di mesin pemantau jangan dihentikan di antara dua sesi.

Jangan dipotong: Scene 3, 7, dan 12.

Boleh dipotong: bagian menunggu pemindaian dan menunggu analisis.
