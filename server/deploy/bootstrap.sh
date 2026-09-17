#!/usr/bin/env bash
#
# Personal CRM — one-shot setup for a fresh Ubuntu droplet.
#
#   ssh root@<droplet-ip>
#   git clone https://github.com/leoner11/personal.git /srv/personal-crm
#   DOMAIN=crm.example.com bash /srv/personal-crm/server/deploy/bootstrap.sh
#
# ⚠ Point the domain's A record at the droplet BEFORE running this. Caddy asks
# Let's Encrypt for a certificate on first start, and issuance fails if the
# name does not already resolve here.
#
# Safe to re-run: every step checks before it acts.
set -euo pipefail

DOMAIN="${DOMAIN:-}"
APP_DIR=/srv/personal-crm
DATA_DIR=$APP_DIR/data
ENV_FILE=/etc/personal-crm.env

if [[ -z "$DOMAIN" ]]; then
  echo "DOMAIN is required, e.g. DOMAIN=crm.example.com bash $0" >&2
  exit 1
fi
if [[ $EUID -ne 0 ]]; then
  echo "Run as root." >&2
  exit 1
fi

echo "==> 1/8  Swap"
# ⚠ NOT optional on the $4 droplet. It has 512MB and no swap by default; pip
# resolving Django will OOM-kill itself part way through and leave a venv that
# looks installed and is not. 1GB of swap costs 1GB of the 10GB disk.
if ! swapon --show | grep -q /swapfile; then
  fallocate -l 1G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile >/dev/null
  swapon /swapfile
  grep -q '/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
  # Prefer RAM, but use swap rather than dying.
  sysctl -w vm.swappiness=10 >/dev/null
  echo 'vm.swappiness=10' > /etc/sysctl.d/99-swap.conf
  echo "    1GB swapfile created"
else
  echo "    already present"
fi

echo "==> 2/8  Packages"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq python3-venv python3-pip sqlite3 ufw curl debian-keyring \
  debian-archive-keyring apt-transport-https fail2ban >/dev/null

if ! command -v caddy >/dev/null; then
  curl -fsSL https://dl.cloudsmith.io/public/caddy/stable/gpg.key \
    | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
  curl -fsSL https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt \
    > /etc/apt/sources.list.d/caddy-stable.list
  apt-get update -qq && apt-get install -y -qq caddy >/dev/null
fi
echo "    ok"

echo "==> 3/8  Firewall"
# ⚠ Default deny inbound. The sync API is the only thing that should be
# reachable, and it reaches the world through Caddy on 443, never directly.
ufw allow OpenSSH >/dev/null
ufw allow 80/tcp >/dev/null
ufw allow 443/tcp >/dev/null
ufw --force enable >/dev/null
echo "    22, 80, 443 only"

echo "==> 4/8  User and directories"
id -u crm &>/dev/null || useradd --system --home "$APP_DIR" --shell /usr/sbin/nologin crm
mkdir -p "$DATA_DIR"
chown -R crm:crm "$APP_DIR"
echo "    user crm, data in $DATA_DIR"

echo "==> 5/8  Secrets"
# ⚠ Generated here, never committed. Written once and left alone on re-runs:
# regenerating DJANGO_SECRET_KEY would sign out nothing (tokens are not signed
# with it) but regenerating it every deploy is still a bad habit to build.
if [[ ! -f "$ENV_FILE" ]]; then
  cat > "$ENV_FILE" <<EOF
DJANGO_SECRET_KEY=$(python3 -c 'import secrets;print(secrets.token_urlsafe(50))')
DJANGO_ALLOWED_HOSTS=$DOMAIN
DJANGO_DB_PATH=$DATA_DIR/db.sqlite3
# ⚠ Signup is OPEN while this is empty. Set it to an invite code and restart
# once your own account exists — an open endpoint on a public IP will be found
# and used to create junk accounts, even though they can see nothing of yours.
REGISTRATION_SECRET=
# Contact address shown on https://$DOMAIN/privacy. Until it is set, that page
# answers 503 — the App Store needs it before submission.
PRIVACY_CONTACT_EMAIL=
# DJANGO_DEBUG deliberately absent. Present and set to 1, a 500 serves your
# settings and local variables to whoever triggered it.
EOF
  chmod 600 "$ENV_FILE"
  chown root:crm "$ENV_FILE"
  echo "    wrote $ENV_FILE"
else
  echo "    $ENV_FILE exists, left alone"
fi

echo "==> 6/8  Python environment"
python3 -m venv "$APP_DIR/venv" 2>/dev/null || true
"$APP_DIR/venv/bin/pip" install -q --upgrade pip
"$APP_DIR/venv/bin/pip" install -q -r "$APP_DIR/server/requirements.txt"
chown -R crm:crm "$APP_DIR/venv"
echo "    django + gunicorn installed"

echo "==> 7/8  Migrate"
set -a; . "$ENV_FILE"; set +a
sudo -u crm -E "$APP_DIR/venv/bin/python" "$APP_DIR/server/manage.py" migrate --noinput
echo "    schema up to date"

echo "==> 8/8  Services"
install -m 644 "$APP_DIR/server/deploy/personal-crm.service" \
  /etc/systemd/system/personal-crm.service
sed "s/crm\.example\.com/$DOMAIN/" "$APP_DIR/server/deploy/Caddyfile" > /etc/caddy/Caddyfile
mkdir -p /var/log/caddy && chown caddy:caddy /var/log/caddy

# Daily backup. SQLite is one file, so this is the whole disaster plan.
# ⚠ .backup, not cp — copying a file mid-write yields a corrupt database.
cat > /etc/cron.daily/personal-crm-backup <<EOF
#!/bin/sh
mkdir -p $DATA_DIR/backups
sqlite3 $DATA_DIR/db.sqlite3 ".backup '$DATA_DIR/backups/db-\$(date +%F).sqlite3'"
find $DATA_DIR/backups -name 'db-*.sqlite3' -mtime +14 -delete
EOF
chmod +x /etc/cron.daily/personal-crm-backup

systemctl daemon-reload
systemctl enable --now personal-crm >/dev/null
systemctl restart personal-crm
systemctl reload caddy 2>/dev/null || systemctl restart caddy
sleep 2

echo
echo "──────────────────────────────────────────────────────────────"
systemctl is-active --quiet personal-crm \
  && echo "  personal-crm: running" \
  || { echo "  personal-crm: FAILED — journalctl -u personal-crm -n 40"; exit 1; }
systemctl is-active --quiet caddy \
  && echo "  caddy:        running" \
  || echo "  caddy:        FAILED — journalctl -u caddy -n 40"
echo
echo "  https://$DOMAIN/sync should now answer 401 (no token yet):"
echo "    curl -s -o /dev/null -w '%{http_code}\\n' https://$DOMAIN/sync"
echo
echo "  Next: in the Mac app set kSyncBaseUrl to https://$DOMAIN in"
echo "  app/lib/domain/config.dart, rebuild, then Account -> Create an account."
echo "  Afterwards put an invite code in REGISTRATION_SECRET and:"
echo "    systemctl restart personal-crm"
echo "──────────────────────────────────────────────────────────────"
