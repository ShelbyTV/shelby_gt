class VideosController < ApplicationController  

  def show
    # TODO: return error if :id not present w/ params.has_key?(:id)
    id = params.delete(:id)
    @params = params
    @video = Video.find(id)
  end
  
  def create
    
  end
  
  def update
    @video = Video.find(params[:id])
  end
  
  def destroy
    @video = Video.find(params[:id])
  end


end