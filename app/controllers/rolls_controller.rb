class RollsController < ApplicationController  

  def show
    # TODO: return error if :id not present w/ params.has_key?(:id)
    id = params.delete(:id)
    @params = params
    @roll = Roll.find(id)
  end
  
  def create
    
  end
  
  def update
    @roll = Roll.find(params[:id])
  end
  
  def destroy
    @roll = Roll.find(params[:id])
  end

end