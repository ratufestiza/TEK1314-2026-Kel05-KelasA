# Logbook Proyek PBL Keamanan Siber - Kelompok 5

Skenario: 05 Internal Database Fortress
Mata kuliah: TEK1314 Keamanan Siber, Kelas A
Anggota: Fattih Algie Maulana (J0404241002), Syamil Abdillah (J0404241139), Ratu Festiza Alya Ichsan (J0404241174), Al Fariz Muhammad Zibril (J0404241036)

Logbook ini mencatat progres per pekan beserta artefaknya. Tanggal mengikuti pekan kuliah, sesuaikan kalau tanggal aslinya bergeser.

## Ringkasan checkpoint

| Checkpoint | Pekan | Kriteria lulus | Status |
| --- | --- | --- | --- |
| Proof of Concept | 3 | VM Target bisa di-ping dari VM Attacker | Lulus |
| Logging Check | 5 | Security Onion bisa merekam ping dan trafik | Lulus |
| Hardening Review | 7 | Sistem sudah diamankan sebelum diserang | Lulus |
| Checkpoint Fase 2 | 9 | Rencana serangan dan deklarasi tech stack siap | Lulus, dibahas di Pertemuan 9 |
| Siklus Purple Team | 11 | Serangan, deteksi, mitigasi, verifikasi tercatat | Lulus, MQTT tuntas pada tindak lanjut |
| Final | 13 | Incident report, video, slide, repositori | Laporan dan slide selesai, video menyusul |

## Minggu 1 sampai 2, 24 Agustus 2026: Fase Setup

Target: repo GitHub dan VM Target siap.

- Repo kelompok dibuat, berisi dokumentasi proyek, berkas bukti, dan laporan.
- VM Target disiapkan dari image Ubuntu Server, diberi nama UBUNTU SYAMIL, RAM 2048 MB, CPU 2, disk 10 GB dinamis.
- VM Target dinilai cocok dipakai ulang, jadi tidak perlu bikin dari nol. Ini sekaligus menekan pemakaian disk host yang sudah di atas sembilan puluh persen.
- Artefak: README.md, dokumen rencana alamat IP.

## Minggu 3, 7 September 2026: Checkpoint 1 Proof of Concept

Target: VM Target bisa di-ping dari VM Attacker.

- Jaringan internal VirtualBox `pbl5-lan` dipasang di tiga VM, promiscuous mode Allow All khusus untuk Security Onion.
- Alamat dipasang sesuai rencana: attacker 192.168.5.100, target 192.168.5.5, Security Onion 192.168.5.200.
- Target memakai netplan, bukan NetworkManager, lalu `netplan apply` dan dicek dengan `ip a`.
- Hasil: ping dari attacker ke target berhasil. Checkpoint lulus.
- Artefak: tangkapan layar ping, catatan alamat di `docs/design/ip_plan.md`.

## Minggu 4 sampai 5, 14 dan 21 September 2026: Checkpoint 2 Logging Check

Target: Security Onion merekam trafik.

- Antarmuka monitoring Security Onion dipasang di `pbl5-lan`, antarmuka manajemen di NAT.
- Uji awal pakai `tcpdump` memastikan paket ICMP dari attacker ke target terbaca.
- Kendala: tangkapan tidak muncul sebelum promiscuous mode dinyalakan. Solusinya diset Allow All di adapter Security Onion.
- Hasil: rekaman trafik jalan, layanan penerima syslog pada port 514 siap dipakai untuk Fase 2.
- Artefak: keluaran tcpdump, `docs/design/ip_plan.md` yang final.

## Minggu 6 sampai 7, 28 September dan 5 Oktober 2026: Checkpoint 3 Hardening Review

Target: sistem sudah diamankan sebelum diserang.

- Audit baseline dikerjakan di Target Node: daftar port mendengar, status firewall, daftar akun, layanan yang berjalan.
- Snapshot VM dibuat sebelum konfigurasi diubah.
- Hardening sepuluh kontrol dikerjakan, mencakup SSH, akun dan hak sudo, fail2ban, pemadaman layanan yang tidak dipakai, ufw, patch, pembatasan basis data ke loopback, hak akses akun basis data, pemindahan kredensial ke berkas env, dan pengiriman log ke Security Onion.
- Audit ulang dikerjakan, hasilnya dibandingkan dengan baseline.
- Demo progres diperlihatkan pada Pertemuan 7.
- Artefak: `docs/blueteam/hardening_checklist.md`, Security Baseline Document, berkas bukti before dan after.

## Minggu 8 sampai 9, 12 dan 19 Oktober 2026: Penutupan Fase 1 dan Persiapan Fase 2

Target: dokumen lengkap dan rencana serangan siap dibahas.

- Pemindaian penutup dari mesin penyerang dikerjakan dua kali, sebelum dan sesudah seluruh hardening aktif. Hasilnya: port terbuka pada pemindaian seluruh port turun dari lima menjadi dua.
- Seluruh screenshot pengujian dirapikan dan diberi nama sesuai kode kontrol, lalu dikumpulkan ke folder bukti.
- Rencana serangan Fase 2 disusun dalam tiga skenario, yaitu reconnaissance, exploitation, dan web serta protokol IoT.
- Deklarasi tech stack diisi dengan membandingkan teknologi proyek IoT asli dan bentuk replikasinya.
- Berkas pendukung dilengkapi: peta aset, diagram topologi, dan aturan keterlibatan.
- Yang dibahas di Pertemuan 9: progres hardening, deklarasi tech stack, dan rencana serangan.

## Minggu 10, 26 Oktober 2026: Mulai Fase 2

Target: eksekusi skenario 1 dan skenario 2.

- Pengintaian dijalankan dari 192.168.5.100 dengan `nmap -sS -sV -O -p-` ke 192.168.5.5.
- Hasil: tiga port terbuka, yaitu 22, 1883, dan 3000, dengan 65532 port tersaring. Deteksi versi mencatat OpenSSH 10.2p1. Sidik sistem operasi tidak menemukan kecocokan, tebakan tertinggi 91 persen mengarah ke perangkat yang salah.
- Lalu lintas pengintaian ditangkap dengan tcpdump, menghasilkan 300 paket dalam berkas 33 kilobyte.
- Skenario 2 dijalankan: enumerasi NSE pada 3306 berakhir filtered, uji koneksi langsung timeout, Hydra MySQL mencoba 20 kandidat tanpa pernah membentuk koneksi, Hydra SSH ditolak pada tahap negosiasi metode.
- fail2ban mencatat lima kegagalan dan memblokir alamat penyerang dua kali, masing-masing 1800 detik.
- Catatan analisis: nol kata sandi valid pada Hydra bukan bukti kata sandi kuat, karena tidak ada satu pun percobaan yang benar-benar terkirim.
- Artefak: `docs/redteam/evidence/skenario-1-recon/`, `docs/redteam/evidence/skenario-2-exploit/`.

## Minggu 11, 2 dan 9 November 2026: Skenario 3 dan Pengisian Log

Target: serangan lapisan aplikasi dan protokol IoT, lalu isi catatan lima tahap.

- Permintaan normal ke endpoint `/sensor` mengembalikan dua baris `sensor-01` dalam bentuk repr tuple Python.
- Payload OR `x' OR '1'='1` mengembalikan empat baris, yaitu seluruh isi tabel. Payload AND mengembalikan nol baris. Payload UNION empat kolom berakhir galat 500 yang membocorkan jejak internal.
- Broker MQTT menerima klien anonim dengan `CONNACK 0`. Langganan ke `sensors/#` berhasil, lalu pesan palsu diterima dan diteruskan ke subscriber.
- Subscriber menulis baris `sensor-99` dengan suhu 99.90 dan kelembapan 0.0. Baris itu tampil di posisi teratas dashboard tanpa penanda.
- Baris palsu sempat muncul tiga kali karena tiga proses subscriber berjalan bersamaan.
- Pencarian di Kibana menghasilkan 50 hits dengan satu alert ICMP. Tidak ada peringatan untuk payload HTTP maupun pesan MQTT, karena sensor berjalan dalam mode import dan tidak ada aturan untuk pola aplikasi.
- Sepuluh sel pertama `docs/purple-team-log.md` diisi dari hasil ini.
- Artefak: `docs/redteam/evidence/skenario-3-web-mqtt/`, `docs/redteam/laporan-redteam-fase-2.docx`.

## Minggu 12, 16 sampai 23 November 2026: Mitigasi

Target: menutup celah yang ditemukan pada Fase 2.

- Dashboard diganti versi aman: query memakai parameter, keluaran memakai `jsonify`, mode debug dimatikan. Berkas asli disimpan sebagai `app.py.asli`.
- Broker MQTT dikonfigurasi dengan `allow_anonymous false` dan `password_file /etc/mosquitto/passwd`, lalu akun `iotuser` dibuat.
- Kendala pertama: layanan gagal dengan `status=13`. Log menunjukkan `Unable to open pwfile`. Penyebabnya berkas kata sandi dimiliki root mode 600, sedangkan broker berjalan sebagai pengguna `mosquitto`.
- Perbaikan: `chown mosquitto:mosquitto` dan `chmod 640` pada berkas kata sandi, layanan kembali active.
- Kendala kedua muncul setelah konfigurasi dianggap selesai: broker masih menerima klien anonim. Pemeriksaan isi `conf.d` menemukan `pb15-awal.conf` dari 18 Oktober yang masih memuat `allow_anonymous true`.
- Sebabnya urutan pembacaan. Mosquitto memuat berkas pada direktori itu sesuai urutan abjad, dan nilai yang dibaca terakhir yang berlaku. Berkas lama dibaca setelah `default.conf`, sehingga menimpa konfigurasi baru.
- Rencana perbaikan: berkas lama dipindahkan keluar direktori konfigurasi, bukan dihapus, lalu layanan dimulai ulang. Langkah ini belum dijalankan sampai logbook ditutup.
- Data palsu `sensor-99` dihapus. Akun `app_iot` tidak punya hak DELETE sehingga muncul `ERROR 1142`, penghapusan dilakukan dengan akun berhak lebih tinggi.
- Artefak: `docs/final/bukti-verifikasi/`.

## Minggu 13, 24 dan 25 November 2026: Verifikasi dan Dokumen Akhir

Target: membuktikan perbaikan berlaku, lalu menyusun laporan dan bahan presentasi.

- Payload yang sama diulang dari mesin yang sama. Permintaan normal tetap mengembalikan dua baris dalam bentuk JSON, sehingga aplikasi terbukti masih hidup.
- Payload OR mengembalikan array kosong. Payload UNION mengembalikan HTTP 200 dengan badan kosong, bukan lagi galat 500.
- Verifikasi MQTT tidak berhasil pada sesi ini. Publish dari mesin target dijawab `CONNACK 0`, artinya broker hidup dan masih menerima klien anonim.
- **Tindak lanjut 27 November 2026.** Penyebabnya berkas `pb15-awal.conf` dari Oktober yang dibaca terakhir dan menimpa `allow_anonymous false`. Berkas itu dipindahkan ke `/root`, akun `sensor` dibuat, konfigurasi ditulis ulang, dan publish anonim kini ditolak dengan `not authorised`. Subscriber diberi kredensial agar aliran data tetap jalan.
- Tangkapan lalu lintas sesi verifikasi menghasilkan 45 paket.
- Lima belas sel `docs/purple-team-log.md` selesai diisi, termasuk sel yang mencatat kegagalan.
- `docs/final/incident_report.pdf` disusun mengikuti NIST SP 800-61r2, delapan bagian, 25 halaman.
- `slides.pdf` disusun, dua belas slide.
- Video demonstrasi diunggah ke https://youtu.be/b0riabC46ik dan tautannya dicantumkan di README.
- Repositori dirapikan: bukti disusun per skenario, `.gitignore` dipasang, README dan logbook diperbarui.
- Video demonstrasi sudah diunggah ke https://youtu.be/b0riabC46ik dan tautannya tercantum di README, menggantikan catatan sebelumnya.

## Catatan lintas pekan

Semua akses hanya ke VM Target kelompok sendiri, sesuai aturan keterlibatan. Tidak ada pemindaian ke jaringan kampus, WiFi publik, atau infrastruktur lab.

Kegagalan dicatat sebagai kegagalan. Dua hal yang masih terbuka sampai akhir: serangan lapisan aplikasi tidak terdeteksi oleh sensor, dan identitas perangkat masih diambil mentah dari nama topik. Autentikasi MQTT sendiri sudah tuntas pada tindak lanjut 27 November: berkas konfigurasi lama dipindahkan, publish anonim ditolak, dan data sah tetap tercatat. Yang belum tertutup adalah pemalsuan identitas oleh akun yang sah, dan itu masuk bagian rekomendasi, bukan dihilangkan dari catatan.
