load 'deploy/assets'
require 'capistrano-unicorn'

set :deploy_to, "/home/gt/api"

#############################################################
# Servers
#############################################################

role :web, "166.78.255.147"
role :app, "166.78.255.147"

#############################################################
# Git
#############################################################

set :repository,  "git@github.com:ShelbyTV/shelby_gt.git"
set :branch, fetch(:branch, "staging")

set :rails_env, "staging"
set :unicorn_env, "staging"
set :app_env,     "staging"

after 'deploy:restart', 'unicorn:duplicate'

namespace :deploy do
  desc "Deploy the currently checked out branch"
  task :current_branch do
    set :branch, `git rev-parse --abbrev-ref HEAD`.rstrip
    deploy.default
  end
end