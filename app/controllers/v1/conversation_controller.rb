class V1::ConversationController < ApplicationController  

  ##
  # Returns a conversation, with the given parameters.
  #
  # [GET] /v1/conversation/:id.json
  # 
  # @param [Required, String] id The id of the conversation
  # @todo return error if id not present w/ params.has_key?(:id)
  def show
    id = params.delete(:id)
    if @conversation = Conversation.find(id)
      @messages = @conversation.messages
      @status = "ok"
    else
      @status, @message = "error", "could not find user"
    end
  end
  
end