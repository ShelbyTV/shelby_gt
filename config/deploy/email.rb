set :deploy_to, "/home/gt/email"

#############################################################
#	Servers
#############################################################

role :app, "162.209.91.72"

#############################################################
#	Git
#############################################################

set :repository,  "git@github.com:ShelbyTV/shelby_gt.git"
set :branch, fetch(:branch, "master")

set :rails_env, "production"
set :app_env,   "production"