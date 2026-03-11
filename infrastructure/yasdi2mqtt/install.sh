#!/bin/bash
# Install yasdi2mqtt on Pi 4 (Raspberry Pi OS / Debian)
#
# Prerequisites: git, cmake, gcc, make, openssl, libcjson, libpaho-mqtt
#
# Run as root or with sudo.

set -euo pipefail

echo "=== Installing build dependencies ==="
apt install -y git gcc make cmake openssl libssl-dev libcjson1 libcjson-dev libpaho-mqtt1.3 libpaho-mqtt-dev

echo "=== Installing YASDI library ==="
cd /tmp
if [ ! -d yasdi ]; then
  git clone https://github.com/konstantinblaesi/yasdi.git
fi
cd yasdi/sdk/projects/generic-cmake
mkdir -p build-gcc && cd build-gcc
cmake -DYASDI_DEBUG_OUTPUT=0 ..
make -j$(nproc)
make install
ldconfig

echo "=== Installing yasdi2mqtt ==="
cd /tmp
if [ ! -d yasdi2mqtt ]; then
  git clone https://github.com/pkwagner/yasdi2mqtt.git
fi
cd yasdi2mqtt
make YASDI_PATH=/tmp/yasdi
make YASDI_PATH=/tmp/yasdi install

echo "=== Installing configuration files ==="
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cp "${SCRIPT_DIR}/yasdi.ini" /etc/yasdi.ini
cp "${SCRIPT_DIR}/yasdi2mqtt.env" /etc/yasdi2mqtt.env
cp "${SCRIPT_DIR}/yasdi2mqtt.service" /etc/systemd/system/yasdi2mqtt.service

echo "=== Enabling service ==="
systemctl daemon-reload
systemctl enable yasdi2mqtt

echo ""
echo "Done. Before starting, verify:"
echo "  1. /etc/yasdi.ini - correct serial port (ttyAMA0 vs ttyUSB0)"
echo "  2. /etc/yasdi2mqtt.env - correct MQTT broker address"
echo ""
echo "Then start with: sudo systemctl start yasdi2mqtt"
echo "Check logs with:  journalctl -u yasdi2mqtt -f"
