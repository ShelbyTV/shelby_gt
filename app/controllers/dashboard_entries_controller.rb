class DashboardEntriesController < ApplicationController  

  # optional parameters:
  #   params[:limit]            : Integer
  #   params[:offset]           : Integer
  #   params[:include_children] : Boolean
  #   params[:unread]           : Boolean
  def show
    # TODO: return error if :id not present w/ params.has_key?(:id)
    id = params.delete(:id)
    @params = params
    @post = Post.find(id)
  end
  
  def create
    
  end
  
  def update
    @post = Post.find(params[:id])
  end
  
  def destroy
    @post = Post.find(params[:id])
  end

end
