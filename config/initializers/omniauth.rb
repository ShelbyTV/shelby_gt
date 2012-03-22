Rails.application.config.middleware.use OmniAuth::Builder do
  provider :twitter, Settings::Twitter.consumer_key, Settings::Twitter.consumer_secret
  provider :facebook, Settings::Facebook.app_id, Settings::Facebook.app_secret, :scope => 'read_stream,publish_stream,offline_access,email,publish_actions'
  provider :tumblr, Settings::Tumblr.key, Settings::Tumblr.secret
end