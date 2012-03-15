def set_omniauth(opts = {})
  default = {:provider => :twitter,
             :uuid     => "1234",
             :twitter => {
                            :nickname => "nick",
                            :email => "foobar@example.com",
                            :first_name => "foo",
                            :last_name => "bar"
                          }
            }

  credentials = default.merge(opts)
  provider = credentials[:provider]
  user_hash = credentials[provider]

  OmniAuth.config.test_mode = true

  OmniAuth.config.mock_auth[provider] = {
    'provider' => credentials[:provider],    
    'uid' => credentials[:uuid],
    "info" => {
      "nickname" => user_hash[:nickname],
      "email" => user_hash[:email],
      "first_name" => user_hash[:first_name],
      "last_name" => user_hash[:last_name]
      }
    }
end