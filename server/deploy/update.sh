#!/usr/bin/env bash
#
# Pull and restart. Run on the droplet after pushing to GitHub:
#   bash /srv/personal-crm/server/deploy/update.sh
set -euo pipefail

APP_DIR=/srv/personal-crm
ENV_FILE=/etc/personal-crm.env
[[ $EUID -eq 0 ]] || { echo "Run as root." >&2; exit 1; }

set -a; . "$ENV_FILE"; set +a

# ⚠ Back up BEFORE migrating, not after. A migration that goes wrong is exactly
# when you want the previous file, and .backup rather than cp because copying a
# database mid-write yields a corrupt one.
mkdir -p "$APP_DIR/data/backups"
sqlite3 "$DJANGO_DB_PATH" ".backup '$APP_DIR/data/backups/db-predeploy-$(date +%F-%H%M).sqlite3'"
echo "==> backed up"

git -C "$APP_DIR" pull --ff-only
"$APP_DIR/venv/bin/pip" install -q -r "$APP_DIR/server/requirements.txt"
sudo -u crm -E "$APP_DIR/venv/bin/python" "$APP_DIR/server/manage.py" migrate --noinput
chown -R crm:crm "$APP_DIR/data"

systemctl restart personal-crm
sleep 2
if systemctl is-active --quiet personal-crm; then
  echo "==> personal-crm running"
else
  # ⚠ Say where to look. A deploy script that fails silently is how a server
  # ends up down for a day.
  echo "==> FAILED. journalctl -u personal-crm -n 40" >&2
  exit 1
fi
