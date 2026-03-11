#!/bin/bash
# Install yasdi2mqtt on Raspberry Pi OS Bookworm (Debian 12) or newer.
#
# Uses apt packages for cJSON and Paho MQTT C, only builds YASDI and
# yasdi2mqtt from source.
#
# Run as root or with sudo.

set -euo pipefail

BUILD_DIR="/tmp/yasdi2mqtt-build"
mkdir -p "$BUILD_DIR"

echo "=== Installing dependencies from apt ==="
apt update
apt install -y git gcc make cmake \
  libssl-dev libcjson-dev libpaho-mqtt-dev

# ----------------------------------------------------------
# 1. YASDI (SMA Data Protocol library) — not packaged
# ----------------------------------------------------------
echo "=== Building YASDI ==="
cd "$BUILD_DIR"
if [ ! -d yasdi ]; then
  git clone https://github.com/konstantinblaesi/yasdi.git
fi
cd yasdi/sdk/projects/generic-cmake
mkdir -p build-gcc && cd build-gcc
cmake -DYASDI_DEBUG_OUTPUT=0 -DCMAKE_INSTALL_PREFIX=/usr/local ..
make -j$(nproc)
make install
ldconfig

# ----------------------------------------------------------
# 2. yasdi2mqtt
# ----------------------------------------------------------
echo "=== Building yasdi2mqtt ==="
cd "$BUILD_DIR"
if [ ! -d yasdi2mqtt ]; then
  git clone https://github.com/pkwagner/yasdi2mqtt.git
fi
cd yasdi2mqtt
make YASDI_PATH="$BUILD_DIR/yasdi/sdk"
make YASDI_PATH="$BUILD_DIR/yasdi/sdk" install

# ----------------------------------------------------------
# 3. Install configuration files
# ----------------------------------------------------------
echo "=== Installing configuration files ==="
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cp "${SCRIPT_DIR}/yasdi.ini" /etc/yasdi.ini
cp "${SCRIPT_DIR}/yasdi2mqtt.env" /etc/yasdi2mqtt.env
cp "${SCRIPT_DIR}/yasdi2mqtt.service" /etc/systemd/system/yasdi2mqtt.service

echo "=== Enabling service ==="
systemctl daemon-reload
systemctl enable yasdi2mqtt

echo ""
echo "============================================"
echo "  Build complete."
echo "============================================"
echo ""
echo "Before starting, verify:"
echo "  1. /etc/yasdi.ini - correct serial port (ttyAMA0 vs ttyUSB0)"
echo "  2. /etc/yasdi2mqtt.env - correct MQTT broker address"
echo ""
echo "Then start with: sudo systemctl start yasdi2mqtt"
echo "Check logs with:  journalctl -u yasdi2mqtt -f"
echo ""
echo "Build artifacts are in $BUILD_DIR"
echo "You can remove them with: rm -rf $BUILD_DIR"
