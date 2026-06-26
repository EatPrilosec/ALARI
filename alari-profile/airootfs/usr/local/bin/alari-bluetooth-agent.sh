#!/usr/bin/env bash
(
echo "power on"
echo "discoverable on"
echo "pairable on"
echo "agent NoInputNoOutput"
echo "default-agent"
while true; do sleep 3600; done
) | bluetoothctl
