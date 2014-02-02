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

#############################################################
# Git
#############################################################

set :repository,  "git@github.com:ShelbyTV/shelby_gt.git"
# run cap with '-S branch=somebranchname' to deploy to staging server from
# branch 'somebranchname' instead of branch 'staging'
set :branch, fetch(:branch, "staging")

set :rails_env, "staging"
set :unicorn_env, "staging"
set :app_env,     "staging"

#############################################################
# resque
#############################################################

# run cap with '-S restart_resque=0' to disable restarting Resque on deploy
if !fetch(:restart_resque, '1').to_i.zero?
  set :workers, { "dashboard_entries_queue" => 4, "apple_push_notifications_queue" => 4, "twitter_unfollow" => 2 }
  set :interval, 1
  set :resque_environment_task, true
  after "deploy:restart", "resque:restart"
end

after 'deploy:restart', 'unicorn:duplicate'

namespace :deploy do
  desc "Deploy the currently checked out branch"
  task :current_branch do
    set :branch, `git rev-parse --abbrev-ref HEAD`.rstrip
    deploy.default
  end
end