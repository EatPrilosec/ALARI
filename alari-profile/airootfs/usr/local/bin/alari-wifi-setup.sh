#!/usr/bin/env bash

# Find a file named wifi.txt in the root of any partition
WIFI_FILE=""
MNT_DIR="/mnt/alari_wifi_scan"

mkdir -p "$MNT_DIR"

if [ -f "/wifi.txt" ]; then
    WIFI_FILE=$(cat "/wifi.txt")
else
    # Loop through all block devices
for part in $(lsblk -lno NAME,TYPE | awk '$2=="part" {print $1}'); do
    # Try mounting read-only
    mount -o ro "/dev/$part" "$MNT_DIR" 2>/dev/null
    if [ $? -eq 0 ]; then
        if [ -f "$MNT_DIR/wifi.txt" ]; then
            WIFI_FILE=$(cat "$MNT_DIR/wifi.txt")
            umount "$MNT_DIR"
            break
        fi
        umount "$MNT_DIR"
    fi
done
fi

if [ -n "$WIFI_FILE" ]; then
    SSID=$(echo "$WIFI_FILE" | grep "^SSID=" | cut -d'=' -f2- | tr -d '\r')
    PASSWORD=$(echo "$WIFI_FILE" | grep "^PASSWORD=" | cut -d'=' -f2- | tr -d '\r')

    if [ -n "$SSID" ] && [ -n "$PASSWORD" ]; then
        echo "Found WiFi config for $SSID, setting up iwd..."
        mkdir -p /var/lib/iwd
        cat > /var/lib/iwd/"$SSID.psk" <<EOF
[Security]
Passphrase=$PASSWORD
EOF
    fi
else
    echo "No wifi.txt found on any partition."
fi
