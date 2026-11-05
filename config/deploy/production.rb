server "shrub.ca",
       roles: %w[app db web],
       ssh_options: { user: "houseconcerts-deploy" }

set :deploy_to, "/data/sites/houseconcerts"
