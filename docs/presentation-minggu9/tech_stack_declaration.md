# Deklarasi Tech Stack

Kelompok 5 - Skenario 05 Internal Database Fortress

Produk yang direplikasi pada skenario ini adalah sistem monitoring kandang ayam berbasis Internet of Things yang menggunakan ESP32 DevKit V1 sebagai mikrokontroler utama. Sistem tersebut membaca dua sensor, yaitu DHT22 untuk pengukuran suhu dan kelembapan serta DS18B20 untuk pengukuran suhu, kemudian mengirimkan data hasil pembacaan ke Firebase Realtime Database melalui protokol HTTPS REST di atas koneksi WiFi.

Dari sisi backend, proyek asli tidak memiliki server sendiri. Seluruh backend bertumpu pada layanan cloud Firebase Realtime Database paket Spark, dan penggunaannya dilakukan melalui komputer lokal. Basis data yang dipakai merupakan basis data NoSQL dengan penyimpanan berformat JSON. Antarmuka pengguna berupa dashboard web berbasis Firebase yang menampilkan data suhu dan kelembapan secara realtime dan dibuka melalui peramban pada komputer lokal.

Pada replika Target Node, arsitektur tersebut dipindahkan menjadi layanan yang berdiri sendiri. Backend dijalankan pada Ubuntu Server 26.04 LTS dengan alamat 192.168.5.5. Basis data digantikan oleh MySQL 8.4 relasional pada 127.0.0.1:3306 dengan basis data bernama iot_db, dan jalur data sensor memakai MQTT pada port 1883 dengan topik sensors/# serta HTTP REST pada endpoint dashboard. Antarmuka monitoring berupa dashboard Flask pada port 3000, sedangkan pemantauan trafik dan log dikerjakan oleh CyberOps Security Onion pada alamat 192.168.5.200.

Perbedaan tersebut disengaja. Proyek asli menumpang layanan cloud terkelola sehingga hampir tidak ada permukaan yang dapat dikonfigurasi sendiri, karena basis data, antarmuka, dan jalur datanya dipegang oleh penyedia layanan. Pemindahan ke layanan mandiri menghasilkan empat permukaan yang dapat diperiksa dan diperketat, yaitu SSH, dashboard web, broker MQTT, dan basis data relasional. Konsekuensi yang diakui adalah replika tidak memakai penyimpanan NoSQL sebagaimana aslinya, sehingga tidak menilai hal seperti aturan keamanan pada tingkat dokumen di Firebase. Yang dinilai adalah hal yang setara pada sisi server sendiri, yaitu kontrol akses akun, izin berkas, dan pembatasan alamat pendengar.

Seluruh data pada replika merupakan data dummy. Replika tidak tersambung ke sistem produksi Mitra dan tidak memuat data pelanggan.

Pembagian perangkat pada replika terdiri atas Target Node pada VM UBUNTU SYAMIL dengan alamat 192.168.5.5, mesin penyerang pada Cybersecurity LabVM dengan alamat 192.168.5.100, dan mesin pemantau pada CyberOps Security Onion dengan alamat 192.168.5.200. Seluruh perangkat berada pada jaringan pbl5-lan dengan subnet 192.168.5.0/24.
