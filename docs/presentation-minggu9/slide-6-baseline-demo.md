# Slide 6: Baseline Traffic dan Live Demo

Satu tabel saja. Angka diambil dari berkas pemindaian di `docs/blueteam/evidence`.

| Port atau ukuran | Layanan | Sebelum 18 Oktober | Sesudah 19 Oktober | Keterangan |
| --- | --- | --- | --- | --- |
| 22 | SSH OpenSSH 10.2p1 | terbuka | terbuka | tidak muncul pada pemindaian seluruh port karena pemindai terblokir fail2ban |
| 80 | HTTP Apache 2.4.66 | terbuka | tersaring | layanan dimatikan, port ditutup ufw |
| 1883 | MQTT | terbuka | terbuka | dibiarkan untuk pengujian Fase 2 |
| 3000 | HTTP Werkzeug 3.1.5 | terbuka | terbuka | dashboard replika, sasaran uji injeksi |
| 3306 | MySQL 8.4.11 | terbuka | tersaring | hanya mendengar di loopback, kontrol C1 |
| 9090 | tidak dipakai | tertutup | tersaring | layanan tidak pernah dipakai |
| Jumlah port terbuka | | 5 | 2 | |
| Port tersaring | | 0 | 65.533 | |
| Port tertutup | | 65.530 | 0 | |
| Durasi pemindaian seluruh port | | 20,52 detik | 780,26 detik | naik karena paket dibuang, bukan ditolak |

Baris paling bawah slide: demo langsung, Security Onion menangkap lalu lintas ping dari 192.168.5.100 menuju 192.168.5.5 melalui tcpdump dan menu Hunt.

## Kalimat pembicara

Sebelum hardening ada lima port terbuka dan pemindaian seluruh port selesai dalam dua puluh detik. Setelah hardening tinggal dua port, sedangkan enam puluh lima ribu port lain tidak menolak koneksi, hanya membuang paket. Itu sebabnya durasi pemindaian naik menjadi tiga belas menit.

## Catatan tanya jawab

Port 22 tidak muncul pada hasil pemindaian seluruh port bukan karena tertutup, melainkan karena mesin pemindai terblokir fail2ban di tengah proses. Port 1883 dan 3000 sengaja dibiarkan terbuka karena menjadi sasaran skenario Fase 2. Seluruh pengujian hanya pada replika dengan data dummy, tidak ada trafik keluar lab.
