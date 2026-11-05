server "shrub.ca",
       roles: %w[app db web],
       ssh_options: {
         user: "houseconcerts-deploy",
         # Refuse to connect unless the host key is already in
         # known_hosts, rather than trusting a new one on first connect
         verify_host_key: :always,
         # Look host keys up with net-ssh, not SSHKit's default. SSHKit 1.25.1
         # only finds a key on a known_hosts line that lists both the server's
         # name and its IP, so it misses lines with only the name, such as
         # those in DEPLOY_KNOWN_HOSTS.
         known_hosts: Net::SSH::KnownHosts
       }

set :deploy_to, "/data/sites/houseconcerts"
