# Hal

RS485 data acquisition for the SMA Sunny Island off-grid power system.

Taps the RS485 bus between a Sunny Island 6.0H-11 and its Sunny Remote Control,
parses display update packets, and publishes real-time power system data to MQTT.

## Architecture

This app is one component of a larger off-grid home automation system:

- **This app (Hal)**: RS485 → MQTT bridge, runs on Pi 4 (2GB)
- **Mosquitto**: MQTT broker, runs on Pi 1
- **SBFspot**: Sunny Boy → MQTT + PVoutput, runs on Pi 1
- **Home Assistant**: Device control + automations, runs on Pi 5
- **InfluxDB + Telegraf**: Time-series storage (MQTT → InfluxDB), runs on Pi 5
- **Grafana**: Dashboards, runs on Pi 5

## Running

```bash
# Development
mix deps.get
mix run --no-halt

# Production (via release)
MIX_ENV=prod mix release
MQTT_BROKER=inverter RS485_PORT=ttyAMA0 _build/prod/rel/hal/bin/hal start
```

## Configuration

Environment variables (production):

- `MQTT_BROKER` - hostname of the MQTT broker (default: `inverter`)
- `RS485_PORT` - serial port for RS485 adapter (default: `ttyAMA0`)

## MQTT Topics Published

| Topic | Type | Description |
|---|---|---|
| `power/genset/engaged` | boolean | Generator connected to bus |
| `power/genset/output` | float | Generator output (kW) |
| `power/genset/request` | boolean | SI requesting generator start |
| `power/flow/power` | float | Charge/discharge power (kW, negative = charging) |
| `power/flow/status` | string | "charge" or "discharge" |
| `power/load` | float | House load (kW) |
| `power/battery/fan` | boolean | Battery fan running |
| `power/battery/charge` | integer | Battery state of charge (%) |
| `power/time` | string | Sunny Island clock (HH:MM:SS) |
