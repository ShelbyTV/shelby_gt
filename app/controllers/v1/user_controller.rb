class V1::UserController < ApplicationController  
  
  before_filter :authenticate_user!, :except => [:show]
  
  ####################################
  # Returns one user, with the given parameters.
  #   REQUIRES AUTHENTICATION
  #
  # [GET] /v1/users/:id.json
  # 
  # @param [Required, String] id The id of the user
  # @param [Optional, Boolean] include_auths Include the embedded authorizations
  # @param [Optional, Boolean] rolls_following Include the referenced rolls the user is following
  def show
    if user_signed_in?
      @user = current_user
      @auths =  @user.authentications if current_user.id.to_s == params[:id] and params[:include_auths] == "true"
    elsif @user = User.find(params[:id])
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
  # [PUT] /v1/users/:id.json
  # 
  # @param [Required, String] id The id of the user  
  # @param [Required, String] attr The attribute(s) to update
  def update
    id = params.delete(:id)
    @user = User.find(id)
    if @user and @user.update_attributes(params)
      begin
        @user.save!
        @status = 200
      rescue => e
        @status, @message = 500, "could not save user: #{e}"
      end
    else
      @status = 500
      @message = @user ? "could not update user" : "could not find user"
    end
  end

end