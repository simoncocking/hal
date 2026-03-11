# Hal

Off-grid home automation and monitoring system for a solar/battery/genset power installation
based on SMA Sunny Island 6.0H-11 and Sunny Boy 4000TL-20.

## Architecture

```
┌─────────────────┐     RS485      ┌──────────────────┐
│  Sunny Island    │───────────────▶│  Pi 4 (2GB)      │
│  6.0H-11        │                │  ├ yasdi2mqtt     │──── MQTT ────┐
│                 │                │  └ Hal RS485 app  │──── MQTT ──┐ │
│  Sunny Remote   │───── RS485 ───▶│    (transitional) │            │ │
│  Control (SRC)  │                └──────────────────┘            │ │
└─────────────────┘                                                │ │
                                                                   │ │
┌─────────────────┐  Bluetooth   ┌──────────────────┐              │ │
│  Sunny Boy      │─────────────▶│  Pi 1 (512MB)    │              │ │
│  4000TL-20      │              │  ├ SBFspot        │──── MQTT ──┐│ │
│                 │              │  └ Mosquitto ◀════╪═════════════╪═╡
└─────────────────┘              └──────────────────┘   ▲         │ │
                                                        │         │ │
┌─────────────────┐                                     │         │ │
│  ESP32          │──── MQTT (shw/#) ───────────────────┤         │ │
│  (SHW temps)    │                                     │         │ │
└─────────────────┘                                     │         │ │
                                                        │         │ │
┌─────────────────┐                                     │         │ │
│  Tasmota        │──── MQTT (stat/+/POWER*) ───────────┤         │ │
│  devices (×7)   │                                     │         │ │
└─────────────────┘                                     │         │ │
                                                                  │ │
                                   ┌──────────────────┐           │ │
                                   │  Pi 5 (8GB+NVMe) │           │ │
                                   │  ├ Home Assistant │◀══════════╪═╡
                                   │  ├ InfluxDB 2.7   │           │ │
                                   │  ├ Telegraf  ◀════╪═══════════╧═╛
                                   │  └ Grafana        │
                                   └──────────────────┘
```

## Hardware

| Host | Hardware | Role | IP |
|------|----------|------|----|
| Pi 1 | Raspberry Pi 1 (BCM2708, 512MB) | Mosquitto MQTT broker, SBFspot | 10.0.0.3 |
| Pi 4 | Raspberry Pi 4 Model B (2GB) | yasdi2mqtt, Hal RS485 app (transitional) | — |
| Pi 5 | Raspberry Pi 5 (8GB, NVMe SSD) | Home Assistant, InfluxDB, Telegraf, Grafana (Docker) | — |

## Network Dependencies

All services run on-prem. No internet connectivity is required for operation.
The only outbound dependency is SBFspot's optional upload to PVoutput.org.

## Pi 4: yasdi2mqtt

The Pi 4 is physically connected to the RS485 bus between the Sunny Island
and the Sunny Remote Control. It runs [yasdi2mqtt](https://github.com/pkwagner/yasdi2mqtt)
to query all spot channels from the SI and publish them as JSON to MQTT.

During the transition, the Hal Elixir app also runs on the Pi 4, passively
reading display update packets from the same RS485 bus and publishing to
`power/` topics. Once yasdi2mqtt is confirmed to provide all the same data
(and more), the Elixir app can be retired.

**Note:** Running two bus masters (yasdi2mqtt + Sunny Remote Control) on the
same RS485 bus causes occasional collisions. This is expected and results in
intermittent poll failures (gaps in data). These are acceptable during the
transition. Long-term, the SRC may be replaced with a Pi-based touchscreen
controller using YASDI for both monitoring and control.

### Installation

```bash
cd infrastructure/yasdi2mqtt
sudo ./install.sh

# Verify config, then:
sudo systemctl start yasdi2mqtt
journalctl -u yasdi2mqtt -f
```

### Configuration

| File | Purpose |
|------|---------|
| `/etc/yasdi.ini` | YASDI driver config (serial port, baud rate, protocol) |
| `/etc/yasdi2mqtt.env` | MQTT broker address, topic prefix, poll interval |
| `/etc/systemd/system/yasdi2mqtt.service` | systemd unit file |

### MQTT Topics (yasdi2mqtt)

Publishes to `solar/sunny_island/<serial_number>` as JSON:

```json
{
  "timestamp": 1710100000,
  "sn": "1234567890",
  "values": {
    "Pac": 1200,
    "Uac": 230.1,
    "Iac": 5.2,
    "Fac": 50.01,
    "Ubat": 51.8,
    "Ibat": 12.3,
    "BatSoC": 85,
    "TmpBat": 24.5,
    "TmpDev": 32.1,
    "Riso": 10000,
    "E-Total-In": 12345.6,
    "E-Total-Out": 11234.5,
    "h-Total": 8760,
    "Status": "Mpp",
    "Fehler": 0
  }
}
```

The exact channel names depend on firmware version. Check actual output
with `mosquitto_sub -h 10.0.0.3 -t 'solar/sunny_island/#' -v` and adjust
Home Assistant and Telegraf configs to match.

## Pi 4: Hal Elixir App (transitional)

The Elixir app passively reads display update packets from the RS485 bus
(SMANet protocol, HDLC framing) and publishes parsed values to MQTT.

### MQTT Topics (Hal legacy)

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

### Running

```bash
# Development
mix deps.get
mix run --no-halt

# Production (via release)
MIX_ENV=prod mix release
MQTT_BROKER=inverter RS485_PORT=ttyAMA0 _build/prod/rel/hal/bin/hal start
```

### Environment Variables

- `MQTT_BROKER` — hostname of MQTT broker (default: `inverter`)
- `RS485_PORT` — serial port for RS485 adapter (default: `ttyAMA0`)

## Pi 5: Docker Stack

The Pi 5 runs the monitoring and automation stack via Docker Compose.

### Services

| Service | Port | Purpose |
|---------|------|---------|
| Home Assistant | 8123 | Device control, automations, mobile UI |
| InfluxDB 2.7 | 8086 | Time-series storage (365 day retention) |
| Telegraf 1.30 | — | MQTT → InfluxDB bridge |
| Grafana 11.0 | 3000 | Dashboards and visualization |

### Deployment

```bash
cd infrastructure
docker compose up -d
```

### Default Credentials (change before first deploy!)

| Service | Username | Password |
|---------|----------|----------|
| InfluxDB | admin | changeme-influx |
| Grafana | admin | changeme-grafana |
| InfluxDB API token | — | hal-influxdb-token |

## Transition Plan

1. **Phase 1 (current):** Deploy yasdi2mqtt on Pi 4 alongside existing Elixir app.
   Both publish to MQTT. Dual bus masters with SRC — accept occasional collisions.
   Compare data from both sources to validate yasdi2mqtt output.

2. **Phase 2:** Once yasdi2mqtt is confirmed working, retire the Elixir RS485 app.
   Remove `sunny_island_legacy` Telegraf input and `(legacy)` HA sensors.

3. **Phase 3 (future):** Replace Sunny Remote Control with Pi + touchscreen
   running a custom control interface using YASDI for bidirectional communication
   (read all channels + write parameter channels for operational control).
   Single bus master — eliminates RS485 collisions entirely.
