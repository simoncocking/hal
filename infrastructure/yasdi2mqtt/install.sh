#!/bin/bash
# Install yasdi2mqtt on Pi 4 (Raspberry Pi OS / Debian)
#
# Prerequisites: git, cmake, build-essential
#
# Run as root or with sudo.

set -euo pipefail

echo "=== Installing YASDI library ==="
cd /tmp
if [ ! -d yasdi ]; then
  git clone https://github.com/konstantinblaesi/yasdi.git
fi
cd yasdi
mkdir -p build && cd build
cmake -DCMAKE_INSTALL_PREFIX=/usr/local ..
make -j$(nproc)
make install
ldconfig

echo "=== Installing yasdi2mqtt ==="
cd /tmp
if [ ! -d yasdi2mqtt ]; then
  git clone https://github.com/pkwagner/yasdi2mqtt.git
fi
cd yasdi2mqtt
mkdir -p build && cd build
cmake -DCMAKE_INSTALL_PREFIX=/usr/local ..
make -j$(nproc)
make install

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
