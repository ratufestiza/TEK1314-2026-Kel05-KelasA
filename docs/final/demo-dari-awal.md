# Demo Purple Team, dari awal sampai akhir

Satu alur lurus. Tidak ada cabang. Ikuti nomornya.

Semua perintah di dokumen ini sudah dicocokkan dengan kondisi VM pada 26 November 2026.

---

## BAGIAN A - Tiga VM nyala

Di host Windows, urutan nyala penting. Target dulu, Onion terakhir.

`"/c/Program Files/Oracle/VirtualBox/VBoxManage.exe" startvm "AYAM" --type headless`

`"/c/Program Files/Oracle/VirtualBox/VBoxManage.exe" startvm "Cybersecurity LabVM Worksation 20230210" --type headless`

`"/c/Program Files/Oracle/VirtualBox/VBoxManage.exe" startvm "CyberOps Security Onion" --type headless`

Cek ketiganya jalan:

`"/c/Program Files/Oracle/VirtualBox/VBoxManage.exe" list runningvms`

---

## BAGIAN B - Kembalikan Target ke kondisi rentan

Satu perintah. Jalankan di VM AYAM.

`sudo bash /tmp/purple.sh reset`

Yang dilakukan skrip itu, berurutan:

1. Matikan proses `app.py` dan `subscriber.py` yang lama.
2. Pasang `app.py` versi rentan, 1483 byte.
3. Pasang `app.py.aman` versi aman, 1791 byte.
4. Tulis ulang konfigurasi MQTT supaya terbuka.
5. Hapus baris `sensor-9x` dari tabel.
6. Unban `192.168.5.100` dari fail2ban.
7. Nyalakan dashboard dan subscriber.
8. Cetak status lengkap.

Hasil yang harus keluar di akhir:

| Baris | Harus |
| --- | --- |
| `app.py` | 1483 byte |
| `app.py.aman` | 1791 byte |
| uji query normal | 2 |
| uji payload OR | `mode RENTAN`, 4 baris |
| uji tabel dashboard | `halaman / menampilkan tabel` |

Kalau baris `payload OR` tertulis `mode AMAN`, berarti berkas belum tertimpa atau proses lama masih hidup. Jalankan ulang perintahnya.

---

## BAGIAN C - Mulai merekam di Onion

Ini yang tadi terlewat, dan ini yang bikin Kibana kosong.

**Buka konsol VM Onion,** bukan SSH. SSH di Onion sedang tidak menjawab, jadi pakai jendela VirtualBox langsung.

Masuk, lalu jalankan:

`ip -br a`

Cari antarmuka yang punya alamat `192.168.5.200`. Namanya biasanya `eth2`. Pakai nama itu di perintah berikut.

`sudo tcpdump -i eth2 -n -w /tmp/pbl5-demo.pcap -U`

Biarkan terminalnya terbuka. Jangan ditutup sampai serangan selesai.

**Layarnya akan tetap kosong. Itu normal.** Opsi `-w` menulis paket ke berkas, bukan menampilkan ke layar. Jangan panik dan jangan `Ctrl+C`. Kalau mau memastikan rekamannya jalan tanpa menghentikannya, buka tab baru di Onion dengan `Ctrl+Shift+T`, lalu:

`ls -l /tmp/pbl5-demo.pcap`

Ukurannya harus bertambah. Atau periksa isinya:

`sudo tcpdump -r /tmp/pbl5-demo.pcap -c 5`

Kalau keluar lima baris paket, rekamannya jalan.

**Tes rekamannya jalan.** Dari VM Attacker:

`curl -s -m 5 "http://192.168.5.5:3000/sensor?device=sensor-01"`

Di terminal tcpdump harus muncul baris port 3000. Kalau tidak muncul, nama antarmukanya salah.

**Kenapa harus sekarang.** Sensor Onion lu berjalan di mode import bernama `seconion-import`. Dia tidak memantau kabel secara langsung. Yang dianalisis cuma berkas pcap yang diimpor. Jadi kalau tidak ada yang merekam, tidak ada yang bisa diimpor, dan Kibana tetap kosong.

---

## BAGIAN D - Skenario 1, pengintaian

Di VM Attacker.

`nmap -sS -sV -p- 192.168.5.5`

Yang diucapkan sambil menunggu: "Sebelum hardening ada lima port terbuka dan versi setiap layanan terbaca. Sekarang tinggal tiga."

Hasil yang benar: 22, 1883, 3000 terbuka. 3306 tidak muncul.

---

## BAGIAN E - Skenario 2, akses kredensial

Di VM Attacker.

`nc -vz 192.168.5.5 3306`

Tunggu sampai `timed out`. Yang diucapkan: "Timeout, bukan refused. Paketnya dibuang, jadi dari sisi penyerang layanannya tidak terlihat."

`hydra -l root -P /usr/share/wordlists/rockyou.txt ssh://192.168.5.5 -t 4`

Hentikan dengan `Ctrl+C` setelah satu menit. Yang ditunjukkan: ditolak pada negosiasi metode, karena SSH hanya menerima kunci.

Di VM AYAM, tunjukkan pembatasannya:

`sudo fail2ban-client status sshd`

---

## BAGIAN F - Skenario 3a, SQL injection

Di VM Attacker. Tiga perintah, urut.

`curl "http://192.168.5.5:3000/sensor?device=sensor-01"`

Hasil: 2 baris.

`curl "http://192.168.5.5:3000/sensor?device=x%27%20OR%20%271%27%3D%271"`

Hasil: 4 baris, seluruh tabel.

`curl "http://192.168.5.5:3000/sensor?device=x%27%20AND%20%271%27%3D%272"`

Hasil: `()`.

Yang diucapkan: "Tiga payload, tiga hasil berbeda. Ini bukti masukannya mengubah logika query, bukan cuma bug tampilan."

---

## BAGIAN G - Skenario 3b, data palsu lewat MQTT

Di VM Attacker, terminal pertama:

`mosquitto_sub -h 192.168.5.5 -t 'sensors/#' -v`

Di VM Attacker, terminal kedua:

`mosquitto_pub -h 192.168.5.5 -t sensors/sensor-99 -m 99.90`

Tanpa tanda kutip. Subscriber menolak format berkoma, jadi `99.90,0.00` akan dibuang.

Di VM AYAM, cek log subscriber:

`tail -3 /tmp/subscriber.log`

Harus ada `tersimpan: sensor-99 99.9 0.0`.

Di browser VM Attacker, buka:

`http://192.168.5.5:3000/`

Baris suhu 99.90 muncul di paling atas. Angka itu mustahil untuk peternakan sapi perah.

---

## BAGIAN H - Mitigasi

Di VM AYAM, satu perintah:

`sudo bash /tmp/purple.sh mitigasi`

Skrip itu mematikan proses dulu, baru menimpa berkas, baru menyalakan ulang. Urutan ini penting. Kalau berkas ditimpa sambil aplikasi masih jalan, Python tetap memakai kode lama di memori dan verifikasi akan gagal padahal berkasnya sudah benar.

Hasil di akhir harus `mode AMAN`.

---

## BAGIAN I - Verifikasi

Di VM Attacker, ulangi payload yang sama persis:

`curl "http://192.168.5.5:3000/sensor?device=x%27%20OR%20%271%27%3D%271"`

Hasil yang benar: JSON dengan `"jumlah": 0`.

Yang diucapkan: "Payload sama, hasil nol. Yang berubah bukan serangannya, tapi cara aplikasi memperlakukan masukan."

---

## BAGIAN J - Hentikan rekaman dan impor ke Onion

Di konsol Onion, tekan `Ctrl+C` untuk menghentikan tcpdump.

Cek jumlah paketnya:

`tcpdump -r /tmp/pbl5-demo.pcap | wc -l`

Harus ribuan, bukan nol.

Impor lewat antarmuka Security Onion. Di versi yang terpasang, masuk ke menu Hunt lalu pilih opsi impor pcap, arahkan ke `/tmp/pbl5-demo.pcap`.

Setelah impor selesai, buka Kibana di browser dalam VM Onion:

`https://localhost`

Set rentang waktu ke 1 jam terakhir. Data baru muncul setelah impor, bukan sebelumnya.

**Kalau impor tidak bisa dilakukan di tengah demo,** katakan apa adanya: "Deteksi dianalisis dari berkas tangkapan yang diimpor, bukan dari arus langsung. Untuk demo ini rekamannya sedang diproses." Jangan mengklaim Kibana menangkap langsung.

---

## BAGIAN K - Yang harus disebut di penutup

1. Skenario 1 tertutup oleh pembatasan port.
2. Skenario 2 tertutup oleh MySQL loopback, SSH kunci, dan fail2ban.
3. Skenario 3a tertutup oleh parameterized query, terbukti lewat pengulangan payload.
4. Skenario 3b dicatat sebagai temuan terbuka. Autentikasi broker sudah disiapkan tetapi belum terbukti berlaku penuh.
5. Deteksi berjalan dalam mode import, sehingga ada jeda antara serangan dan hasil analisis. Itu keterbatasan yang dicatat, bukan disembunyikan.

---

## Kalau ada yang gagal

| Gejala | Sebab | Perbaikan |
| --- | --- | --- |
| payload OR tetap 4 baris setelah mitigasi | proses lama masih hidup | `ps -eo pid,args \| grep "python3 app.py"` lalu `sudo kill <PID>` |
| `Address already in use` di log | port dipegang proses lama | sama, matikan PID-nya dulu |
| dashboard balik ke halaman sapaan | berkas lama masih jalan | `sudo bash /tmp/purple.sh reset` |
| data MQTT tidak masuk tabel | payload berkoma | publish angka polos `99.90` |
| Kibana kosong | belum ada pcap diimpor | ulangi Bagian C lalu Bagian J |
| SSH Onion tidak menjawab | sshd hang, VM kehabisan tenaga | pakai konsol VirtualBox, jangan SSH |
| `killall -f` tidak dikenal | image tidak punya opsi itu | pakai `sudo kill <PID>` |
