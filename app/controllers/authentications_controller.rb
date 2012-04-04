# encoding: UTF-8
require 'user_manager'

#TODO: Remove the @opener_location stuff here, just use redirect_to ?
class AuthenticationsController < ApplicationController  
  before_filter #, :authenticate_user!, :only => [:merge_accounts, :do_merge]
  #before_filter :read_user_on_primary_only

  def index
  end
  
  def create
    omniauth = request.env["omniauth.auth"]
    # See if we have a matching user...
    user = User.first( :conditions => { 'authentications.provider' => omniauth['provider'], 'authentications.uid' => omniauth['uid'] } )

=begin    
#TODO: ---- Current user with two seperate accounts
    if user_signed_in? and  and user != current_user
      # make sure they want to merge "user" into "current_user"
      session[:user_to_merge_in_id] = user.id.to_s
      
      @opener_location = merge_accounts_path
=end
# ---- Current user, just signing in
    if user
      if user.faux == User::FAUX_STATUS[:true]
        GT::UserManager.convert_faux_user_to_real(user, omniauth)
      else
        GT::UserManager.start_user_sign_in(user, omniauth, session)
      end
      
      sign_in(:user, user)
      cookies[:signed_in] = { :value => "true", :expires => 1.week.from_now, :domain => '.shelby.tv' }
      StatsManager::StatsD.increment(Settings::StatsConstants.user['signin']['success'][omniauth['provider'].to_s])
      
      @opener_location = request.env['omniauth.origin'] || root_path
      
# ---- Adding new authentication to current user
    elsif user_signed_in?
      new_auth = GT::UserManager.add_new_auth_from_omniauth(current_user, omniauth)
      
      if new_auth
        @opener_reload = true
      else
        Rails.logger.error "AuthenticationsController#create - ERROR - tried to add authentication to #{current_user.id}, user.save failed with #{current_user.errors.full_messages.join(', ')}"
        @opener_location = new_user_session_path
      end

# ---- New User signing up!
    else
      user = GT::UserManager.create_new_user_from_omniauth(omniauth)

      if user.valid?
        sign_in(:user, user)
        cookies[:signed_in] = { :value => "true", :expires => 1.week.from_now, :domain => '.shelby.tv' }
        
        StatsManager::StatsD.increment(Settings::StatsConstants.user['signin']['success'][omniauth['provider'].to_s])
        
        @opener_location = request.env['omniauth.origin'] || root_path
      else
        Rails.logger.error "AuthenticationsController#create - ERROR: user invalid: #{user.join(', ')} -- nickname: #{user.nickname} -- name #{user.name}"
        
        @opener_location = new_user_session_path
      end
      
    end
    
    render :action => 'redirector', :layout => 'simple'
  end
  
  def fail
    #if their session is fucked, it will cause bad auth params.
    reset_session
    
    StatsManager::StatsD.increment(Settings::StatsConstants.user['signin']['failure'])
    
    @opener_location = new_user_session_path
    render :action => 'redirector', :layout => 'simple'
  end
  
  def sign_out_user
    sign_out(:user)
    cookies.delete(:signed_in, :domain => '.shelby.tv')
    StatsManager::StatsD.increment(Settings::StatsConstants.user['signout'])
    redirect_to request.headers['HTTP_REFERER']
  end
  
end