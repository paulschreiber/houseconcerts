lock "~>3"

set :bundle_version, 4

# The Gemfile's deploy group is only for running deploys
set :bundle_without, %w[development test deploy].join(":")

set :application, "houseconcerts"
set :repo_url, "https://github.com/paulschreiber/houseconcerts.git"
set :branch, "main"

set :ssh_options,
    # Refuse to connect unless the host key is already in known_hosts, rather
    # than trusting a new one on first connect
    verify_host_key: :always,
    # Look host keys up with net-ssh, not SSHKit's default. SSHKit 1.25.1 only
    # finds a key on a known_hosts line that lists both the server's name and
    # its IP, so it misses lines with only the name, such as those in
    # DEPLOY_KNOWN_HOSTS.
    known_hosts: Net::SSH::KnownHosts

# Default value for :log_level is :debug
set :log_level, :info

# Default value for :linked_files is []
set :linked_files, %w[config/database.yml config/master.key config/credentials.yml.enc]

# Default value for linked_dirs is []
# storage holds uploaded files (artist photos), which must outlive each release.
set :linked_dirs, fetch(:linked_dirs, []).push("log", "storage", "vendor/bundle")

set :passenger_restart_with_touch, true

namespace :assets do
  task :clean do
    on roles(fetch(:assets_roles)) do
      within release_path do
        with rails_env: fetch(:rails_env) do
          execute :rake, "assets:clean"
        end
      end
    end
  end
end
after "deploy:updated", "assets:clean"

namespace :solid_queue do
  desc "Restart the Solid Queue systemd service"
  task :restart do
    on roles(:app) do
      execute :sudo, :systemctl, :restart, "houseconcerts-solidqueue"
    end
  end
end
after "deploy:finished", "solid_queue:restart"
