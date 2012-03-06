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
  # [POST] /v1/conversation/:conversation_id/messages.json
  #
  # @param [Required, String] text The text for the message
  def create
    if ( !params.include?(:text) or !user_signed_in?)
      @status = 500
      @message = "text of message required" unless params.include?(:text)
      @message = "not authenticated, could not access user" unless user_signed_in?
    else
      conversation = Conversation.find(params[:conversation_id])
      if !conversation
        @status, @message = 500, "could not find that conversation"
      else
        @new_message = Message.new(:text => params[:title])
        @new_message.user = current_user
        @new_message.nickname = current_user.nickname
        @new_message.user_image_url = current_user.user_image
        conversation.messages << @new_message
        begin        
          @status = 200 if conversation.save!
        rescue => e
          @status, @message = 500, e
        end
      end
    end
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