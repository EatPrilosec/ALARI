#!/usr/bin/env bash

# Check if ALARI_PERSIST exists
if blkid -L ALARI_PERSIST > /dev/null; then
    exit 0
fi

# Find the boot device. The archiso volume has the label ALARI_LIVE
BOOTMNT=$(blkid -L ALARI_LIVE)
if [ -z "$BOOTMNT" ]; then
    echo "Could not find boot medium."
    exit 1
fi

# Extract the base block device (e.g., /dev/sdb1 -> /dev/sdb, /dev/mmcblk0p1 -> /dev/mmcblk0)
DEV_NAME=$(lsblk -no PKNAME "$BOOTMNT" | head -n1 | tr -d ' ')
if [ -z "$DEV_NAME" ]; then
    # Fallback if findmnt returned the whole disk directly
    DEV=$BOOTMNT
else
    DEV="/dev/$DEV_NAME"
fi

echo "Found boot device: $DEV"

# Move GPT backup data to end of disk
sgdisk -e "$DEV"

# Create new partition (0 means next available, using all space), type 8300 (Linux)
sgdisk -n 0:0:0 -c 0:"ALARI_PERSIST" -t 0:8300 "$DEV"

# Inform kernel of partition table change
partprobe "$DEV" || blockdev --rereadpt "$DEV"

# Wait for udev to process the new partition
udevadm settle
sleep 2

# Find the newly created partition node using PARTLABEL
NEW_PART=$(lsblk -lno NAME,PARTLABEL | awk '$2=="ALARI_PERSIST"{print "/dev/"$1}')

if [ -n "$NEW_PART" ]; then
    echo "Formatting $NEW_PART as ext4..."
    mkfs.ext4 -L ALARI_PERSIST "$NEW_PART"
    
    echo "Persistence configured. Rebooting..."
    reboot
else
    echo "Failed to locate the new partition."
    exit 1
fi
