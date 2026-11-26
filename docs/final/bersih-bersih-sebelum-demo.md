# Bersih-bersih Bekas Purple Team

Dijalankan sebelum demo, bukan saat demo. Tidak ada perintah serangan di berkas ini. Tujuannya mengembalikan ketiga VM ke kondisi baseline, supaya malam ini lu mulai dari nol.

Urutannya: Target dulu, lalu Attacker, lalu Monitoring. Matikan VM dengan urutan terbalik.

---

## 1. Target Node (AYAM)

### 1.1 Matikan proses sisa

Cek dulu apa yang masih jalan:

`ps aux | grep -e subscriber -e app.py | grep -v grep`

Kemarin ada tiga subscriber jalan bersamaan. Kalau masih ada, jangan pakai `killall`, karena `-f` tidak dikenal di image ini dan nama prosesnya `python3` sehingga `killall subscriber` juga tidak menemukan apa pun.

Ambil PID-nya dulu:

`ps -eo pid,cmd | grep subscriber | grep -v grep`

Lalu matikan satu per satu, dari PID terkecil:

`sudo kill <PID>`

Cek ulang, harus kosong:

`ps -eo pid,cmd | grep subscriber | grep -v grep`

Kalau ada yang tetap hidup, ulangi dengan `sudo kill -9 <PID>`.

Kalau Flask-nya nyala dari terminal manual, tutup terminalnya atau `Ctrl+C` di jendela itu.

### 1.2 Hapus data palsu dari tabel

`sudo mysql -u root -p`

`USE iot_db;`

`SELECT * FROM sensor_readings;`

Lihat nama kolomnya dulu, jangan menebak:

`DESCRIBE sensor_readings;`

Dari kode aplikasi, kolom identitas perangkat bernama `device_id`. Hapus baris palsu:

`DELETE FROM sensor_readings WHERE device_id='sensor-99';`

Kalau nama kolom ternyata lain, hapus lewat nilainya saja, tanpa tanda kutip:

`DELETE FROM sensor_readings WHERE suhu=99.90;`

Cek hasilnya, harus sisa empat baris id 1 sampai 4:

`SELECT * FROM sensor_readings;`

`exit`

### 1.3 Bebaskan IP penyerang

Kemarin Attacker kena ban fail2ban. Kalau dibiarkan, malam ini skenario 2 langsung ketolak sebelum sempat kelihatan.

`sudo fail2ban-client status`

`sudo fail2ban-client unban 192.168.5.100`

`sudo fail2ban-client status sshd`

Daftar banned harus kosong.

### 1.4 Kosongkan catatan login yang kotor

Ini opsional. Kalau mau alert malam ini bersih dan cuma berisi percobaan baru, kosongkan:

`sudo truncate -s 0 /var/log/auth.log`

Kalau nggak mau, lewati saja. Yang penting saat demo, lu sebut saja rentang waktunya.

### 1.5 Pastikan kondisi rentan sudah benar

Ini yang tadi sudah diset, cuma perlu dipastikan sekali lagi.

Ukuran berkas aplikasi, versi rentan 1483 byte dan versi aman 1791 byte:

`ls -l /opt/iot-dashboard/app.py /opt/iot-dashboard/app.py.aman`

Konfigurasi broker:

`sudo cat /etc/mosquitto/conf.d/default.conf`

Harus berisi `listener 1883 0.0.0.0` dan `allow_anonymous true`.

Yang pasti tidak boleh berubah: sepuluh kontrol hardening Fase 1, yaitu SSH, ufw, MySQL yang cuma di loopback, dan seterusnya. Itu bagian dari cerita demo.

### 1.6 Hapus berkas sisa

`ls -la /tmp`

`ls -la ~`

Hapus berkas buatan sendiri dari kemarin, misalnya skrip payload atau salinan konfigurasi. Jangan hapus berkas sistem.

---

## 2. Attacker Node (Cybersecurity LabVM)

1. Pastikan tidak ada proses nyangkut:

`ps aux | grep -e nmap -e hydra -e curl | grep -v grep`

2. Hapus berkas hasil kerja kemarin di folder home:

`ls -la ~`

3. Kosongkan riwayat perintah kalau mau tampilan bersih saat demo:

`history -c`

---

## 3. Monitoring (CyberOps Security Onion)

Jangan hapus index. Itu bisa merusak Kibana dan makan waktu lama.

Cukup:
1. Buka Kibana, catat waktu sekarang (WIB), jadikan penanda "sebelum demo".
2. Saat demo, filter pakai rentang waktu setelah penanda itu.
3. Ingat Kibana menampilkan UTC, selisih tujuh jam dari WIB.

---

## 4. Penutup

1. Matikan VM dengan urutan terbalik: Onion, Attacker, Target.

`"/c/Program Files/Oracle/VirtualBox/VBoxManage.exe" controlvm "CyberOps Security Onion" acpipowerbutton`

`"/c/Program Files/Oracle/VirtualBox/VBoxManage.exe" controlvm "Cybersecurity LabVM Worksation 20230210" acpipowerbutton`

`"/c/Program Files/Oracle/VirtualBox/VBoxManage.exe" controlvm "AYAM" acpipowerbutton`

2. Jangan ambil snapshot setelah bersih-bersih. Kalau suatu saat butuh balik, snapshot yang ada sekarang sudah cukup.

3. Nyalakan lagi malam ini dengan urutan Target, Attacker, Monitoring, lalu jalankan `runbook-demo-purple-team.md`.

---

## Yang tidak perlu dibersihkan

1. Sepuluh kontrol hardening Fase 1. Itu bukti kerja, bukan sampah.
2. `app.py.aman`. Itu versi aman yang dipakai di sesi mitigasi nanti.
3. Berkas bukti di laptop, yaitu tangkapan layar SS-13 sampai SS-20. Itu lampiran laporan.
4. Riwayat commit Git. Jangan disentuh.
