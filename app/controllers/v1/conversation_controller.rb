class V1::ConversationController < ApplicationController  

  ##
  # Returns a conversation, with the given parameters.
  #
  # [GET] /v1/conversation/:id.json
  # 
  # @param [Required, String] id The id of the conversation
  def show
    if @conversation = Conversation.find(params[:id])
      @messages = @conversation.messages
      @status = 200
    else
      @status, @message = 500, "could not find user"
    end
  end
  
end