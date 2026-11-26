# Mitigasi Purple Team, Langkah per Langkah

Dijalankan di VM AYAM sebagai pengguna `fattih`. Semua perintah dengan `sudo` berarti butuh hak administrator.

Target: 192.168.5.5. Penyerang: 192.168.5.100. Pemantau: 192.168.5.200.

---

## Sebelum mulai: rekaman jangan dihentikan

Perekaman di Onion harus sudah berjalan, dan **jangan dihentikan sampai Bagian D**.

Perintahnya di VM Onion:

```
sudo tcpdump -i eth2 -n -w /tmp/pbl5-demo.pcap -U
```

Rekaman harus hidup dari sebelum serangan, mencakup mitigasi, sampai sesudah verifikasi. Kalau dihentikan lebih awal, tahap deteksi hanya punya data serangan, tanpa data sesudah mitigasi.

Kalau sempat terhenti, nyalakan lagi sebelum melanjutkan.

---

## Bagian A - Mitigasi SQL injection

Ganti aplikasi versi rentan dengan versi aman.

### A1. Lihat PID aplikasi

```
ps -eo pid,args | grep "python3 app.py"
```

Catat angka PID di awal baris.

### A2. Matikan prosesnya

```
sudo kill PID_ITU
```

Ganti `PID_ITU` dengan angka yang dicatat.

### A3. Pastikan port 3000 sudah lepas

```
ss -tln | grep 3000
```

Kalau masih muncul, paksa berhenti:

```
sudo kill -9 PID_ITU
```

Kalau tidak ada keluaran, port sudah lepas dan boleh lanjut.

### A4. Pasang aplikasi versi aman

```
sudo cp /opt/iot-dashboard/app.py.aman /opt/iot-dashboard/app.py
```

### A5. Cek ukuran berkas

```
ls -l /opt/iot-dashboard/app.py
```

Harus 1791 byte. Kalau masih 1483, berarti penyalinan gagal.

---

## Bagian B - Mitigasi MQTT

Menutup akses anonim pada broker.

### B1. Lihat isi folder konfigurasi

```
ls /etc/mosquitto/conf.d
```

Catat nama berkas yang ada.

### B2. Pindahkan berkas lama

Berkas lama memuat `allow_anonymous true` dan dibaca paling akhir, sehingga menimpa konfigurasi baru. Ini penyebab mitigasi sebelumnya gagal.

```
sudo mv /etc/mosquitto/conf.d/pb15-awal.conf /root/pb15-awal.conf.nonaktif
```

Kalau berkasnya tidak ada, lewati langkah ini.

### B3. Bikin akun sensor

```
sudo mosquitto_passwd -c -b /etc/mosquitto/passwd sensor 'SensorPBL5!2026'
```

### B4. Ganti pemilik berkas sandi

```
sudo chown mosquitto:mosquitto /etc/mosquitto/passwd
```

### B5. Batasi izin berkas

```
sudo chmod 640 /etc/mosquitto/passwd
```

### B6. Cek hasilnya

```
ls -l /etc/mosquitto/passwd
```

Harus `-rw-r----- 1 mosquitto mosquitto`.

### B7. Tulis konfigurasi baru

Ketik manual, jangan pakai `sed`.

```
sudo nano /etc/mosquitto/conf.d/default.conf
```

Isi ketiga baris ini saja:

```
listener 1883 0.0.0.0
allow_anonymous false
password_file /etc/mosquitto/passwd
```

Simpan dengan `Ctrl+O` lalu Enter, keluar dengan `Ctrl+X`.

### B8. Restart broker

```
sudo systemctl restart mosquitto
```

### B9. Uji anonim harus ditolak

```
mosquitto_pub -h 127.0.0.1 -t uji/anonim -m 1
```

Harus keluar `Connection error: Connection Refused: not authorised.`

Kalau perintahnya diam tanpa pesan alias sukses, berarti akses anonim masih terbuka. Ulangi B1 dan B2.

### B10. Cek isi subscriber

```
sudo grep -n "connect\|mqtt" /opt/iot-dashboard/subscriber.py
```

Catat nama variabel klien yang dipakai, misalnya `client` atau `mqttc`.

### B11. Sisipkan kredensial

```
sudo nano /opt/iot-dashboard/subscriber.py
```

Tambahkan satu baris sebelum baris `.connect(`:

```
client.username_pw_set("sensor", "SensorPBL5!2026")
```

Sesuaikan nama variabel dengan hasil B10.

### B12. Matikan subscriber lama

```
ps -eo pid,args | grep "python3 subscriber.py"
```

```
sudo kill PID_ITU
```

Subscriber lama masih memakai koneksi anonim, jadi harus dijalankan ulang.

---

## Bagian C - Nyalakan dan uji

### C1. Masuk ke folder aplikasi

```
cd /opt/iot-dashboard
```

### C2. Nyalakan subscriber

```
sudo -b nohup python3 subscriber.py > /var/log/iot/subscriber.log 2>&1 &
```

### C3. Nyalakan dashboard

```
sudo -b nohup python3 app.py > /var/log/iot/dashboard.log 2>&1 &
```

### C4. Tunggu tiga detik

```
sleep 3
```

### C5. Cek dua port hidup

```
ss -tln | grep -e 3000 -e 1883
```

### C6. Uji SQL injection harus kosong

```
curl "http://192.168.5.5:3000/sensor?device=x%27%20OR%20%271%27%3D%271"
```

Harus `{"jumlah": 0, "data": []}`.

### C7. Uji permintaan normal harus tetap jalan

```
curl "http://192.168.5.5:3000/sensor?device=sensor-01"
```

Harus JSON berisi dua data sensor-01.

### C8. Uji MQTT anonim harus ditolak

Dari mesin penyerang 192.168.5.100:

```
mosquitto_pub -h 192.168.5.5 -t sensors/sensor-99 -m 99.90
```

Harus `Connection Refused: not authorised`.

### C9. Cek subscriber masih bekerja

```
tail -5 /var/log/iot/subscriber.log
```

---

## Bagian D - Hentikan rekaman

Baru dilakukan setelah C6 sampai C9 sesuai.

### D1. Hentikan perekaman

Di jendela tcpdump pada VM Onion, tekan `Ctrl+C`.

### D2. Cek berkas rekamannya

```
ls -l /tmp/pbl5-demo.pcap
```

### D3. Cek isinya ada

```
sudo tcpdump -r /tmp/pbl5-demo.pcap -c 5
```

Kalau keluar lima baris paket, rekaman berisi data dan siap diimpor.

---

## Hasil yang harus keluar

| Langkah | Hasil benar |
| --- | --- |
| A5 | `app.py` 1791 byte |
| B6 | `-rw-r----- 1 mosquitto mosquitto` |
| B9 | `Connection Refused: not authorised` |
| C5 | port 3000 dan 1883 muncul |
| C6 | `{"jumlah": 0, "data": []}` |
| C7 | JSON dua data sensor-01 |
| C8 | `Connection Refused: not authorised` |
| D3 | lima baris paket |

---

## Kalau ada yang gagal

| Gejala | Sebab | Tindakan |
| --- | --- | --- |
| A5 masih 1483 byte | berkas belum tersalin | ulangi A4, cek `/opt/iot-dashboard/app.py.aman` ada |
| A3 port 3000 masih dipakai | proses lama belum mati | `sudo kill -9 PID_ITU` |
| B9 diam tanpa pesan | `pb15-awal.conf` masih ada | ulangi B1 dan B2 |
| C6 masih mengembalikan data | aplikasi versi lama masih jalan | ulangi A1 sampai A5, lalu C3 |
| C7 error 500 | subscriber atau basis data mati | cek `/var/log/iot/dashboard.log` |
| C8 masih diterima | konfigurasi broker belum berlaku | `sudo systemctl restart mosquitto` lalu ulangi C8 |
| C9 kosong | subscriber gagal konek | lihat `/var/log/iot/subscriber.log` |
