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

DEPLOY_USER=houseconcerts-deploy
GROUP=houseconcerts
APP=/data/sites/houseconcerts
SUDOERS=/etc/sudoers.d/$DEPLOY_USER

if [[ $EUID -ne 0 ]]; then
  echo "Run this as root (sudo)." >&2
  exit 1
fi
# Checked one line at a time: ssh-keygen -l also accepts a whole private key
# file, but not a line of one.
keys=()
for file in "$@"; do
  while IFS= read -r line || [[ -n $line ]]; do
    [[ -z $line || $line == \#* ]] && continue
    if ! ssh-keygen -l -f - <<<"$line" >/dev/null 2>&1; then
      echo "$file isn't a public key file." >&2
      exit 1
    fi
    keys+=("$line")
  done <"$file"
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

# 2. SSH keys, written as the deploy user: it owns ~/.ssh, so it could swap
#    in a symlink that root would follow.
as_deploy_user() {
  sudo -u "$DEPLOY_USER" "$@"
}
KEYS=$HOME_DIR/.ssh/authorized_keys
as_deploy_user install -d -m 700 "$HOME_DIR/.ssh"
as_deploy_user touch "$KEYS"
as_deploy_user chmod 600 "$KEYS"
for line in "${keys[@]}"; do
  as_deploy_user grep -qxF -- "restrict $line" "$KEYS" ||
    as_deploy_user tee -a "$KEYS" >/dev/null <<<"restrict $line"
done

# 3. The app directory: releases, shared files, the git cache and the
#    current symlink. Only the owner changes; setup_solidqueue_user.sh sets
#    the group on the files the worker shares.
mkdir -p "$APP"
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

# 5. Check the tools a deploy needs are on the PATH Capistrano's SSH commands
#    get, which sshd takes from /etc/environment (on Debian and Ubuntu), not
#    sudo's secure_path.
as_deploy_user env -i HOME="$HOME_DIR" bash <<'EOF'
set -a
. /etc/environment 2>/dev/null || true
set +a
for tool in git ruby bundle; do
  command -v "$tool" >/dev/null || { echo "$tool not found" >&2; exit 1; }
done
bundle --version
EOF
echo "ok: $DEPLOY_USER is set up with $(as_deploy_user grep -c . "$KEYS") key(s)"
