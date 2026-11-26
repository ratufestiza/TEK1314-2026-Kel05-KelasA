# Impor pcap ke Security Onion, langkah demi langkah

Dipakai setelah rekaman selesai. Tanpa langkah ini, Kibana tetap kosong walaupun tcpdump sudah merekam ribuan paket.

---

## Kenapa harus diimpor

Sensor di lab ini berjalan dalam mode import dengan nama `seconion-import`. Dia tidak memantau kabel secara langsung. Yang dianalisis hanya berkas tangkapan yang dimasukkan ke sensor.

Nama `seconion-import` itu bukan nama karangan. Itu nama yang muncul di laporan proyek kalian sendiri, dan nama itu hanya keluar kalau sensor dijalankan lewat alat impor. Artinya jalur yang dipakai memang jalur impor, bukan jalur pemantauan langsung.

Konsekuensinya: merekam saja tidak cukup, dan menunggu juga tidak mengubah apa pun. Harus ada langkah impor.

---

## Sebelum mulai

Kerjakan semuanya di dalam VM Onion, lewat jendela VirtualBox langsung. SSH ke Onion sedang tidak menjawab, jadi jangan buang waktu mencoba masuk lewat jaringan.

Pastikan tiga hal ini dulu.

**1. Rekaman sudah dihentikan.** Kalau tcpdump masih jalan, tekan `Ctrl+C` dulu. Mengimpor berkas yang masih ditulis menghasilkan pcap rusak atau terpotong.

**2. Berkasnya ada dan tidak kosong.**

`ls -l /tmp/pbl5-demo.pcap`

Ukurannya harus ratusan kilobyte ke atas. Kalau nol byte, rekamannya memang gagal dan tidak ada gunanya diimpor.

**3. Isinya benar.**

`tcpdump -r /tmp/pbl5-demo.pcap -c 5`

Harus keluar lima baris paket. Kalau keluar `No such file`, nama berkasnya beda, cek dengan `ls /tmp/*.pcap`.

Catat nama berkas persisnya. Sering salah ketik waktu mengetik tangan, misalnya `pbls-demo.pcap` bukan `pbl5-demo.pcap`. Yang penting konsisten antara perintah rekam dan perintah impor.

---

## Cara utama, lewat perintah

Ini cara yang paling bisa diandalkan, karena tidak bergantung pada versi antarmuka.

**Langkah 1, cek alatnya ada.**

`which so-import-pcap`

Kalau keluar path seperti `/usr/sbin/so-import-pcap`, lanjut. Kalau kosong, lihat bagian cara alternatif di bawah.

**Langkah 2, lihat bantuannya sekali.**

`sudo so-import-pcap --help`

Tujuannya memastikan bentuk argumennya sesuai versi yang terpasang. Cukup dibaca, tidak perlu dihapal.

**Langkah 3, jalankan impor.**

`sudo so-import-pcap /tmp/pbl5-demo.pcap`

Tulis path lengkapnya, jangan hanya nama berkas.

**Langkah 4, tunggu.** Ini bagian yang paling sering bikin panik.

Prosesnya bisa lima sampai lima belas menit untuk rekaman beberapa ribu paket. Layarnya akan diam lama. Itu normal. Jangan `Ctrl+C`, jangan tutup jendela, jangan buka Kibana dulu.

Yang terjadi di belakang: berkas dipecah, dibaca ulang oleh Suricata dan Zeek, lalu hasilnya dimasukkan ke Elasticsearch. Tiga pekerjaan berat, satu per satu.

**Langkah 5, tunggu sampai selesai.**

Kalau muncul pesan yang menyebut selesai, impor berhasil. Kalau muncul pesan error, catat kalimat terakhirnya, jangan diketik ulang dari ingatan.

**Langkah 6, kalau disuruh berhenti.**

Beberapa versi meminta impor dihentikan manual setelah selesai:

`sudo so-import-stop`

Kalau perintah itu tidak ada, tidak masalah, lewati.

---

## Cara alternatif, lewat antarmuka

Pakai ini kalau `so-import-pcap` tidak ada di image.

Buka browser di dalam VM Onion, ke `https://localhost`.

Masuk ke menu **Hunt**. Cari halaman yang berhubungan dengan PCAP. Di Security Onion 2.x namanya bisa **PCAP** atau **Import**, tergantung versi. Yang dicari adalah formulir yang meminta path berkas pcap di sisi server.

Isi path-nya, misalnya `/tmp/pbl5-demo.pcap`, lalu jalankan.

Kalau tidak menemukan menunya, jangan mengarang langkah. Cek dulu versinya:

`sudo so-version`

Lalu sesuaikan sendiri nama menunya, karena penamaan berubah antar versi.

---

## Setelah impor, buka Kibana

Browser di dalam VM Onion, bukan dari Attacker.

`https://localhost`

**Langkah 1, buka Discover.** Menu paling atas, ikon kompas.

**Langkah 2, pilih indeks.** Di laporan kalian indeksnya bernama `logstash`. Cari pola indeks yang memuat kata itu. Kalau kosong, pilih pola yang tersedia, biasanya ada yang mencakup `so-` atau tanggal.

**Langkah 3, set rentang waktu.** Jangan pakai "Last 15 minutes", karena data impor masuk dengan cap waktu aslinya, bukan waktu impor. Pilih **Last 7 days** atau atur manual ke tanggal rekaman.

Ini penyebab paling sering kenapa Kibana terlihat kosong padahal impornya berhasil: rentang waktunya terlalu sempit.

**Langkah 4, tambahkan kolom.** Di daftar kolom sebelah kiri, tambahkan `source.ip` dan `destination.ip`. Kalau nama kolomnya berbeda, cari yang memuat `ip`.

**Langkah 5, saring.** Ketik di kotak pencarian:

`source.ip : "192.168.5.100" and destination.ip : "192.168.5.5"`

Yang akan muncul: lalu lintas dari Attacker ke Target.

---

## Cara membaca hasilnya dengan jujur

Yang terekam sensor adalah **pola jaringan**, bukan isi serangan. Ini penting disampaikan, jangan sampai kesannya lebih hebat dari kenyataan.

| Yang dilakukan | Yang muncul di Kibana |
| --- | --- |
| nmap seluruh port | banyak koneksi berulang ke port berbeda, plus ICMP |
| nc ke port tertutup | percobaan koneksi yang tidak berlanjut |
| hydra ke SSH | percobaan koneksi berulang ke port 22 |
| SQL injection lewat curl | permintaan HTTP biasa, tanpa alert khusus |
| publish MQTT | hampir tidak terlihat, protokolnya tidak dipahami sensor |

Kalimat yang dipakai: "Yang terekam adalah bentuk lalu lintasnya. Untuk serangan lapisan aplikasi tidak ada aturan yang mengenalinya, jadi tidak muncul sebagai alert. Itu kesenjangan yang kami catat."

Jangan mengklaim sensor mendeteksi SQL injection. Tidak ada aturannya di lab ini, dan penonton yang paham akan langsung bertanya.

---

## Selisih waktu

Kibana memakai UTC, catatan tim memakai WIB. Selisih tujuh jam. Kejadian jam 20.00 WIB akan muncul sebagai 13.00 di Kibana. Jangan dikira sesi berbeda.

---

## Kalau tetap kosong setelah impor

Periksa berurutan, jangan lompat.

| Gejala | Sebab | Perbaikan |
| --- | --- | --- |
| Kibana kosong, impor terlihat selesai | rentang waktu terlalu sempit | set Last 7 days atau tanggal manual |
| Kibana kosong, impor tidak pernah selesai | proses masih jalan atau mati di tengah | jalankan ulang, tunggu lebih lama |
| `so-import-pcap: command not found` | image tidak menyertakan alat itu | pakai jalur antarmuka, cek `sudo so-version` |
| berkas nol byte | tcpdump mati sebelum merekam | ulangi rekaman, cek `ls -l` sebelum impor |
| data muncul tapi tidak ada yang cocok | filter IP salah | kosongkan filter, lihat semua, baru saring |
| nama sensor bukan `seconion-import` | sensor jalan mode langsung | berarti impor tidak dipakai, cek ulang perintahnya |

---

## Versi pendek untuk ditempel di catatan

1. `Ctrl+C` di terminal tcpdump.
2. `ls -l /tmp/pbl5-demo.pcap` harus besar.
3. `tcpdump -r /tmp/pbl5-demo.pcap -c 5` harus keluar paket.
4. `sudo so-import-pcap /tmp/pbl5-demo.pcap`
5. Tunggu sampai selesai, jangan dihentikan.
6. Buka `https://localhost` di browser Onion.
7. Discover, pilih pola indeks yang memuat `logstash`, set Last 7 days.
8. Saring `source.ip : "192.168.5.100"`.
