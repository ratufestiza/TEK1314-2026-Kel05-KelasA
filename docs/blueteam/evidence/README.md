# Bukti hardening, aturan penamaan

Berkas di folder ini adalah bukti before/after untuk sepuluh kontrol pada `../hardening_checklist.md`.

Aturan nama berkas: `KODE-isi.png`, dengan KODE mengacu ke kode kontrol (A1 sampai C4). Berkas yang dipakai lintas kontrol, bukan milik satu kontrol tertentu, memakai awalan `LINTAS`. Screenshot before masuk ke `before/`, screenshot after masuk ke `after/`. Keluaran `nmap` disimpan sebagai berkas `.txt` di folder yang sama.

Aturan kredensial: kalau di layar sedang tampil nilai kata sandi, bagian itu dipotong atau ditutup dulu sebelum disimpan. Screenshot pada percobaan pertama masih memuat nilai kata sandi, dan berkas itu sudah dikeluarkan dari folder ini serta tidak dipakai di laporan mana pun. Kata sandi yang lolos ke berkas bukti tetap dihitung salah walaupun kontrolnya jalan.

## Daftar berkas per kontrol

| Kontrol | Berkas before | Berkas after | Status |
| --- | --- | --- | --- |
| A1 SSH kunci publik | `before/A1-sshd-effective-config-before.png`, `before/A1-sshd-config-before.png` | `after/A1-sshd-effective-config.png` | Selesai |
| A2 akun dan sudo | `before/A2-home-750.png` | `after/A2-home-700.png` | Selesai |
| A3 fail2ban | `before/A3-maxretry-5.png` | `after/A3-maxretry-3.png`, `after/A3-banned-ip.png`, `after/A3-tes-login-gagal.png` | Selesai |
| B1 matikan layanan | `before/B1-ss-port-80-terbuka.png`, `before/B1-layanan-vm-before.png` | `after/LINTAS-nmap-after-detail.txt` (port 80 hilang, berubah jadi tersaring) | Selesai |
| B2 ufw | `before/B2-ufw-inactive.png` | `after/B2-ufw-status-verbose.png` | Selesai |
| B3 patch | `before/B3-apt-26-paket.png` | `after/B3-apt-bersih.png` | Selesai |
| C1 MySQL loopback | `before/LINTAS-recon-awal.png`, `before/LINTAS-nmap-before-detail.txt` | `after/C1-ss-3306-loopback.png` | Selesai |
| C2 akun basis data | `before/C2-grants-webapp.png` | `after/C2-grants-app_iot.png`, `after/C2-use-mysql-ditolak.png` | Selesai |
| C3 kredensial | `before/C3-password-di-apppy.png` | `after/C3-iotenv-600.png` | Selesai |
| C4 log ke Security Onion | `before/C4-rsyslog-tanpa-forward.png` | `after/C4-log-diterima-established.png` | Selesai |

## Bukti lintas kontrol

| Berkas | Isi |
| --- | --- |
| `before/LINTAS-recon-awal.png` | Keadaan awal mesin target: lima layanan mendengar di seluruh antarmuka, firewall belum aktif |
| `before/LINTAS-ufw-patch-sebelum.png` | Firewall belum aktif, berdampingan dengan daftar paket yang menunggu pembaruan |
| `before/LINTAS-nmap-before-all.txt` | Pemindaian seluruh port sebelum pengerasan: lima port terbuka |
| `before/LINTAS-nmap-before-detail.txt` | Pemindaian enam port terpilih sebelum pengerasan, lengkap dengan versi layanan |
| `after/LINTAS-nmap-after-all.txt` | Pemindaian seluruh port sesudah pengerasan: dua port terbuka, 65.533 tersaring |
| `after/LINTAS-nmap-after-detail.txt` | Pemindaian enam port terpilih sesudah pengerasan: port 80, 3306, dan 9090 tersaring |

## Catatan

C1 tidak punya screenshot before tersendiri karena gambar lama pada tahap itu ikut menangkap nilai kata sandi basis data, sehingga tidak boleh dipakai. Sebagai gantinya, keadaan sebelum C1 dibuktikan oleh `before/LINTAS-recon-awal.png` dan `before/LINTAS-nmap-before-detail.txt`, yang sama-sama menunjukkan port 3306 terbuka beserta versi MySQL-nya.
