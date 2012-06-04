require 'user_manager'

class V1::TokenController < ApplicationController  

  ##
  # Ensures User matching the given credentials has a single sign on token and returns it.
  # N.B. Until we allow for email/password authentication, must provide 3rd party credentials.
  #
  # If given credentials are valid, but don't match any user, a new User will be created.
  #
  # That token can be used to authenticate against the api by including with an HTTP request as the value
  # for the parameter auth_token.  For example: http://api.gt.shelby.tv/v1/dashboard?auth_token=sF7waBf8jBMqsxeskPp2
  #
  # [POST] /v1/token
  #
  # @param [Required, String] provider_name The name of the 3rd party provider the user is authorized with (ie. "twitter")
  # @param [Required, String] uid The id of the User at the 3rd party
  # @param [Required, String] token The oAuth token of this User at said provider
  # @param [Optional, String] secret The oAuth secret of this User at said provider (if used by the provider)
  # @return [User] User w/ authentication token
  def create
    provider = params[:provider_name]
    uid = params[:uid]
    token = params[:token]
    secret = params[:secret]
    
    @user = User.first( :conditions => { 'authentications.provider' => provider, 'authentications.uid' => uid } )
    
    if @user
      if GT::UserManager.verify_user(@user, provider, uid, token, secret)
        
        if @user.faux == User::FAUX_STATUS[:true]
          return render_error(404, "Unable to convert faux user to real user.")
          #TODO: get details normally retrieved by omniauth and convert: GT::UserManager.convert_faux_user_to_real(@user, omniauth)
        else
          GT::UserManager.start_user_sign_in(@user, :provider => provider, :uid => uid, :token => token, :secret => secret)
        end
        
        sign_in(:user, @user)
        @user.ensure_authentication_token!
        @status = 200
        #renders v1/user/show which includes user.authentication_token
      else
        return render_error(404, "Failed to verify user.")
      end
    else
      return render_error(404, "Unable to create new users.")
      
      #TODO: create a new user via GT::UserManager
      # THOUGHT: we may be able to use omniauth to get user info and then call GT::UserManager.create_new_user_from_omniauth(o)
      #          actually, we may be able to use omniauth to do the verification step (ie. get user info via omniauth, on success, it's verified)
      #          then we don't actually need to validate, below
      #          https://github.com/intridea/omniauth/wiki/Auth-Hash-Schema
      #       --OR-- just hit the endpoint myself and map to omniauth so we can use the same code path.
      #TODO: if created, validate via GT::UserManager
      #TODO: if NOT created, return false
    end
  end
  
  ##
  # Remove the single sign on token from its User.
  #
  # [POST] /v1/token/:id
  #
  # @param [Required, String] auth_token The auth_token for this User
  # @return [Boolean] returns if the token was successfull destroyed
  def destroy
    @user=User.find_by_authentication_token(params[:id])
    if @user.nil?
      render_error(404, "Invalid token.")
    else
      @user.reset_authentication_token!
      @status = 200
      #renders v1/user/show which includes user.authentication_token
    end
  end
  
end