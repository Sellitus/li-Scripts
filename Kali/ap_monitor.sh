
if [ $# -ne 1 ]; then
  echo "Error: Pass MAC as first arg"
  exit 1
fi

sudo airodump-ng --bssid $1 --band a --write MonitorDump wlan0mon
