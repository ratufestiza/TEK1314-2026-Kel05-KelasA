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

**Narasi pembuka:**

Mitigasi mencakup dua bagian yang berbeda: injeksi pada lapisan aplikasi, dan penyisipan data melalui layanan pesan. Keduanya ditangani pada tahap ini, dengan perintah yang dijalankan langsung di mesin target.

### Bagian pertama, SQL Injection

**Aksi:**

```
ps -eo pid,args | grep "python3 app.py"
sudo kill 4536
sudo cp /opt/iot-dashboard/app.py.aman /opt/iot-dashboard/app.py
ls -l /opt/iot-dashboard/app.py
sudo -b nohup python3 app.py > /var/log/iot/dashboard.log 2>&1 &
```

**Narasi:**

Perintah pertama menampilkan daftar proses yang sedang berjalan dan menyaring yang relevan, untuk memperoleh nomor proses aplikasi. Nomor itu diperlukan karena penghentian harus ditujukan kepada proses tertentu, bukan kepada seluruh proses Python pada mesin.

Perintah kedua menghentikan proses tersebut. Urutannya penting: aplikasi harus berhenti sebelum berkasnya diganti, karena proses yang sedang berjalan menyimpan kode di memori. Apabila berkas ditimpa sementara aplikasi masih hidup, berkas pada disk sudah benar, tetapi perilakunya tetap perilaku kode lama. Kondisi itu pernah terjadi pada latihan sebelumnya dan membuat pengujian gagal meskipun penggantian berkas berhasil.

Perintah ketiga menyalin berkas versi aman menimpa berkas versi rentan. Hanya satu berkas yang ditimpa. Konfigurasi basis data, layanan pesan, dan mekanisme pemblokiran tidak disentuh, agar perubahan yang diuji terbatas pada satu variabel.

Perintah keempat memeriksa ukuran berkas hasil penyalinan. Ukuran versi rentan 1483 byte, sedangkan versi aman 1791 byte. Pemeriksaan ini bukan formalitas: tanpa angka pembanding, kegagalan penyalinan tidak akan terlihat, dan pengujian berikutnya akan dinilai salah.

Perintah kelima menjalankan aplikasi kembali di latar belakang, dengan keluarannya diarahkan ke berkas log. Aplikasi dijalankan terpisah dari terminal agar tetap hidup setelah sesi ditutup, dan agar terminal tetap dapat dipakai untuk perintah berikutnya.

### Bagian kedua, MQTT Injection

**Aksi:**

```
ls /etc/mosquitto/conf.d
sudo mv /etc/mosquitto/conf.d/pb15-awal.conf /root/pb15-awal.conf.nonaktif
sudo mosquitto_passwd -c -b /etc/mosquitto/passwd sensor 'SensorPBL5!2026'
sudo chown mosquitto:mosquitto /etc/mosquitto/passwd
sudo chmod 640 /etc/mosquitto/passwd
ls -l /etc/mosquitto/passwd
sudo nano /etc/mosquitto/conf.d/default.conf
sudo systemctl restart mosquitto
mosquitto_pub -h 127.0.0.1 -t uji/anonim -m 1
sudo nano /opt/iot-dashboard/subscriber.py
sudo -b nohup python3 subscriber.py > /var/log/iot/subscriber.log 2>&1 &
```

**Narasi:**

Mitigasi pada layanan pesan tidak dapat diselesaikan dengan mengganti berkas aplikasi. Masalahnya berada pada konfigurasi broker.

Perintah pertama menampilkan isi direktori konfigurasi broker. Ini langkah yang menentukan, karena broker membaca seluruh berkas dalam direktori tersebut secara berurutan menurut abjad, dan nilai yang dibaca terakhir yang berlaku. Apabila terdapat lebih dari satu berkas yang mengatur hal yang sama, berkas dengan nama terakhir yang menang.

Perintah kedua memindahkan berkas konfigurasi lama keluar dari direktori tersebut. Berkas lama itu masih memuat akses anonim aktif, dan namanya berada setelah berkas konfigurasi baru. Inilah sebab kegagalan mitigasi pada percobaan sebelumnya: konfigurasi baru sudah ditulis, tetapi nilainya kalah oleh berkas lama. Memindahkan berkas itu lebih dahulu membuat konfigurasi baru benar-benar berlaku.

Perintah ketiga membuat berkas kata sandi dan menambahkan satu akun untuk perangkat sensor. Berkas lama ditimpa, agar tidak ada akun sisa dari percobaan sebelumnya yang masih dapat dipakai.

Perintah keempat menyerahkan kepemilikan berkas kata sandi kepada akun layanan broker, karena layanan itu yang akan membacanya.

Perintah kelima membatasi izin berkas. Hanya pemilik dan grupnya yang dapat membaca. Pengguna lain pada mesin yang sama tidak dapat melihat kata sandi, sehingga akun tersebut tidak dapat dipakai hanya karena seseorang berhasil masuk ke mesin ini.

Perintah keenam memeriksa hasilnya. Izin yang benar terlihat sebagai baca dan tulis untuk pemilik, baca untuk grup, dan tidak ada akses untuk lainnya.

Perintah ketujuh membuka berkas konfigurasi broker untuk ditulis ulang. Isinya tiga baris: alamat dan port tempat broker mendengarkan, pernyataan bahwa akses anonim tidak diizinkan, dan penunjukan berkas kata sandi sebagai sumber identitas. Ketiga baris itu menggantikan pengaturan lama, sehingga klien tanpa identitas tidak lagi diterima.

Perintah kedelapan memuat ulang layanan broker. Perubahan pada berkas konfigurasi tidak berlaku sampai layanannya dijalankan ulang.

Perintah kesembilan menguji hasilnya dari dalam mesin, tanpa menyertakan identitas. Apabila broker menolak, konfigurasi telah berlaku. Pengujian dilakukan dari mesin itu sendiri lebih dahulu, supaya tidak ada faktor jaringan yang mengaburkan hasil.

Perintah kesepuluh membuka berkas layanan penerima data. Layanan itu selama ini terhubung tanpa identitas, sehingga setelah akses anonim ditutup ia akan ikut ditolak. Yang ditambahkan hanya satu baris, yaitu penyertaan identitas akun sebelum koneksi dibuka. Tanpa langkah ini, penutupan akses anonim akan menghentikan aliran data yang sah, dan sistem menjadi aman karena tidak lagi berfungsi.

Perintah kesebelas menjalankan kembali layanan penerima dengan kredensial tersebut. Layanan lama harus dimatikan lebih dahulu, karena ia masih memegang koneksi dengan identitas lama.

### Yang berubah

| Objek | Sebelum | Sesudah |
| --- | --- | --- |
| Berkas aplikasi | 1483 byte, query disusun dengan pemformatan string | 1791 byte, query dan nilai dikirim terpisah |
| Keluaran aplikasi | representasi objek, skema terbaca | struktur berlabel, skema tidak terbaca |
| Halaman dashboard | nilai disisipkan langsung ke HTML | nilai disandikan lebih dahulu |
| Petunjuk endpoint | tercantum di halaman | dihapus |
| Akses broker | anonim diterima | anonim ditolak |
| Berkas konfigurasi lama | aktif di direktori konfigurasi | dipindahkan keluar |
| Layanan penerima data | terhubung tanpa identitas | terhubung dengan kredensial |

**Narasi penutup bagian:**

Dari tabel ini terlihat bahwa hanya satu perubahan yang menutup injeksi SQL, yaitu perubahan cara query disusun. Tiga perubahan lain pada berkas aplikasi bersifat pengerasan tambahan. Pada sisi layanan pesan, yang menutup penyisipan data adalah penolakan terhadap klien tanpa identitas, sedangkan pemindahan berkas lama adalah syarat agar penolakan itu benar-benar berlaku.

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
