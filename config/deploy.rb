set :application, "shelby_gt"
default_run_options[:pty] = true

#############################################################
#	Bundler
#############################################################
require "bundler/capistrano"

#############################################################
#	Multistage Deploy via capistrano-ext
#############################################################

set :stages, %w(staging)
set :default_stage, 'staging'
require 'capistrano/ext/multistage'