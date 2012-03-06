class AuthenticationsController < ApplicationController  
  #before_filter :authenticate_user!, :only => [:merge_accounts, :do_merge]
  #before_filter :read_user_on_primary_only

  def index
  
  end
  
  def create
    omniauth = request.env["omniauth.auth"]
    # See if we have a matching user...
    user = User.first( :conditions => { 'authentications.provider' => omniauth['provider'], 'authentications.uid' => omniauth['uid'] } )
    
    # Broadcast id saved as cookie when user isn't logged in
    #referral_broadcast_id = cookies[:shelby_referral_broadcast_id]
    #cookies[:shelby_referral_broadcast_id] = nil
    
    # ---- Current user with two seperate accounts
    if user_signed_in? and user and user != current_user
      # make sure they want to merge "user" into "current_user"
      session[:user_to_merge_in_id] = user.id.to_s
      
      @opener_location = merge_accounts_path
    
    # ---- Current user, just signing in
    elsif user
      #SigninHelper.start_user_signin(user, omniauth, referral_broadcast_id, session)
      sign_in(:user, user)
      
      render :text => "Welcome #{user.nickname}"
      
      #@opener_location = request.env['omniauth.origin'] || root_path

    elsif user_signed_in?         # ---- Adding new authentication to current user
      current_user.authentications << (a = Authentication.build_from_omniauth(omniauth))
      
      if current_user.save
        @opener_reload = true
      else
        Rails.logger.error "AuthenticationsController#create - ERROR - tried to add authentication to #{current_user.id}, user.save failed with #{current_user.errors.full_messages.join(', ')}"
        
        Stats.increment(Stats::FAILED_ADD_TW_AUTH) if omniauth['provider'] == 'twitter'
        Stats.increment(Stats::FAILED_ADD_FB_AUTH) if omniauth['provider'] == 'facebook'
        Stats.increment(Stats::FAILED_ADD_TU_AUTH) if omniauth['provider'] == 'tumblr'
        @opener_location = new_user_session_path
      end

    # ---- New User signing up!
    else
      user = User.new_from_omniauth(omniauth, referral_broadcast_id)
      user.authentications << Authentication.build_from_omniauth(omniauth)
      
      # check if signup was form a referral
      referral_broadcast_id ? Stats.increment(Stats::SIGNUP_FROM_REFERRAL) : Stats.increment(Stats::SIGNUP_NOT_FROM_REFERRAL)
      
      if user.valid?
        user.save
      
        # Update Signin Stat
        #Stats.increment(Stats::SIGNIN)
        #Stats.increment(Stats::USER_SIGNIN_TWITTER, user.id, 'twitter_signin') if omniauth['provider'] == 'twitter'
        #Stats.increment(Stats::USER_SIGNIN_FACEBOOK, user.id, 'facebook_signin') if omniauth['provider'] == 'facebook'

        # Track the signup for A/B testing
        #track! :new_signup

        sign_in(:user, user)
        @opener_location = request.env['omniauth.origin'] || root_path
      else
        Rails.logger.error "AuthenticationsController#create - ERROR - user invalid: #{user.errors.full_messages.join(', ')} -- nickname: #{user.nickname} -- name #{user.name}"
        #Stats.increment(Stats::FAILED_SIGNUP)
        
        @opener_location = new_user_session_path
      end
      
    end
    
    #render :action => 'redirector', :layout => 'simple'
  end

  def fail
    #Stats.increment(Stats::FAILED_SIGNIN)
    if current_user
      Rails.logger.error "AuthenticationsController#fail user: #{current_user.nickname}"
    else
      Rails.logger.error "AuthenticationsController#fail User NOT logged in"
    end
    
    #if their session is fucked, it will cause bad auth params.
    reset_session
        
    @opener_location = new_user_session_path
    render :action => 'redirector', :layout => 'simple'
  end
  
end