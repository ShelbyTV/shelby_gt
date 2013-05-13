require "bundler/capistrano"

set :application, "shelby_gt"
default_run_options[:pty] = true

# Use developer's local ssh keys when git clone/updating on the remote server
ssh_options[:forward_agent] = true

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

namespace :util do
  desc "Utils to be run"
  task :create_new_user do
    server = find_servers(:roles => [:app]).first
    run_with_tty server, %W(cd #{deploy_to}/current && #{rake} wizard:create_new_user RAILS_ENV=production)
  end

  def run_with_tty(server, cmd)
    default_run_options[:shell] = '/bin/bash'
    command = []
    command += %W( ssh -t )
    command += %W( -l #{user} #{server.host} )
    # have to escape this once if running via double ssh
    command += [self[:gateway] ? '\&\&' : '&&']
    command += Array(cmd)
    system *command
  end
end

#############################################################
#	Multistage Deploy via capistrano-ext
#############################################################

set :stages, %w(production arnold1 arnold2 arnold3 arnold4)
set :default_stage, 'production'
require 'capistrano/ext/multistage'
