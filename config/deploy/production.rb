load 'deploy/assets'
require 'capistrano-unicorn'
require 'capistrano-resque'

set :deploy_to, "/home/gt/api"

#############################################################
# Servers
#############################################################

role :web, "198.61.235.104", "198.61.236.118"
role :app, "198.61.235.104", "198.61.236.118"
role :resque_worker, "198.61.235.104", "198.61.236.118"

#############################################################
# Git
#############################################################

set :repository,  "git@github.com:ShelbyTV/shelby_gt.git"
set :branch, "master"

set :rails_env, "production"
set :unicorn_env, "production"
set :app_env,     "production"

#############################################################
# resque
#############################################################

set :workers, { "dashboard_entries_queue" => 4, "apple_push_notifications_queue" => 4 }
set :interval, 1
set :resque_environment_task, true
after "deploy:restart", "resque:restart"

after 'deploy:restart', 'unicorn:duplicate'