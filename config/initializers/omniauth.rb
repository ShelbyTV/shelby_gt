Rails.application.config.middleware.use OmniAuth::Builder do
  provider :twitter, Settings::ExternalAccounts.twitter_consumer_key, Settings::ExternalAccounts.twitter_consumer_secret
  provider :facebook, Settings::ExternalAccounts.facebook_app_id, Settings::ExternalAccounts.facebook_app_secret, :scope => 'read_stream,publish_stream,offline_access,email,publish_actions'
  provider :tumblr, Settings::ExternalAccounts.tumblr_key, Settings::ExternalAccounts.tumblr_secret
  
end