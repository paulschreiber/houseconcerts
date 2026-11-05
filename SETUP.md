# Server setup

How to set up a server for deploys: a dedicated deploy user, the Solid Queue
worker as its own user, and deploys from GitHub Actions. See “Server” in
[`INFRASTRUCTURE.md`](INFRASTRUCTURE.md) for how the result fits together, and
“Apache” there for the web server.

Run the development machine steps from a checkout of `main`. They use
`$SERVER`, the host in `config/deploy/production.rb`. Set it in each terminal
you use:

```bash
SERVER=deploy.example.com  # replace with your actual server
```

## 1. Prepare the server

Over SSH, as yourself (with sudo):

- `ruby -v; bundle -v` shows the system Ruby (`/usr/bin/ruby`) and Bundler 4,
  which the deploy user needs on its `PATH`. `setup_deploy_user.sh` checks this
  too, but only after it has made its changes.
- `systemctl show apache2 -p MemoryDenyWriteExecute` says `no`. If it says
  `yes`, Passenger can’t start the app: see “Native gems and systemd hardening”
  in [`INFRASTRUCTURE.md`](INFRASTRUCTURE.md).
- `/data/sites/houseconcerts/shared/config/` holds the files every release
  links to: `database.yml`, `master.key` and `credentials.yml.enc`.
  `database.yml` connects to MySQL with a password, not socket authentication,
  so both new users can connect.
- If logrotate manages `/data/sites/houseconcerts/shared/log`, its `create` line
  is `create 0664 houseconcerts-deploy houseconcerts`, so rotated logs stay
  writable by both users.

## 2. Make the SSH keys

On your development machine, your own key for deploying from it (skip it if
`~/.ssh/id_ed25519` already exists), then the GitHub Actions deploy key:

```bash
ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519
ssh-keygen -t ed25519 -N "" -C "github-actions houseconcerts deploy" -f ~/houseconcerts_deploy_key
```

## 3. Create the deploy user

From your development machine:

```bash
ssh "$SERVER" mkdir -p houseconcerts-setup
scp config/deploy/setup_deploy_user.sh ~/.ssh/id_ed25519.pub ~/houseconcerts_deploy_key.pub \
  "$SERVER":houseconcerts-setup/
```

Then on the server:

```bash
sudo bash ~/houseconcerts-setup/setup_deploy_user.sh \
  ~/houseconcerts-setup/id_ed25519.pub ~/houseconcerts-setup/houseconcerts_deploy_key.pub
```

## 4. Deploy from your development machine

Capistrano only connects if the server’s ED25519 host key is in your
`~/.ssh/known_hosts` (`ssh-keygen -F "$SERVER" -l` lists it). If it isn’t, copy
it over your existing, trusted connection first:

```bash
ssh "$SERVER" cat /etc/ssh/ssh_host_ed25519_key.pub | awk -v host="$SERVER" '{print host, $1, $2}' >> ~/.ssh/known_hosts
bundle exec cap production deploy
```

On a new server, this first deploy ends with an error from
`solid_queue:restart`, because the worker isn’t installed yet. The release is
already live by then.

## 5. Set up the worker

From your development machine:

```bash
scp config/deploy/setup_solidqueue_user.sh config/deploy/templates/houseconcerts-solidqueue.service \
  "$SERVER":houseconcerts-setup/
```

Then on the server. Stop if the script fails:

```bash
cd ~/houseconcerts-setup
sudo bash setup_solidqueue_user.sh
sudo cp houseconcerts-solidqueue.service /etc/systemd/system/
sudo systemd-analyze verify /etc/systemd/system/houseconcerts-solidqueue.service
sudo systemctl enable --now houseconcerts-solidqueue
```

`setup_solidqueue_user.sh` ends by booting the app as `houseconcerts-jobs` and
connecting to the database; if that fails, see the notes at the top of the
script.

## 6. Check it

On the server:

- `systemctl status houseconcerts-solidqueue`: running, as `houseconcerts-jobs`
- `ps -eo user:24,cmd | grep -i '[p]assenger'`: the app runs as `houseconcerts-deploy`
- `sudo -l -U houseconcerts-deploy`: only the restart rule

## 7. Set up GitHub

Create the `production` environment and its `main`-only rule first, then add
the secret and variable to it (never as repository secrets). The environment
makes you approve each deploy; drop the `reviewers` entry to skip that.

```bash
REPO=$(gh repo view --json nameWithOwner --jq .nameWithOwner)
GH_USER_ID=$(gh api user --jq .id)
gh api -X PUT "repos/$REPO/environments/production" --input - <<EOF
{"reviewers":[{"type":"User","id":$GH_USER_ID}],"prevent_self_review":false,
 "deployment_branch_policy":{"protected_branches":false,"custom_branch_policies":true}}
EOF
gh api -X POST "repos/$REPO/environments/production/deployment-branch-policies" -f name=main -f type=branch

gh secret set DEPLOY_SSH_KEY --env production < ~/houseconcerts_deploy_key
ssh-keygen -F "$SERVER" | grep -v '^#' | gh variable set DEPLOY_KNOWN_HOSTS --env production
```

`DEPLOY_KNOWN_HOSTS` gets every line for the server in your `known_hosts`. Check
with `ssh-keygen -F "$SERVER" -l` that they include its ED25519 key (from step
4): net-ssh asks for that one first.

## 8. Deploy from GitHub

**Actions → Deploy → Run workflow**, on `main` (and approve it, if you kept the
reviewer).

## 9. Clean up

From your development machine, remove the setup files from the server and both
halves of the GitHub Actions deploy key, which GitHub now holds:

```bash
ssh "$SERVER" rm -r houseconcerts-setup
rm ~/houseconcerts_deploy_key ~/houseconcerts_deploy_key.pub
```

## Add a deploy key

`setup_deploy_user.sh` is safe to run again: it adds the keys you give it and
keeps the others. From your development machine, with the new public key in
`new_key.pub`:

```bash
ssh "$SERVER" mkdir -p houseconcerts-setup
scp config/deploy/setup_deploy_user.sh new_key.pub "$SERVER":houseconcerts-setup/
```

Then on the server:

```bash
sudo bash ~/houseconcerts-setup/setup_deploy_user.sh ~/houseconcerts-setup/new_key.pub
rm -r ~/houseconcerts-setup
```

To replace the GitHub Actions key, add the new one this way, set
`DEPLOY_SSH_KEY` to its private half as in step 7, then delete the old key’s
line from `~houseconcerts-deploy/.ssh/authorized_keys`.
