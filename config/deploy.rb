require "bundler/capistrano"

set :application, "shelby_gt"
set :user, "gt"
default_run_options[:pty] = true

#############################################################
# Git
#############################################################

set :scm, :git

#keep a local cache to speed up deploys
set :deploy_via, :remote_cache
# Use developer's local ssh keys when git clone/updating on the remote server
ssh_options[:forward_agent] = true

namespace :passenger do
  desc "Restart Application"
  task :restart do
    run "touch #{current_path}/tmp/restart.txt"
    #run 'curl -sL -w "I just tapped %{url_effective}: %{http_code}\\n" "http://shelby.tv" -o /dev/null'
  end
end

namespace :deploy do
  desc "Restart passenger"
  task :restart do
    passenger.restart
  end
end


#############################################################
#	Multistage Deploy via capistrano-ext
#############################################################

set :stages, %w(production arnold1 arnold2 arnold3 arnold4 email)
set :default_stage, 'production'
require 'capistrano/ext/multistage'
