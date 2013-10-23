load 'deploy/assets'
require 'capistrano-unicorn'

set :deploy_to, "/home/gt/api"

#############################################################
# Servers
#############################################################

role :web, "198.61.235.104"
role :app, "198.61.235.104"

#############################################################
# Git
#############################################################

set :repository,  "git@github.com:ShelbyTV/shelby_gt.git"
set :branch, "master"

set :rails_env, "production"
set :unicorn_env, "production"
set :app_env,     "production"

namespace :deploy do
  desc "Deploy the currently checked out branch"
  task :current_branch do
    set :branch, `git rev-parse --abbrev-ref HEAD`.rstrip
    deploy.default
  end
end

after 'deploy:restart', 'unicorn:duplicate'