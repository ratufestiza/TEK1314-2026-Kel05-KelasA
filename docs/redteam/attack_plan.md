# Attack Plan Fase 2

Kelompok 5 - Skenario 05 Internal Database Fortress

- Target Node: VM UBUNTU SYAMIL, Ubuntu Server 26.04 LTS, 192.168.5.5
- Attacker: Cybersecurity LabVM, 192.168.5.100
- Monitoring: CyberOps Security Onion, 192.168.5.200
- Jaringan: pbl5-lan, 192.168.5.0/24

Semua serangan hanya ke Target Node replika. Dilarang menyentuh sistem produksi Mitra.

Titik awal pengukuran: Target Node sudah melewati hardening Fase 1, yaitu sepuluh kontrol pada `docs/blueteam/hardening_checklist.md`. Jadi serangan di bawah ini bukan lagi diukur dari mesin mentah, melainkan dari kondisi yang sudah diperketat. Yang tembus pada kondisi ini menjadi bahan mitigasi, dan yang gagal menjadi bukti kontrolnya bekerja.

## Skenario 1 - Reconnaissance

| Item | Isi |
| --- | --- |
| Kategori | Reconnaissance |
| Teknik | Pemindaian port, OS fingerprinting, enumerasi versi layanan dan banner |
| Tools | nmap, Wireshark |
| Target | 192.168.5.5 |
| Perintah | `nmap -sS -sV -O -p- 192.168.5.5` |
| Hasil yang diharapkan | Daftar port terbuka, versi MySQL, versi SSH, perkiraan sistem operasi. Kondisi sekarang hanya menyisakan port 22, 1883, dan 3000 yang bisa dijangkau dari mesin penyerang |
| Relevansi | Jadi dasar dua skenario berikutnya, dan dipakai Blue sebagai pembanding jumlah port sebelum vs sesudah hardening |
| Deteksi Blue | Alert koneksi SYN beruntun ke banyak port dari satu alamat |

## Skenario 2 - Exploitation

| Item | Isi |
| --- | --- |
| Kategori | Exploitation / Akses |
| Teknik | Percobaan kredensial default, lalu brute-force akun basis data dan akun sistem |
| Tools | Hydra, Nmap NSE (mysql-info, mysql-enum) |
| Target | MySQL pada 3306 dan SSH pada 22 di 192.168.5.5 |
| Perintah | `nmap --script mysql-info,mysql-enum -p 3306 192.168.5.5` lalu `hydra -l root -P daftar.txt 192.168.5.5 mysql` |
| Hasil yang diharapkan | Menemukan akun berkata sandi lemah, atau membuktikan bahwa kredensial default sudah dihapus dan percobaan berulang kini diblokir fail2ban |
| Relevansi | Menyasar inti skenario Internal Database Fortress, yaitu basis datanya sendiri. Port 3306 sudah dibatasi ke loopback, jadi hasil percobaan ini sekaligus menguji kontrol C1 |
| Deteksi Blue | Alert percobaan login gagal berulang di MySQL dan SSH, lalu fail2ban memblokir alamatnya |

## Skenario 3 - Web dan Protokol IoT

| Item | Isi |
| --- | --- |
| Kategori | Web/API/Protokol IoT |
| Teknik | SQL injection pada endpoint dashboard, dan penyadapan topik MQTT |
| Tools | Burp Suite atau OWASP ZAP, MQTT Explorer, mosquitto_sub dan mosquitto_pub palsu |
| Target | Endpoint dashboard pada 3000 dan broker MQTT pada 1883 di 192.168.5.5 |
| Perintah | `zap-cli quick-scan -s sqli http://192.168.5.5:3000` lalu `mosquitto_sub -h 192.168.5.5 -t '#' -v` |
| Hasil yang diharapkan | Query berhasil dimanipulasi, atau topik MQTT bisa dibaca dan dipalsukan. Kedua port ini memang masih terbuka, jadi skenario inilah yang paling mungkin menghasilkan temuan |
| Relevansi | Menyasar jalur data dari sensor ke basis data, bukan cuma pintu masuknya |
| Deteksi Blue | Alert pola query mencurigakan dan koneksi MQTT dari alamat yang tidak dikenal |

## Kesesuaian dengan ketentuan panduan

Kategori yang dipakai: Reconnaissance, Exploitation, dan Web/API/Protokol IoT. Tiga skenario, tiga kategori berbeda, dan tidak ada skenario Availability. Aturan DoS maksimal satu dari tiga terpenuhi otomatis karena tidak ada DoS sama sekali.

Tools tiap skenario disebut eksplisit sejak tahap rencana supaya Blue bisa menyiapkan deteksi yang nyambung, dan supaya kelayakan rencananya bisa dinilai sebelum eksekusi.

## Rencana tangkapan bukti

Tiap skenario disimpan di `docs/redteam/evidence/` dengan nama `skenario-1-recon/`, `skenario-2-exploit/`, dan `skenario-3-web/`. Isinya keluaran perintah dan tangkapan layar. Folder diisi bertahap mulai Minggu 10.

## Tugas Red Team

| Waktu | Tugas | Berkas yang disentuh |
| --- | --- | --- |
| Minggu 9 | Menjelaskan rencana tiga skenario di depan kelas, dan ikut mengisi kolom kiri deklarasi tech stack | `docs/presentation-minggu9/`, `docs/presentation-minggu9/tech_stack_declaration.md` |
| Minggu 10 | Eksekusi tiga skenario terhadap Target Node yang sudah di-hardening, simpan keluaran perintah dan tangkapan layar | `docs/redteam/evidence/skenario-1-recon/`, `skenario-2-exploit/`, `skenario-3-web/` |
| Minggu 10 | Mengisi tahap 1 (Serang) dan tahap 3 (Analisis) pada tiap skenario | `docs/purple-team-log.md` |
| Minggu 11 | Mengulang serangan yang sama setelah mitigasi Blue, lalu mengisi tahap 5 (Verifikasi) | `docs/purple-team-log.md` |
| Minggu 11 | Menyumbang bagian serangan pada Vulnerability Assessment Report | laporan Minggu 11 |

Batasan yang berlaku sepanjang Fase 2: serangan hanya ke Target Node replika, tidak menyentuh sistem produksi Mitra, dan trafik serangan tidak boleh keluar dari jaringan lab.
