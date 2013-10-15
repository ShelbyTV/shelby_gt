set :deploy_to, "/home/gt/email"

#############################################################
#	Servers
#############################################################

role :app, "162.209.91.72"

#############################################################
#	Git
#############################################################

set :repository,  "git@github.com:ShelbyTV/shelby_gt.git"
set :branch, "master"

namespace :deploy do
  desc "Deploy the currently checked out branch"
  task :current_branch do
    set :branch, `git rev-parse --abbrev-ref HEAD`.rstrip
    deploy.default
  end
end