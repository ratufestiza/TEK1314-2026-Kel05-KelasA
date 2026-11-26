#!/bin/bash
# Skrip demo purple team PBL5. Dijalankan di VM Target (AYAM) sebagai root.
#   sudo bash /tmp/purple.sh reset      -> kembalikan ke kondisi rentan
#   sudo bash /tmp/purple.sh mitigasi   -> tukar ke versi aman
#   sudo bash /tmp/purple.sh cek        -> tampilkan status

set -u
DIR="/opt/iot-dashboard"
LOG="/var/log/iot"
AKSI="${1:-cek}"
mkdir -p "$LOG" 2>/dev/null
# /tmp memakai fs.protected_regular, root tidak boleh menimpa berkas milik user
# lain di direktori sticky. Log lama di /tmp dibersihkan supaya tidak bentrok.
rm -f /tmp/dashboard.log /tmp/subscriber.log 2>/dev/null

hijau() { printf '\033[32m%s\033[0m\n' "$1"; }
merah() { printf '\033[31m%s\033[0m\n' "$1"; }
kuning() { printf '\033[33m%s\033[0m\n' "$1"; }

berhenti_proses() {
  local pola="$1"
  local pid
  for pid in $(ps -eo pid,args | grep -F "$pola" | grep -v grep | awk '{print $1}'); do
    echo "  matikan PID $pid ($pola)"
    kill "$pid" 2>/dev/null
    sleep 1
    if kill -0 "$pid" 2>/dev/null; then
      kill -9 "$pid" 2>/dev/null
    fi
  done
}

tunggu_port() {
  local i
  for i in $(seq 1 15); do
    if ss -tln | grep -q ":3000 "; then return 0; fi
    sleep 1
  done
  return 1
}

nyalakan() {
  cd "$DIR" || exit 1
  setsid nohup python3 app.py > "$LOG/dashboard.log" 2>&1 < /dev/null &
  setsid nohup python3 subscriber.py > "$LOG/subscriber.log" 2>&1 < /dev/null &
  sleep 2
}

kasus_reset() {
  echo "=== RESET KE KONDISI RENTAN ==="

  echo "[1] matikan proses lama"
  berhenti_proses "python3 app.py"
  berhenti_proses "python3 subscriber.py"
  if ss -tln | grep -q ":3000 "; then
    merah "  port 3000 masih dipakai, cari manual: ss -tlnp | grep 3000"
  else
    hijau "  port 3000 sudah lepas"
  fi

  echo "[2] pasang versi rentan"
  if [ ! -f /tmp/app.py.rentan ]; then
    merah "  /tmp/app.py.rentan tidak ada. Kirim ulang dari host."
    exit 1
  fi
  cp /tmp/app.py.rentan "$DIR/app.py"
  cp /tmp/app.py.aman "$DIR/app.py.aman"
  chown root:root "$DIR/app.py" "$DIR/app.py.aman"
  chmod 644 "$DIR/app.py" "$DIR/app.py.aman"
  echo "  app.py      $(stat -c%s "$DIR/app.py") byte"
  echo "  app.py.aman $(stat -c%s "$DIR/app.py.aman") byte"
  if [ "$(stat -c%s "$DIR/app.py")" -eq 1483 ] && [ "$(stat -c%s "$DIR/app.py.aman")" -eq 1791 ]; then
    hijau "  ukuran benar"
  else
    merah "  ukuran tidak sesuai, cek /tmp/app.py.rentan dan /tmp/app.py.aman"
  fi

  echo "[3] buka MQTT"
  cat > /etc/mosquitto/conf.d/default.conf <<'MQTT'
listener 1883 0.0.0.0
allow_anonymous true
MQTT
  systemctl restart mosquitto
  sleep 1
  if ss -tln | grep -q "0.0.0.0:1883"; then
    hijau "  mosquitto mendengarkan 0.0.0.0:1883"
  else
    merah "  mosquitto tidak di 0.0.0.0, cek: systemctl status mosquitto"
  fi

  echo "[4] hapus data palsu dari tabel"
  if [ -f /etc/mysql/debian.cnf ]; then
    mysql --defaults-file=/etc/mysql/debian.cnf -e "DELETE FROM iot_db.sensor_readings WHERE device_id LIKE 'sensor-9%';" 2>/dev/null \
      && hijau "  baris sensor-9x dihapus" \
      || kuning "  gagal lewat debian.cnf, hapus manual di prompt mysql"
    mysql --defaults-file=/etc/mysql/debian.cnf -N -e "SELECT COUNT(*) FROM iot_db.sensor_readings;" 2>/dev/null \
      | while read -r n; do echo "  jumlah baris sekarang: $n"; done
  else
    kuning "  /etc/mysql/debian.cnf tidak ada, hapus manual di prompt mysql"
  fi

  echo "[5] lepaskan blokir fail2ban"
  fail2ban-client unban 192.168.5.100 >/dev/null 2>&1
  fail2ban-client set sshd unbanip 192.168.5.100 >/dev/null 2>&1
  fail2ban-client reload >/dev/null 2>&1
  hijau "  perintah unban dijalankan"

  echo "[6] nyalakan aplikasi"
  nyalakan
  if tunggu_port; then hijau "  port 3000 hidup"; else merah "  port 3000 tidak hidup, lihat $LOG/dashboard.log"; fi

  kasus_cek
}

kasus_mitigasi() {
  echo "=== TUKAR KE VERSI AMAN ==="

  echo "[1] matikan proses lama dulu"
  berhenti_proses "python3 app.py"
  if ss -tln | grep -q ":3000 "; then
    merah "  port 3000 masih dipakai, hentikan dulu"
    exit 1
  fi
  hijau "  port 3000 lepas"

  echo "[2] timpa berkas"
  cp "$DIR/app.py.aman" "$DIR/app.py"
  echo "  app.py sekarang $(stat -c%s "$DIR/app.py") byte"

  echo "[3] nyalakan ulang"
  cd "$DIR" || exit 1
  setsid nohup python3 app.py > "$LOG/dashboard.log" 2>&1 < /dev/null &
  sleep 2
  if tunggu_port; then hijau "  port 3000 hidup"; else merah "  gagal, lihat $LOG/dashboard.log"; fi

  kasus_cek
}

kasus_cek() {
  echo "=== STATUS ==="
  echo "berkas:"
  ls -l "$DIR/app.py" "$DIR/app.py.aman" 2>/dev/null | awk '{print "  "$5" byte  "$9}'
  echo "proses:"
  ps -eo pid,args | grep -e "python3 app.py" -e "python3 subscriber.py" | grep -v grep | awk '{print "  PID "$1"  "$2" "$3}'
  echo "port:"
  ss -tln | grep -e ":3000 " -e ":1883 " -e ":3306 " | awk '{print "  "$4}'

  echo "uji query normal (harus 2 baris):"
  local normal
  normal=$(curl -s -m 5 "http://127.0.0.1:3000/sensor?device=sensor-01" | grep -o "sensor-[0-9]*" | wc -l)
  echo "  hasil: $normal"

  echo "uji payload OR (rentan harus lebih dari normal, aman harus 0):"
  local orhasil
  orhasil=$(curl -s -m 5 "http://127.0.0.1:3000/sensor?device=x%27%20OR%20%271%27%3D%271")
  if echo "$orhasil" | grep -q '"jumlah"'; then
    echo "  mode AMAN, $(echo "$orhasil" | grep -o '\"jumlah\": [0-9]*')"
  else
    echo "  mode RENTAN, $(echo "$orhasil" | grep -o "sensor-[0-9]*" | wc -l) baris"
  fi

  echo "uji tabel dashboard:"
  if curl -s -m 5 "http://127.0.0.1:3000/" | grep -q "<table"; then
    hijau "  halaman / menampilkan tabel"
  else
    merah "  halaman / bukan tabel, app.py mungkin versi lama"
  fi
}

case "$AKSI" in
  reset) kasus_reset ;;
  mitigasi) kasus_mitigasi ;;
  cek) kasus_cek ;;
  *) echo "pakai: sudo bash /tmp/purple.sh reset|mitigasi|cek"; exit 1 ;;
esac
