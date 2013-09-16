require 'user_manager'
require 'imposter_omniauth'

class V1::TokenController < ApplicationController
  skip_before_filter :verify_authenticity_token


  ##
  # Ensures User matching the given credentials has a single sign on token and returns it.
  # Either supply 3rd party credentials or email/password.
  #
  # If we have a currently authenticated user...
  #   - If given credentials are valid, but don't match any user, they will be added to the current user.
  #   - If given credentials are valid, and match a user other than the current user, the matched user will be
  #     merged in to the current user.
  # If we don't have an authenticated user...
  #   - If given credentials are valid, and match a user, that user will be returned
  #   - If given credentials are valid, and do not match a user, a new one will be created and returned
  #      - unless params[:intention] == "login" in which case we return a 403 error
  #
  # The returned token can be used to authenticate against the api by including with an HTTP request as the value
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
  #   @param [Required, String] email The email address (or username) associated with a user (used in conjuction with password)
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
    elsif email
      User.where(:primary_email => email.downcase).first
      User.find_by_primary_email(email.downcase) || User.find_by_nickname(email.downcase)
    end
    
    #----------------------------------Already Authenticated User----------------------------------
    if current_user
      if @user
        if @user != current_user
          # Do not merge
          return render_error(403, {:current_user_nickname => current_user.nickname, 
                                    :existing_other_user_nickname => @user.nickname,
                                    :error_message => "Not merging users, email help@shelby.tv to request this." })
        elsif token
          # Update token and secret, save user
          auth = @user.authentication_by_provider_and_uid(provider, uid)
          auth.oauth_token = token
          auth.oauth_secret = secret
          @user.save
        end
        
      elsif token
        #Add auth to current_user, return current_user w/ token
        omniauth = GT::ImposterOmniauth.get_user_info(provider, uid, token, secret)
        new_auth = GT::UserManager.add_new_auth_from_omniauth(current_user, omniauth)
        @user = current_user

        unless new_auth
          return render_error(404, "failed to add authentication to current user")
        end
        
      elsif password
        return render_error(404, "user already authenticated, email/password unnecessary")

      else
        return render_error(404, "user already authenticated; must provide oauth token")
      end
      
    #----------------------------------Existing User, Not Authenticated----------------------------------
    elsif @user
      if token and GT::UserManager.verify_user(@user, provider, uid, token, secret)
        
        if @user.user_type == User::USER_TYPE[:faux]
          GT::UserManager.convert_faux_user_to_real(@user, GT::ImposterOmniauth.get_user_info(provider, uid, token, secret))
        else
          GT::UserManager.start_user_sign_in(@user, :provider => provider, :uid => uid, :token => token, :secret => secret)
        end

      elsif password and @user.valid_password? password
        GT::UserManager.start_user_sign_in(@user)

      else
        return render_error(404, "Failed to verify user; provide oauth tokens or email/password.")
      end


    #----------------------------------New User (Not Authenticated)----------------------------------
    elsif token
      if params[:intention] == "login"
        #iOS sends this; we don't want to create account for OAuth unless explicity signing up
        return render_error(403, {:error_code => 403001,
                                  :error_message => "Account not found for given token.  Use sign up to create an account."})
      end

      omniauth = GT::ImposterOmniauth.get_user_info(provider, uid, token, secret)

      if omniauth.blank?
        return render_error(404, "Failed to create new user.")
      end

      @user = GT::UserManager.create_new_user_from_omniauth(omniauth)

      unless @user.valid?
        return render_error(404, "Failed to create new user.")
      end

    elsif password
      return render_error(404, "Use /v1/user/create to create a new user without oauth")
      
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
