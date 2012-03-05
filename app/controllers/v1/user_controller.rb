class V1::UserController < ApplicationController  

  respond_to :json
  
  # only for testing purposes
  def index
    @success = "ok" if @users = User.all
  end
  
  ####################################
  # Returns one user, with the given parameters.
  #
  # [GET] /v1/users/:id.json
  # 
  # @param [Required, String] id The id of the user
  # @param [Optional, Boolean] include_auths Include the embedded authorizations
  # @param [Optional,  Boolean] include_rolls Include the referenced rolls the user is following
  #
  # @todo return error if id not present w/ params.has_key?(:id)
  def show
    id = params.delete(:id)
    if @user = User.find(id)
      @auths = params[:include_auths] ? @user.authentications : nil
      @rolls = params[:include_rolls] ? @user.rolls : nil
    else
      @status, @message = "error", "could not find user"
    end
  end

  ####################################
  # Updates and returns one user, with the given parameters.
  #
  # [PUT] /v1/users/:id.json
  # 
  # @param [Required, String] id The id of the user  
  # @param [Required, String] attr The attribute(s) to update
  #
  def update
    id = params.delete(:id)
    @status, @message = "error", "could not find user" unless @user = User.find(id)
    if @user.update_attributes(params)
      @status = "ok"
    else
      @status, @message = "error", "could not update user"
    end
  end

end