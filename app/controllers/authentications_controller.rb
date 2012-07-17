# encoding: UTF-8
require 'user_manager'
require 'invitation_manager'
require 'api_clients/twitter_info_getter'

class AuthenticationsController < ApplicationController  
 
  def index
  end
  
  def create
    if omniauth = request.env["omniauth.auth"]
      user = User.first( :conditions => { 'authentications.provider' => omniauth['provider'], 'authentications.uid' => omniauth['uid'] } )
    elsif !params[:username].blank?
      u = (User.find_by_primary_email(params[:username].downcase) || User.find_by_nickname(params[:username].downcase.to_s))
      if u and u.valid_password?(params[:password])
        user = u
      else
        @opener_location = add_query_params(redirect_path || Settings::ShelbyAPI.web_root, {
          :error => "username_password_fail"
          })
        return render :action => 'redirector', :layout => 'simple'
      end
    end
      

=begin    
#TODO: ---- Current user with two seperate accounts
    if current_user and user and user != current_user
      # make sure they want to merge "user" into "current_user"
      session[:user_to_merge_in_id] = user.id.to_s
      
      @opener_location = merge_accounts_path
=end
# ---- Current user, just signing in
    if user
      
      if user.gt_enabled
        sign_in_current_user(user, omniauth)

      elsif gt_interest = GtInterest.find(cookies[:gt_access_token])
        gt_interest.used!(user)
        cookies.delete(:gt_access_token, :domain => ".shelby.tv")
        sign_in_current_user(user, omniauth)
        
      elsif cohort_entrance = CohortEntrance.find(session[:cohort_entrance_id])
        sign_in_current_user(user, omniauth)

      elsif private_invite = cookies[:gt_roll_invite] # if they were invited via private roll, they get in
        GT::InvitationManager.private_roll_invite(user, private_invite)
        cookies.delete(:gt_roll_invite, :domain => ".shelby.tv")
        sign_in_current_user(user, omniauth)
        
      else
        # NO GT FOR YOU, just redirect to error page w/o signing in
        @opener_location = add_query_params(redirect_path || Settings::ShelbyAPI.web_root, {:access => "nos"})
      end
      
# ---- Adding new authentication to current user
    elsif current_user and omniauth
      new_auth = GT::UserManager.add_new_auth_from_omniauth(current_user, omniauth)
      
      if new_auth
        @opener_location = redirect_path || Settings::ShelbyAPI.web_root
      else
        Rails.logger.error "AuthenticationsController#create - ERROR - tried to add authentication to #{current_user.id}, user.save failed with #{current_user.errors.full_messages.join(', ')}"
        @opener_location = redirect_path || Settings::ShelbyAPI.web_root
      end

# ---- New User signing up w/ omniauth!
    elsif omniauth
      # if they have a GtInterest or CohortEntrance, they are allowed in
      gt_interest = GtInterest.find(cookies[:gt_access_token])
      cohort_entrance = CohortEntrance.find(session[:cohort_entrance_id])
      
      # if they are invited by someone via an invitation to join a private roll, and the inviter is gt_enabled, let em in!
      # gt_roll_invite consists of "inviter uid, invitee email address, roll id"
      if private_invite = cookies[:gt_roll_invite] and invite_info = cookies[:gt_roll_invite].split(',')
        inviter = User.find(invite_info[0])
        roll = Roll.find(invite_info[2])
      end
      
      if gt_interest or cohort_entrance or (private_invite and inviter and inviter.gt_enabled)
        user = GT::UserManager.create_new_user_from_omniauth(omniauth)
        
        if user.valid?
          sign_in(:user, user)
          user.remember_me!(true)
          set_common_cookie(user, session[:_csrf_token])
          
          if gt_interest
            gt_interest.used!(user) 
            cookies.delete(:gt_access_token, :domain => ".shelby.tv")
          end
          if cohort_entrance
            use_cohort_entrance(user, cohort_entrance)
            session[:cohort_entrance_id] = nil
          end
          if private_invite
            GT::InvitationManager.private_roll_invite(user, private_invite)
            GT::UserManager.copy_cohorts!(inviter, user, ["roll_invited"])
            cookies.delete(:gt_roll_invite, :domain => ".shelby.tv")
          end
          
          StatsManager::StatsD.increment(Settings::StatsConstants.user['signin']['success'][omniauth['provider'].to_s])
          @opener_location = redirect_path || Settings::ShelbyAPI.web_root
        else

          Rails.logger.error "AuthenticationsController#create - ERROR: user invalid: #{user.errors.full_messages.join(', ')} -- nickname: #{user.nickname} -- name #{user.name}"
          @opener_location = redirect_path || Settings::ShelbyAPI.web_root
        end
      else
        # NO GT FOR YOU!  Just redirect to error page w/o creating account
        @opener_location = add_query_params(redirect_path || Settings::ShelbyAPI.web_root, {:access => "nos"})
      end
        
# ---- New User signing up w/ email & password
    elsif !params[:user].blank?
      # if they are invited by someone via an invitation to join a private roll, let em in!
      # gt_roll_invite consists of "inviter uid, invitee email address, roll id"
      if private_invite = cookies[:gt_roll_invite] and invite_info = cookies[:gt_roll_invite].split(',')
        inviter = User.find(invite_info[0])
        roll = Roll.find(invite_info[2])
      end
      cohort_entrance = CohortEntrance.find(session[:cohort_entrance_id])
      
      if private_invite or cohort_entrance
      
        user = GT::UserManager.create_new_user_from_params(params[:user])

        if user.valid?
          sign_in(:user, user)
          user.remember_me!(true)
          set_common_cookie(user, session[:_csrf_token])

          if cohort_entrance
            use_cohort_entrance(user, cohort_entrance)
            session[:cohort_entrance_id] = nil
          end
          if private_invite
            GT::InvitationManager.private_roll_invite(user, private_invite)
            GT::UserManager.copy_cohorts!(inviter, user, ["roll_invited"])
            cookies.delete(:gt_roll_invite, :domain => ".shelby.tv")
          end

          StatsManager::StatsD.increment(Settings::StatsConstants.user['signin']['success']['username'])

          @opener_location = redirect_path || Settings::ShelbyAPI.web_root
        else
          Rails.logger.error "AuthenticationsController#create_with_email - ERROR: user invalid: #{user.errors.full_messages.join(', ')} -- nickname: #{user.nickname} -- name #{user.name} -- primary_email #{user.primary_email}"

          # TEMPORARILY returning user to cohort entrance as applicalbe
          #@opener_location = add_query_params(clean_query_params(redirect_path || Settings::ShelbyAPI.web_root), {
          @opener_location = add_query_params(cohort_entrance ? cohort_entrance.url : (redirect_path || Settings::ShelbyAPI.web_root), {
            :error => "new_user_invalid"
            })
        end
        
      else
        #not invited, deny access
        @opener_location = add_query_params(redirect_path || Settings::ShelbyAPI.web_root, {:access => "nos"})
      end
    else
# ---- NO GT FOR YOU!  Just redirect to error page w/o creating account
      @opener_location = add_query_params(redirect_path || Settings::ShelbyAPI.web_root, {:access => "nos"})
    end

    @opener_location = clean_query_params(@opener_location)

    # if there is a user logged in who has twitter authorization, look up the user's followings
    # and save them for autocomplete the next time we're free
    if user && user.authentications.any?{|auth| auth.provider == 'twitter'}
      ShelbyGT_EM.next_tick {
        begin
          following_screen_names = APIClients::TwitterInfoGetter.new(user).get_following_screen_names
          user.store_autocomplete_info(:twitter, following_screen_names)
        rescue Grackle::TwitterError
          # if we have Grackle problems, just give up
        end
      }
    end

    render :action => 'redirector', :layout => 'simple'
  end
  
  def fail
    #if their session is fucked, it will cause bad auth params.
    reset_session

    StatsManager::StatsD.increment(Settings::StatsConstants.user['signin']['failure'])

    @opener_location = add_query_params(redirect_path || Settings::ShelbyAPI.web_root, {
      :auth_failure => 1,
      :auth_strategy => params[:strategy]
      })
    
    render :action => 'redirector', :layout => 'simple'
  end
  
  def sign_out_user
    sign_out(:user)
    StatsManager::StatsD.increment(Settings::StatsConstants.user['signout'])
    
    redirect_to request.referer || Settings::ShelbyAPI.web_root
  end

  private
    def redirect_path
      clean_query_params(session[:return_url] || request.env['omniauth.origin'])
    end
    
    def set_common_cookie(user, form_authenticity_token)
      # ensure csrf_token in cookie
      cookies[:_shelby_gt_common] = {
        :value => "authenticated_user_id=#{user.id.to_s},csrf_token=#{form_authenticity_token}",
        :expires => 20.years.from_now,
        :domain => '.shelby.tv'
      }      
    end
    
    def use_cohort_entrance(user, cohort_entrance)
      cohort_entrance.used! user if cohort_entrance
    end
    
    def sign_in_current_user(user, omniauth=nil)
      GT::UserManager.convert_faux_user_to_real(user, omniauth) if user.faux == User::FAUX_STATUS[:true]
      GT::UserManager.start_user_sign_in(user, :omniauth => omniauth)
      
      if session[:cohort_entrance_id]
        use_cohort_entrance user, CohortEntrance.find(session[:cohort_entrance_id])
        session[:cohort_entrance_id] = nil
      end
      
      sign_in(:user, user)
      
      set_common_cookie(user, form_authenticity_token)
      
      if omniauth
        StatsManager::StatsD.increment(Settings::StatsConstants.user['signin']['success'][omniauth['provider'].to_s])
      else
        StatsManager::StatsD.increment(Settings::StatsConstants.user['signin']['success']['username'])
      end
      
      @opener_location = redirect_path || Settings::ShelbyAPI.web_root
    end
    
    def clean_query_params(loc, params=["auth_failure", "auth_strategy"])
      if loc
        # remove parameters describing a previous auth failure from the redirect url as they are no longer relevant
        redirect_uri = URI(loc)
        query = Rack::Utils.parse_query redirect_uri.query
        params.each { |p| query.delete(p) }
        redirect_uri.query = query.empty? ? nil : query.to_query

        redirect_uri.to_s
      end
    end
    
    def add_query_params(loc, params)
      # add parameters describing the auth failure to the redirect url
      redirect_uri = URI(loc)
      query = Rack::Utils.parse_query redirect_uri.query
      params.each { |param, val| query[param.to_s] = val unless val.blank? }
      redirect_uri.query = query.to_query

      redirect_uri.to_s
    end
  
end
