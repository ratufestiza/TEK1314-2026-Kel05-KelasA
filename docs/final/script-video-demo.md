# Script Video Demo Purple Team

Naskah narasi gaya presentasi, pakai "kita". Urutan ikut `demo-dari-awal.md`.

---

## SCENE 1 - Pembuka

**Layar:** tiga jendela VM.

**Narasi:**

Assalamualaikum warahmatullahi wabarakatuh. Perkenalkan nama saya Fattih, dari Kelompok 5, skenario 05, Internal Database Fortress.

Jadi di sini saya akan mempresentasikan simulasi purple team, mulai dari serangan, deteksi, mitigasi, sampai verifikasi ulang.

Sistem yang kami buat ini sprinkler otomatis buat kandang sapi perah. Sensornya baca suhu dan kelembapan, datanya masuk ke database, terus ditampilin di dashboard.

Nah kalau data sensornya dipalsuin, penyiramnya bisa nyala di waktu yang salah. Buat ternak itu bahaya.

Jadi yang kami uji di sini bukan sensornya, tapi jalur datanya.

Ada tiga mesin. Target di 192.168.5.5, attacker di 192.168.5.100, dan onion di 192.168.5.200.

Kenapa purple team? Karena setelah kita nyerang, kita juga siapin mitigasinya, terus kita serang lagi buat buktiin mitigasinya jalan. Kalau cuma nyerang doang, itu red team. Bedanya di pengulangan terakhir.

---

## SCENE 2 - Nyalakan mesin

**Layar:** terminal host.

**Aksi:**

```
"/c/Program Files/Oracle/VirtualBox/VBoxManage.exe" startvm "AYAM" --type headless
"/c/Program Files/Oracle/VirtualBox/VBoxManage.exe" startvm "Cybersecurity LabVM Worksation 20230210" --type headless
"/c/Program Files/Oracle/VirtualBox/VBoxManage.exe" startvm "CyberOps Security Onion" --type headless
"/c/Program Files/Oracle/VirtualBox/VBoxManage.exe" list runningvms
```

**Narasi:**

Baiklah, pertama-tama kita nyalain dulu ketiga mesinnya.

Urutannya target dulu, terus attacker, terakhir onion, karena onion paling lama bootingnya.

Kalau sudah, kita cek pakai list runningvms, harusnya keluar tiga.

---

## SCENE 3 - Balikin target ke kondisi rentan

**Layar:** jendela AYAM.

**Aksi:**

```
sudo bash /tmp/purple.sh reset
```

**Narasi:**

Sebelum mulai, kita balikin dulu mesin target ke kondisi sebelum mitigasi.

Ini penting. Kalau enggak dimulai dari kondisi rentan, serangannya enggak bakal jalan, dan enggak ada yang bisa dibuktiin.

Di sini kita pakai script purple.sh reset. Jadi dia bakal matiin proses lama, pasang aplikasi versi rentan, buka MQTT, hapus data palsu, buka blokiran fail2ban, terus nyalain lagi aplikasinya.

Nah yang paling penting itu matiin proses lamanya dulu. Soalnya kalau file-nya diganti tapi aplikasinya masih jalan, dia tetep pakai kode lama yang udah ada di memori. Jadi keliatan bener, tapi kelakuannya masih rentan.

Kalau sudah, kita cek hasilnya. Harusnya 1483 byte, query normal 2 baris, terus payload injeksi 4 baris dengan tulisan mode rentan. Kalau tulisannya mode aman, berarti ada yang salah.

---

## SCENE 4 - Merekam dari onion

**Layar:** jendela onion.

**Aksi:**

```
ip -br a
sudo tcpdump -i eth2 -n -w /tmp/pbl5-demo.pcap -U
```

**Narasi:**

Baiklah, sekarang kita masuk ke bagian onion dulu.

Jadi sebelum kita nyerang, kita harus mulai merekam dulu dari sini, biar nanti serangan dari attacker ke target bisa kedetect di onion.

Pertama kita cek identitas onionnya dulu, pakai ip -br a. Nah terlihat di sini IP onion itu 192.168.5.200, dan interface-nya eth2.

Setelah itu kita masuk ke command untuk merekam, yaitu tcpdump, dengan interface eth2, terus hasilnya kita simpan ke file /tmp/pbl5-demo.pcap.

Nah kalau sudah, layarnya memang bakal kosong. Itu normal, karena hasilnya masuk ke file, bukan ditampilin di layar. Jadi kita biarin aja dulu, jangan dihentikan, sampai semua serangannya selesai.

Ini harus dimulai dari sekarang, karena sensor di onion ini mode import. Jadi dia enggak nonton kabel langsung, dia cuma bisa analisis file yang nanti kita import.

Kalau sudah, kita lanjut ke bagian nmap.

---

## SCENE 5 - Nmap

**Layar:** jendela attacker.

**Aksi:**

```
nmap -sS -sV -p- 192.168.5.5
```

**Narasi:**

Sekarang kita pindah ke mesin attacker. Yang pertama kita lakuin itu scanning, buat lihat port apa aja yang masih kebuka di target.

Hasilnya tiga port. 22 untuk SSH, 1883 untuk MQTT, dan 3000 untuk dashboard. Port 3306, MySQL, enggak muncul.

Sebelum hardening dulu lima port kebuka, lengkap sama versinya. Jadi sekarang yang penting bukan yang muncul, tapi yang hilang.

Waktunya juga beda jauh. Dulu sekitar dua puluh detik, sekarang hampir delapan ratus detik. Karena port yang enggak dipakai udah ditutup, dan ufw buang paket ke port yang enggak diizinin.

Kalau sudah, kita lanjut ke bagian kredensial.

---

## SCENE 6 - Kredensial

**Layar:** jendela attacker, lalu AYAM.

**Aksi:**

```
nc -vz 192.168.5.5 3306
hydra -l root -P /usr/share/wordlists/rockyou.txt ssh://192.168.5.5 -t 4
sudo fail2ban-client status sshd
```

**Narasi:**

Sekarang kita coba ke jalur kredensialnya.

Pertama kita tes port MySQL-nya langsung. Hasilnya timeout, bukan refused.

Bedanya apa? Kalau refused, artinya ada yang nolak, jadi kita tau di situ ada layanan. Kalau timeout, paketnya dibuang diem-diem, jadi dari sisi kita kayak enggak ada apa-apa. Itu karena MySQL-nya cuma denger di localhost.

Terus kita coba brute force SSH pakai hydra. Hasilnya ditolak sebelum sempet nyoba password, karena SSH-nya cuma nerima key.

Karena enggak ada satu pun password yang beneran diuji, kita stop di sini. Jadi kita enggak bisa nyimpulin apa-apa soal kekuatan password-nya.

Terakhir kita cek fail2ban di target. Jadi selain SSH-nya cuma nerima key, ada juga yang nyatet percobaan gagal terus ngeblokir IP-nya.

Kalau sudah, kita lanjut ke bagian SQL injection.

---

## SCENE 7 - SQL injection

**Layar:** jendela attacker.

**Aksi:**

```
curl "http://192.168.5.5:3000/sensor?device=sensor-01"
curl "http://192.168.5.5:3000/sensor?device=x%27%20OR%20%271%27%3D%271"
curl "http://192.168.5.5:3000/sensor?device=x%27%20AND%20%271%27%3D%272"
```

**Narasi:**

Nah tiga command ini gunanya buat nunjukin satu hal: input dari URL bisa ngubah perintah yang dikirim ke database.

Yang pertama, permintaan normal, keluar dua baris.

Yang kedua kita kasih kondisi yang selalu benar, semua isi tabel kebuka.

Yang ketiga kita kasih kondisi yang selalu salah, hasilnya kosong.

Kalau cuma yang kedua doang, masih bisa dibilang bug tampilan. Tapi begitu yang ketiga hasilnya nol, jelas ini logika query-nya yang berubah, bukan tampilannya.

Dan karena outputnya masih format mentah Python, struktur tabelnya juga ikut kebaca dari luar.

Kalau sudah, kita lanjut ke bagian MQTT.

---

## SCENE 8 - Data palsu lewat MQTT

**Layar:** dua terminal attacker, lalu AYAM, lalu browser.

**Aksi:**

```
mosquitto_sub -h 192.168.5.5 -t 'sensors/#' -v
mosquitto_pub -h 192.168.5.5 -t sensors/sensor-99 -m 99.90
tail -3 /var/log/iot/subscriber.log
```

**Narasi:**

Sekarang bagian kedua, bukan nyuri data, tapi ngerusak kepercayaan ke datanya.

Di terminal kiri kita mantau, di terminal kanan kita kirim pesan. Enggak ada password, enggak ada penolakan, langsung masuk.

Terus kita cek di mesin target. Datanya tersimpan, sensor-99 dengan suhu 99.9.

Sensor-99 itu enggak ada. Kita ngarang namanya. Tapi subscriber percaya aja, langsung disimpen kayak data beneran.

Coba kita buka dashboard-nya. Ada baris baru di paling atas, suhu 99.9. Buat sapi itu enggak masuk akal, suhu normalnya sekitar 38. Kalau sistem ini dipakai beneran, penyiramnya bakal nyala terus.

Dan yang paling bahaya, di dashboard enggak ada tanda apa-apa. Datanya kelihatan sama persis kayak data asli.

Jadi masalahnya bukan datanya dicuri, tapi datanya udah enggak bisa dipercaya. Sistem yang ngambil keputusan dari data salah bisa lebih bahaya daripada sistem yang mati.

Kalau sudah, kita balik lagi ke onion buat analisis.

---

## SCENE 9 - Stop rekam, import

**Layar:** jendela onion.

**Aksi:**

```
tcpdump -r /tmp/pbl5-demo.pcap | wc -l
sudo so-import-pcap /tmp/pbl5-demo.pcap
```

**Narasi:**

Sekarang kita balik ke onion. Serangannya udah selesai, jadi rekamannya kita hentikan dulu.

Terus kita cek paketnya ada berapa. Kalau nol, berarti rekamannya gagal.

Kalau sudah, kita import ke sensornya. Ini yang makan waktu, bisa lima sampai lima belas menit. Jadi kalau layarnya diem lama, itu normal, jangan dihentikan.

Di belakang dia mecah file-nya, baca ulang pakai Suricata sama Zeek, terus masukin hasilnya ke Elasticsearch.

Kalau sudah selesai, kita buka Kibana.

---

## SCENE 10 - Deteksi di onion

**Layar:** Kibana, Discover.

**Aksi:** index pattern `logstash`, rentang 24 jam, lalu:

```
"192.168.5.100" AND "192.168.5.5"
```

**Narasi:**

Di Kibana kita masuk ke Discover, pilih index pattern yang ada tulisan logstash-nya, terus rentang waktunya kita lebarkan ke dua puluh empat jam terakhir.

Ini penting. Kalau rentangnya kesempitan, hasilnya kosong, padahal import-nya berhasil. Soalnya data import bawa waktu asli rekamannya, bukan waktu kita import.

Terus kita saring pakai pencarian teks biasa, "192.168.5.100" AND "192.168.5.5". Kita sengaja enggak pakai filter kolom, karena nama kolom di versi ini beda sama versi baru. Kalau salah ngetik, Kibana malah error.

Hasilnya keluar log Zeek. Ada port, jumlah byte, sama status koneksinya. Statusnya SF, artinya koneksinya selesai normal, servernya beneran bales.

Nah di sini saya juga mau jujur soal batasnya. Ada dua.

Pertama, karena sensor kami mode import, jadi ada jeda antara serangan sama hasil analisisnya.

Kedua, yang kelihatan di sini bentuk lalu lintasnya, bukan isi serangannya. SQL injection di URL enggak keliatan sebagai alert, karena enggak ada rule yang ngenalin. MQTT juga hampir enggak keliatan.

Jadi deteksi kami bagus di lapisan jaringan, tapi lemah di lapisan aplikasi. Itu yang kami catat sebagai kekurangan, bukan kami diemin.

Kalau sudah, kita lanjut ke mitigasi.

---

## SCENE 11 - Mitigasi

**Layar:** jendela AYAM.

**Aksi:**

```
sudo bash /tmp/purple.sh mitigasi
```

**Narasi:**

Sekarang kita masuk ke mitigasinya.

Di sini kita pakai script lagi, isinya tiga langkah. Matiin aplikasinya dulu, timpa file-nya pakai versi aman, terus nyalain lagi.

Kenapa harus mati dulu? Karena Python nyimpen kodenya di memori. Kalau file-nya diganti pas aplikasinya masih jalan, dia tetep pakai kode lama. Jadi file-nya udah bener, tapi kelakuannya masih rentan. Itu pernah kejadian waktu kita latihan, dan bikin bingung soalnya hasil tesnya gagal padahal file-nya udah diganti.

Terus apa aja yang berubah di versi aman? Ada tiga.

Pertama, query-nya enggak nyambungin string lagi, tapi pakai parameter. Jadi input kita dikirim terpisah, dibaca sebagai data, bukan sebagai perintah.

Kedua, outputnya sekarang JSON, jadi struktur tabelnya enggak kebocor lagi.

Ketiga, debug-nya dimatiin, jadi kalau ada error enggak nampilin isi internal aplikasinya.

Kalau sudah, kita balik lagi ke attacker buat verifikasi.

---

## SCENE 12 - Verifikasi

**Layar:** jendela attacker.

**Aksi:**

```
curl "http://192.168.5.5:3000/sensor?device=x%27%20OR%20%271%27%3D%271"
curl "http://192.168.5.5:3000/sensor?device=sensor-01"
```

**Narasi:**

Sekarang kita ulang serangannya. Payload-nya sama persis, enggak kita ubah sedikit pun.

Hasilnya nol.

Nah ini intinya purple team. Kita enggak ngubah serangannya. Yang berubah cara aplikasinya nerima input. Jadi kalau hasilnya beda, berarti mitigasinya yang ngaruh.

Kalau kita cuma bilang udah dimitigasi, itu klaim. Tapi dengan ngulang serangan yang sama dan nunjukin hasilnya berubah, itu bukti.

Terus kita tes yang normal juga, buat mastiin aplikasinya masih jalan dan enggak rusak gara-gara mitigasi. Hasilnya dua baris, sekarang bentuknya JSON.

Kalau sudah, kita masuk ke penutup.

---

## SCENE 13 - Penutup

**Layar:** tiga jendela VM.

**Narasi:**

Jadi kesimpulannya.

Scanning, tertutup. Tinggal tiga port, MySQL enggak keliatan dari jaringan.

Kredensial, tertutup. MySQL cuma localhost, SSH cuma nerima key, fail2ban ngeblokir percobaan berulang.

SQL injection, tertutup, dan udah kita buktiin dengan ngulang payload yang sama.

Yang MQTT, belum selesai. Konfigurasinya udah disiapin, tapi belum kita pastiin berlaku penuh. Jadi kita catat sebagai temuan terbuka.

Kita sengaja enggak bilang selesai, karena konfigurasi yang belum kebukti itu bukan mitigasi.

Sekian dari kami, terima kasih.

---

# Catatan Produksi

Kalau mau hemat waktu, rekam dua sesi. Sesi pertama Scene 1 sampai 8, berhenti pas dashboard nampilin data palsu. Sesi kedua Scene 9 sampai 13. Tapi perekaman di onion jangan dihentikan di antara dua sesi.

Jangan dipotong: Scene 3, Scene 7, Scene 12.

Boleh dipotong: bagian nunggu nmap dan nunggu import.

Kalau ada yang gagal, jangan disunting seolah berhasil. Balikin kondisi target, ulang dari Scene 7.
