class V1::RollController < ApplicationController  
  
  ##
  # Returns one roll, with the given parameters.
  #
  # [GET] /v1/roll/:id.json
  # 
  # @param [Required, String] id The id of the user
  #
  # @todo return error if id not present w/ params.has_key?(:id)
  def show
    id = params.delete(:id)
    @params = params
    if @roll = Roll.find(id)
      @status =  "ok"
    else
      @status, @message = "error", "could not find that roll"
    end
  end
  
  ##
  # Creates and returns one roll, with the given parameters.
  # 
  # [POST] /v1/roll.json
  # 
  # @param [Required, String] id The id of the user
  #
  # @todo FIGURE THIS OUT. BUILD IT.
  def create
    
  end
  
  ##
  # Updates and returns one roll, with the given parameters.
  # 
  # [PUT] /v1/roll/:id.json
  # 
  # @param [Required, String] id The id of the roll
  #
  # @todo FIGURE THIS OUT. BUILD IT.
  def update
    id = params.delete(:id)
    @roll = Roll.find(id)
    @status, @message = "error", "could not find roll" unless @roll
    if @roll.update_attributes(params)
      @status = "ok"
    else
      @status, @message = "error", "could not update roll"
    end
  end
  
  ##
  # Destroys one roll, returning Success/Failure
  # 
  # [DELETE] /v1/roll/:id.json
  # 
  # @param [Required, String] id The id of the roll
  def destroy
    roll = Roll.find(params[:id])
    @status, @message = "error", "could not find that roll to destroy" unless roll
    if roll.destroy
      @status =  "ok"
    else
      @status, @message = "error", "could not destroy that roll"
    end
  end

end