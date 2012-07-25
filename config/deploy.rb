set :application, "gt"

# Use developer's local ssh keys when git clone/updating on the remote server
default_run_options[:pty] = true
ssh_options[:forward_agent] = true

$:.unshift(File.expand_path('./lib', ENV['rvm_path']))
require "rvm/capistrano"
set :rvm_type, :user
set :rvm_ruby_string, '1.9.3-p194'
set :current_path, '/home/gt/api/current'

#############################################################
#	Passenger
#############################################################

#namespace :passenger do
#  desc "Restart Application"
#  task :restart do
#    run "touch #{current_path}/tmp/restart.txt"
#    #run 'curl -sL -w "I just tapped %{url_effective}: %{http_code}\\n" "http://shelby.tv" -o /dev/null'
#  end
#end

#namespace :deploy do
#  desc "Restart passenger"
#  task :restart do
#    passenger.restart
#  end
#end

#############################################################
#	Bundler
#############################################################

namespace :bundler do
  task :create_symlink, :roles => :app do
    shared_dir = File.join(shared_path, 'bundle')
    release_dir = File.join(current_release, '.bundle')
    run("mkdir -p #{shared_dir} && ln -s #{shared_dir} #{release_dir}")
  end
  
  task :bundle_new_release, :roles => :app do
    bundler.create_symlink
    run "cd #{release_path} && bundle install --without test"
  end
  
  task :lock, :roles => :app do
    run "cd #{current_release} && bundle lock;"
  end
  
  task :unlock, :roles => :app do
    run "cd #{current_release} && bundle unlock;"
  end
end

after "deploy:update_code" do
  bundler.bundle_new_release
end
#############################################################
#	Multistage Deploy via capistrano-ext
#############################################################

set :stages, %w(production arnold1 arnold2 arnold3 arnold4)
set :default_stage, 'production'
require 'capistrano/ext/multistage'
require 'capistrano-unicorn'