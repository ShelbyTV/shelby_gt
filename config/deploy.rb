require "bundler/capistrano"

set :application, "shelby_gt"
set :user, "gt"
default_run_options[:pty] = true

#############################################################
# Git
#############################################################

set :scm, :git

#keep a local cache to speed up deploys
set :deploy_via, :remote_cache
# Use developer's local ssh keys when git clone/updating on the remote server
ssh_options[:forward_agent] = true

#############################################################
#	Multistage Deploy via capistrano-ext
#############################################################

set :stages, %w(production staging arnold1 arnold2 arnold3 arnold4 email)
set :default_stage, 'production'
require 'capistrano/ext/multistage'