require 'message_manager'

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
    StatsManager::StatsD.time(Settings::StatsConstants.api['messages']['create']) do
      if !params.include?(:text)
        render_error(400, "text of message required")
      else
        @conversation = Conversation.find(params[:conversation_id])
        if @conversation
          msg_opts = {:user => current_user, :public => true, :text => params[:text]}
          @new_message = GT::MessageManager.build_message(msg_opts)
          @conversation.messages << @new_message
          begin
            if @conversation.save!

              # send email notification in a non-blocking manor
              EM.next_tick do 
                GT::NotificationManager.check_and_send_comment_notification(current_user, @conversation, @new_message)
              end

              @status = 200 
              StatsManager::StatsD.increment(Settings::StatsConstants.message['create'], nil, nil, request)
            end
          rescue => e
            render_error(404, e)
          end
        else
          render_error(404, "could not find that conversation")
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
  # @param [Required, String] id the id of the message to destroy.
  # @return [Integer] messages remaining in conversation.
  def destroy
    StatsManager::StatsD.time(Settings::StatsConstants.api['messages']['destroy']) do
      message_id = params[:id]
      @conversation = Conversation.find(params[:conversation_id])
      message = @conversation.find_message_by_id(message_id)
      unless @conversation and message
        render_error(404, "could not find that conversation")
      else
        @conversation.pull(:messages => {:_id => message.id})
        @conversation.reload
        StatsManager::StatsD.increment(Settings::StatsConstants.message['delete'], nil, nil, request)
        @status = 200
      end
    end
  end

end