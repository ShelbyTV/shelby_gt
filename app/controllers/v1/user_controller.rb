class V1::UserController < ApplicationController  
  
  before_filter :user_authenticated?, :except => [:signed_in, :show]
  
  ####################################
  # Returns true (false) if user is (not) signed in
  #
  # [GET] /v1/signed_in
  def signed_in
    @status = 200
    @signed_in = user_signed_in? ? true : false
    render 'signed_in', :layout => 'with_callbacks' if params[:callback]
  end
  
  ####################################
  # Returns one user, with the given parameters.
  #   REQUIRES AUTHENTICATION
  #
  # [GET] /v1/user/:id
  # 
  # @param [Optional, String] id The id of the user, if not present, user is current_user
  # @param [Optional, Boolean] rolls_following Include the referenced rolls the user is following
  def show
    StatsManager::StatsD.time(Settings::StatsConstants.api['user']['show']) do
      if params[:id]
                
        if @user = User.find(params[:id]) or @user = User.find_by_nickname(params[:id])
          @include_rolls = (user_signed_in? and current_user.id.to_s == params[:id] and params[:include_rolls] == "true" ) ? true : false
          @status = 200
        else
          render_error(404, "could not find that user")
        end
      elsif user_signed_in? and @user = current_user
        @include_rolls = (params[:include_rolls] == "true") ? true : false
        @status = 200
        render 'show', :layout => 'with_callbacks' if params[:callback]
      else
        render_error(404, "could not find that user")
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
  def update
    StatsManager::StatsD.time(Settings::StatsConstants.api['user']['update']) do
      @user = current_user
      params.keep_if {|key,value| [:name, :nickname, :primary_email, :preferences].include?key.to_sym}
      begin
        if @user.update_attributes!(params)
          @status = 200
        elsif params[:preferences]
          @user.preferences.update_attributes!(params[:preferences])
          @status = 200
        else
          render_error(404, "error while updating user.")
        end
      rescue => e
        render_error(404, "error while updating user: #{e}")
      end
    end
  end

  ##
  # Returns the rolls the current_user is following
  #   REQUIRES AUTHENTICATION
  #
  # [GET] /v1/user/:id/rolls
  # 
  # @param [Required, String] id The id of the user
  # @param [Optional, boolean] include_children Return the following_users?
  def rolls
    StatsManager::StatsD.time(Settings::StatsConstants.api['user']['rolls']) do
      if current_user.id.to_s == params[:id]
        
        return render_error(404, "please specify a valid id") unless since_id = ensure_valid_bson_id(params[:id])
        
        @user = current_user
        @status = 200
      else
        render_error(401, "you are not authorized to view that users rolls.")
      end
    end
  end
  
end