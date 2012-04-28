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
      
      if user.gt_enabled
        if user.faux == User::FAUX_STATUS[:true]
          GT::UserManager.convert_faux_user_to_real(user, omniauth)
        else
          GT::UserManager.start_user_sign_in(user, omniauth, session)
        end
      
        sign_in(:user, user)
        Rails.logger.info("TOKEN: #{form_authenticity_token}")
        # ensure csrf_token in cookie
        cookies[:_shelby_gt_common] = {
          :value => "authenticated_user_id=#{user.id.to_s},csrf_token=#{form_authenticity_token}",
          :expires => 1.week.from_now,
          :domain => '.shelby.tv'
        }
        StatsManager::StatsD.increment(Settings::StatsConstants.user['signin']['success'][omniauth['provider'].to_s])
      
        @opener_location = request.env['omniauth.origin'] || web_root_url
      else
        # NO GT FOR YOU, just redirect to error page w/o signing in
        @opener_location = "#{Settings::ShelbyAPI.web_root}/?access=nos"
      end
      
# ---- Adding new authentication to current user
    elsif user_signed_in?
      new_auth = GT::UserManager.add_new_auth_from_omniauth(current_user, omniauth)
      
      if new_auth
        @opener_location = request.env['omniauth.origin'] || web_root_url
      else
        Rails.logger.error "AuthenticationsController#create - ERROR - tried to add authentication to #{current_user.id}, user.save failed with #{current_user.errors.full_messages.join(', ')}"
        @opener_location = web_root_url
      end

# ---- New User signing up!
    else
      # if they have a GtInterest access token, and they've been allowed entry, create the user and update the GtInterest
      gt_interest = GtInterest.find(cookies[:gt_access_token])
      
      if gt_interest and gt_interest.allow_entry?
        user = GT::UserManager.create_new_user_from_omniauth(omniauth)

        if user.valid?
          sign_in(:user, user)
          gt_interest.used!(user)
          # ensure csrf_token in cookie
          cookies[:_shelby_gt_common] = {
            :value => "authenticated_user_id=#{user.id.to_s},csrf_token=#{session[:_csrf_token]}",
            :expires => 1.week.from_now,
            :domain => '.shelby.tv'
          }
          StatsManager::StatsD.increment(Settings::StatsConstants.user['signin']['success'][omniauth['provider'].to_s])
        
          @opener_location = request.env['omniauth.origin'] || web_root_url
        else
          Rails.logger.error "AuthenticationsController#create - ERROR: user invalid: #{user.join(', ')} -- nickname: #{user.nickname} -- name #{user.name}"
        
          @opener_location = web_root_url
        end
      else
        # ...otherwise NO GT FOR YOU!  Just redirect to error page w/o creating account
        @opener_location = "#{Settings::ShelbyAPI.web_root}/?access=nos"
      end
      
    end
    
    render :action => 'redirector', :layout => 'simple'
  end
  
  def fail
    #if their session is fucked, it will cause bad auth params.
    reset_session
    
    StatsManager::StatsD.increment(Settings::StatsConstants.user['signin']['failure'])
    
    @opener_location = web_root_url
    render :action => 'redirector', :layout => 'simple'
  end
  
  def sign_out_user
    sign_out(:user)
    StatsManager::StatsD.increment(Settings::StatsConstants.user['signout'])
    
    redirect_to request.referer || web_root_url
  end
  
end