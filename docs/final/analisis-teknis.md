# PCAP Import Teknis dan Naskah Narasi

Dua bagian dalam satu berkas. Bagian pertama bahan analisis, dipakai kalau ditanya dosen atau waktu menyusun laporan. Bagian kedua naskah yang dibaca waktu merekam video.

---

# BAGIAN 1 - ANALISIS TEKNIS SQL INJECTION

## 1. Perjalanan satu request, dari browser sampai MySQL

**Lapisan 1, browser.** Yang diketik:

`http://192.168.5.5:3000/sensor?device=x%27%20OR%20%271%27%3D%271`

Browser mengirim baris permintaan:

`GET /sensor?device=x%27%20OR%20%271%27%3D%271 HTTP/1.1`

Isinya masih `%27` dan `%20`, karena browser meng-encode karakter khusus supaya struktur URL tidak rusak. `%27` adalah satu byte `0x27`, yaitu tanda kutip tunggal.

**Lapisan 2, Flask.** Flask memecah query string, lalu mendekode `%27` menjadi `'`. Di sini `request.args.get("device")` menghasilkan string:

```
x' OR '1'='1
```

Sampai titik ini belum ada yang salah. Itu memang tugasnya, menerima masukan dari luar.

**Lapisan 3, aplikasi. Di sinilah keamanannya hilang.** Baris 47 versi rentan:

```python
cur.execute("SELECT * FROM sensor_readings WHERE device_id = '%s'" % dev)
```

Python mengevaluasi operator `%` lebih dulu, sebelum pymysql melihat apa pun. Hasilnya satu string:

```
SELECT * FROM sensor_readings WHERE device_id = 'x' OR '1'='1'
```

Pada detik itu, batas antara perintah dan data sudah tidak ada. Yang tersisa hanya satu potong teks.

**Lapisan 4, pymysql.** String itu dikirim ke server sebagai paket `COM_QUERY`. Isinya teks query tadi, apa adanya, tanpa metadata yang menandai bagian mana perintah dan bagian mana nilai. Protokol MySQL memang hanya punya satu tempat untuk teks query.

**Lapisan 5, MySQL.** Parser membaca dari kiri ke kanan:

```
SELECT * FROM sensor_readings WHERE device_id = 'x' OR '1'='1'
                                               └──┬──┘ └────┬────┘
                                              literal    kondisi
```

Parser menemukan literal string `'x'`, menutupnya, lalu menemukan `OR`, dan menganggap sisanya bagian sah dari klausa `WHERE`. Secara grammar itu query yang valid. Tidak ada yang error, tidak ada yang mencurigakan.

MySQL menjalankan `OR '1'='1'` yang selalu benar. Semua baris lolos filter.

---

## 2. Kenapa parser tidak curiga

Parser SQL tidak punya informasi untuk curiga. Dia tidak melihat siapa yang mengetik. Yang diterima hanya satu string. Dia tidak tahu bahwa potongan `OR '1'='1'` datang dari URL, bukan dari programmer yang menulis kode.

Bandingkan dua cara memanggil fungsi:

| Cara | Yang dikirim | Bisa dipalsukan |
| --- | --- | --- |
| Sambung string | satu teks, sudah tercampur | ya, data bisa jadi perintah |
| Kirim parameter | teks query final + nilai terpisah | tidak, nilai tidak pernah jadi perintah |

Pada cara pertama, database menerima satu saluran. Pada cara kedua, dua saluran.

Itu seluruh rahasianya. Bukan fungsi ajaib, tapi jumlah saluran.

---

## 3. Anatomi payload, per bagian

Payload `x' OR '1'='1` bukan teks acak. Tiap bagian punya tugas.

| Bagian | Fungsi |
| --- | --- |
| `x` | isi biasa, supaya query terlihat normal |
| `'` | penutup literal string, ini kuncinya |
| `OR` | operator logika, mengubah arti klausa |
| `'1'='1'` | kondisi yang selalu benar |

Kenapa harus ada `x` di depan? Tanpa itu, query menjadi `WHERE device_id = '' OR '1'='1'`, yang juga jalan. Tapi `x` membuat bentuknya mirip nama perangkat, jadi lebih mudah lolos dari filter kasar yang hanya mencari kata `OR`.

Kenapa harus ada `'1'='1'` di akhir? Tanpa itu query berakhir dengan `OR` menggantung, MySQL langsung error sintaks, dan payload yang error adalah payload yang gagal.

---

## 4. Tiga payload, tiga bukti

Demonstrasi menjadi kuat karena tidak hanya menunjukkan satu hasil aneh, tapi tiga hasil yang saling mengunci.

| Payload | Hasil | Arti |
| --- | --- | --- |
| `sensor-01` | 2 baris | perilaku normal |
| `x' OR '1'='1` | 4 baris | seluruh tabel |
| `x' AND '1'='2` | 0 baris | tabel kosong |

Kalau hanya menunjukkan yang OR, orang bisa menjawab "itu kebetulan atau bug tampilan". Begitu payload AND mengembalikan nol, argumen itu mati. Nol tidak bisa dijelaskan oleh bug tampilan, karena nol berarti logika database yang diubah, bukan halaman.

Satu parameter, tiga hasil berbeda, semuanya masuk akal secara logika SQL. Itu bukti mekanisme, bukan bukti gejala.

---

## 5. Kenapa validasi masukan bukan solusi

Percobaan pertama biasanya menambahkan filter sederhana:

```python
if "OR" in dev:
    tolak
```

Bypass-nya banyak:

| Trik | Contoh | Lolos filter `OR` |
| --- | --- | --- |
| huruf kecil | `x' or '1'='1` | ya |
| komentar | `x'/**/OR/**/'1'='1` | ya |
| operator lain | `x' || '1'='1` | ya |
| tanpa kutip | `device=1 OR 1=1` pada kolom angka | ya |
| encoding | `x%27%20OR%20%271%27%3D%271` | tergantung |
| substring | `x' O/**/R '1'='1` | ya |

Yang dikejar terus berubah. Namanya blacklist, dan blacklist selalu kalah, karena penyerang bisa mencoba ribuan variasi sementara programmer hanya bisa memikirkan beberapa.

Yang benar adalah memindahkan nilai keluar dari teks query. Bukan memeriksa isinya, tapi memastikan isinya tidak pernah bisa menjadi perintah, mau isinya apa pun.

---

## 6. Bagaimana versi aman menutupnya

Baris 54 versi aman:

```python
ambil("SELECT * FROM sensor_readings WHERE device_id = %s", (dev,))
```

Dua hal yang berubah.

**Pertama, `%s` tanpa kutip.** Versi rentan memakai `'%s'`, versi aman hanya `%s`. Ini bukan gaya penulisan, ini penanda bahwa posisi tersebut akan diisi nilai terikat, bukan ditempel sebagai teks.

**Kedua, `(dev,)` pada argumen kedua.** Nilai dikirim terpisah. Koma di dalamnya penting, itu yang membuat Python membacanya sebagai tuple satu elemen, bukan string di dalam kurung.

Lalu di dalam fungsi `ambil`, baris 23:

```python
cur.execute(sql, nilai)
```

pymysql mengambil nilai `dev` dan meng-escape karakter yang punya arti khusus di MySQL: `\0`, `\n`, `\r`, `\`, `'`, `"`, dan `\x1a`.

`x' OR '1'='1` berubah menjadi:

```
x\' OR \'1\'=\'1
```

Lalu dimasukkan ke dalam kutip yang sudah disiapkan query:

```
WHERE device_id = 'x\' OR \'1\'=\'1'
```

Semua kutip di dalam nilai sekarang menjadi `\'`, yang berarti kutip literal, bukan penutup string. MySQL membacanya sebagai permintaan mencari perangkat bernama persis `x' OR '1'='1`. Tidak ada perangkat dengan nama itu, hasilnya nol.

**Catatan teknis.** Ini client side escaping, bukan prepared statement sejati. Escaping terjadi di Python, bukan di server. Efeknya sama untuk injeksi, tapi secara arsitektur berbeda. Prepared statement sejati mengirim query dan nilai lewat dua paket protokol terpisah, dan query di-parse sekali di server tanpa nilai. Kalau ingin yang sejati, pymysql menyediakan `cursor(prepared=True)`.

Kalau ditanya, jawab jujur: parameterized query dengan escaping di sisi klien. Jangan mengklaim prepared statement.

---

## 7. Kenapa keluaran repr itu masalah terpisah

Ini bukan soal injeksi, tapi soal kebocoran. Dan kebocoran ini menaikkan tingkat serangan.

`str(rows)` menghasilkan:

```
((1, 'sensor-01', 28.5, 65.0, datetime.datetime(2026, 10, 18, 9, 0)), ...)
```

Dari situ penyerang mendapat peta:

| Posisi | Contoh isi | Tipe |
| --- | --- | --- |
| 0 | 1 | int |
| 1 | sensor-01 | str |
| 2 | 28.5 | float |
| 3 | 65.0 | float |
| 4 | 2026-10-18 09:00 | datetime |

Kenapa penting? Karena `UNION SELECT` mensyaratkan jumlah kolom yang sama. Tanpa bocoran ini, penyerang harus menebak satu per satu: satu kolom gagal, dua gagal, tiga gagal, sampai lima berhasil. Dengan bocoran, dia langsung tahu harus lima, dan tahu tipe tiap posisi supaya tidak error konversi.

Jadi kebocoran bentuk keluaran bukan sekadar kurang rapi. Itu mempersingkat kerja penyerang.

Versi aman menggantinya dengan JSON, yang hanya mengirim nama kolom dan nilai, tanpa jejak tipe Python.

---

## 8. Seberapa jauh kerusakannya

**Yang bisa:**

Membaca semua baris tabel lewat `OR`. Membaca tabel lain lewat `UNION SELECT` kalau jumlah kolom cocok dan user database punya hak ke tabel itu. Membaca struktur database lewat `information_schema.tables` dan `information_schema.columns`, yang hampir selalu bisa diakses semua user.

**Yang tidak bisa:**

Menumpuk perintah dengan titik koma. Payload `x'; DROP TABLE sensor_readings; --` ditolak, karena pymysql tidak mengaktifkan flag `MULTI_STATEMENTS`. Satu `COM_QUERY` hanya boleh satu statement.

Jadi dampaknya baca dan ubah data dalam satu query, bukan eksekusi perintah berantai.

**Yang menentukan seberapa parah:** hak akses user MySQL yang dipakai aplikasi. Kalau user itu hanya punya `SELECT` di satu tabel, kerusakan terbatas di situ. Kalau dia punya `ALL PRIVILEGES`, bisa sampai hapus data. Ini prinsip least privilege, dan alasan user aplikasi tidak boleh memakai `root` database.

---

## 9. Kenapa hardening tidak menolong

Sebelum hardening, MySQL mendengarkan di `0.0.0.0:3306` dan penyerang bisa langsung menyambung.

Setelah hardening, MySQL hanya mendengarkan di loopback. Dari luar, timeout.

Kelihatannya aman. Tapi lihat dari sudut pandang aplikasi:

```
Penyerang -> port 3000 (terbuka) -> aplikasi -> loopback -> MySQL
```

Jalurnya hanya berpindah, bukan tertutup. Aplikasi berada di dalam mesin yang sama, jadi dia boleh menyambung ke loopback. Dan aplikasi meneruskan query apa pun yang disuruh, memakai izinnya sendiri.

Ini disebut confused deputy: penyerang tidak punya izin ke database, tapi dia bisa menyuruh sesuatu yang punya izin untuk mengambilkan data.

Yang menutup jalur ini bukan firewall, bukan loopback, tapi satu baris kode. Dan itu baru terbukti kalau serangannya diulang setelah mitigasi.

---

## 10. Ringkasan satu paragraf

Aplikasi menyambung masukan pengguna ke teks query memakai `%`, sehingga batas antara perintah dan data hilang sebelum sampai ke database. MySQL menerima satu teks yang sudah tercampur, mem-parse-nya sebagai query sah, dan menjalankannya dengan izin yang dimiliki aplikasi. Menutup port 3306 hanya memindahkan jalur, karena aplikasi tetap menjadi perantara yang punya izin ke database. Perbaikannya bukan memfilter masukan, tapi mengirim nilai sebagai parameter terpisah, sehingga apa pun isinya tidak pernah bisa dibaca sebagai perintah.

---

## Tabel ringkas seluruh perubahan versi aman

| Baris | Versi rentan | Versi aman | Jenis |
| --- | --- | --- | --- |
| query `/sensor` | `'%s'` disambung dengan `%` | `%s` dengan argumen `(dev,)` | keamanan, inti |
| keluaran `/sensor` | `str(rows)` | `jsonify` | keamanan, kebocoran |
| sel tabel `/` | ditempel langsung | `html.escape` | keamanan, XSS |
