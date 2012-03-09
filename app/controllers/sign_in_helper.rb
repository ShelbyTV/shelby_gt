class SigninHelper
  
  
  # in NOS used in Broadcast controller to handle coming from FB OG
  def self.get_fb_user_token(request_url, code)
    begin
      redirect_uri = remove_code_from_redirect_uri(request_url)
      koala = Koala::Facebook::OAuth.new(APP_CONFIG[:facebook_app_id], APP_CONFIG[:facebook_app_secret], request_url)
      access_token = koala.get_access_token_info(code)
      return access_token
    rescue => e
      Rails.logger.error "[FB TOKEN ERROR] Error getting facebook token via Koala"
    end
    return nil
  end

  def self.remove_code_from_redirect_uri(redirect_uri)
    url, params = redirect_uri.split("?")
    params = params.split('&').inject({}) { |hash, param| k, v = param.split('='); hash[k] = v; hash }
    params.delete("code")
    "http://#{APP_CONFIG[:domain]}" + url + '?' + CGI::unescape(params.to_query)
  end
  
end