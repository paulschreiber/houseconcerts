# config valid only for current version of Capistrano
lock "~>3"

set :application, "houseconcerts"
set :repo_url, "https://github.com/paulschreiber/houseconcerts.git"
set :branch, "main"

# Default branch is :master
# ask :branch, `git rev-parse --abbrev-ref HEAD`.chomp

# Default deploy_to directory is /var/www/my_app_name
# set :deploy_to, '/var/www/my_app_name'

# Default value for :format is :pretty
# set :format, :pretty

# Default value for :log_level is :debug
set :log_level, :info

# Default value for :pty is false
# set :pty, true

# Default value for :linked_files is []
set :linked_files, %w[config/database.yml config/master.key config/credentials.yml.enc]

# Default value for linked_dirs is []
set :linked_dirs, fetch(:linked_dirs, []).push("log", "vendor/bundle")

# Default value for default_env is {}
# set :default_env, { path: "/opt/ruby/bin:$PATH" }

# Default value for keep_releases is 5
# set :keep_releases, 5

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
