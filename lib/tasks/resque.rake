require 'resque/tasks'
task "resque:setup" => :environment do
  logger = Logger.new("log/resque.log")
  logger.level = Logger::WARN
  Rails.logger = Resque.logger = logger
end