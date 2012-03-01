class UsersController < ApplicationController  

=begin
  # only for testing purposes
  def index
    @users = User.all
  end
=end
  
  
  # optional parameters:
  #   params[:include_auths]  : Boolean
  #   params[:include_rolls]  : Boolean
  def show
    # TODO: return error if :id not present w/ params.has_key?(:id)
    id = params.delete(:id)
    @params = params
    @user = User.find(params[:id])
  end
  
  def create
    
  end
  
  def update
    @user = User.find(params[:id])
  end
  
  def destroy
    @user = User.find(params[:id])
  end


end