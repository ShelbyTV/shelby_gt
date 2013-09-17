RSpec.configure do |config|
  config.include Devise::TestHelpers, :type => :controller
end

# for setting up the omniauth request env in controller tests
def setup_omniauth_env(auth=nil)
  auth = auth || { "provider" => "facebook", "uid" => "1234", "extra" => { "user_hash" => { "email" => "ghost@nobody.com" } } }

  request.env["devise.mapping"] = Devise.mappings[:user]
  env = { "omniauth.auth" => auth }
  request.stub(:env).and_return(env)
  request.env['warden'] = mock(Warden, :authenticate => mock_user, :authenticate! => mock_user)
end

def mock_user(stubs={})
  @mock_user ||= Factory.create(:user)
end