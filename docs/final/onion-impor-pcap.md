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

**Langkah 4, jangan pakai filter kalau belum yakin nama field-nya.** Di SecOnion 16.04, nama field yang benar-benar ada di log Zeek adalah `id.orig_h`, `id.resp_h`, `destination_ips`, `virtual_host`. Tidak ada `source_ip` dan tidak ada `destination_ip`. Mengetik nama yang tidak ada akan memunculkan error, bukan hasil kosong.

**Langkah 5, saring lewat search bar, bukan lewat tombol filter.** Ini cara yang paling tahan versi dan sudah terbukti:

`"192.168.5.100" AND "192.168.5.5"`

Tanda kutip penting supaya dibaca sebagai frasa, bukan dipecah per bagian.

Kalau mau memakai nama field, pakai yang benar:

`id.orig_h:"192.168.5.100" AND id.resp_h:"192.168.5.5"`

Kalau cara itu masih error, berarti field-nya bertipe analyzed, dan Kibana 6 tidak mengizinkan filter di field seperti itu. Balik ke pencarian teks bebas.

Yang muncul: log Zeek `conn`, `http`, dan `files` dari Attacker ke Target, dengan `conn_state: SF` dan `resp_bytes` yang menandakan ada balasan dari server.

**Pola indeks** yang benar untuk versi ini `*:logstash-*`, pakai titik dua. Itu yang muncul di daftar pola indeks, bukan `logstash` saja.

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

## Kalau Kibana menampilkan SearchError: unknown error

Ini bukan masalah pcap dan bukan masalah impor. Ini Kibana yang tidak bisa menghubungi Elasticsearch.

Tandanya: muncul spanduk merah `Discover: unknown error`, di bawahnya `SearchError: unknown error`, jumlah hit nol, dan di kiri bawah tertulis `Searching 0/1`.

Urutan penanganannya di konsol Onion:

`sudo so-status`

Cari baris `elasticsearch`. Kalau `stopped`:

`sudo so-elasticsearch-start`

Tunggu dua menit, lalu tes:

`curl -s localhost:9200/_cat/indices?v | head`

Kalau keluar daftar indeks, Elasticsearch hidup. Kalau `Connection refused`, dia masih mati dan impor tidak ada gunanya.

Kalau Elasticsearch hidup tapi Kibana tetap error:

`sudo so-kibana-restart`

Baru setelah Kibana bisa membuka Discover, jalankan impor.

---

## Versi yang dipakai di lab ini

Security Onion di lab ini versi lama, 16.04. Perbedaannya berpengaruh ke dua hal:

| Hal | Versi ini | Versi baru |
| --- | --- | --- |
| Pola indeks | `*:logstash-*` | `logs-*` |
| Nama field IP | `id.orig_h`, `id.resp_h`, `destination_ips` | `source.ip`, `destination.ip` |

Jadi jangan mengetik `source_ip` atau `source.ip` di versi ini, field itu tidak ada dan akan memunculkan error. Pakai pencarian teks bebas dengan tanda kutip:

`"192.168.5.100" AND "192.168.5.5"`

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
8. Saring `"192.168.5.100" AND "192.168.5.5"` di search bar.
