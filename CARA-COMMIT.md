# Cara Commit ke GitHub

Folder ini siap dorong. Git lokal sudah terinisialisasi, seluruh berkas sudah masuk staging, dan commit sudah dibuat di atas commit terakhir yang ada di repo GitHub kalian. Artinya tidak ada konflik, cukup satu perintah dorong.

Repo tujuan: `https://github.com/ratufestiza/TEK1314-2026-Kel05-KelasA`

## Yang sudah dilakukan di folder ini

- `git init` dan remote `origin` sudah menunjuk ke repo kalian.
- Seluruh isi sudah di-commit dengan pesan `Susun ulang repo: artefak Minggu 1-13, incident report final, slide, bukti per skenario`.
- Commit itu dibangun di atas commit terakhir repo kalian, jadi riwayat lama tidak hilang dan tidak perlu force push.
- `.gitignore` memblokir video, berkas pcap, dan berkas kredensial, sehingga rekaman yang nanti dibuat tidak akan pernah ikut walaupun diletakkan di dalam folder.

## Satu perintah untuk dorong

Buka terminal di folder ini, lalu jalankan:

`git push origin main`

Kalau muncul permintaan login, pilih browser yang sudah masuk akun GitHub pemilik repo. Setelah selesai, buka halaman repo dan cek folder `docs` sudah terisi lengkap.

## Setelah video selesai

Video diunggah ke YouTube sebagai Unlisted, bukan ke repo. Setelah dapat tautannya, buka `README.md` di GitHub lewat tombol pensil, ganti baris `[tautan menyusul]` dengan alamat YouTube, lalu commit langsung dari web. Tidak perlu terminal.

## Kalau ada yang gagal

**`rejected, fetch first`.** Berarti ada commit baru di GitHub setelah folder ini dibuat. Jalankan `git pull --rebase origin main`, lalu `git push origin main`.

**`Authentication failed`.** Jalankan `git config --global credential.helper manager`, lalu ulangi push dan login lewat browser.

**`file is 100 MB`.** Ada berkas besar lolos. Cek dengan `git ls-files`, lalu pastikan tidak ada berkas `.mp4` atau `.pcap` yang ikut.

**Ingin membatalkan semuanya.** Jalankan `git reset --hard origin/main`. Folder kembali seperti isi GitHub terakhir, seluruh perubahan lokal hilang.

## Isi yang sudah diverifikasi

| Pemeriksaan | Hasil |
| --- | --- |
| Berkas tercatat git | 108 |
| Berkas video di dalam repo | tidak ada |
| Berkas pcap di dalam repo | tidak ada |
| Ukuran folder tanpa `.git` | 17 MB |
| Berkas terbesar | incident report 5,2 MB, jauh di bawah batas 100 MB |
| Tautan markdown rusak | 0 dari 22 |
| Karakter em dash | 0 di seluruh berkas markdown |
| Kredensial terbuka | tidak ada, seluruh kata sandi ditutup pada tangkapan |
| Berkas lama yang terhapus | tidak ada, seluruh isi repo lama dipertahankan |
