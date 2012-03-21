set :application, "shelby_gt"
default_run_options[:pty] = true

#############################################################
#	Passenger
#############################################################

namespace :passenger do
  desc "Restart Application"
  task :restart do
    run "touch #{current_path}/tmp/restart.txt"
    #run 'curl -sL -w "I just tapped %{url_effective}: %{http_code}\\n" "http://shelby.tv" -o /dev/null'
  end
end

namespace :deploy do
  desc "Restart passenger"
  task :restart do
    passenger.restart
  end
end

#############################################################
#	Bundler
#############################################################

namespace :bundler do
  task :create_symlink, :roles => :app do
    shared_dir = File.join(shared_path, 'bundle')
    release_dir = File.join(current_release, '.bundle')
    run("mkdir -p #{shared_dir} && ln -s #{shared_dir} #{release_dir}")
  end
  
  task :bundle_new_release, :roles => :app do
    bundler.create_symlink
    run "cd #{release_path} && bundle install --without test"
  end
  
  task :lock, :roles => :app do
    run "cd #{current_release} && bundle lock;"
  end
  
  task :unlock, :roles => :app do
    run "cd #{current_release} && bundle unlock;"
  end
end

after "deploy:update_code" do
  bundler.bundle_new_release
end
#############################################################
#	Multistage Deploy via capistrano-ext
#############################################################

set :stages, %w(production arnold)
set :default_stage, 'production'
require 'capistrano/ext/multistage'