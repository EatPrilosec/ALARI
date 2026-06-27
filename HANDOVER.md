# ALARI (Arch Linux Audio Receiver Interface)

## Project Purpose
ALARI is a custom Arch Linux based live ISO intended to run off a USB drive. It acts as a headless or UI-driven audio receiver, featuring a Vite/React WebUI and a FastAPI Python backend for controlling audio playback (Bluetooth, Spotify/librespot, etc.).

## How it Works
1. **ISO Generation:** The ISO is built using `mkarchiso` configured via the `alari-profile/` directory.
2. **Testing Environment:** We use a test script (`alari-test/run_test.sh`) that:
   - Builds the web UI and API.
   - Builds the ISO.
   - Creates a simulated 8GB USB drive (`truncate` and `dd`).
   - Boots QEMU (`qemu-system-x86_64`) passing through a physical WiFi card (via `vfio-pci`) and a USB audio device.
3. **Persistence Mechanism:** The ISO boots as a Live environment but is designed to have persistence.
   - A custom `mkinitcpio` hook (`alari-profile/airootfs/usr/lib/initcpio/hooks/alari_persist`) dynamically patches the `archiso` hook in RAM during early boot. This forces it to ignore the `cow_label` on the first boot when the persistence partition doesn't exist yet.
   - On the first successful boot, `alari-persist.service` triggers `alari-persist-setup.sh`, which finds the boot drive via `blkid -L ALARI_LIVE`, partitions the remaining space for `ALARI_PERSIST`, formats it, and reboots.
4. **User Setup:** `alari-setup.service` creates the default `alari` user during the boot process.

## Current Hurdles
- We've been trying to get the `alari-setup.service` (user creation) and `alari-persist-setup.sh` (persistence partition creation) to run correctly without failing.
- **Recent Fixes:**
  - `alari-setup.service` was running too early in `sysinit.target` before `/home` was ready. It was recently modified to run `After=systemd-sysusers.service` and `Before=systemd-user-sessions.service getty@tty1.service`.
  - `alari-persist-setup.sh` was failing to find the boot drive because `archiso` unmounts the USB stick in RAM mode. It was updated to use `blkid -L ALARI_LIVE` to find the raw device instead of looking at `/run/archiso/bootmnt`.
- **Next Steps:**
  - The previous test environment was slow (QEMU / `mkarchiso` took ~15 mins) and constrained by RAM.
  - We started QEMU manually and piped the serial output to `alari-test/serial_boot.log` to debug the boot sequence.
  - The next step is to examine `serial_boot.log` (or run a fresh boot) to verify if the `alari` user is being created correctly, if the `ALARI_PERSIST` partition is successfully provisioned, and squash any remaining userspace bugs.
