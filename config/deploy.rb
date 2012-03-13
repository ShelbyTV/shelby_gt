set :application, "shelby_gt"
default_run_options[:pty] = true

#############################################################
#	Bundler
#############################################################
require "bundler/capistrano"

#############################################################
#	Multistage Deploy via capistrano-ext
#############################################################

set :stages, %w(production)
set :default_stage, 'production'
require 'capistrano/ext/multistage'