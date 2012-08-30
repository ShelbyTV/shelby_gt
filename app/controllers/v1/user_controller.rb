class V1::UserController < ApplicationController  
  require 'user_manager'

  extend NewRelic::Agent::MethodTracer
  
  before_filter :user_authenticated?, :except => [:signed_in, :show]

  ####################################
  # Returns true (false) if user is (not) signed in
  #
  # [GET] /v1/signed_in
  def signed_in
    @status = 200
    @signed_in = user_signed_in? ? true : false
  end
  
  ####################################
  # Returns one user, with the given parameters.
  #   REQUIRES AUTHENTICATION
  #
  # [GET] /v1/user/:id
  # 
  # @param [Optional, String] id The id of the user, if not present, user is current_user
  def show
    StatsManager::StatsD.time(Settings::StatsConstants.api['user']['show']) do
      if params[:id]
        unless @user = User.find(params[:id]) or @user = User.find_by_nickname(params[:id])
          return render_error(404, "could not find that user")
        end
      elsif user_signed_in?
        @user = current_user
      else
        return render_error(401, "current user not authenticated")
      end

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
  def update
    StatsManager::StatsD.time(Settings::StatsConstants.api['user']['update']) do
      @user = current_user
      begin
        if params[:password] and (params[:password] != params[:password_confirmation])
          return render_error(409, "Passwords did not match.")
        end
        
        if params[:nickname] and params[:nickname] != @user.nickname
          return render_error(409, "Nickname taken") if User.exists?(:nickname => params[:nickname])
        end
        
        if @user.update_attributes(params)
          @status = 200
          
          # When changing the password, need to re-sign in (and bypass validation)
          sign_in(@user, :bypass => true) if params[:password]
        else
          render_error(404, "error updating user.")
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
  
  private
  
    def self.move_roll(roll_array, target_roll, pos)
      if rollIndex = roll_array.index(target_roll)
        r = roll_array.slice!(rollIndex)
        roll_array.insert(pos, r)
      end
    end
  
end
