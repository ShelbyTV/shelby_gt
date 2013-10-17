set :deploy_to, "/home/gt/shelby_gt"

#############################################################
#	Servers
#############################################################

role :app, "50.57.52.177"

#############################################################
#	Git
#############################################################

set :repository,  "git@github.com:ShelbyTV/shelby_gt.git"
set :branch, "master"

#TODO: copy lib/etc/arnold_gt.conf to /etc/init/arnold_gt.conf
#TODO: print message about NOT restarting pump_iron and how to do so w/ upstart
