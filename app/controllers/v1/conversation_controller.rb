class V1::ConversationController < ApplicationController  

  ##
  # Returns a conversation, with the given parameters.
  #
  # [GET] /conversation.[format]/:id
  # 
  # @param [Required, String] id The id of the conversation
  # @todo return error if id not present w/ params.has_key?(:id)
  def show
    id = params.delete(:id)
    @params = params
    @conversation = Conversation.find(id)
    @messages = @conversation.messages
  end
  
  ##
  # Creates and returns one conversation, with the given parameters.
  #
  # [POST] /conversation.[format]?[argument_name=argument_val]
  # @todo FIGURE THIS OUT. BUILD IT.
  def create
    
  end
  
  ##
  # Updates and returns one conversation, with the given parameters.
  #
  # [PUT] /conversation.[format]/:id?attr_name=attr_val
  # 
  # @param [Required, String] id The id of the conversation
  # @param [Required, String] attr The attribute(s) to update
  #
  # @todo FIGURE THIS OUT. BUILD IT.
  def update
    @conversation = Conversation.find(params[:id])
  end
  
  ##
  # Destroys one conversation, returning Success/Failure
  #
  # [GET] /conversation.[format]/:id
  # 
  # @param [Required, String] id The id of the conversation to destroy.
  # @return [Integer] Whether request was successful or not.
  def destroy
    @conversation = Conversation.find(params[:id])
    @status = @conversation.destroy ? "ok" : "error"
  end

end