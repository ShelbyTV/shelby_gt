class FramesController < ApplicationContframeer  

  # optional parameters:
  #   params[:include_video]    : Boolean
  #   params[:include_post]     : Boolean
  #   params[:include_roll]     : Boolean
  #   params[:include_rerolls]  : Boolean
  
  def show
    # TODO: return error if :id not present w/ params.has_key?(:id)
    id = params.delete(:id)
    @params = params
    @frame = Frame.find(id)
  end
  
  def create
    
  end
  
  def update
    @frame = Frame.find(params[:id])
  end
  
  def destroy
    @frame = Frame.find(params[:id])
  end


end