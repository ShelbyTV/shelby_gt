set :application, "shelby_gt"
default_run_options[:pty] = true

#############################################################
#	Passenger
#############################################################

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
#	Bundler
#############################################################
require "bundler/capistrano"

#############################################################
#	Multistage Deploy via capistrano-ext
#############################################################

set :stages, %w(production)
set :default_stage, 'production'
require 'capistrano/ext/multistage'