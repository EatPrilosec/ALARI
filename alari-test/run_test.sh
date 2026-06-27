#!/bin/bash
set -e

# Configuration
PROFILE_DIR="../alari-profile"
ROOTFS="$PROFILE_DIR/airootfs"
OPT_ALARI="$ROOTFS/opt/alari"
SYSTEMD_DIR="$ROOTFS/etc/systemd/system"
WIFI_TXT="../wifi.txt"

echo "=== ALARI Test Build & Run ==="

# 0. Set up VFIO for PCI Passthrough
echo "[0/6] Binding WiFi card to vfio-pci..."
echo "NOTE: Your host machine will temporarily lose WiFi access!"

sudo modprobe vfio-pci
# Unbind from current driver
if [ -e /sys/bus/pci/devices/0000:02:00.0/driver ]; then
    echo "0000:02:00.0" | sudo tee /sys/bus/pci/devices/0000:02:00.0/driver/unbind >/dev/null
fi
# Bind to vfio-pci
echo "vfio-pci" | sudo tee /sys/bus/pci/devices/0000:02:00.0/driver_override >/dev/null
echo "0000:02:00.0" | sudo tee /sys/bus/pci/drivers_probe >/dev/null
NEEDS_BUILD=true
EXISTING_ISO=$(ls ../out/*.iso 2>/dev/null | head -n 1)

if [ -n "$EXISTING_ISO" ]; then
    NEWER=$(find ../alari-profile ../alari-webui/src ../alari-webui/index.html ../alari-webui/vite.config.js ../alari-webui/package.json ../alari-api ../wifi.txt -type f -newer "$EXISTING_ISO" 2>/dev/null | head -n 1)
    if [ -z "$NEWER" ]; then
        echo "No source files changed since last build. Skipping image generation..."
        NEEDS_BUILD=false
        ISO_FILE=$(basename "$EXISTING_ISO")
        ISO_FILE="out/$ISO_FILE"
    fi
fi

if [ "$NEEDS_BUILD" = true ]; then
    # 1. Clean old builds
    echo "[1/6] Cleaning up old builds..."
    sudo rm -rf ../out ../work
    sudo rm -rf $OPT_ALARI
    mkdir -p $OPT_ALARI
    mkdir -p $SYSTEMD_DIR
    mkdir -p $ROOTFS/var/lib/iwd

    # 2. Build WebUI
    echo "[2/6] Building WebUI..."
    cd ../alari-webui
    npm run build
    cp -r dist $OPT_ALARI/webui
    cd ../alari-test

    # 3. Copy API files
    echo "[3/6] Copying API backend..."
    cp -r ../alari-api $OPT_ALARI/api

    # 4. Inject systemd services and config
    echo "[4/6] Configuring systemd services and WiFi..."

    # Copy wifi.txt to the root of the image
    if [ -f "$WIFI_TXT" ]; then
        cp "$WIFI_TXT" "$ROOTFS/wifi.txt"
        echo "Copied wifi.txt to the root of the image"
    else
        echo "Warning: wifi.txt not found!"
    fi

    # Create ALARI API service
    cat <<EOF > "$SYSTEMD_DIR/alari-api.service"
[Unit]
Description=ALARI API Backend
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/alari/api
ExecStart=/usr/bin/uvicorn main:app --host 0.0.0.0 --port 80
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    # Create IP Reporter service
    cat <<EOF > "$SYSTEMD_DIR/alari-report-ip.service"
[Unit]
Description=ALARI IP Reporter (QEMU Serial)
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c "ip -4 addr show wlan0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}' > /dev/ttyS0 || echo 'No IP found' > /dev/ttyS0"

[Install]
WantedBy=multi-user.target
EOF

    # Enable services in archiso (by creating symlinks in airootfs/etc/systemd/system/multi-user.target.wants)
    mkdir -p "$SYSTEMD_DIR/multi-user.target.wants"
    ln -sf /etc/systemd/system/alari-api.service "$SYSTEMD_DIR/multi-user.target.wants/alari-api.service"
    ln -sf /etc/systemd/system/alari-report-ip.service "$SYSTEMD_DIR/multi-user.target.wants/alari-report-ip.service"
    # Enable iwd
    ln -sf /usr/lib/systemd/system/iwd.service "$SYSTEMD_DIR/multi-user.target.wants/iwd.service"

    # 5. Build ISO
    echo "[5/6] Building Archiso (this will take a while)..."
    cd ..
    sudo mkarchiso -v -w work/ -o out/ alari-profile/
    ISO_FILE=$(ls out/*.iso | head -n 1)
    echo "Built ISO: $ISO_FILE"
else
    cd ..
fi


# 6. Prepare USB & Run QEMU
echo "[6/6] Preparing USB drive and booting QEMU..."

USB_IMG="out/simulated_usb.img"
if [ ! -f "$USB_IMG" ] || [ "$NEEDS_BUILD" = true ]; then
    echo "Creating 8GB simulated USB drive with ISO..."
    sudo truncate -s 8G "$USB_IMG"
    sudo dd if="$ISO_FILE" of="$USB_IMG" conv=notrunc status=progress
fi

echo "Waiting for VM to acquire IP via WiFi... The IP will be printed below when ready."

sudo qemu-system-x86_64 \
    -m 2048 \
    -enable-kvm \
    -drive file="$USB_IMG",format=raw \
    -device vfio-pci,host=02:00.0 \
    -device qemu-xhci \
    -device usb-host,vendorid=0x0bda,productid=0xb00a \
    -serial file:alari-test/ip_address.log \
    -daemonize

echo "QEMU booted in background."
echo "Monitoring serial output for IP address..."

# Wait for IP address to be written
cd alari-test
rm -f ip_address.log
touch ip_address.log

while true; do
    if [ -s ip_address.log ]; then
        IP_ADDR=$(cat ip_address.log)
        echo "========================================="
        echo "ALARI is accessible at: http://$IP_ADDR"
        echo "========================================="
        break
    fi
    sleep 2
done
