class V1::RollController < ApplicationController  
  
  ##
  # Returns one roll, with the given parameters.
  #
  # [GET] /rolls.[format]/:id
  # 
  # @param [Required, String] id The id of the user
  #
  # @todo return error if id not present w/ params.has_key?(:id)
  def show
    id = params.delete(:id)
    @params = params
    @roll = Roll.find(id)
  end
  
  ##
  # Creates and returns one roll, with the given parameters.
  # 
  # [POST] /rolls.[format]?[argument_name=argument_val]
  # 
  # @param [Required, String] id The id of the user
  #
  # @todo FIGURE THIS OUT. BUILD IT.
  def create
    
  end
  
  ##
  # Updates and returns one roll, with the given parameters.
  # 
  # [PUT] /rolls.[format]/:id?attr_name=attr_val
  # 
  # @param [Required, String] id The id of the roll
  #
  # @todo FIGURE THIS OUT. BUILD IT.
  def update
    @roll = Roll.find(params[:id])
  end
  
  ##
  # Destroys one roll, returning Success/Failure
  # 
  # [DELETE] /rolls.[format]/:id
  # 
  # @param [Required, String] id The id of the roll
  def destroy
    @roll = Roll.find(params[:id])
    @status = @roll.destroy ? "ok" : "error"
  end

end