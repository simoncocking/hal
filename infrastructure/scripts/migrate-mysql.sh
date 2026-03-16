#!/bin/bash
# Migrate SBFspot MySQL database from old Pi to new Pi 5 MariaDB container
#
# Usage:
#   1. Run from the Pi 5
#   2. Dumps the database from the old Pi over SSH
#   3. Restores into the local MariaDB Docker container
#
# Prerequisites:
#   - SSH access to the old Pi (pi1 / 10.0.0.3)
#   - MariaDB container running on Pi 5 (docker compose up -d mariadb)
#   - mysql-client or mariadb-client on the old Pi

set -euo pipefail

# Source host (old Pi running MySQL)
OLD_HOST="${OLD_HOST:-rs485.local}"
OLD_HOST_USER="${OLD_HOST_USER:-simon}"
OLD_DB_USER="${OLD_DB_USER:?Set OLD_DB_USER environment variable}"
OLD_DB_PASS="${OLD_DB_PASS:-}"
OLD_DB_NAME="${OLD_DB_NAME:?Set OLD_DB_NAME environment variable}"

# Destination (new MariaDB container on Pi 5)
NEW_DB_ROOT_PASS="${MARIADB_ROOT_PASS:?Set MARIADB_ROOT_PASS environment variable}"
SBFSPOT_DB_NAME="${MARIADB_SBFSPOT_DB_NAME:?Set MARIADB_SBFSPOT_DB_NAME environment variable}"
SBFSPOT_USER="${MARIADB_SBFSPOT_USER:?Set MARIADB_SBFSPOT_USER environment variable}"

DUMP_FILE="/tmp/sbfspot_dump.sql"

echo "=== SBFspot MySQL Migration ==="
echo ""

# Step 1: Dump from old host
echo "Step 1: Dumping database from ${OLD_HOST}..."
if [ -z "$OLD_DB_PASS" ]; then
    echo "  Enter the MySQL password for ${OLD_DB_USER} on ${OLD_HOST}:"
    read -rs OLD_DB_PASS
fi

ssh "${OLD_HOST_USER}@${OLD_HOST}" \
    "mysqldump -u '${OLD_DB_USER}' -p'${OLD_DB_PASS}' --single-transaction --routines --triggers '${OLD_DB_NAME}'" \
    > "$DUMP_FILE"

DUMP_SIZE=$(du -h "$DUMP_FILE" | cut -f1)
echo "  Dump complete: ${DUMP_FILE} (${DUMP_SIZE})"

# Step 2: Restore into MariaDB container
echo ""
echo "Step 2: Restoring into MariaDB container..."
docker exec -i mariadb mariadb -u root -p"${NEW_DB_ROOT_PASS}" "${SBFSPOT_DB_NAME}" < "$DUMP_FILE"
echo "  Restore complete."

# Step 3: Grant access to SBFspot user
# The MYSQL_USER from docker-compose creates the user; this ensures grants are correct
echo ""
echo "Step 3: Verifying ${SBFSPOT_USER} user permissions..."
docker exec -i mariadb mariadb -u root -p"${NEW_DB_ROOT_PASS}" <<EOF
GRANT ALL PRIVILEGES ON \`${SBFSPOT_DB_NAME}\`.* TO '${SBFSPOT_USER}'@'%';
FLUSH PRIVILEGES;
EOF

# Step 4: Verify
echo ""
echo "Step 4: Verifying data..."
docker exec -i mariadb mariadb -u root -p"${NEW_DB_ROOT_PASS}" "${SBFSPOT_DB_NAME}" -e "
SELECT 'SpotData' AS tbl, COUNT(*) AS row_count, MIN(TimeStamp) AS earliest, MAX(TimeStamp) AS latest FROM SpotData
UNION ALL
SELECT 'DayData', COUNT(*), MIN(TimeStamp), MAX(TimeStamp) FROM DayData
UNION ALL
SELECT 'MonthData', COUNT(*), MIN(TimeStamp), MAX(TimeStamp) FROM MonthData;
"

echo ""
echo "=== Migration complete ==="
echo "Clean up dump file with: rm ${DUMP_FILE}"
