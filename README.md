# TEK1314-2026-Kel05-KelasA
Repository Mata Kuliah Keamanan Siber Kelas A – Kelompok 5 | TEK1314 2026

Fattih Algie Maulana (J0404241002)

Syamil Abdillah (J0404241139

Ratu Festiza Alya Ichsan (J0404241174)

1. Dokumentasi Instalasi CyberOPS dan Security Union
2. https://docs.google.com/document/d/1kLTl9QgCAbP9AlRmZ7LeZou6PkfrzocWbvTxVEbz9e0/edit?tab=t.0

# PBL Keamanan Siber - Kelompok 5
# Skenario Proyek
Proyek PBL Kelompok 4 mengangkat skenario Simulasi Pengujian Keamanan Server Rentan Menggunakan Metasploitable. Lingkungan proyek terdiri dari tiga node utama:

Kali Linux sebagai Attacker Node yang digunakan oleh Red Team.
Ubunru Server CLI + DVWA sebagai Target Server atau korban.
Security Onion sebagai Monitoring Node yang digunakan oleh Blue Team untuk memantau aktivitas jaringan.

# Peran Team

Blue Team

Blue Team bertugas menggambar diagram topologi jaringan yang menghubungkan Attacker Node, Target Node, dan Monitoring Node. Selain itu, Blue Team menyusun skema IP Address beserta tabel routing sederhana yang sesuai dengan segmen unik kelompok. Tim ini juga menentukan posisi penempatan Security Onion agar dapat memantau seluruh lalu lintas di dalam segmen jaringan kelompok. 

Red Team

Red Team bertanggung jawab melakukan riset mengenai port dan service yang berpotensi dibuka atau dieksploitasi dalam skenario serangan. Mereka memberikan masukan terkait pemilihan OS Target berdasarkan celah keamanan atau versi rentan yang ingin didemonstrasikan. Hasil analisis berupa daftar port dan catatan potensi celah tersebut kemudian diserahkan kepada Blue Team untuk dimasukkan ke dalam desain topologi.  

Lead

Lead bertugas mengoordinasikan diskusi pemilihan OS Target dan memastikan seluruh keputusan tim tercatat dengan baik. Lead juga memastikan rancangan topologi serta tabel IP sudah final dan disepakati oleh Red Team maupun Blue Team. Terakhir, Lead bertanggung jawab mengunggah gambar topologi dan dokumen pendukung ke repositori GitHub kelompok

# Network

Topologi jaringan dirancang menggunakan segmen:

- Network: 192.168.5.0/24
- Target Server: 192.168.5.5
- Attacker Node: 192.168.5.100
- Monitoring Node: 192.168.5.200

# Port yang Menjadi Fokus Pengujian

| No | Hostname | Device | IP Address | Subnet Mask | Gateway | OS Direncanakan |
|----|----------|--------|------------|-------------|---------|-----------------|
| 1 | SW-K05 | Switch 2960-24TT | 192.168.5.2 | 255.255.255.0 | - | Cisco IOS 15.0 |
| 2 | Target-Node-K05 | Server-PT | 192.168.5.5 | 255.255.255.0 | - | Ubuntu Server CLI + DVWA |
| 3 | Attacker-Node-K05 | PC-PT | 192.168.5.100 | 255.255.255.0 | - | Kali Linux |
| 4 | Monitoring-Node-K05 | Server-PT | 192.168.5.200 | 255.255.255.0 | - | Security Onion |
