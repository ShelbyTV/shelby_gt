# Load the rails application
require File.expand_path('../application', __FILE__)

# Initialize the rails application
ShelbyGt::Application.initialize!

ActionMailer::Base.smtp_settings = {
  :address => "smtp.sendgrid.net",
  :port => 25,
  :domain => "shelby.tv",
  :authentication => :plain,
  :user_name => Settings::Sendgrid.username,
  :password => Settings::Sendgrid.password
}