class UsersController < ApplicationController  

=begin
  # only for testing purposes
  def index
    @users = User.all
  end
=end
  
  ##
  # Returns one user, with the given parameters.
  #
  # [GET] /users.[format]?[argument_name=argument_val]
  # 
  # @param [Required, String] id The id of the user
  # @param [Optional, Boolean] include_auths Include the embedded authorizations
  # @param [Optional,  Boolean] include_rolls Include the referenced rolls the user is following
  def show
    # TODO: return error if :id not present w/ params.has_key?(:id)
    id = params.delete(:id)
    @params = params
    @user = User.find(params[:id])
  end
  
  def create
    
  end

  ##
  # Updates and returns one user, with the given parameters.
  #
  # [GET] /users.[format]?[argument_name=argument_val]
  # 
  # @param [Required, String] id The id of the user  
  # @param [Required, String] attr The attribute(s) to update
  def update
    @user = User.find(params[:id])
  end
  
  ##
  # Destroys one user, returning Success/Failure
  #
  # [GET] /users.[format]?[argument_name=argument_val]
  # 
  # @param [Required, String] id The id of the user to destroy.
  # @return [Integer] Whether request was successful or not.
  def destroy
    @user = User.find(params[:id])
    if @user.destroy
      @success = 1
    else
      @error = 1
    end
  end


end