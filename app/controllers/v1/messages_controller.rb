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
  # @return [Integer] Messages remaing + 200.
  def destroy
    message_id = params[:id]
    conversation = Conversation.find(params[:conversation_id])
    @status, @message = 500, "could not find that conversation" unless conversation
    if conversation.pull(:messages => {:_id => params[:id]})
      conversation.reload
      @messages = conversation.messages
      @status = 200
    else 
      @status, @message = 500, "could not destroy that message"
    end
  end

end