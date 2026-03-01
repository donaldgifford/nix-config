# WIFI

```bash
nmcli connection add \
  type wifi \
  ifname wlo1 \
  con-name "mywifi" \
  ssid "YOUR_SSID" \
  wifi-sec.key-mgmt wpa-psk \
  wifi-sec.psk "YOUR_PASSWORD"

nmcli connection up "mywifi"
```

