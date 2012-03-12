class V1::UserController < ApplicationController  
  
  before_filter :authenticate_user!, :except => [:show]
  
  ####################################
  # Returns one user, with the given parameters.
  #   REQUIRES AUTHENTICATION
  #
  # [GET] /v1/users/:id
  # 
  # @param [Required, String] id The id of the user
  # @param [Optional, Boolean] include_auths Include the embedded authorizations
  # @param [Optional, Boolean] rolls_following Include the referenced rolls the user is following
  def show
    if @user = User.find(params[:id])
      @include_auths = (current_user.id.to_s == params[:id] and params[:include_auths] == "true" ) ? true : false
      @status = 200
    else
      @status, @message = 500, "could not find user"
    end
    @rolls_following = params[:rolls_following] == "true" ? @user.roll_followings : nil
  end
  
  ####################################
  # Updates and returns one user, with the given parameters.
  #   REQUIRES AUTHENTICATION
  #
  # [PUT] /v1/users/:id
  # 
  # @param [Required, String] id The id of the user  
  # @param [Required, String] attr The attribute(s) to update
  def update
    id = params.delete(:id)
    @user = User.find(id)
    params[:primary_email] = nil if params[:primary_email] = ""
    begin
        @user.save! if @user.update_attributes!(params)
        @status = 200
    rescue => e
      @status, @message = 500, "error while updating user: #{e}"
    end
  end

end