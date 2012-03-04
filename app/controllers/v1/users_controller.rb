class V1::UserController < ApplicationController  


  # only for testing purposes
  def index
    @success = 1 if @users = User.all
  end
  
  ####################################
  # Returns one user, with the given parameters.
  #
  # [GET] /users.[format]/:id?attr_name=attr_val
  # 
  # @param [Required, String] id The id of the user
  # @param [Optional, Boolean] include_auths Include the embedded authorizations
  # @param [Optional,  Boolean] include_rolls Include the referenced rolls the user is following
  #
  # @todo return error if id not present w/ params.has_key?(:id)
  def show
    id = params.delete(:id)
    @params = params
    @user = User.find(id)
    @auths = @params[:include_auths] ? @user.authentications : nil
  end

  ####################################
  # Creates and returns one user, with the given parameters.
  #
  # [POST] /users.[format]?[argument_name=argument_val]
  # @todo FIGURE THIS OUT. BUILD IT.
  def create
    
  end

  ####################################
  # Updates and returns one user, with the given parameters.
  #
  # [PUT] /users.[format]/:id?attr_name=attr_val
  # 
  # @param [Required, String] id The id of the user  
  # @param [Required, String] attr The attribute(s) to update
  #
  # @todo FIGURE THIS OUT. BUILD IT.
  def update
    @user = User.find(params[:id])
  end
  
  ####################################
  # Destroys one user, returning Success/Failure
  #
  # [DELETE] /users.[format]/:id
  # 
  # @param [Required, String] id The id of the user to destroy.
  # @return [Integer] Whether request was successful or not.
  def destroy
    @user = User.find(params[:id])
    @status = @user.destroy ? "ok" : "error"
  end


end