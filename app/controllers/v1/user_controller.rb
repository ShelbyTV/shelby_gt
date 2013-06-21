# encoding: UTF-8
require 'user_stats_manager'
require "framer"

class V1::UserController < ApplicationController

  extend NewRelic::Agent::MethodTracer

  include ApplicationHelper

  before_filter :user_authenticated?, :except => [:signed_in, :create, :index, :show]

  ####################################
  # Returns true (false) if user is (not) signed in
  #
  # [GET] /v1/signed_in
  def signed_in
    @status = 200
    @signed_in = user_signed_in? ? true : false
  end

  ####################################
  # Updates a users session count.
  # Returns 200 if successful
  #
  # [GET] /v1/user/:id/visit
  def log_session
    return render_error(404, "must include a user id") unless params[:id]
    if User.find(params[:id]) == current_user
      current_user.increment(:session_count => 1)
      @status = 200
    else
      render_error(404, "could not update the current users session")
    end
  end

  ##
  # Creates a new user with the given basic info.
  # Supports mobile via JSON, web via HTML.
  #
  # To create a new user via OAuth for web, use AuthenticationsController#create
  # To create a new user via OAuth for mobile, use V1::TokenController#create
  #
  # This route should only be used over HTTPS
  #
  # [POST] /v1/user
  #
  # @param [Required, String] user.name The full name of the user signing up
  # @param [Required, String] user.nickname The desired username
  # @param [Required, String] user.password The plaintext password
  # @param [Required, String] user.primary_email The email address of the new user
  #
  # Example payload:
  # {user: {name: "dan spinosa", nickname: "spinosa", primary_email: "dan@shelby.tv", password: "pass"}}
  def create
    @user = GT::UserManager.create_new_user_from_params(params[:user]) if params[:user]

    if @user and @user.errors.empty? and @user.valid?
      sign_in(:user, @user)

      respond_to do |format|
        format.json do
          @status = 200
          @user.remember_me!(true)
          set_common_cookie(@user, form_authenticity_token)
          @user.ensure_authentication_token!
          render 'v1/user/show'
        end
        format.html do
          @user.remember_me!(true)
          set_common_cookie(@user, form_authenticity_token)
          redirect_to '/'
        end
      end
    else
      respond_to do |format|
        format.json { @user ? render_errors_of_model(@user) : render_error(409, "Must supply params as {user:{name:'name',...}}") }
        format.html { redirect_to '/user/new' } #NOT YET IMPLEMENTED
      end
    end
  end

  ##
  # Returns a collection of users according to search criteria.
  #
  # [GET] /v1/user
  #
  # @param [Optional, String] ids comma-separated list of user ids, if not present, user is current_user
  def index
    StatsManager::StatsD.time(Settings::StatsConstants.api['user']['index']) do
      if params[:ids]
        ids = params[:ids].split(",")
        if ids.length <= 10
          @users = User.find(ids)
          @status = 200
        else
          render_error(400, "too many ids included (max 10)")
        end
      elsif user_signed_in?
        @status = 200
        @user = current_user
        @user_personal_roll_subdomain = (@user.public_roll and @user.public_roll.subdomain)
        render 'v1/user/show'
      else
        render_error(401, "current user not authenticated")
      end
    end
  end

  ####################################
  # Returns one user, with the given parameters.
  #   REQUIRES AUTHENTICATION
  #
  # [GET] /v1/user/:id
  #
  # @param [Required, String] id The id of the user
  def show
    StatsManager::StatsD.time(Settings::StatsConstants.api['user']['show']) do
      if params[:id]
        unless @user = User.find(params[:id]) or @user = User.find_by_nickname(params[:id])
          return render_error(404, "could not find that user")
        end
      else
        return render_error(401, "current user not authenticated")
      end

      @user_personal_roll_subdomain = (@user.public_roll and @user.public_roll.subdomain)
      @status = 200
    end
  end

  ####################################
  # Updates and returns one user, with the given parameters.
  #   REQUIRES AUTHENTICATION
  #
  # [PUT] /v1/user/:id
  #
  # @param [Required, String] attr The attribute(s) to update
  # All params are in models/user.rb listed as :attr_accessible
  #
  # Note: The payload should be flat with attributes at the top level, not within a user object
  #   correct: {nickname: "spinosa", ...}
  #     wrong: {user: {nickname: "spinosa", ...}}
  #
  def update
    StatsManager::StatsD.time(Settings::StatsConstants.api['user']['update']) do
      @user = current_user
      begin

        #DEBT: This is a little ghetto, should check all conditions and then return error
        if params[:password] and (params[:password] != params[:password_confirmation])
          return render_error(409, "Passwords did not match.", {:user => {:password => "did not match confirmation"}})
        end

        params[:nickname] = clean_nickname(params[:nickname]) if params[:nickname]
        if params[:nickname] and params[:nickname] != @user.downcase_nickname and (user_with_nickname = User.first(:downcase_nickname => params[:nickname]))
          if user_with_nickname.user_type == User::USER_TYPE[:faux]
            #we're stealing this faux user's nickname for the real user
            user_with_nickname.release_nickname!
          else
            return render_error(409, "Nickname taken", {:user => {:nickname => "has already been taken"}})
          end
        end

        if params[:primary_email] and params[:primary_email] != @user.primary_email
          return render_error(409, "Email taken", {:user => {:primary_email => "has already been taken"}}) if User.exists?(:primary_email => params[:primary_email])
        end

        had_completed_onboarding = (@user.app_progress? and @user.app_progress.onboarding? and @user.app_progress.onboarding.to_s == '4')

        if @user.update_attributes(params)
          @status = 200

          # When changing the password, need to re-sign in (and bypass validation)
          sign_in(@user, :bypass => true) if params[:password]

          # If the user just completed onboarding, send a notification to their inviter if they had one
          if params[:app_progress] and params[:app_progress][:onboarding] and params[:app_progress][:onboarding].to_s == '4' and !had_completed_onboarding
            if inviter = @user.invited_by
              ShelbyGT_EM.next_tick do
                GT::NotificationManager.check_and_send_invite_accepted_notification(inviter, @user)
              end
            end
          end

          if current_user == @user
            @user_personal_roll_subdomain = (@user.public_roll and @user.public_roll.subdomain)
          end
        else
          render_errors_of_model(@user)
        end
      rescue => e
        render_error(404, "error while updating user: #{e}")
      end
    end
  end

  ##
  # Returns whether the users' oauth tokens are valid
  #   REQUIRES AUTHENTICATION
  #
  # [GET] /v1/user/:id/is_token_valid
  #
  # @param [Required, String] id The id of the user
  # @param [Required, String] provider provider that want to check on
  def valid_token
    StatsManager::StatsD.time(Settings::StatsConstants.api['user']['valid_token']) do
      if !["facebook"].include?(params[:provider]) # using include? allows us to do this for twitter/tumblr in the future
        return render_error(404, "this route only currently supports facebook as a provider.")
      end

      if auth = current_user.first_provider(params[:provider]) and auth.is_a? Authentication
        @token_valid = GT::UserFacebookManager.verify_auth(auth.oauth_token)
        @status = 200
      else
        return render_error(404, "This user does not have a #{params[:provider]} authentication to check on")
      end
    end
  end

  ##
  # Returns the stats for the user (right now the stats for their personal roll)
  #   REQUIRES AUTHENTICATION
  #
  # [GET] /v1/user/:id/stats
  #
  # @param [Required, String] id The id of the user
  # @param [Optional, Integer] num_frames The number of recent frames to return stats for, default 3
  def stats
    StatsManager::StatsD.time(Settings::StatsConstants.api['user']['stats']) do
      if params[:id] == current_user.id.to_s
        # A regular user can only view his/her own stats
        @user = current_user
      elsif current_user.is_admin
        # admin users can view anyone's stats
        unless @user = User.where(:id => params[:id]).first
          return render_error(404, "could not find that user")
        end
      else
        return render_error(401, "unauthorized")
      end

      @status = 200
      num_recent_frames = params[:num_frames] ? params[:num_frames].to_i : Settings::UserStats.num_recent_frames
      @stats = GT::UserStatsManager.get_dot_tv_stats_for_recent_frames(@user, num_recent_frames)
      @stats.each {|s| s.frame.creator[:shelby_user_image] = avatar_url_for_user(s.frame.creator)}
    end
  end

  ##
  # Creates a new dashboard entry for a user with the given frame id.
  #
  # [POST] /v1/user/:id/dashboard_entry
  #
  # @param [Required, String] frame_id The frame id to add as a dashboard entry
  #
  def add_dashboard_entry
    if @frame = Frame.find(params.delete(:frame_id)) and u = User.find(params[:id])
      if dbe  = GT::Framer.create_dashboard_entry(@frame, ::DashboardEntry::ENTRY_TYPE[:new_hashtag_frame], u)
        @dashboard_entry = dbe.first
        @status = 200
      else
        return render_error(404, "error while creating dashboard entry")
      end
    else
      return render_error(404, "could not find that frame or user")
    end
  end

  private

    def self.move_roll(roll_array, target_roll, pos)
      if rollIndex = roll_array.index(target_roll)
        r = roll_array.slice!(rollIndex)
        roll_array.insert(pos, r)
      end
    end

    def clean_nickname(nick)
      nick = nick.downcase
      nick = nick.strip
      nick = nick.gsub(/[ ,:&~]/,'_')
      return nick
    end

end
