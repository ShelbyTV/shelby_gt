load 'deploy/assets'
require 'capistrano-unicorn'
require 'capistrano/foreman'

set :deploy_to, "/home/gt/api"

#############################################################
# Servers
#############################################################

role :web, "166.78.255.147"
role :app, "166.78.255.147"
role :resque_worker, "166.78.255.147"

#############################################################
# Git
#############################################################

set :repository,  "git@github.com:ShelbyTV/shelby_gt.git"
set :branch, fetch(:branch, "staging")

set :rails_env, "staging"
set :unicorn_env, "staging"
set :app_env,     "staging"

#############################################################
# resque via foreman/upstart
#############################################################

set :foreman_sudo, 'rvmsudo'
set :foreman_upstart_path, '/etc/init/'
set :foreman_options, {
  app: 'shelby-gt',
  log: "#{shared_path}/log",
  procfile: "#{release_path}/Procfile.production",
  user: fetch(:user, "gt")
}
after "deploy:update", "foreman:export"
after 'deploy:restart', 'foreman:restart'

after 'deploy:restart', 'unicorn:duplicate'

namespace :deploy do
  desc "Deploy the currently checked out branch"
  task :current_branch do
    set :branch, `git rev-parse --abbrev-ref HEAD`.rstrip
    deploy.default
  end
end