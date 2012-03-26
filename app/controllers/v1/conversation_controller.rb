class V1::ConversationController < ApplicationController  
  
  before_filter :cors_preflight_check, :user_authenticated?
  
  ##
  # Returns a conversation including messages, with the given parameters.
  #   AUTHENTICATION REQUIRED
  #
  # [GET] /v1/conversation/:id
  # 
  # @param [Required, String] id The id of the conversation
  def show
    StatsManager::StatsD.client.time(Settings::StatsNames.video['show']) do
      if @conversation = Conversation.find(params[:id])
        @status = 200
      else
        @status, @message = 400, "could not find conversation"
        render 'v1/blank', :status => @status
      end
    end
  end
  
end