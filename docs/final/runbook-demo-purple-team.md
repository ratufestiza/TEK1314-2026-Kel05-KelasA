# Runbook Demo Purple Team - Besok

Tujuan: mengembalikan Target Node ke kondisi rentan supaya tiga skenario bisa diperagakan ulang, tanpa menyentuh sepuluh kontrol hardening Fase 1.

Kondisi sekarang: dashboard sudah memakai versi aman, MQTT masih menerima klien anonim (gagal ditutup kemarin), data `sensor-99` sudah dihapus, IP penyerang kemungkinan masih terblokir fail2ban.

## Di mesin mana perintah ini dijalankan

Ini yang paling gampang bikin salah, jadi dibaca dulu.

| Perintah | Dijalankan di | Alamat yang dipakai |
| --- | --- | --- |
| Balikkan `app.py`, restart, cek service | VM AYAM (Target) | tanpa alamat, cukup nama service |
| Unban fail2ban | VM AYAM (Target) | tanpa alamat |
| nmap, nc, hydra, curl serangan, mosquitto_pub, mosquitto_sub | VM Cybersecurity LabVM (Attacker) | `192.168.5.5` |
| Buka Kibana, cek alert | VM CyberOps Security Onion | `192.168.5.200` |

Semua perintah uji di runbook ini dijalankan dari Attacker dan menembak `192.168.5.5`.

---

## Langkah 0 - Bersihkan disk dulu

Disk C: hanya sisa sekitar 1,6 GB. Tiga VM sekaligus akan gagal.

1. Matikan semua VM.
2. Jalankan pembersihan di host:

`~/hermes-tools/.venv/Scripts/python.exe -c "import shutil; print(shutil.disk_usage('C:/').free/2**30)"`

Angka harus di atas 15 GB sebelum lanjut. Kalau masih di bawah, hapus snapshot lama atau VM yang tidak dipakai.

---

## Langkah 1 - Nyalakan urutan yang benar

1. Nyalakan Target dulu, tunggu sampai prompt login muncul.

`"/c/Program Files/Oracle/VirtualBox/VBoxManage.exe" startvm "AYAM" --type headless`

2. Nyalakan Attacker.

`"/c/Program Files/Oracle/VirtualBox/VBoxManage.exe" startvm "Cybersecurity LabVM Worksation 20230210" --type headless`

3. Nyalakan Monitoring paling akhir, karena Security Onion paling lama siap.

`"/c/Program Files/Oracle/VirtualBox/VBoxManage.exe" startvm "CyberOps Security Onion" --type headless`

4. Cek ketiganya jalan:

`"/c/Program Files/Oracle/VirtualBox/VBoxManage.exe" list runningvms`

---

## Langkah 2 - Masuk ke Target Node

Dari Attacker Node, atau dari jendela VM Target langsung.

`ssh fattih@192.168.5.5`

Cek alamat benar:

`ip a | grep 192.168.5`

Harus muncul `inet 192.168.5.5/24`. Kalau kosong, pasang ulang alamat pada adapter `pbl5-lan`:

`sudo netplan apply`

Kalau tetap kosong, berarti berkas netplan belum memuat alamat itu. Buka dengan `sudo nano /etc/netplan/50-cloud-init.yaml`, isi alamat `192.168.5.5/24` pada antarmuka yang menuju `pbl5-lan`, simpan, lalu jalankan `sudo netplan apply` lagi.

Bukti terakhir alamat sudah benar: saat Flask menyala, outputnya menyebut `Running on http://192.168.5.5:3000`. Kalau `192.168.5.5` tidak ada di daftar itu, alamat segmen lab belum terpasang dan Attacker tidak akan bisa menyentuh port 3000.

---

## Langkah 3 - Catat keadaan sekarang sebelum diubah

Jangan lewat langkah ini. Kalau ada yang salah, ini satu-satunya jalan balik.

1. Lihat berkas aplikasi:

`ls -l /opt/iot-dashboard/`

2. Cari nama service dashboard yang sebenarnya:

`systemctl list-units --type=service | grep -i -e iot -e dash -e flask`

3. Cek service lain:

`systemctl is-active mosquitto mysql`

4. Cek subscriber berjalan berapa proses:

`ps aux | grep -i subscriber | grep -v grep`

Kemarin sempat ada tiga proses subscriber berjalan bersamaan, dan itu yang bikin baris palsu muncul tiga kali. Sekarang harus satu saja. Kalau lebih dari satu, matikan sisanya:

`killall -f subscriber`

Catatan: `pkill` tidak ada di image ini, yang tersedia `killall`. Sesudah itu jalankan satu proses subscriber lagi sesuai cara yang biasa dipakai.

---

## Langkah 4 - Balikkan aplikasi ke versi rentan

1. Simpan versi aman yang sekarang, jangan ditimpa:

`sudo cp /opt/iot-dashboard/app.py /opt/iot-dashboard/app.py.aman`

2. Cek berkas asli masih ada:

`ls -l /opt/iot-dashboard/app.py.asli`

Kalau tidak ada, cari cadangannya:

`ls -l /opt/iot-dashboard/*.bak /opt/iot-dashboard/*asli* 2>/dev/null`

3. Tukar ke versi rentan:

`sudo cp /opt/iot-dashboard/app.py.asli /opt/iot-dashboard/app.py`

4. Restart service dashboard, pakai nama yang didapat dari Langkah 3:

`sudo systemctl restart <nama-service>`

5. Pastikan hidup:

`systemctl is-active <nama-service>`

---

## Langkah 5 - Uji aplikasi sudah hidup

Jalankan di VM Attacker. Alamatnya `192.168.5.5`, titik.

1. Pembanding normal, harus mengembalikan dua baris:

`curl "http://192.168.5.5:3000/sensor?device=sensor-01"`

2. Payload OR, harus mengembalikan seluruh isi tabel:

`curl "http://192.168.5.5:3000/sensor?device=x%27%20OR%20%271%27%3D%271"`

Kalau nomor 1 gagal connect, jangan lanjut. Berarti Flask mati, atau alamat `192.168.5.5` belum terpasang di AYAM, atau ufw menahan. Periksa di AYAM dengan `ip a | grep 192.168.5`, lalu `sudo netplan apply` kalau kosong.

Kalau nomor 1 keluar dua baris tapi nomor 2 keluar array kosong, berarti yang jalan masih versi aman. Tukar ulang berkasnya di AYAM dan restart.

---

## Langkah 6 - Bebaskan IP penyerang dari fail2ban

1. Lihat status:

`sudo fail2ban-client status sshd`

2. Kalau `192.168.5.100` ada di daftar banned:

`sudo fail2ban-client set sshd unbanip 192.168.5.100`

3. Ulangi untuk jail lain kalau ada:

`sudo fail2ban-client status`

---

## Langkah 7 - Pastikan MQTT tetap rentan

Tidak perlu diubah, karena kemarin memang gagal ditutup. Cukup dibuktikan:

1. Dari Target:

`mosquitto_sub -h 192.168.5.5 -t 'sensors/#' -C 1 -W 3`

2. Dari Attacker, kirim pesan:

`mosquitto_pub -h 192.168.5.5 -t sensors/sensor-99 -m "99.9,0.0"`

Kalau pesan masuk tanpa kata sandi, jalur ini siap didemokan.

---

## Langkah 8 - Uji tiga skenario dari Attacker

**Semua di sini dijalankan di VM Cybersecurity LabVM, bukan di AYAM.** Alamat target harus `192.168.5.5`, jangan `127.0.0.1`.

1. Skenario 1, pengintaian:

`nmap -sS -sV -p- 192.168.5.5`

Yang diharapkan: tiga port terbuka, yaitu 22, 1883, dan 3000.

2. Skenario 2, kredensial:

`nc -vz 192.168.5.5 3306`

Yang diharapkan: timeout, bukan refused.

`hydra -l root -P /usr/share/wordlists/rockyou.txt ssh://192.168.5.5 -t 4`

Yang diharapkan: ditolak pada tahap negosiasi metode.

3. Skenario 3 bagian web, dua perintah, perhatikan bedanya:

`curl "http://192.168.5.5:3000/sensor?device=sensor-01"`

`curl "http://192.168.5.5:3000/sensor?device=x%27%20OR%20%271%27%3D%271"`

4. Skenario 3 bagian MQTT:

`mosquitto_sub -h 192.168.5.5 -t 'sensors/#' -v`

Biarkan terminal itu terbuka, lalu di terminal kedua:

`mosquitto_pub -h 192.168.5.5 -t sensors/sensor-99 -m "99.9,0.0"`

Yang diharapkan: pesan muncul di terminal subscriber, dan baris `sensor-99` masuk ke tabel lalu tampil di dashboard.

**Kalau `192.168.5.5` tidak menjawab sama sekali padahal Flask hidup, cek dulu di AYAM.** Saat Flask menyala, outputnya harus menyebut `Running on http://192.168.5.5:3000`. Kalau yang muncul hanya `127.0.0.1` dan `10.0.3.15`, berarti alamat segmen lab belum terpasang. Perbaikannya di AYAM: `sudo netplan apply`, lalu cek `ip a | grep 192.168.5`.

---

## Langkah 9 - Siapkan jalur balik untuk sesi mitigasi

Saat demo masuk tahap mitigasi, tukar lagi ke versi aman:

`sudo cp /opt/iot-dashboard/app.py.aman /opt/iot-dashboard/app.py`

`sudo systemctl restart <nama-service>`

Lalu ulangi payload yang sama dan tunjukkan hasilnya kosong. Inilah bukti yang diminta Tahap 5.

---

## Urutan demo besok, ringkas

| Menit | Yang dilakukan | Siapa |
| --- | --- | --- |
| 0-3 | Buka tiga VM, tunjukkan alamat dan topologi | Lead |
| 3-8 | Skenario 1, nmap penuh, tunjukkan tiga port | Red Team |
| 8-13 | Skenario 2, MySQL timeout dan Hydra ditolak | Red Team |
| 13-18 | Tunjukkan fail2ban memblokir, buka Kibana | Blue Team |
| 18-25 | Skenario 3, SQL injection bocor, MQTT disisipi data palsu | Red Team |
| 25-30 | Tunjukkan dashboard menampilkan data palsu | Red Team |
| 30-35 | Tukar aplikasi ke versi aman, restart | Blue Team |
| 35-40 | Ulangi payload, tunjukkan hasil kosong | Red Team |
| 40-45 | Rekap: yang tertutup, yang masih terbuka | Lead |

---

## Jebakan yang sudah pernah kena

1. Berkas perbaikan tidak pernah sampai ke target karena folder bersama tidak terpasang. Kalau menyalin berkas, salin langsung di dalam VM, jangan andalkan folder bersama.
2. Mosquitto memuat konfigurasi sesuai urutan abjad. Periksa nilai efektif, bukan berkas yang baru ditulis.
3. Muncul `ERROR 1142` saat menghapus data, karena `app_iot` tidak punya hak DELETE. Untuk demo, hapus pakai akun root.
4. Waktu di Kibana memakai UTC, sedangkan catatan tim memakai WIB. Selisih tujuh jam, bukan sesi berbeda.
5. Kalau MQTT tiba-tiba menolak koneksi, cek apakah ada yang memindahkan `pb15-awal.conf`. Berkas itu yang membuat konfigurasi aman tidak berlaku.
