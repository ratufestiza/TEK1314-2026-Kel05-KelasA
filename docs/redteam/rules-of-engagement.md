# Rules of Engagement

Kelompok 5 - Skenario 05 Internal Database Fortress - TEK1314 Keamanan Siber

## Ruang lingkup

| Item | Isi |
| --- | --- |
| Sasaran yang diizinkan | Hanya VM Target Node replika, 192.168.5.5 |
| Jaringan | pbl5-lan, 192.168.5.0/24 |
| Mesin penyerang | Cybersecurity LabVM, 192.168.5.100 |
| Mesin pemantau | CyberOps Security Onion, 192.168.5.200 |
| Sasaran yang dilarang | Sistem produksi Mitra, jaringan kampus, WiFi publik, infrastruktur lab, dan alamat lain di luar subnet 192.168.5.0/24 |

## Teknik yang diizinkan

1. Pemindaian port dan enumerasi layanan pada sasaran yang diizinkan.
2. Percobaan kredensial lemah dan kredensial default pada sasaran yang diizinkan.
3. Pengujian celah pada aplikasi web replika, termasuk injeksi query.
4. Penyadapan dan penyuntikan data pada broker pesan replika.
5. Analisis trafik memakai penangkap paket di jaringan lab.

## Batasan

1. Tidak ada serangan yang mengganggu ketersediaan. Tidak ada DoS, tidak ada banjir paket, tidak ada penghapusan data.
2. Tidak ada serangan ke luar jaringan lab, termasuk tool yang otomatis menghubungi layanan daring.
3. Tidak ada perubahan konfigurasi pada Target Node dari sisi penyerang, kecuali yang sudah direncanakan bersama Blue Team sebagai bagian mitigasi.
4. Data pribadi dan kredensial yang ditemukan saat pengujian tidak boleh disebar. Kalau ikut tertangkap di tangkapan layar, bagian itu dipotong.

## Waktu pelaksanaan

Serangan Fase 2 dikerjakan mulai Minggu 10, setelah hardening Fase 1 selesai dan dokumennya lengkap. Setiap sesi dicatat waktu mulai dan selesai di purple team log.

## Penanganan bukti

Semua keluaran perintah, tangkapan layar, dan berkas penangkapan paket disimpan di `docs/redteam/evidence/` berdasarkan skenario, dan dirujuk dari `docs/purple-team-log.md`.

## Pelaporan

Temuan yang berhasil maupun yang gagal dilaporkan apa adanya. Serangan yang gagal tetap dicatat, karena kegagalan itu membuktikan kontrol sedang bekerja. Temuan yang berhasil menjadi bahan mitigasi Blue Team, lalu diuji ulang dan diverifikasi pada Minggu 11.
