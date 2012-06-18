#require 'bundler/capistrano'

set :deploy_to, "/home/gt/api"

#############################################################
#	Servers
#############################################################

role :web, "108.166.56.26"
role :app, "108.166.56.26"
role :db,  "108.166.56.26", :primary => true

set :user, "gt"

#############################################################
#	Git
#############################################################

set :scm, :git
set :repository,  "git@github.com:ShelbyTV/shelby_gt.git"
set :branch, "master"
#set :git_enable_submodules, 1
set :deploy_via, :remote_cache #keep a local cache to speed up deploys

#############################################################
#	Copy our error pages to nginx
# Thinking we could just change nginx config to load from app directory instead of doing this copying...
#############################################################
#namespace :five_hundred do
#  desc "copies public/___.html to /opt/nginx/html/___.html"
#  task :copy_to_nginx do
#    run "cp #{release_path}/public/500.html /opt/nginx/html/50x.html"
#    run "cp #{release_path}/public/maintenance.html /opt/nginx/html/maintenance.html"
#  end
#end

###################################
# Send stat to graphite.shelby.tv #
###################################
#namespace :stats do
#  task :send_deploy_message, :roles => :app do
#    require 'socket'
#    socket = UDPSocket.new
#    message = "deploy.production:1|c"
#    socket.send(message, 0, '50.56.19.195', 8125)
#  end
#end

after "deploy:symlink" do
  #stats.send_deploy_message
  #five_hundred.copy_to_nginx
end

#############################################################
#	Crontab via Whenever
#############################################################

#set :whenever_command, "bundle exec whenever -f config/schedule.rb"
#set :whenever_roles, :app
#require "whenever/capistrano"
