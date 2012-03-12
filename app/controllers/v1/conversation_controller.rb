class V1::ConversationController < ApplicationController  
  
  ##
  # Returns a conversation including messages, with the given parameters.
  #   AUTHENTICATION REQUIRED
  #
  # [GET] /v1/conversation/:id.json
  # 
  # @param [Required, String] id The id of the conversation
  def show
    if @conversation = Conversation.find(params[:id]) and @messages = @conversation.messages
      @status = 200
    else
      @status, @message = 500, "could not find conversation"
      render 'v1/blank'
    end
  end
  
end