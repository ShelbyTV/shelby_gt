# encoding: UTF-8
require 'user_manager'
require 'user_merger'

class AuthenticationsController < ApplicationController  
  
  before_filter :authenticate_user!, :only => [:should_merge_accounts, :do_merge_accounts]
 
  def index
  end
  
  ##
  # Authenticates user via email or username and password.
  #
  # This route should only be used over HTTPS
  #
  # [POST] /authentications/login
  # 
  # @param [Required, String] username May be the username or the primary email address of the user
  # @param [Required, String] password The plaintext password
  def login
    u = (User.find_by_primary_email(params[:username].downcase) || User.find_by_nickname(params[:username].downcase.to_s)) if params[:username]
    if u and u.has_password? and u.valid_password?(params[:password])
      user = u
    else
      query = {:auth_failure => 1, :auth_strategy => "that username/password"}
      query[:redir] = params[:redir] if params[:redir]
      redirect_to add_query_params(request.referer || Settings::ShelbyAPI.web_root, query) and return
    end
    
    # any user with valid email/password is a valid Shelby user
    # this sets up redirect
    sign_in_current_user(user)
    redirect_to clean_query_params(@opener_location) and return
  end
  
  # This method has grown into a fucking beast.  
  # ==> Needs *serious* refactoring and simplification. <==
  def create
    if omniauth = request.env["omniauth.auth"]
      user = User.first( :conditions => { 'authentications.provider' => omniauth['provider'], 'authentications.uid' => omniauth['uid'] } )
    end
    
    #look into beta_invite for all code paths
    invite_id = params[:invite_id] or (request.env['omniauth.params'] && request.env['omniauth.params']['invite_id'])
    if invite_id
      beta_invite = BetaInvite.find(invite_id)
      unless beta_invite and beta_invite.unused?
        @opener_location = add_query_params(Settings::ShelbyAPI.web_root, {:invite => "invalid"})
        render :action => 'redirector', :layout => 'simple' and return
      end
    end


# ---- Current user with two seperate accounts
    if current_user and user and user != current_user
      # make sure they want to merge "user" into "current_user"
      session[:user_to_merge_in_id] = user.id.to_s
      
      @opener_location = should_merge_accounts_authentications_path


# ---- Current user, just signing in
    elsif user
      
      if user.gt_enabled
        sign_in_current_user(user, omniauth)

      elsif gt_interest = GtInterest.find(cookies[:gt_access_token])
        gt_interest.used!(user)
        cookies.delete(:gt_access_token, :domain => ".shelby.tv")
        sign_in_current_user(user, omniauth)
        user.gt_enable!
        
      elsif cohort_entrance = CohortEntrance.find(session[:cohort_entrance_id])
        use_cohort_entrance(user, cohort_entrance)
        session[:cohort_entrance_id] = nil        
        sign_in_current_user(user, omniauth)
        user.gt_enable!
        
      elsif beta_invite
        use_beta_invite(user, beta_invite)
        sign_in_current_user(user, omniauth)
        user.gt_enable!
        
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
            
      if gt_interest or cohort_entrance or beta_invite
        user = GT::UserManager.create_new_user_from_omniauth(omniauth)
        
        if user.valid?
          sign_in(:user, user)
          user.remember_me!(true)
          set_common_cookie(user, form_authenticity_token)
          
          if gt_interest
            gt_interest.used!(user) 
            cookies.delete(:gt_access_token, :domain => ".shelby.tv")
          end
          if cohort_entrance
            use_cohort_entrance(user, cohort_entrance)
            session[:cohort_entrance_id] = nil
          end
          if beta_invite
            use_beta_invite(user, beta_invite)
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
      # can now signup in a popup so no_redirect should not be set!
      @no_redirect = true unless session[:popup]

      cohort_entrance = CohortEntrance.find(session[:cohort_entrance_id])
      
      if cohort_entrance or beta_invite

        user = GT::UserManager.create_new_user_from_params(params[:user])

        if user.valid? and user.errors.empty?
          sign_in(:user, user)
          user.remember_me!(true)
          set_common_cookie(user, form_authenticity_token)

          if cohort_entrance
            use_cohort_entrance(user, cohort_entrance)
            session[:cohort_entrance_id] = nil
          end
          if beta_invite
            use_beta_invite(user, beta_invite)
          end

          StatsManager::StatsD.increment(Settings::StatsConstants.user['signin']['success']['username'])
          @user_errors = false
          @opener_location = redirect_path || Settings::ShelbyAPI.web_root
        else
          Rails.logger.info "AuthenticationsController#create_with_email - FAIL: user invalid: #{user.errors.full_messages.join(', ')} -- nickname: #{user.nickname} -- name #{user.name} -- primary_email #{user.primary_email}"

          # keep list of errors handy to pass to a client if necessary.
          @user_errors = model_errors_as_simple_hash(user)

          # return to beta invite url, origin, or web root with errors
          loc = nil
          loc = beta_invite.url if beta_invite
          loc = cohort_entrance.url if cohort_entrance
          loc = clean_query_params(redirect_path || Settings::ShelbyAPI.web_root) unless loc
          @opener_location = add_query_params(loc, @user_errors)
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
    
    render :action => 'redirector', :layout => 'simple'

=begin
    respond_to do |format|
      format.html { render :action => 'redirector', :layout => 'simple' }
      # allow AJAX use for signup via popup window and send errors back if there are any
      format.js   { 
        if cohort_entrance
          session[:user_errors] = @user_errors == false ? false : @user_errors.to_json 
          render :action => 'popup_communicator', :format => :js
        else
          render :text => "sorry, something went wrong"
        end
      }
    end
=end    
  end
  
  # confirm that they want to merge, will post to do_merge_accounts
  def should_merge_accounts
    @into_user = current_user  
    redirect_to sign_out_user_path unless @other_user = User.find_by_id(session[:user_to_merge_in_id])
  end
  
  def do_merge_accounts
    # Not looking at params, that would be a security issue
    @into_user = current_user
    @other_user = User.find_by_id(session[:user_to_merge_in_id])
    
    if @other_user and @into_user
      session[:user_to_merge_in_id] = nil
      if GT::UserMerger.merge_users(@other_user, @into_user)
        @opener_location = Settings::ShelbyAPI.web_root
        return render :action => 'redirector', :layout => 'simple'
      end
    end
    
    # if we fell through
    @opener_location = sign_out_user_path
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
    
    #render :action => 'redirector', :layout => 'simple'
    redirect_to @opener_location and return
  end
  
  def sign_out_user
    sign_out(:user)
    StatsManager::StatsD.increment(Settings::StatsConstants.user['signout'])

    redirect_to root_path(request.referer) || Settings::ShelbyAPI.web_root
  end

  private
    def redirect_path
      clean_query_params(session[:return_url] || request.env['omniauth.origin'] || params[:redir])
    end
    
    def use_cohort_entrance(user, cohort_entrance)
      cohort_entrance.used! user if cohort_entrance
    end
    
    def use_beta_invite(user, beta_invite)
      beta_invite.used_by!(user) if beta_invite
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

    def root_path(loc)
      if loc
        root_uri = URI(loc)
        root_uri.path = "/"
        root_uri.query = nil
        root_uri.fragment = nil

        root_uri.to_s
      end
    end
    
end
