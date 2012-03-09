class V1::ConversationController < ApplicationController  
  
  before_filter :authenticate_user!
  
  ##
  # Returns a conversation, with the given parameters.
  #   AUTHENTICATION REQUIRED
  #
  # [GET] /v1/conversation/:id.json
  # 
  # @param [Required, String] id The id of the conversation
  def show
    if @conversation = Conversation.find(params[:id])
      @messages = @conversation.messages
      @status = 200
    else
      @status, @message = 500, "could not find conversation"
    end
  end
  
end