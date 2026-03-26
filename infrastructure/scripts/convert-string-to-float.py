#!/usr/bin/env python3
"""
Convert string-typed sunny_boy data in InfluxDB to float.

Telegraf was initially configured with data_type="string" for the PV
MQTT input, so ~2 weeks of sunny_boy data has _value stored as strings.
This causes Flux aggregateWindow(fn: mean) to silently fail when both
string and float data are in the same query range.

This script:
  1. Reads all string-typed sunny_boy data (identified by having a 'site' tag
     from Telegraf, which the migration data doesn't have)
  2. Deletes the string data from InfluxDB
  3. Rewrites it with float values

After this, all sunny_boy data in InfluxDB is float, and simple Grafana
queries work across all time ranges.

Prerequisites:
    pip install influxdb-client --break-system-packages

Usage:
    python3 convert-string-to-float.py [--dry-run]
"""

import argparse
import os
import sys
from datetime import datetime, timezone

try:
    from influxdb_client import InfluxDBClient, Point, WritePrecision
    from influxdb_client.client.write_api import SYNCHRONOUS
except ImportError:
    print("Install influxdb-client: pip install influxdb-client --break-system-packages")
    sys.exit(1)


INFLUX_URL = os.environ.get("INFLUX_URL", "http://localhost:8086")
INFLUX_TOKEN = os.environ.get("INFLUXDB_TOKEN", "")
INFLUX_ORG = os.environ.get("INFLUX_ORG", "hal")
INFLUX_BUCKET = os.environ.get("INFLUX_BUCKET", "power")

# Time range for string data (Telegraf started ~2026-03-13)
START = "2026-03-01T00:00:00Z"
STOP = "2026-03-28T00:00:00Z"


def main():
    parser = argparse.ArgumentParser(description="Convert string sunny_boy data to float")
    parser.add_argument("--dry-run", action="store_true", help="Read and report without modifying")
    args = parser.parse_args()

    client = InfluxDBClient(url=INFLUX_URL, token=INFLUX_TOKEN, org=INFLUX_ORG)
    query_api = client.query_api()

    # Step 1: Read all string-typed sunny_boy data
    # Telegraf data has site="tallarook" tag; migrated data has source="migration" tag
    query = f'''from(bucket: "{INFLUX_BUCKET}")
  |> range(start: {START}, stop: {STOP})
  |> filter(fn: (r) => r._measurement == "sunny_boy" and r.site == "tallarook")
'''
    print(f"Reading string-typed sunny_boy data ({START} to {STOP})...")
    tables = query_api.query(query, org=INFLUX_ORG)

    # Collect points with float conversion
    points = []
    skipped = 0
    skip_keys = {"result", "table", "_start", "_stop", "_time", "_value", "_field", "_measurement"}

    for table in tables:
        for record in table.records:
            try:
                value = float(record.get_value())
            except (ValueError, TypeError):
                skipped += 1
                continue

            p = Point("sunny_boy")
            # Copy all tags from the record
            for key, val in record.values.items():
                if key in skip_keys or key.startswith("_"):
                    continue
                if val is not None:
                    p = p.tag(key, str(val))
            p = p.field("value", value)
            p = p.time(record.get_time(), WritePrecision.NS)
            points.append(p)

    print(f"  Found {len(points):,} points to convert ({skipped} skipped)")

    if not points:
        print("Nothing to convert.")
        client.close()
        return

    if args.dry_run:
        print("Dry run — no changes made.")
        client.close()
        return

    # Step 2: Delete the string data
    print("Deleting string-typed data...")
    delete_api = client.delete_api()
    delete_api.delete(
        start=START,
        stop=STOP,
        predicate='_measurement="sunny_boy" AND site="tallarook"',
        bucket=INFLUX_BUCKET,
        org=INFLUX_ORG,
    )
    print("  Deleted.")

    # Step 3: Rewrite as float
    print(f"Writing {len(points):,} points as float...")
    write_api = client.write_api(write_options=SYNCHRONOUS)
    batch_size = 5000
    for i in range(0, len(points), batch_size):
        batch = points[i : i + batch_size]
        write_api.write(bucket=INFLUX_BUCKET, record=batch)
        done = min(i + batch_size, len(points))
        print(f"  {done:,}/{len(points):,} ({done * 100 // len(points)}%)")

    print("Done! All sunny_boy data is now float-typed.")
    client.close()


if __name__ == "__main__":
    main()
