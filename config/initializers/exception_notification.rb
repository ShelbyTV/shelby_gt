=begin
if Rails.env == "production"
  ShelbyGt::Application.config.middleware.use ExceptionNotifier,
    :email_prefix => "[GT Backend Error] ",
    :sender_address => %{"ShelbyGT Notifier" <whatever-noreply@shelby.com>},
    :exception_recipients => %w{webapp-errors@shelby.tv}
end
=end