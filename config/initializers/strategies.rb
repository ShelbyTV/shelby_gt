Warden::Strategies.add(:oauth) do
  def valid?
    return true
  end

  def authenticate!
    header = env["HTTP_AUTHORIZATION"]
    md = /OAuth (\w*)/.match (header)
    if md and md[1]
      token_id = md[1]
      user_id = Rack::OAuth2::Server::AccessToken.from_token(token_id).identity
      user = User.find(user_id)
    else  
      user = nil
    end
    user.nil? ? fail!("Can't login") : success!(user)
  end
end
