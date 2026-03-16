#!/usr/bin/env python3
"""
Migrate SBFspot SpotData from MySQL/MariaDB to InfluxDB.

Reads the SpotData table and writes points to InfluxDB using the same
measurement names and tag structure as Telegraf, so historical and live
data appear as a single continuous series in Grafana.

Telegraf writes:
  - sunny_boy measurement, metric tag = ac_watts, ac_amps, etc.
  - Topic structure: power/pv/<metric>

This script mirrors that structure so Grafana queries work across
both historical and live data without modification.

Usage:
    python3 migrate-spotdata-to-influx.py [--dry-run] [--batch-size 5000]

Prerequisites:
    pip install mysql-connector-python influxdb-client --break-system-packages
"""

import argparse
import os
import sys
from datetime import datetime, timezone

try:
    import mysql.connector
except ImportError:
    print(
        "Install mysql-connector-python: pip install mysql-connector-python --break-system-packages"
    )
    sys.exit(1)

try:
    from influxdb_client import InfluxDBClient, Point, WritePrecision
    from influxdb_client.client.write_api import SYNCHRONOUS
except ImportError:
    print(
        "Install influxdb-client: pip install influxdb-client --break-system-packages"
    )
    sys.exit(1)


# --- Configuration ---
MYSQL_HOST = os.environ.get("MYSQL_HOST", "rs485.local")
MYSQL_PORT = int(os.environ.get("MYSQL_PORT", "3306"))
MYSQL_USER = os.environ.get("MARIADB_SBFSPOT_USER", "sbfspot")
MYSQL_PASS = os.environ.get("MARIADB_SBFSPOT_PASS", "")
MYSQL_DB = os.environ.get("MARIADB_SBFSPOT_DB_NAME", "")

INFLUX_URL = os.environ.get("INFLUX_URL", "http://localhost:8086")
INFLUX_TOKEN = os.environ.get("INFLUXDB_TOKEN", "")
INFLUX_ORG = os.environ.get("INFLUX_ORG", "hal")
INFLUX_BUCKET = os.environ.get("INFLUX_BUCKET", "power")

# Map SpotData columns to the metric tags Telegraf uses
# Column name -> (measurement, metric_tag, unit_divisor)
# unit_divisor converts SBFspot units to match what MQTT publishes
COLUMN_MAP = {
    "Pac1": ("sunny_boy", "ac_watts", 1),  # W
    "Iac1": ("sunny_boy", "ac_amps", 1000),  # mA -> A
    "Uac1": ("sunny_boy", "ac_volts", 1000),  # mV -> V  (bonus, not in MQTT)
    "Pdc1": ("sunny_boy", "string_1/dc_watts", 1),  # W
    "Pdc2": ("sunny_boy", "string_2/dc_watts", 1),  # W
    "Idc1": ("sunny_boy", "string_1/dc_amps", 1000),  # mA -> A
    "Idc2": ("sunny_boy", "string_2/dc_amps", 1000),  # mA -> A
    "Udc1": ("sunny_boy", "string_1/dc_volts", 100),  # cV -> V
    "Udc2": ("sunny_boy", "string_2/dc_volts", 100),  # cV -> V
    "EToday": ("sunny_boy", "kwh_today", 1000),  # Wh -> kWh
    "ETotal": ("sunny_boy", "kwh_total", 1000),  # Wh -> kWh
    "Temperature": ("sunny_boy", "temperature", 100),  # c°C -> °C
}


def get_row_count(cursor):
    """Get total SpotData rows for progress reporting."""
    cursor.execute("SELECT COUNT(*) FROM SpotData")
    return cursor.fetchone()[0]


def fetch_spotdata(cursor, batch_size=5000):
    """Yield SpotData rows in batches."""
    cursor.execute("""
        SELECT TimeStamp, Serial,
               Pac1, Iac1, Uac1,
               Pdc1, Pdc2, Idc1, Idc2, Udc1, Udc2,
               EToday, ETotal, Temperature
        FROM SpotData
        ORDER BY TimeStamp ASC
    """)

    batch = []
    for row in cursor:
        batch.append(row)
        if len(batch) >= batch_size:
            yield batch
            batch = []
    if batch:
        yield batch


def row_to_points(row):
    """Convert a SpotData row to InfluxDB points."""
    ts_epoch = row[0]  # Unix timestamp
    serial = str(row[1])

    # Convert epoch to datetime
    ts = datetime.fromtimestamp(ts_epoch, tz=timezone.utc)

    points = []
    columns = [
        "Pac1",
        "Iac1",
        "Uac1",
        "Pdc1",
        "Pdc2",
        "Idc1",
        "Idc2",
        "Udc1",
        "Udc2",
        "EToday",
        "ETotal",
        "Temperature",
    ]

    for i, col in enumerate(columns):
        value = row[i + 2]  # offset by TimeStamp and Serial
        if value is None or value == 0:
            continue

        measurement, metric_tag, divisor = COLUMN_MAP[col]
        converted = float(value) / divisor

        point = (
            Point(measurement)
            .tag("metric", metric_tag)
            .tag("serial", serial)
            .tag("source", "migration")
            .field("value", converted)
            .time(ts, WritePrecision.S)
        )
        points.append(point)

    return points


def main():
    parser = argparse.ArgumentParser(description="Migrate SBFspot SpotData to InfluxDB")
    parser.add_argument(
        "--dry-run", action="store_true", help="Print stats without writing"
    )
    parser.add_argument(
        "--batch-size", type=int, default=5000, help="Rows per batch (default 5000)"
    )
    parser.add_argument("--mysql-host", default=MYSQL_HOST)
    parser.add_argument("--mysql-port", type=int, default=MYSQL_PORT)
    parser.add_argument("--mysql-user", default=MYSQL_USER)
    parser.add_argument("--mysql-pass", default=MYSQL_PASS)
    parser.add_argument("--mysql-db", default=MYSQL_DB)
    parser.add_argument("--influx-url", default=INFLUX_URL)
    parser.add_argument("--influx-token", default=INFLUX_TOKEN)
    parser.add_argument("--influx-org", default=INFLUX_ORG)
    parser.add_argument("--influx-bucket", default=INFLUX_BUCKET)
    args = parser.parse_args()

    # Connect to MySQL
    print("Connecting to MySQL...")
    conn = mysql.connector.connect(
        host=args.mysql_host,
        port=args.mysql_port,
        user=args.mysql_user,
        password=args.mysql_pass,
        database=args.mysql_db,
    )
    cursor = conn.cursor()

    total_rows = get_row_count(cursor)
    print(f"SpotData has {total_rows:,} rows to migrate")

    if total_rows == 0:
        print("Nothing to migrate.")
        return

    # Connect to InfluxDB
    if not args.dry_run:
        print("Connecting to InfluxDB...")
        influx = InfluxDBClient(
            url=args.influx_url, token=args.influx_token, org=args.influx_org
        )
        write_api = influx.write_api(write_options=SYNCHRONOUS)

    # Process in batches
    rows_done = 0
    points_written = 0
    start_time = datetime.now()

    for batch in fetch_spotdata(cursor, args.batch_size):
        all_points = []
        for row in batch:
            all_points.extend(row_to_points(row))

        if not args.dry_run and all_points:
            write_api.write(bucket=args.influx_bucket, record=all_points)

        rows_done += len(batch)
        points_written += len(all_points)
        elapsed = (datetime.now() - start_time).total_seconds()
        rate = rows_done / elapsed if elapsed > 0 else 0
        pct = rows_done / total_rows * 100

        print(
            f"\r  {rows_done:,}/{total_rows:,} rows ({pct:.1f}%) | "
            f"{points_written:,} points | {rate:.0f} rows/sec",
            end="",
            flush=True,
        )

    elapsed = (datetime.now() - start_time).total_seconds()
    print(f"\n\nDone in {elapsed:.1f}s")
    print(f"  Rows processed: {rows_done:,}")
    print(f"  Points {'would be ' if args.dry_run else ''}written: {points_written:,}")

    if rows_done > 0:
        # Show date range
        cursor.execute(
            "SELECT FROM_UNIXTIME(MIN(TimeStamp)), FROM_UNIXTIME(MAX(TimeStamp)) FROM SpotData"
        )
        first, last = cursor.fetchone()
        print(f"  Date range: {first} to {last}")

    cursor.close()
    conn.close()
    if not args.dry_run:
        influx.close()


if __name__ == "__main__":
    main()
