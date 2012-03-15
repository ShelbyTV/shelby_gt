class V1::MessagesController < ApplicationController  
  before_filter :authenticate_user!
  
  ##
  # Creates and returns one message, with the given parameters.
  #   REQUIRES AUTHENTICATION
  #
  # [POST] /v1/conversation/:conversation_id/messages
  #
  # @param [Required, String] text the text for the message
  # @return [Integer] returns the entire conversation.
  def create
    if !params.include?(:text)
      @status, @message = 500, "text of message required"
      render 'v1/blank'
    else
      @conversation = Conversation.find(params[:conversation_id])
      if @conversation
        @new_message = Message.new
        @new_message.text = params[:text]
        @new_message.user = current_user
        @new_message.nickname = current_user.nickname
        @new_message.user_image_url = current_user.user_image
        
        @conversation.messages << @new_message
        begin        
          @status = 200 if @conversation.save!
        rescue => e
          @status, @message = 500, e
          render 'v1/blank'
        end
      else
        @status, @message = 500, "could not find that conversation"
        render 'v1/blank'
      end
    end
  end
    
  ##
  # Destroys one message, returning Success/Failure
  #   REQUIRES AUTHENTICATION
  #
  # [GET] /v1/conversation/:conversation_id/messages/:id
  # 
  # @param [Required, String] id the id of the message to destroy.
  # @return [Integer] messages remaining in conversation.
  def destroy
    message_id = params[:id]
    @conversation = Conversation.find(params[:conversation_id])
    message = @conversation.find_message_by_id(message_id)
    unless @conversation and message
      @status, @message = 500, "could not find that conversation"
      render 'v1/blank'
    else
      @conversation.pull(:messages => {:_id => message.id})
      @conversation.reload
      @status = 200
    end
  end

end