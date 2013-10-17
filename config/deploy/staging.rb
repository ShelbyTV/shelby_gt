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
set :branch, "staging"

set :rails_env, "staging"
set :unicorn_env, "staging"
set :app_env,     "staging"

after 'deploy:restart', 'unicorn:duplicate'