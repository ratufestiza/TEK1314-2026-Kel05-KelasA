# Script Video Demo Purple Team

Naskah rekam. Urutan ikut `demo-dari-awal.md`.

Tiap scene: **Layar** apa yang terlihat, **Aksi** yang diketik, **Narasi** yang diucapkan.

---

## SCENE 1 - Pembuka

**Layar:** tiga jendela VM.

**Narasi:**

Selamat malam, kami Kelompok 5, skenario 05 Internal Database Fortress.

Sistem kami sprinkler otomatis buat kandang sapi perah. Sensor baca suhu dan kelembapan, datanya masuk database, terus tampil di dashboard.

Kalau data sensornya dipalsukan, penyiram bisa nyala di waktu yang salah. Buat ternak itu bahaya.

Jadi yang kami tes jalur datanya, bukan sensornya.

Tiga mesin. Target 192.168.5.5, penyerang 192.168.5.100, pemantau 192.168.5.200.

Metodenya purple team. Setelah nyerang, kami mitigasi, terus nyerang lagi buat buktiin. Kalau cuma nyerang, itu red team.

---

## SCENE 2 - Nyalakan VM

**Layar:** terminal host.

**Aksi:**

```
"/c/Program Files/Oracle/VirtualBox/VBoxManage.exe" startvm "AYAM" --type headless
"/c/Program Files/Oracle/VirtualBox/VBoxManage.exe" startvm "Cybersecurity LabVM Worksation 20230210" --type headless
"/c/Program Files/Oracle/VirtualBox/VBoxManage.exe" startvm "CyberOps Security Onion" --type headless
"/c/Program Files/Oracle/VirtualBox/VBoxManage.exe" list runningvms
```

**Narasi:**

Nyalain tiga VM, headless pakai VBoxManage. Target dulu, Onion terakhir karena bootingnya paling lama.

Cek pakai `list runningvms`, harusnya keluar tiga.

---

## SCENE 3 - Balikin ke kondisi rentan

**Layar:** jendela AYAM.

**Aksi:**

```
sudo bash /tmp/purple.sh reset
```

**Narasi:**

Target saya balikin dulu ke kondisi rentan. Kalau enggak, serangannya enggak jalan.

Enam langkah. Matiin proses lama, pasang app.py versi rentan, buka MQTT, hapus data palsu, unban fail2ban, nyalain lagi.

Yang penting matiin proses dulu. Kalau file diganti tapi prosesnya masih hidup, aplikasi tetep pakai kode lama.

Cek hasilnya. Harus 1483 byte, query normal 2 baris, payload OR 4 baris dengan tulisan mode rentan.

---

## SCENE 4 - Mulai rekam di Onion

**Layar:** jendela Onion.

**Aksi:**

```
ip -br a
sudo tcpdump -i eth2 -n -w /tmp/pbl5-demo.pcap -U
```

**Narasi:**

Pindah ke Onion, lewat jendela VirtualBox, bukan SSH.

`ip -br a` buat cari interface yang IP-nya 192.168.5.200. Hasilnya eth2.

Terus rekam. `-i` pilih interface, `-w` simpan ke file, `-U` langsung tulis ke disk.

Layarnya bakal kosong, itu normal. Paketnya masuk file, bukan ke layar.

Harus direkam sekarang, karena sensor di sini mode import. Yang dianalisis nanti cuma file yang diimport.

---

## SCENE 5 - Scanning

**Layar:** jendela Attacker.

**Aksi:**

```
nmap -sS -sV -p- 192.168.5.5
```

**Narasi:**

Masuk penyerang. `-sS` SYN scan, `-sV` deteksi versi, `-p-` semua port.

Hasilnya tiga port. 22 SSH, 1883 MQTT, 3000 dashboard. 3306 MySQL enggak muncul.

Sebelum hardening lima port kebuka. Yang penting yang hilang, bukan yang muncul.

Waktunya juga naik dari 20 detik jadi hampir 800 detik, karena port ditutup dan ufw buang paket.

---

## SCENE 6 - Kredensial

**Layar:** jendela Attacker.

**Aksi:**

```
nc -vz 192.168.5.5 3306
hydra -l root -P /usr/share/wordlists/rockyou.txt ssh://192.168.5.5 -t 4
```

**Narasi:**

Timeout, bukan refused.

Refused artinya ada yang nolak, jadi kita tau ada layanan. Timeout artinya paket dibuang diem-diem. Dari luar kayak enggak ada apa-apa. Efek MySQL cuma denger di localhost.

Terus brute force SSH. Ditolak sebelum nyoba password, karena SSH cuma nerima key.

Saya stop. Enggak ada password yang beneran diuji, jadi enggak bisa nyimpulin soal kekuatan password.

**Aksi:** di AYAM.

```
sudo fail2ban-client status sshd
```

**Narasi:**

Cek fail2ban di target. Ini lapis kedua, nyatet percobaan gagal terus ngeblokir IP-nya.

---

## SCENE 7 - SQL injection

**Layar:** jendela Attacker.

**Aksi:**

```
curl "http://192.168.5.5:3000/sensor?device=sensor-01"
curl "http://192.168.5.5:3000/sensor?device=x%27%20OR%20%271%27%3D%271"
curl "http://192.168.5.5:3000/sensor?device=x%27%20AND%20%271%27%3D%272"
```

**Narasi:**

Normal dulu. Dua baris.

Sekarang payload. `%27` itu kutip, `%20` spasi, jadi isinya `x' OR '1'='1`. Hasilnya empat baris, semua isi tabel.

Karena aplikasinya nyambungin input langsung ke query. Kutip saya nutup string, `OR '1'='1'` dibaca sebagai perintah.

Ketiga, `AND '1'='2'`. Hasilnya nol.

Dua, empat, nol. Kalau cuma OR, bisa dibilang kebetulan. Nol enggak bisa. Berarti logika query-nya yang berubah.

Satu lagi, outputnya bukan JSON tapi format mentah Python. Struktur tabelnya kebaca dari luar.

---

## SCENE 8 - Data palsu MQTT

**Layar:** dua terminal Attacker.

**Aksi:**

```
mosquitto_sub -h 192.168.5.5 -t 'sensors/#' -v
mosquitto_pub -h 192.168.5.5 -t sensors/sensor-99 -m 99.90
```

**Narasi:**

Terminal kiri mantau, terminal kanan ngirim.

Enggak ada password, langsung masuk.

**Aksi:** di AYAM.

```
tail -3 /var/log/iot/subscriber.log
```

**Narasi:**

Cek log subscriber. Tersimpan sensor-99. Perangkat itu enggak ada, saya ngarang.

**Aksi:** browser Attacker.

```
http://192.168.5.5:3000/
```

**Narasi:**

Buka dashboard. Suhu 99.9 di paling atas. Buat sapi enggak masuk akal, normalnya 38.

Dan enggak ada tanda apa-apa. Datanya kelihatan sama kayak asli.

Jadi masalahnya bukan data dicuri, tapi data udah enggak bisa dipercaya.

---

## SCENE 9 - Stop rekam, import

**Layar:** jendela Onion.

**Aksi:** `Ctrl+C`, lalu:

```
tcpdump -r /tmp/pbl5-demo.pcap | wc -l
sudo so-import-pcap /tmp/pbl5-demo.pcap
```

**Narasi:**

Rekaman stop pakai Ctrl+C. Cek jumlah paket dulu, kalau nol berarti gagal.

Impor ke sensor. Makan 5 sampai 15 menit, layarnya diem. Di belakang dia proses pakai Suricata sama Zeek, terus masuk Elasticsearch.

---

## SCENE 10 - Deteksi

**Layar:** Kibana, Discover.

**Aksi:** index pattern `logstash`, rentang 24 jam, lalu ketik:

```
"192.168.5.100" AND "192.168.5.5"
```

**Narasi:**

Discover, pilih index pattern `logstash`, rentang waktu 24 jam.

Rentangnya jangan sempit. Data import pakai waktu asli rekaman, kalau sempit hasilnya kosong padahal impornya berhasil.

Yang keluar log Zeek. Ada port, jumlah byte, status SF artinya server beneran bales.

Batasnya dua. Sensor kami mode import, jadi ada jeda. Dan yang kelihatan bentuk lalu lintasnya, bukan isi serangan. SQL injection enggak keliatan sebagai alert, MQTT juga.

Jadi deteksi bagus di jaringan, lemah di aplikasi. Itu kami catat, bukan kami diemin.

---

## SCENE 11 - Mitigasi

**Layar:** jendela AYAM.

**Aksi:**

```
sudo bash /tmp/purple.sh mitigasi
```

**Narasi:**

Tiga langkah. Matiin, timpa, nyalain.

Harus mati dulu, karena Python nyimpen kode di memori. Kalau ditimpa pas masih jalan, dia tetep pakai kode lama.

Yang berubah: query pakai parameter, output jadi JSON, debug dimatiin.

---

## SCENE 12 - Verifikasi

**Layar:** jendela Attacker.

**Aksi:**

```
curl "http://192.168.5.5:3000/sensor?device=x%27%20OR%20%271%27%3D%271"
curl "http://192.168.5.5:3000/sensor?device=sensor-01"
```

**Narasi:**

Ulang payload yang sama. Hasilnya nol.

Saya enggak ngubah serangannya. Yang berubah cara aplikasi nerima input. Itu buktinya.

Tes normal juga. Dua baris, sekarang JSON. Aplikasinya masih jalan.

---

## SCENE 13 - Penutup

**Layar:** tiga jendela VM.

**Narasi:**

Kesimpulannya.

Scanning, tertutup. Tinggal tiga port.

Kredensial, tertutup. MySQL localhost, SSH key, fail2ban.

SQL injection, tertutup, dibuktiin lewat pengulangan.

MQTT, belum selesai. Konfigurasi udah disiapin tapi belum kebukti berlaku. Kami catat sebagai temuan terbuka.

Konfigurasi yang belum kebukti itu bukan mitigasi.

Sekian, terima kasih.

---

# Catatan Produksi

Rekam dua sesi kalau mau hemat waktu. Sesi 1 Scene 1 sampai 8, berhenti saat dashboard nampilin 99.9. Sesi 2 Scene 9 sampai 13. Tapi tcpdump jangan distop di antaranya.

Jangan dipotong: Scene 3 (reset), Scene 7 (tiga payload), Scene 12 (verifikasi).

Boleh dipotong: nunggu nmap, nunggu import.

Kalau gagal, jangan disunting seolah berhasil. Reset, ulang dari Scene 7.
