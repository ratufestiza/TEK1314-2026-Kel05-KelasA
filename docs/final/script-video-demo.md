# Script Video Demo Purple Team

Bahasa ngomong, bukan bahasa tulis. Urutan ikut `demo-dari-awal.md`.

---

## SCENE 1 - Pembuka

**Layar:** tiga jendela VM.

**Narasi:**

Assalamualaikum warahmatullahi wabarakatuh. Perkenalkan, nama saya Fattih, dari Kelompok 5, skenario 05, Internal Database Fortress.

Jadi di sini saya mau nampilin simulasi purple team. Mulai dari serangannya, deteksi, mitigasi, sampai verifikasi di akhir.

Sistem yang kami buat ini sprinkler otomatis buat kandang sapi perah. Sensornya baca suhu sama kelembapan, datanya masuk ke database, terus muncul di dashboard.

Nah kalau data sensornya dipalsuin, penyiramnya bisa nyala di waktu yang enggak tepat. Buat ternak itu bahaya.

Makanya yang kita uji di sini jalur datanya, bukan sensornya.

Ada tiga mesin. Target di 192.168.5.5, attacker di 192.168.5.100, onion di 192.168.5.200.

Kenapa purple team? Jadi setelah kita nyerang, kita juga siapin mitigasinya, terus kita serang lagi buat buktiin mitigasinya jalan. Kalau cuma nyerang doang itu red team. Bedanya di pengulangan terakhir.

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

Target dulu, terus attacker, terakhir onion. Onion paling akhir karena bootingnya paling lama.

Kalau sudah, kita cek pakai list runningvms. Harusnya keluar tiga.

---

## SCENE 3 - Balikin target ke kondisi rentan

**Layar:** jendela AYAM.

**Aksi:**

```
sudo bash /tmp/purple.sh reset
```

**Narasi:**

Sebelum mulai, kita balikin dulu target ke kondisi sebelum mitigasi.

Ini penting. Kalau enggak dari kondisi rentan, serangannya enggak jalan, dan enggak ada yang bisa dibuktiin.

Di sini kita pakai script purple.sh reset. Jadi dia matiin proses lama, pasang aplikasi versi rentan, buka MQTT, hapus data palsu, buka blokiran fail2ban, terus nyalain lagi.

Nah yang paling penting itu matiin prosesnya dulu. Soalnya kalau file-nya diganti tapi aplikasinya masih jalan, dia tetep pakai kode lama yang udah ada di memori. Jadi file-nya udah bener, tapi kelakuannya masih rentan.

Kalau sudah, kita cek hasilnya. Harusnya 1483 byte, query normal dua baris, payload injeksi empat baris, dan tulisannya mode rentan. Kalau tulisannya mode aman, berarti gagal.

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

Jadi sebelum nyerang, kita harus mulai merekam dulu dari sini, biar serangan dari attacker ke target bisa kedetect di onion.

Pertama kita cek identitas onionnya dulu pakai ip -br a. Nah kelihatan di sini IP onion-nya 192.168.5.200, interface-nya eth2.

Terus kita masukin command buat merekam, tcpdump, pakai interface eth2, hasilnya kita simpan di /tmp/pbl5-demo.pcap.

Nah kalau sudah, layarnya bakal kosong. Itu normal, karena hasilnya masuk ke file, bukan ditampilin. Jadi kita biarin aja, jangan dihentiin, sampai semua serangannya selesai.

Ini harus dari sekarang, karena sensor di onion ini mode import. Dia enggak nonton kabel langsung, dia cuma bisa analisis file yang nanti kita import.

Kalau sudah, kita lanjut ke bagian nmap.

---

## SCENE 5 - Nmap

**Layar:** jendela attacker.

**Aksi:**

```
nmap -sS -sV -p- 192.168.5.5
```

**Narasi:**

Nah sekarang kita pindah ke attacker. Yang pertama kita scanning dulu, buat liat port apa aja yang masih kebuka di target.

Hasilnya tiga port. 22 buat SSH, 1883 buat MQTT, 3000 buat dashboard. Port 3306 MySQL enggak muncul.

Dulu sebelum hardening lima port kebuka. Jadi sekarang yang penting bukan yang muncul, tapi yang hilang.

Waktunya juga jauh lebih lama. Dulu sekitar dua puluh detik, sekarang hampir delapan ratus detik. Karena port yang enggak kepake udah ditutup, dan ufw buang paket ke port yang enggak diizinin.

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

Nah sekarang kita coba ke jalur kredensialnya.

Pertama kita tes port MySQL-nya langsung. Hasilnya timeout, bukan refused.

Bedanya apa? Kalau refused, ada yang nolak, jadi kita tau di situ ada layanan. Kalau timeout, paketnya dibuang diem-diem, jadi dari sisi kita kayak enggak ada apa-apa. Itu karena MySQL-nya cuma denger di localhost.

Terus kita coba brute force SSH. Hasilnya ditolak sebelum sempet nyoba password, karena SSH-nya cuma nerima key.

Nah karena enggak ada satu pun password yang beneran diuji, kita stop di sini. Jadi kita enggak bisa nyimpulin apa-apa soal kekuatan password-nya.

Terakhir kita cek fail2ban di target. Jadi selain SSH-nya cuma nerima key, ada juga yang nyatet percobaan gagal terus ngeblokir IP-nya.

Kalau sudah, kita lanjut ke SQL injection.

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

Nah tiga command ini gunanya buat nunjukin satu hal. Input dari URL itu bisa ngubah perintah yang dikirim ke database.

Yang pertama permintaan normal, keluar dua baris.

Yang kedua kita kasih kondisi yang selalu benar, semua isi tabel kebuka.

Yang ketiga kita kasih kondisi yang selalu salah, hasilnya kosong.

Nah kalau cuma yang kedua doang, masih bisa dibilang bug tampilan. Tapi begitu yang ketiga hasilnya nol, jelas ini logika query-nya yang berubah, bukan tampilannya.

Terus outputnya juga masih format mentah Python. Jadi struktur tabelnya ikut kebaca dari luar.

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

Nah sekarang bagian kedua. Di sini kita coba masukin data palsu lewat MQTT.

Jadi di terminal kiri kita pantau semua pesan yang masuk. Di terminal kanan kita kirim satu pesan.

Nah pesannya langsung masuk. Enggak ada password, enggak ada yang nolak.

Terus kita cek di mesin target. Datanya kesimpen, sensor-99, suhu 99.9.

Nah sensor-99 ini sebenarnya enggak ada. Kita yang ngarang. Tapi subscriber-nya percaya aja, langsung disimpen kayak data asli.

Sekarang kita buka dashboard-nya. Lihat, barisnya muncul paling atas, suhu 99.9.

Buat sapi suhu segitu enggak mungkin, normalnya sekitar 38. Jadi kalau ini dipakai beneran, penyiramnya bakal nyala terus.

Dan yang paling parah, di dashboard-nya enggak ada tanda apa-apa. Kelihatannya sama persis kayak data yang asli.

Jadi intinya, di sini bukan datanya yang dicuri, tapi datanya jadi enggak bisa dipercaya. Kalau data yang dipakai buat ambil keputusan salah, hasilnya juga salah.

Nah kalau sudah, kita balik lagi ke onion buat analisis.

---

## SCENE 9 - Stop rekam, import

**Layar:** jendela onion.

**Aksi:**

```
tcpdump -r /tmp/pbl5-demo.pcap | wc -l
sudo so-import-pcap /tmp/pbl5-demo.pcap
```

**Narasi:**

Nah sekarang kita balik ke onion. Serangannya udah selesai, jadi rekamannya kita hentiin dulu.

Terus kita cek paketnya ada berapa. Kalau nol, berarti rekamannya gagal.

Kalau aman, kita import ke sensornya. Nah ini yang makan waktu, bisa lima sampai lima belas menit. Jadi kalau layarnya diem lama, itu normal, jangan dihentiin.

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

Ini penting. Kalau rentangnya kesempitan, hasilnya kosong, padahal import-nya berhasil. Karena data import bawa waktu asli rekamannya.

Terus kita saring pakai pencarian teks biasa, "192.168.5.100" AND "192.168.5.5". Kita sengaja enggak pakai filter kolom, karena nama kolom di versi ini beda sama versi baru. Kalau salah ngetik, Kibana malah error.

Nah hasilnya keluar log Zeek. Ada port, jumlah byte, sama status koneksinya. Statusnya SF, artinya koneksinya selesai normal, servernya beneran bales.

Di sini saya juga mau jujur soal batasnya. Ada dua.

Pertama, karena sensor kami mode import, jadi ada jeda antara serangan sama hasil analisisnya.

Kedua, yang kelihatan di sini bentuk lalu lintasnya, bukan isi serangannya. SQL injection di URL enggak keliatan sebagai alert, karena enggak ada rule yang ngenalin. MQTT juga hampir enggak keliatan.

Jadi deteksi kami bagus di jaringan, lemah di aplikasi. Itu yang kami catat, bukan kami diemin.

Kalau sudah, kita lanjut ke mitigasi.

---

## SCENE 11 - Mitigasi

**Layar:** jendela AYAM.

**Aksi:**

```
sudo bash /tmp/purple.sh mitigasi
```

**Narasi:**

Nah sekarang kita masuk ke mitigasinya.

Di sini kita pakai script lagi. Isinya tiga langkah. Matiin aplikasinya dulu, timpa file-nya pakai versi aman, terus nyalain lagi.

Kenapa harus mati dulu? Karena Python nyimpen kodenya di memori. Kalau file-nya diganti pas aplikasinya masih jalan, dia tetep pakai kode lama. Jadi file-nya udah bener, tapi kelakuannya masih rentan. Itu pernah kejadian waktu kita latihan, bikin bingung.

Terus apa aja yang berubah? Ada tiga.

Pertama, query-nya enggak nyambungin string lagi, tapi pakai parameter. Jadi input kita dikirim terpisah, dibaca sebagai data, bukan perintah.

Kedua, outputnya sekarang JSON. Jadi struktur tabelnya enggak kebocor lagi.

Ketiga, debug-nya dimatiin. Jadi kalau ada error, enggak nampilin isi internal aplikasinya.

Kalau sudah, kita balik ke attacker buat verifikasi.

---

## SCENE 12 - Verifikasi

**Layar:** jendela attacker.

**Aksi:**

```
curl "http://192.168.5.5:3000/sensor?device=x%27%20OR%20%271%27%3D%271"
curl "http://192.168.5.5:3000/sensor?device=sensor-01"
```

**Narasi:**

Sekarang kita ulang serangannya. Payload-nya sama persis, enggak kita ubah.

Hasilnya nol.

Nah ini intinya purple team. Kita enggak ngubah serangannya. Yang berubah cara aplikasinya nerima input. Jadi kalau hasilnya beda, berarti mitigasinya yang ngaruh.

Kalau kita cuma bilang udah dimitigasi, itu klaim. Tapi dengan ngulang serangan yang sama dan hasilnya berubah, itu bukti.

Terus kita tes yang normal juga, buat mastiin aplikasinya masih jalan. Hasilnya dua baris, sekarang bentuknya JSON.

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

Jangan dipotong: Scene 3, 7, 12.

Boleh dipotong: bagian nunggu nmap dan nunggu import.

Kalau ada yang gagal, jangan disunting seolah berhasil. Balikin kondisi target, ulang dari Scene 7.
