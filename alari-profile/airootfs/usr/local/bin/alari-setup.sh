#!/usr/bin/env bash

# Create alari user if it doesn't exist
if ! id alari &>/dev/null; then
    useradd -m -G wheel,audio,video alari
    echo "alari:alari" | chpasswd
    echo "root:alari" | chpasswd
    # Enable linger for alari to start user services (pipewire, librespot) at boot
    loginctl enable-linger alari
fi
