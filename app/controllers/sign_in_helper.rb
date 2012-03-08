class SigninHelper
  
  def self.start_user_signin(user, omniauth=nil, referral_broadcast_id=nil, session=nil)
    # It's possible for authenication tokens to change...
    #user.update_authentication_tokens!(omniauth) if omniauth
  
    # Always remember users, onus is on them to log out
    #user.remember_me!
  
    # Whateve needs to happen on demand at sign in
    #user.do_at_sign_in
    #if referral_broadcast_id and (bcast = Broadcast.find(referral_broadcast_id))
      #redirect them to the broadcast they clicked on (will play if it's theirs, re-broadcast otherwise)
    #  session[:user_return_to] = bcast.permalink

      #send referral stat
    #  Stats.increment(Stats::USER_VIA_SHORTLINK)
    #end
    
    #if omniauth
      # Update Signin Stat
    #  Stats.increment(Stats::USER_SIGNIN_TWITTER, user.id, 'twitter_signin') if omniauth['provider'] == 'twitter'
    #  Stats.increment(Stats::USER_SIGNIN_FACEBOOK, user.id, 'facebook_signin') if omniauth['provider'] == 'facebook'
    #else
    #  Stats.increment(Stats::USER_SIGNIN_FACEBOOK, user.id, 'facebook_app_signin')
    #end
    # Track the login for A/B testing
    #track! :login
      
  end
  
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