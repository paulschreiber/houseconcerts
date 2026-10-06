#!/usr/bin/env bash
# One-time server setup so the Solid Queue worker runs as its own
# unprivileged user instead of the deploy user (the "user" in
# config/deploy/production.rb).
#
# Run on the server as root (sudo), after setup_deploy_user.sh:
#   sudo bash setup_solidqueue_user.sh
#
# Then install the updated unit (see the comments at the top of
# config/deploy/templates/houseconcerts-solidqueue.service). See "Server" in
# INFRASTRUCTURE.md.
#
# Safe to run more than once. It changes nothing for the web app: Passenger
# keeps running as the deploy user, which joins the shared group (from new
# logins, and for Passenger once it restarts).
#
# Before relying on the worker, also check:
# - If config/database.yml connects to MySQL without a password (socket
#   authentication as the deploy user), give the app's MySQL user a password,
#   or the worker can't connect. The check at the end catches this.
# - If logrotate manages shared/log, its "create" line should be
#   "create 0664 houseconcerts-deploy houseconcerts" so rotated logs stay
#   group-writable.

set -euo pipefail

DEPLOY_USER=${DEPLOY_USER:-houseconcerts-deploy}
SERVICE_USER=houseconcerts-jobs
GROUP=houseconcerts
APP=/data/sites/houseconcerts
SHARED=$APP/shared

if [[ $EUID -ne 0 ]]; then
  echo "Run this as root (sudo)." >&2
  exit 1
fi
if ! id "$DEPLOY_USER" >/dev/null 2>&1; then
  echo "$DEPLOY_USER doesn't exist yet: run setup_deploy_user.sh first." >&2
  exit 1
fi

# 1. The group shared by the deploy user and the worker, and the worker's
#    system user (no login shell, no home directory).
getent group "$GROUP" >/dev/null || groupadd --system "$GROUP"
if ! id "$SERVICE_USER" >/dev/null 2>&1; then
  useradd --system --gid "$GROUP" --no-create-home --home-dir /nonexistent \
    --shell /usr/sbin/nologin "$SERVICE_USER"
fi
usermod --append --groups "$GROUP" "$DEPLOY_USER"

# 2. Logs: both Passenger (as the deploy user) and the worker append to
#    log/production.log, so the directory is group-writable and setgid (new
#    files inherit the group), and the existing logs become group-writable.
chgrp -R "$GROUP" "$SHARED/log"
chmod 2775 "$SHARED/log"
find "$SHARED/log" -type f -exec chmod g+w {} +

# 3. Secrets: readable by the group, not by everyone.
for file in config/master.key config/database.yml config/credentials.yml.enc; do
  chgrp "$GROUP" "$SHARED/$file"
  chmod 0640 "$SHARED/$file"
done

# 4. Check the worker can boot the app and reach the database, as the
#    service will: this reads the gems, master.key and database.yml, connects
#    to MySQL, and writes to the log. (DISABLE_BOOTSNAP, since systemd only
#    creates the worker's cache directory when the service runs.)
sudo -u "$SERVICE_USER" env RAILS_ENV=production DISABLE_BOOTSNAP=1 \
  bash -c "cd $APP/current && /usr/bin/ruby bin/rails runner 'SolidQueue::Job.count'"
echo "ok: $SERVICE_USER can boot the app and reach the database"
