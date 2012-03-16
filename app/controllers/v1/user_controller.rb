class V1::UserController < ApplicationController  
  
  before_filter :authenticate_user!, :except => [:show]
  
  ####################################
  # Returns one user, with the given parameters.
  #   REQUIRES AUTHENTICATION
  #
  # [GET] /v1/user/:id
  # 
  # @param [Optional, String] id The id of the user, if not present, user is current_user
  # @param [Optional, Boolean] include_auths Include the embedded authorizations
  # @param [Optional, Boolean] rolls_following Include the referenced rolls the user is following
  def show
    if @user = User.find(params[:id])
      @include_auths = (user_signed_in? and current_user.id.to_s == params[:id] and params[:include_auths] == "true" ) ? true : false
      @status = 200
    elsif user_signed_in?
      @user = current_user
      @include_auths = (params[:include_auths] == "true" ) ? true : false
      @rolls_following = params[:rolls_following] == "true" ? @user.roll_followings : nil
      @status = 200
    else
      @status, @message = 500, "could not find user"
      render 'v1/blank'
    end
  end
  
  ####################################
  # Updates and returns one user, with the given parameters.
  #   REQUIRES AUTHENTICATION
  #
  # [PUT] /v1/user/:id
  # 
  # @param [Required, String] id The id of the user  
  # @param [Required, String] attr The attribute(s) to update
  def update
    id = params.delete(:id)
    @user = User.find(id)
    # allow for email to be removed, not sure if we want this or not...
    params[:primary_email] = nil if params[:primary_email] = ""
    begin
      if @user.update_attributes!(params)
        @status = 200
      else
        @status, @message = 500, "error while updating user."
        render 'v1/blank'        
      end
    rescue => e
      @status, @message = 500, "error while updating user: #{e}"
      render 'v1/blank'
    end
  end

end