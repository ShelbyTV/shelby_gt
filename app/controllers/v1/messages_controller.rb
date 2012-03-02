class V1::MessagesController < ApplicationController  

  ##
  # Returns a message, with the given parameters.
  #
  # [GET] /message.[format]/:id
  # 
  # @param [Required, String] id The id of the message
  # @todo return error if id not present w/ params.has_key?(:id)
  def show
    id = params.delete(:id)
    @params = params
    @message = message.find(id)
  end
  
  ##
  # Creates and returns one message, with the given parameters.
  #
  # [POST] /message.[format]?[argument_name=argument_val]
  # @todo FIGURE THIS OUT. BUILD IT.
  def create
    
  end
  
  ##
  # Updates and returns one message, with the given parameters.
  #
  # [PUT] /message.[format]/:id?attr_name=attr_val
  # 
  # @param [Required, String] id The id of the message
  # @param [Required, String] attr The attribute(s) to update
  #
  # @todo FIGURE THIS OUT. BUILD IT.
  def update
    @message = message.find(params[:id])
  end
  
  ##
  # Destroys one message, returning Success/Failure
  #
  # [GET] /message.[format]/:id
  # 
  # @param [Required, String] id The id of the message to destroy.
  # @return [Integer] Whether request was successful or not.
  def destroy
    @message = message.find(params[:id])
    @status = @message.destroy ? "ok" : "error"
  end

end