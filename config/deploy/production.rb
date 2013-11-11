load 'deploy/assets'
require 'capistrano-unicorn'

set :deploy_to, "/home/gt/api"

#############################################################
# Servers
#############################################################

role :web, "198.61.235.104", "198.61.236.118"
role :app, "198.61.235.104", "198.61.236.118"

#############################################################
# Git
#############################################################

set :repository,  "git@github.com:ShelbyTV/shelby_gt.git"
set :branch, "master"

set :rails_env, "production"
set :unicorn_env, "production"
set :app_env,     "production"

after 'deploy:restart', 'unicorn:duplicate'