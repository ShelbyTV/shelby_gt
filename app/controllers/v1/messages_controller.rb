class V1::MessagesController < ApplicationController  
  
  ##
  # Creates and returns one message, with the given parameters.
  #
  # [POST] /v1/conversation/:conversation_id/messages.json
  # @todo FIGURE THIS OUT. BUILD IT.
  def create
    
  end
    
  ##
  # Destroys one message, returning Success/Failure
  #
  # [GET] /v1/conversation/:conversation_id/messages/:id.json
  # 
  # @param [Required, String] id The id of the message to destroy.
  # @return [Integer] Whether request was successful or not.
  def destroy
    message = Message.find(params[:id])
    @status, @message = "error", "could not find that message to destroy" unless message
    if message.destroy 
      @status = "ok"
    else
      @status, @message = "error", "could not destroy that message"
    end
  end

end