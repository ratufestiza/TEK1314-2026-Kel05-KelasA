# Script Video Demo Purple Team

Narasi presentasi. Urutan ikut `demo-dari-awal.md`.

---

## SCENE 1 - Pembuka

**Layar:** tiga jendela VM.

**Narasi:**

Selamat malam. Saya Fattih, Kelompok 5, skenario 05, Internal Database Fortress.

Sistem kami sprinkler otomatis untuk kandang sapi perah. Sensor membaca suhu dan kelembapan, data masuk ke basis data, lalu tampil di dashboard.

Jika data sensor dipalsukan, penyiram dapat menyala pada waktu yang salah.

Tiga mesin: target 192.168.5.5, penyerang 192.168.5.100, pemantau 192.168.5.200.

Metodenya purple team. Setelah serangan, kami menyiapkan mitigasi, lalu mengulang serangan yang sama.

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

Ketiga mesin dinyalakan. Urutannya target, penyerang, pemantau.

---

## SCENE 3 - Mengembalikan kondisi target

**Layar:** jendela AYAM.

**Aksi:**

```
sudo bash /tmp/purple.sh reset
```

**Narasi:**

Sebelum pengujian, target dikembalikan ke kondisi sebelum mitigasi. Tanpa ini, serangan tidak akan berhasil.

Proses lama dihentikan lebih dahulu. Jika berkas diganti saat aplikasi masih berjalan, aplikasi tetap memakai kode di memori.

Skrip memastikan hasilnya benar-benar kondisi rentan.

---

## SCENE 4 - Titik pemantauan

**Layar:** jendela onion.

**Aksi:**

```
ip -br a
sudo tcpdump -i eth2 -n -w /tmp/pbl5-demo.pcap -U
```

**Narasi:**

Pengujian dimulai dari titik pemantauan, karena seluruh serangan harus terekam.

Antarmuka ke segmen target adalah eth2, alamat 192.168.5.200.

Rekaman dimulai sebelum serangan, karena sensor di sini menganalisis berkas tangkapan, bukan memantau kabel langsung.

Layar kosong selama proses berjalan. Hasilnya masuk ke berkas.

---

## SCENE 5 - Pemetaan layanan

**Layar:** jendela penyerang.

**Aksi:**

```
nmap -sS -sV -p- 192.168.5.5
```

**Narasi:**

Tahap pertama, pemetaan layanan.

Hasilnya tiga port: 22, 1883, dan 3000. Port 3306, basis data, tidak muncul, meskipun layanannya tetap berjalan.

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

Tahap kedua, jalur autentikasi.

Sambungan ke basis data berakhir timeout, bukan refused. Paket dibuang tanpa jawaban.

Percobaan kata sandi SSH berhenti pada negosiasi, karena layanan hanya menerima kunci. Tidak ada kata sandi yang benar-benar diuji.

Percobaan berulang dicatat dan diblokir otomatis.

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

Tiga permintaan ini menunjukkan satu hal: masukan dari URL dapat mengubah perintah ke basis data.

Permintaan normal mengembalikan dua baris. Kondisi selalu benar membuka seluruh tabel. Kondisi selalu salah menghasilkan nol.

Nol itu yang menutup perdebatan. Bukan tampilan yang berubah, tapi logika query.

Keluarannya masih format mentah, sehingga struktur kolom ikut terbaca.

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

Terminal kiri memantau pesan yang masuk, terminal kanan mengirim pesan palsu. Pesan diterima tanpa autentikasi.

Pada mesin target, data tersimpan: sensor-99 dengan suhu 99,9. Sensor itu tidak ada, kami yang membuatnya. Subscriber menerimanya sebagai data valid.

Pada dashboard, baris itu muncul di posisi teratas. Suhu normal sapi sekitar 38 derajat, sehingga penyiram akan terus menyala. Tidak ada tanda bahwa data ini palsu.

Dampaknya bukan pencurian data, melainkan hilangnya integritas data.

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

Setelah serangan selesai, perekaman dihentikan dan berkas dimasukkan ke sensor.

Prosesnya memakan waktu karena berkas dibaca ulang oleh Suricata dan Zeek.

Analisis berjalan setelah serangan.

---

## SCENE 10 - Deteksi

**Layar:** Kibana, Discover.

**Aksi:** index pattern `logstash`, rentang 24 jam, lalu:

```
"192.168.5.100" AND "192.168.5.5"
```

**Narasi:**

Hasilnya lalu lintas antara penyerang dan target: port tujuan, jumlah data, dan status koneksi.

Dua batas. Pertama, analisis berjalan setelah serangan. Kedua, yang terekam bentuk lalu lintas, bukan isi serangan. Injeksi pada parameter dan penyisipan pesan tidak dikenali.

---

## SCENE 11 - Mitigasi

**Layar:** jendela AYAM.

**Aksi:**

```
sudo bash /tmp/purple.sh mitigasi
```

**Narasi:**

Mitigasi pada lapisan aplikasi: hentikan, ganti berkas, jalankan kembali.

Harus mati dulu, karena proses yang berjalan menyimpan kode di memori.

Setelah itu, masukan dikirim sebagai nilai terpisah, keluaran menjadi format terstruktur, dan mode pengembangan dimatikan.

---

## SCENE 12 - Verifikasi

**Layar:** jendela penyerang.

**Aksi:**

```
curl "http://192.168.5.5:3000/sensor?device=x%27%20OR%20%271%27%3D%271"
curl "http://192.168.5.5:3000/sensor?device=sensor-01"
```

**Narasi:**

Serangan yang sama diulang tanpa perubahan.

Hasilnya kosong. Karena serangannya identik, perubahan hanya mungkin berasal dari aplikasi.

Permintaan normal juga diuji, untuk memastikan aplikasi tetap berfungsi.

---

## SCENE 13 - Penutup

**Layar:** tiga jendela VM.

**Narasi:**

Kesimpulannya.

Pemetaan layanan tertutup: tersisa tiga port, dan basis data tidak terlihat.

Jalur autentikasi tertutup: basis data hanya dari dalam mesin, SSH hanya kunci, percobaan berulang diblokir.

Injeksi pada aplikasi tertutup, terbukti lewat pengulangan serangan.

Penyisipan data melalui layanan pesan belum tuntas. Konfigurasi sudah disiapkan, tetapi belum terbukti berlaku penuh, jadi kami catat sebagai temuan terbuka.

Konfigurasi yang belum terbukti bukan mitigasi.

Sekian, terima kasih.

---

# Catatan Produksi

Rekam dua sesi. Sesi pertama Scene 1 sampai 8, sesi kedua Scene 9 sampai 13.

Jangan dipotong: Scene 3, 7, dan 12.
