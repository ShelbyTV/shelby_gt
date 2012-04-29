# Load the rails application
require File.expand_path('../application', __FILE__)

# Initialize the rails application
ShelbyGt::Application.initialize!

#############
# Email Setup via Sendgrid:
ActionMailer::Base.smtp_settings = {
  :address => "smtp.sendgrid.net",
  :port => 587,
  :domain => "shelby.tv",
  :authentication => :plain,
  :user_name => Settings::Sendgrid.username,
  :password => Settings::Sendgrid.password,
  :enable_starttls_auto => true
}
# FYI: if port 25 blocked by isp use:
# port 587 with :enable_starttls_auto => true