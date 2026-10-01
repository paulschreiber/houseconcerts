#!/usr/bin/env bash
# One-time server setup so the Solid Queue worker runs as its own
# unprivileged user instead of the deploy user (paul).
#
# Run on the server as root, after a deploy that includes this file:
#   sudo bash /data/sites/houseconcerts/current/config/deploy/setup_solidqueue_user.sh
#
# Then install the updated unit (see the comments at the top of
# config/deploy/templates/houseconcerts-solidqueue.service).
#
# Safe to run more than once. It changes nothing for the web app: Passenger
# keeps running as the deploy user, which joins the shared group.

set -euo pipefail

DEPLOY_USER=paul
SERVICE_USER=houseconcerts-jobs
GROUP=houseconcerts
APP=/data/sites/houseconcerts
SHARED=$APP/shared

if [[ $EUID -ne 0 ]]; then
  echo "Run this as root (sudo)." >&2
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

# 3. tmp (the worker's bootsnap cache): owned by the worker.
mkdir -p "$SHARED/tmp/cache"
chown -R "$SERVICE_USER:$GROUP" "$SHARED/tmp"
chmod 2770 "$SHARED/tmp" "$SHARED/tmp/cache"

# 4. Secrets: readable by the group, not by everyone.
for file in config/master.key config/database.yml config/credentials.yml.enc; do
  chgrp "$GROUP" "$SHARED/$file"
  chmod 0640 "$SHARED/$file"
done

# 5. Check the worker can read what it needs. Release files are normally
#    world-readable; if any check fails, fix that path's permissions.
failed=0
check() {
  if sudo -u "$SERVICE_USER" test "$1" "$2"; then
    echo "ok       $SERVICE_USER $3 $2"
  else
    echo "FAILED   $SERVICE_USER $3 $2" >&2
    failed=1
  fi
}
check -r "$APP/current/Gemfile.lock" "can read"
check -r "$APP/current/config/master.key" "can read"
check -r "$APP/current/config/database.yml" "can read"
check -x "$SHARED/vendor/bundle" "can enter"
check -w "$SHARED/log" "can write"
check -w "$SHARED/tmp/cache" "can write"
check -x /usr/bin/ruby "can run"

cat <<EOF

Also check:
- The unit sets ProtectHome=yes, which hides /home from the worker. If Ruby
  or any gems live under /home (e.g. rbenv in ~$DEPLOY_USER), change it to
  ProtectHome=read-only.
- If config/database.yml connects to MySQL without a password (socket
  authentication as $DEPLOY_USER), give the app's MySQL user a password, or
  the worker won't be able to connect.
- If logrotate manages $SHARED/log, its "create" line should be
  "create 0664 $DEPLOY_USER $GROUP" so rotated logs stay group-writable.
- $DEPLOY_USER's new group membership applies to new logins and to Passenger
  after it restarts.
EOF

exit "$failed"
