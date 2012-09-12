require 'user_manager'

class V1::TokenController < ApplicationController  
  skip_before_filter :verify_authenticity_token
  

  ##
  # Ensures User matching the given credentials has a single sign on token and returns it.
  # Either supply 3rd party credentials or email/password.
  #
  # If given credentials are valid, but don't match any user, a new User will be created.
  #
  # That token can be used to authenticate against the api by including with an HTTP request as the value
  # for the parameter auth_token.  For example: http://api.gt.shelby.tv/v1/dashboard?auth_token=sF7waBf8jBMqsxeskPp2
  #
  # [POST] /v1/token
  #
  # All following third party credentials are Optional if you're using email/password
  #   @param [Required, String] provider_name The name of the 3rd party provider the user is authorized with (ie. "twitter")
  #   @param [Required, String] uid The id of the User at the 3rd party
  #   @param [Required, String] token The oAuth token of this User at said provider
  #   @param [Optional, String] secret The oAuth secret of this User at said provider (if used by the provider)
  #
  # Email/password are both Optional if you're using third party credentials
  #   @param [Required, String] email The email address associated with a user (used in conjuction with password)
  #   @param [Required, String] password The plaintext password (use HTTPS) to verify [Required if using email]
  #
  # @return [User] User w/ authentication token
  #
  def create
    # 3rd party access
    provider = params[:provider_name]
    uid = params[:uid]
    token = params[:token]
    secret = params[:secret]
    # email/password access
    email = params[:email]
    password = params[:password]
    
    @user = if provider and uid
      User.first( :conditions => { 'authentications.provider' => provider, 'authentications.uid' => uid } )
    else
      User.where(:primary_email => email).first
    end
    
    if @user
      
      if token and GT::UserManager.verify_user(@user, provider, uid, token, secret)
        #----------------------------------Current User via 3rd party----------------------------------        
        if @user.faux == User::FAUX_STATUS[:true]
          GT::UserManager.convert_faux_user_to_real(@user, GT::ImposterOmniauth.get_user_info(provider, uid, token, secret))
        else
          GT::UserManager.start_user_sign_in(@user, :provider => provider, :uid => uid, :token => token, :secret => secret)
        end
        
      elsif password and @user.valid_password? password
        #----------------------------------Current User via email/pw----------------------------------
        GT::UserManager.start_user_sign_in(@user)
        
      else
        return render_error(404, "Failed to verify user.")
      end
      
    elsif token
      #----------------------------------New User----------------------------------
      omniauth = GT::ImposterOmniauth.get_user_info(provider, uid, token, secret)
      
      if omniauth.blank?
        return render_error(404, "Failed to create new user.")
      end
      
      @user = GT::UserManager.create_new_user_from_omniauth(omniauth)
      
      unless @user.valid?
        return render_error(404, "Failed to create new user.")
      end

    else
      return render_error(404, "Missing valid provider/uid, and/or token/secret")
    end
    
    #we have a valid user if we've made it here
    @user.ensure_authentication_token!
    sign_in(:user, @user)
    StatsManager::StatsD.increment(Settings::StatsConstants.user['signin']['success']['token'])
    @status = 200
    #renders v1/user/show which includes user.authentication_token
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
