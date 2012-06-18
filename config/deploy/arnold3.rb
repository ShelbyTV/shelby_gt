require 'bundler/capistrano'

set :deploy_to, "/home/gt/shelby_gt"

#############################################################
#	Servers
#############################################################

role :app, "108.166.55.48"

set :user, "gt"

#############################################################
#	Git
#############################################################

set :scm, :git
set :repository,  "git@github.com:ShelbyTV/shelby_gt.git"
set :branch, "master"
set :deploy_via, :remote_cache #keep a local cache to speed up deploys

#TODO: copy lib/etc/arnold_gt.conf to /etc/init/arnold_gt.conf
#TODO: print message about NOT restarting pump_iron and how to do so w/ upstart
