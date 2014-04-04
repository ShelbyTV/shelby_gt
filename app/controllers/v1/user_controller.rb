# encoding: UTF-8
require 'user_stats_manager'
require 'event_tracking'
require "framer"
require "predator_manager"
require 'new_relic/agent/method_tracer'

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
  # Updates a users session count, platform specific.
  # Sends a special Google Analytics update for interesting web session counts.
  # Returns 200 if successful
  #
  # @param [Optional, String] platform Set this to "ios" to track an iPhone or iPad session.  Default platform: "web"
  #
  # [PUT] /v1/user/:id/visit
  def log_session
    return render_error(404, "must include a user id") unless params[:id]
    sessions_platform = params[:platform] || "web"
    if User.find(params[:id]) == current_user

      # Go get any new videos from facebook explicity
      facebook_auth = current_user.authentications.select { |a| a.provider == 'facebook'  }.first
      GT::PredatorManager.update_video_processing(current_user, facebook_auth) if facebook_auth

      case sessions_platform
      when "ios"
        current_user.increment(:ios_session_count => 1)
      when "web"
        current_user.increment(:session_count => 1)
        ShelbyGT_EM.next_tick {
          StatsManager::GoogleAnalytics.track_nth_session(current_user, 1)
          StatsManager::GoogleAnalytics.track_nth_session(current_user, 3)
          StatsManager::GoogleAnalytics.track_nth_session(current_user, 6)
          StatsManager::GoogleAnalytics.track_nth_session(current_user, 10)
        }
      else
        return render_error(404, "invalid platform.  only ios and web supported.")
      end
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
  # @param [Required, String] user.primary_email The email address of the new user
  # @param [Optional, String] user.nickname The desired username, required unless generate_temporary_nickname_and_password == 1
  # @param [Optional, String] user.password The plaintext password, required unless generate_temporary_nickname_and_password == 1
  # @param [Optional, Boolean] generate_temporary_nickname_and_password If "1", nickname and password will use randomly generated values.
  # @param [Optional, String] client_identifier Used by iOS to update user appropriately (ie. add cohort, don't repeat onboarding on web)
  # @param [Optional, String] user.user_type Primarily for new anonymous type user.
  #
  # Example payloads:
  #   Creating user will all details specified:
  #     {user: {name: "dan spinosa", nickname: "spinosa", primary_email: "dan@shelby.tv", password: "pass"}}
  #   Creating user with just name and email:
  #     {user: {name: "dan spinosa", primary_email: "dan@shelby.tv"}, generate_temporary_nickname_and_password: "1"}
  #   Creating a purely anonymous user:
  #     {anonymous: true}
  def create
    if params[:user]
      user_options = params[:user]
    elsif params[:anonymous]
      user_options = {:anonymous => true}
    else
      user_options = {}
    end
    if ((params[:generate_temporary_nickname_and_password] && params[:user]) || params[:anonymous])
      self.class.trace_execution_scoped(['Custom/user_create/generate_temporary_password_and_nickname']) do
        user_options[:nickname] = GT::UserManager.generate_temporary_nickname
        user_options[:password] = GT::UserManager.generate_temporary_password
      end
    end

    self.class.trace_execution_scoped(['Custom/user_create/create_user']) do
      @user = GT::UserManager.create_new_user_from_params(user_options) unless user_options.empty?
    end

    if @user and @user.errors.empty? and @user.valid?
      sign_in(:user, @user)

      if params[:client_identifier]
        @user.update_for_signup_client_identifier!(params[:client_identifier])
      end

      respond_to do |format|
        format.json do
          @status = 200
          @user.remember_me!(true)
          set_common_cookie(@user, form_authenticity_token)
          self.class.trace_execution_scoped(['Custom/user_create/ensure_authentication_token']) do
            @user.ensure_authentication_token!
          end
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
  # If the user is following the specified roll, returns a RollFollowing structure with information about the roll
  # If the user is not following the specified roll, returns a 404
  #   REQUIRES AUTHENTICATION
  #
  # [GET] /v1/user/:id/roll/:roll_id/following
  #
  # @param [Required, String] id The id of the user
  # @param [Required, String] roll_id The id of the roll to check whether the user is following
  def roll_following
    StatsManager::StatsD.time(Settings::StatsConstants.api['user']['show']) do
      @user = current_user
      if @user && @user.id.to_s == params[:id]
        @roll_following = @user.roll_following_for(params[:roll_id])
        if @roll_following
          @roll = Roll.find(@roll_following.roll_id)
          @status = 200
        else
          @status = 404
        end
      else
        @status = 403
      end
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
        if params[:app_progress] and params[:app_progress][:onboarding]
          if "true" == params[:app_progress][:onboarding]
            params[:app_progress][:onboarding] = true
          elsif (true if Integer(params[:app_progress][:onboarding]) rescue false)
            params[:app_progress][:onboarding] = params[:app_progress][:onboarding].to_i
          else
            params[:app_progress][:onboarding] = true
          end
        end

        if @user.update_attributes(params)
          # convert an anonymous user to real if they have email and are updating their password
          if params[:password] && (@user.user_type == User::USER_TYPE[:anonymous])
            GT::UserManager.convert_eligible_user_to_real(@user)
          end

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
      @stats.each {|s| s.frame.creator[:shelby_user_image] = s.frame.creator.avatar_url}
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

  ##
  # Adds a new apn token for the user with the specified id
  # =>   REQUIRES AUTHENTICATION
  #
  # [POST] /v1/user/:id/apn_token?token=:token
  #
  # @param [Required, String] id The id of the user
  # @param [Required, String] token The apn token to add for the user
  #
  def add_apn_token
    if params[:id] == current_user.id.to_s
      # A user can add tokens for themself
      @user = current_user
      return render_error(500, "must specify a token to add") unless token = params.delete(:token)

      # add the token to the user's collection if it's not already there
      @user.push_uniq(:bh => token)

      # the first time we add a token to the user, we mark them as having accepted ios push notifications
      # and disable their email notifications
      unless @user.accepted_ios_push
        User.collection.update({:_id => @user.id}, {
          :$set => {
            :bi => true,
            "preferences.like_notifications" => false,
            "preferences.reroll_notifications" => false,
            "preferences.roll_activity_notifications" => false
          }
        })
        @user.reload
      end

      @status = 200
    else
      @status = 401
    end
  end

  ##
  # Deletes an apn token for the user with the specified id
  # =>   REQUIRES AUTHENTICATION
  #
  # [DELETE] /v1/user/:id/apn_token?token=:token
  #
  # @param [Required, String] id The id of the user
  # @param [Required, String] token The apn token to delete for the user
  #
  def delete_apn_token
    if params[:id] == current_user.id.to_s
      # A user can delete tokens for themself
      @user = current_user
      return render_error(500, "must specify a token to remove") unless token = params.delete(:token)

      # remove the token from the user's collection
      @user.pull(:bh => token)

      @status = 200
    else
      @status = 401
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
