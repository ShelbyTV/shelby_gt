load 'deploy/assets'
require 'capistrano-unicorn'
require 'capistrano-resque'

set :deploy_to, "/home/gt/api"

#############################################################
# Servers
#############################################################

role :web, "166.78.255.147"
role :app, "166.78.255.147"
role :resque_worker, "166.78.255.147"
role :resque_scheduler, "166.78.255.147"

#############################################################
# Git
#############################################################

set :repository,  "git@github.com:ShelbyTV/shelby_gt.git"
set :branch, "staging"

set :rails_env, "staging"
set :unicorn_env, "staging"
set :app_env,     "staging"

#############################################################
# resque
#############################################################

set :workers, { "*" => 4 }
set :resque_environment_task, true

after 'deploy:restart', 'unicorn:duplicate'
after "deploy:restart", "resque:restart"