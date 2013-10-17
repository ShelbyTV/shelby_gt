# Set your full path to application.
app_path = "/home/gt/api/current"

# Set unicorn options
worker_processes 4
preload_app true
timeout 60
listen "/tmp/shelby-gt-api.socket", :backlog => 64
#listen 8080, :tcp_nopush => true

# Spawn unicorn master worker for user apps (group: apps)
user 'gt'

# Fill path to your app
working_directory app_path

# Should be 'staging' by default, otherwise use other env
rails_env = ENV['RAILS_ENV'] || 'staging'

# Log everything to one file
stderr_path "#{app_path}/log/unicorn.log"
stdout_path "#{app_path}/log/unicorn.log"

# Set master PID location
pid "/home/gt/api/shared/pids/unicorn.pid"

before_fork do |server, worker|
  EM.stop if EM.reactor_running?

  old_pid = "#{server.config[:pid]}.oldbin"
  if File.exists?(old_pid) && server.pid != old_pid
    begin
      Process.kill("QUIT", File.read(old_pid).to_i)
    rescue Errno::ENOENT, Errno::ESRCH
      # someone else did our job for us
    end
  end
end

after_fork do |server, worker|
  Thread.new { EM.run }
end
