# Bukti Red Team

Kelompok 5 - Skenario 05 Internal Database Fortress

Dua puluh empat tangkapan layar, tersusun mengikuti tiga skenario pada `../attack_plan.md` dan tiga blok pada `../purple-team-log.md`. Nomor folder, nomor skenario, dan nomor kode bukti dibuat sama agar tidak perlu pemetaan ulang.

Seluruh tangkapan diambil dari mesin penyerang 192.168.5.100 dengan prompt `analyst@secOps`, kecuali SS-07 dan SS-07b yang diambil dari Monitoring Node 192.168.5.200.

## Skenario 1 - Reconnaissance

Delapan berkas. Kode SS-01 sampai SS-07b.

| Kode | Berkas | Isi |
| --- | --- | --- |
| SS-01 | `SS-01-ip-route.png` | Pemeriksaan alamat dan rute dari mesin penyerang |
| SS-02 | `SS-02-host-discovery.png` | Penemuan host pada segmen 192.168.5.0/24 |
| SS-03 | `SS-03-target-identitas.png` | Identitas Target Node, hostname dan `ip -4 addr` |
| SS-04 | `SS-04-scan-all-port.png` | Pemindaian 65535 port, tiga port terbuka, 65532 tersaring |
| SS-05 | `SS-05-scan-detail.png` | Deteksi versi pada daftar port terpilih |
| SS-06 | `SS-06-scan-os.png` | Sidik sistem operasi, tebakan tertinggi 91 persen |
| SS-07 | `SS-07-capture-pcap.png` | Penangkapan lalu lintas, 300 paket, 33 kilobyte |
| SS-07b | `SS-07b-hunt-alert.png` | Pencarian di Kibana, 50 hits, satu alert ICMP |

## Skenario 2 - Exploitation

Tujuh berkas. Kode SS-08 sampai SS-12b.

| Kode | Berkas | Isi |
| --- | --- | --- |
| SS-08 | `SS-08-nse-mysql.png` | Enumerasi NSE pada MySQL, berakhir filtered |
| SS-09 | `SS-09-nc-3306.png` | Uji koneksi ke port 3306, berakhir timeout |
| SS-10 | `SS-10-hydra-mysql.png` | Hydra pada MySQL, 20 kandidat tanpa koneksi terbentuk |
| SS-11 | `SS-11-hydra-ssh.png` | Hydra pada SSH, ditolak pada tahap negosiasi |
| SS-11b | `SS-11b-sshd-password-off.png` | Konfigurasi efektif sshd, kata sandi dimatikan |
| SS-12 | `SS-12-fail2ban.png` | Status jail sshd, alamat penyerang diblokir |
| SS-12b | `SS-12b-fail2ban-log.png` | Catatan fail2ban, Found lalu Ban dua kali |

## Skenario 3 - Web dan MQTT

Sembilan berkas. Kode SS-13 sampai SS-20.

| Kode | Berkas | Isi |
| --- | --- | --- |
| SS-13 | `SS-13-db-normal.png` | Permintaan normal, dua baris dalam repr tuple |
| SS-14 | `SS-14-db-injeksi-or.png` | Payload OR, empat baris, seluruh isi tabel |
| SS-15 | `SS-15-db-union-500.png` | Payload UNION, galat 500 dengan jejak internal |
| SS-16 | `SS-16-db-injeksi-and.png` | Payload AND, nol baris |
| SS-17 | `SS-17-mqtt-sub.png` | Langganan `sensors/#` diterima tanpa autentikasi |
| SS-18 | `SS-18-mqtt-pub.png` | Pesan palsu diterima broker |
| SS-19 | `SS-19-db-data-palsu.png` | Baris palsu masuk ke tabel `sensor_readings` |
| SS-19b | `SS-19b-subscriber-log.png` | Log subscriber, data palsu tersimpan |
| SS-20 | `SS-20-dashboard-palsu.png` | Dashboard menampilkan data palsu di posisi teratas |

## Catatan Penomoran

Kode dengan akhiran huruf, yaitu SS-07b dan SS-11b, adalah bukti tambahan yang diambil setelah penomoran awal selesai. Pemberian akhiran dilakukan agar nomor yang sudah dirujuk di laporan tidak bergeser.

SS-01 dan SS-03 diambil sebelum skenario 1 dimulai, lalu disalin ke folder ini agar urutan bukti tidak terputus.

Bukti sesudah mitigasi tidak berada di folder ini, melainkan di `docs/final/bukti-verifikasi/`, karena fungsinya sebagai bukti kontrol, bukan bukti serangan.

Kredensial tidak muncul pada berkas mana pun di folder ini. Nilai sensitif ditutup pada saat pengambilan tangkapan.
