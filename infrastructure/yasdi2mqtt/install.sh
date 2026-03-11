#!/bin/bash
# Install yasdi2mqtt on Pi 4 (Raspberry Pi OS / Debian)
#
# Builds all dependencies from source for compatibility with
# older distros (e.g. Buster) where libpaho-mqtt and libcjson
# are not available as packages.
#
# Run as root or with sudo.

set -euo pipefail

BUILD_DIR="/tmp/yasdi2mqtt-build"
mkdir -p "$BUILD_DIR"

echo "=== Installing build toolchain ==="
apt install -y git gcc make cmake libssl-dev

# ----------------------------------------------------------
# 1. cJSON (JSON parser library)
# ----------------------------------------------------------
echo "=== Building cJSON ==="
cd "$BUILD_DIR"
if [ ! -d cJSON ]; then
  git clone --depth 1 --branch v1.7.17 https://github.com/DaveGamble/cJSON.git
fi
cd cJSON
mkdir -p build && cd build
cmake -DCMAKE_INSTALL_PREFIX=/usr/local -DENABLE_CJSON_TEST=Off ..
make -j$(nproc)
make install
ldconfig

# ----------------------------------------------------------
# 2. Eclipse Paho MQTT C client library
# ----------------------------------------------------------
echo "=== Building Paho MQTT C ==="
cd "$BUILD_DIR"
if [ ! -d paho.mqtt.c ]; then
  git clone --depth 1 --branch v1.3.13 https://github.com/eclipse-paho/paho.mqtt.c.git
fi
cd paho.mqtt.c
cmake -Bbuild -H. \
  -DCMAKE_INSTALL_PREFIX=/usr/local \
  -DPAHO_WITH_SSL=TRUE \
  -DPAHO_BUILD_SAMPLES=FALSE \
  -DPAHO_BUILD_DOCUMENTATION=FALSE
cmake --build build/ -j$(nproc)
cmake --build build/ --target install
ldconfig

# ----------------------------------------------------------
# 3. YASDI (SMA Data Protocol library)
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
# 4. yasdi2mqtt
# ----------------------------------------------------------
echo "=== Building yasdi2mqtt ==="
cd "$BUILD_DIR"
if [ ! -d yasdi2mqtt ]; then
  git clone https://github.com/pkwagner/yasdi2mqtt.git
fi
cd yasdi2mqtt
make YASDI_PATH="$BUILD_DIR/yasdi"
make YASDI_PATH="$BUILD_DIR/yasdi" install

# ----------------------------------------------------------
# 5. Install configuration files
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
