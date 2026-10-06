#!/usr/bin/env bash
# One-time server setup for the deploy user (the "user" in
# config/deploy/production.rb): Capistrano logs in as it, it owns the app
# directory, and Passenger runs the web app as it (as the owner of
# config.ru). It can't log in with a password, and its only sudo rights are
# restarting the Solid Queue worker.
#
# Run on the server as root (sudo), with the public keys allowed to deploy
# (e.g. your own and the GitHub Actions deploy key) as arguments:
#   sudo bash setup_deploy_user.sh laptop.pub houseconcerts_deploy_key.pub
# Each key is added with "restrict" (no terminal or forwarding, which
# Capistrano doesn't need).
#
# Then run setup_solidqueue_user.sh. See "Server" in INFRASTRUCTURE.md.
#
# Safe to run more than once.

set -euo pipefail

DEPLOY_USER=${DEPLOY_USER:-houseconcerts-deploy}
GROUP=houseconcerts
APP=/data/sites/houseconcerts
SUDOERS=/etc/sudoers.d/$DEPLOY_USER

if [[ $EUID -ne 0 ]]; then
  echo "Run this as root (sudo)." >&2
  exit 1
fi
for key in "$@"; do
  if ! ssh-keygen -l -f "$key" >/dev/null 2>&1; then
    echo "$key isn't a public key." >&2
    exit 1
  fi
done

# 1. The user, with a home directory for its SSH keys and a shell for
#    Capistrano's commands. "*" as its password means it has none (no
#    password login) without locking the account, which would also block SSH
#    keys on servers without PAM.
getent group "$GROUP" >/dev/null || groupadd --system "$GROUP"
if ! id "$DEPLOY_USER" >/dev/null 2>&1; then
  useradd --create-home --user-group --shell /bin/bash "$DEPLOY_USER"
fi
usermod --password '*' --append --groups "$GROUP" "$DEPLOY_USER"
HOME_DIR=$(getent passwd "$DEPLOY_USER" | cut -d: -f6)

# 2. SSH keys
install -d -m 700 -o "$DEPLOY_USER" -g "$DEPLOY_USER" "$HOME_DIR/.ssh"
KEYS=$HOME_DIR/.ssh/authorized_keys
touch "$KEYS"
for key in "$@"; do
  line=$(<"$key")
  grep -qF -- "$line" "$KEYS" || echo "restrict $line" >>"$KEYS"
done
chown "$DEPLOY_USER:$DEPLOY_USER" "$KEYS"
chmod 600 "$KEYS"

# 3. The app directory: releases, shared files, the git cache and the
#    current symlink. Only the owner changes; setup_solidqueue_user.sh sets
#    the group on the files the worker shares.
chown -R "$DEPLOY_USER" "$APP"

# 4. Restarting the worker, for the solid_queue:restart Capistrano task.
#    Checked with visudo before it's installed, since a broken sudoers file
#    can lock everyone out of sudo.
SYSTEMCTL=$(command -v systemctl) || { echo "systemctl not found." >&2; exit 1; }
tmp=$(mktemp)
echo "$DEPLOY_USER ALL=(root) NOPASSWD: $SYSTEMCTL restart houseconcerts-solidqueue" >"$tmp"
visudo -cqf "$tmp"
install -m 0440 -o root -g root "$tmp" "$SUDOERS"
rm "$tmp"

# 5. Check the tools a deploy needs are on the deploy user's PATH.
sudo -u "$DEPLOY_USER" -H bash -c 'for tool in git ruby bundle; do command -v "$tool" >/dev/null || { echo "$tool not found" >&2; exit 1; }; done; bundle --version'
echo "ok: $DEPLOY_USER is set up with $(grep -c . "$KEYS") key(s)"
