# Hardening Checklist

Kelompok 5 - Skenario 05 Internal Database Fortress

- Target Node: VM UBUNTU SYAMIL, Ubuntu Server 26.04 LTS, kernel 7.0.0-38-generic, 192.168.5.5
- Attacker: Cybersecurity LabVM, 192.168.5.100
- Monitoring: CyberOps Security Onion, 192.168.5.200
- Jaringan: pbl5-lan, 192.168.5.0/24

Ketentuan panduan: minimal 8 kontrol tersebar di tiga kategori, minimal 2 kontrol per kategori. Tiap kontrol wajib punya bukti before/after, bukan cuma klaim. Kolom Status diisi salah satu dari Selesai, Sebagian, Belum.

Kesepuluh kontrol di bawah berstatus Selesai. Seluruh bukti ada di `docs/blueteam/evidence/`, daftar berkasnya di `evidence/README.md`.

## A. Access dan Authentication

| Kode | Kontrol | Keadaan akhir | Cara verifikasi | Status | Bukti |
| --- | --- | --- | --- | --- | --- |
| A1 | SSH hanya menerima kunci publik, root dilarang, batas percobaan login tiga kali | `passwordauthentication no`, `permitrootlogin no`, `maxauthtries 3`, hanya akun `fattih` yang boleh masuk, X11 forwarding mati | `sudo sshd -T` lalu filter baris passwordauthentication, permitrootlogin, maxauthtries, allowusers | Selesai | `evidence/before/A1-sshd-effective-config-before.png`, `evidence/before/A1-sshd-config-before.png`, `evidence/after/A1-sshd-effective-config.png` |
| A2 | Akun dan hak sudo dirapikan: izin direktori home diperketat, masa berlaku sudo dibatasi, akun root dikunci | Izin `/home/fattih` 700, berkas `/etc/sudoers.d/99-hardening` 440, akun root terkunci (L) | `ls -l /home`, `sudo cat /etc/sudoers.d/99-hardening`, `sudo passwd -S root` | Selesai | `evidence/before/A2-home-750.png`, `evidence/after/A2-home-700.png` |
| A3 | fail2ban aktif pada jail sshd, percobaan login berulang diblokir | Jail `sshd` aktif, `maxretry 3`, `findtime 600`, `bantime 1800`, alamat `192.168.5.100` pernah masuk daftar blokir, enam percobaan kunci palsu dari mesin penyerang ditolak Permission denied (publickey) | `sudo fail2ban-client status sshd` | Selesai | `evidence/before/A3-maxretry-5.png`, `evidence/after/A3-maxretry-3.png`, `evidence/after/A3-banned-ip.png`, `evidence/after/A3-tes-login-gagal.png` |

## B. Service dan Attack Surface

| Kode | Kontrol | Keadaan akhir | Cara verifikasi | Status | Bukti |
| --- | --- | --- | --- | --- | --- |
| B1 | Layanan yang tidak dipakai dimatikan sampai port-nya tertutup | Apache dan layanan bawaan yang tidak dipakai mati, port 80 tidak lagi mendengar. Yang tersisa hanya 22, 1883, 3000, dan 3306 yang sudah dibatasi ke loopback | `sudo ss -tlnp` sebelum dan sesudah | Selesai | `evidence/before/B1-ss-port-80-terbuka.png`, `evidence/before/B1-layanan-vm-before.png`, `evidence/after/LINTAS-nmap-after-detail.txt` |
| B2 | Firewall menolak seluruh trafik masuk kecuali port yang dipakai | ufw aktif, kebijakan bawaan menolak lalu lintas masuk, empat aturan izin yang mencakup port 22, 1883, dan 3000 dari jaringan lab 192.168.5.0/24, tanpa port 80 dan tanpa port 3306 | `sudo ufw status verbose` | Selesai | `evidence/before/B2-ufw-inactive.png`, `evidence/after/B2-ufw-status-verbose.png` |
| B3 | Sistem dan paket ter-patch ke versi terbaru | Kernel 7.0.0-38-generic, paket yang menunggu pembaruan turun dari 26 menjadi 0 setelah full-upgrade dan autoremove | `uname -r`, `apt list --upgradable` lalu hitung baris upgradable | Selesai | `evidence/before/B3-apt-26-paket.png`, `evidence/after/B3-apt-bersih.png` |

## C. Data dan Application

| Kode | Kontrol | Keadaan akhir | Cara verifikasi | Status | Bukti |
| --- | --- | --- | --- | --- | --- |
| C1 | Basis data hanya mendengarkan di loopback, tidak di jaringan | MySQL hanya mendengar di 127.0.0.1 pada port 3306 dan 33060, percobaan dari mesin penyerang dijawab Connection refused | `sudo ss -tlnp` lalu filter port 3306, dari penyerang `nc -vz 192.168.5.5 3306` | Selesai | `evidence/before/LINTAS-recon-awal.png`, `evidence/after/C1-ss-3306-loopback.png` |
| C2 | Akun basis data berhak terbatas, akun default dihapus | Akun `webapp` beserta hak ALL PRIVILEGES dan WITH GRANT OPTION dihapus, tersisa `app_iot` dengan hak SELECT, INSERT, UPDATE pada `iot_db` saja, percobaan masuk ke basis data sistem dijawab ERROR 1044 | di prompt `mysql`: `SELECT user,host FROM mysql.user;` lalu `SHOW GRANTS FOR app_iot@localhost;` | Selesai | `evidence/before/C2-grants-webapp.png`, `evidence/after/C2-grants-app_iot.png`, `evidence/after/C2-use-mysql-ditolak.png` |
| C3 | Kredensial keluar dari berkas aplikasi, disimpan dengan hak akses 600 | Berkas `app.py` versi 2 hanya merujuk variabel, kredensial ada di `/etc/iot/iot.env` dengan izin -rw------- milik root, percobaan baca oleh pengguna biasa ditolak | `sudo ls -l /etc/iot/iot.env`, `sudo head -n 13 /opt/iot-dashboard/app.py` | Selesai | `evidence/before/C3-password-di-apppy.png`, `evidence/after/C3-iotenv-600.png` |
| C4 | Log aktivitas dikirim ke Security Onion | `/etc/rsyslog.d/50-pbl5-forward.conf` berisi `*.* @@192.168.5.200:514`, sambungan berstatus ESTABLISHED dari 192.168.5.5 port 36168 ke 192.168.5.200 port 514, aturan izin di Security Onion allow from 192.168.5.5 to any port 514 | `sudo ss -tunp` lalu filter port 514, di Security Onion `sudo tcpdump -i eth2 -n port 514` | Selesai | `evidence/before/C4-rsyslog-tanpa-forward.png`, `evidence/after/C4-log-diterima-established.png` |

## Kontrol tambahan yang belum dikerjakan

Sepuluh kontrol di atas semuanya berstatus Selesai, jadi syarat minimum Bagian VIII sudah terpenuhi. Dua item berikut diambil dari daftar contoh Bagian VIII kategori C dan memang sengaja belum dikerjakan, karena dijadwalkan menjadi bahan mitigasi pada siklus Purple Team Loop Minggu 11 setelah serangan Red Team dieksekusi lebih dulu.

| Item | Keadaan sekarang | Rencana | Status |
| --- | --- | --- | --- |
| Autentikasi broker MQTT | Broker masih menerima koneksi tanpa autentikasi, topik sensors/# bisa dibaca dan disuntik data palsu | Mematikan akses anonim, memasang password_file dan acl_file, lalu membatasi topik hanya untuk akun node sensor | Belum |
| Validasi input pada endpoint dashboard | Endpoint /sensor menyambung nilai device langsung ke dalam query basis data, sehingga masih bisa dimanipulasi | Mengganti query menjadi parameterized query dan menambahkan penyaringan masukan | Belum |

Bukti keadaan awal kedua item ini ada pada keluaran nmap dan pada berkas `docs/redteam/attack_plan.md` skenario 3, karena keduanya menjadi sasaran serangan Fase 2.

## Hasil nmap before vs after

Keluaran lengkapnya ada di `docs/blueteam/evidence/before/LINTAS-nmap-before-*.txt` dan `docs/blueteam/evidence/after/LINTAS-nmap-after-*.txt`.

| Cakupan pemindaian | Keadaan port | Sebelum | Sesudah |
| --- | --- | --- | --- |
| Enam port terpilih | Terbuka | 5 | 3 |
| Enam port terpilih | Tertutup | 1 | 0 |
| Enam port terpilih | Tersaring | 0 | 3 |
| Seluruh 65535 port | Terbuka | 5 | 2 |
| Seluruh 65535 port | Tertutup | 65.530 | 0 |
| Seluruh 65535 port | Tersaring | 0 | 65.533 |
| Seluruh 65535 port | Lama pemindaian | 20,52 detik | 780,26 detik |

## Rekap pemenuhan

| Kategori | Jumlah kontrol | Minimal yang diminta | Status |
| --- | --- | --- | --- |
| A. Access dan Authentication | 3 | 2 | terpenuhi |
| B. Service dan Attack Surface | 3 | 2 | terpenuhi |
| C. Data dan Application | 4 | 2 | terpenuhi |
| Total kontrol selesai | 10 | 8 | terpenuhi |
| Kontrol tambahan | 2 item belum dikerjakan | bukan syarat minimum | dijadwalkan Minggu 11 |

Hardening tidak berhenti di satu layer. Sepuluh kontrol tersebar di tiga kategori, jadi syarat minimum panduan terpenuhi, dan seluruhnya sudah berstatus Selesai. Dua item tambahan dari daftar contoh kategori C belum dikerjakan dan dijadwalkan menjadi mitigasi Minggu 11.

## Catatan

1. Kredensial. Tidak ada satu pun nilai kata sandi di berkas bukti. Screenshot lama yang memuat nilai kata sandi tidak dipakai lagi, termasuk pada C1 sehingga kontrol itu memakai bukti pemindaian sebagai pengganti screenshot before.
2. Port 22 pada pemindaian seluruh port tercatat tersaring, sedangkan pada pemindaian port terpilih beberapa menit sebelumnya port itu terbaca terbuka. Hal ini terjadi karena alamat penyerang masuk daftar blokir fail2ban selama pemindaian berlangsung, sesuai mode aggressive pada A3.
3. Perlu dikonfirmasi cepat sebelum presentasi: daftar akun bawaan lewat `getent passwd` dan `getent group sudo`. Kalau masih ada akun bawaan yang tidak dipakai, cabut shell-nya dengan `sudo usermod -s /usr/sbin/nologin NAMA`, kunci dengan `sudo passwd -l NAMA`, keluarkan dari grup sudo dengan `sudo deluser NAMA sudo`, lalu simpan screenshot sebelum dan sesudahnya ke folder evidence.
