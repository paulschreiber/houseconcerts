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
# keeps running as the deploy user, which setup_deploy_user.sh added to the
# shared group.
#
# Before relying on the worker, also check:
# - If config/database.yml connects to MySQL without a password (socket
#   authentication as the deploy user), give the app's MySQL user a password,
#   or the worker can't connect. The check at the end catches this.
# - If logrotate manages shared/log, its "create" line should be
#   "create 0664 houseconcerts-deploy houseconcerts" so rotated logs stay
#   group-writable.

set -euo pipefail

DEPLOY_USER=houseconcerts-deploy
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

# Changes to single paths under shared/ run as the deploy user, which owns
# them: it could swap in a symlink that root's chgrp or chmod would follow.
# (chgrp -R and find -type f don't follow symlinks, so they can run as root.)
as_deploy_user() {
  sudo -u "$DEPLOY_USER" "$@"
}

# 2. Logs: both Passenger (as the deploy user) and the worker append to
#    log/production.log, so the directory is group-writable and setgid (new
#    files inherit the group), and the existing logs become group-writable.
chgrp -R "$GROUP" "$SHARED/log"
as_deploy_user chmod 2775 "$SHARED/log"
find "$SHARED/log" -type f -exec chmod g+w {} +

# 3. Secrets: readable by the group, not by everyone.
for file in config/master.key config/database.yml config/credentials.yml.enc; do
  as_deploy_user chgrp "$GROUP" "$SHARED/$file"
  as_deploy_user chmod 0640 "$SHARED/$file"
done

# 4. Check the worker can boot the app and reach the database, as the
#    service will: this reads the gems, master.key and database.yml, connects
#    to MySQL, and writes to the log. The environment matches the unit's, and
#    its cache directory (the unit's CacheDirectory=) is created here, since
#    systemd only creates it when the service starts.
CACHE=/var/cache/$SERVICE_USER
install -d -m 0755 -o "$SERVICE_USER" -g "$GROUP" "$CACHE"
sudo -u "$SERVICE_USER" env RAILS_ENV=production BOOTSNAP_CACHE_DIR="$CACHE" HOME="$CACHE" \
  bash -c "cd $APP/current && /usr/bin/ruby bin/rails runner 'SolidQueue::Job.count'"
echo "ok: $SERVICE_USER can boot the app and reach the database"
