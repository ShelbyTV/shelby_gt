class V1::MessagesController < ApplicationController  
  before_filter :authenticate_user!
  
  ##
  # Creates and returns one message, with the given parameters.
  #   REQUIRES AUTHENTICATION
  #
  # [POST] /v1/conversation/:conversation_id/messages
  #
  # @param [Required, String] text The text for the message
  def create
    if !params.include?(:text)
      @status, @message = 500, "text of message required"
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
  #   REQUIRES AUTHENTICATION
  #
  # [GET] /v1/conversation/:conversation_id/messages/:id
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