class V1::ConversationController < ApplicationController  
  
  before_filter :user_authenticated?
  
  ##
  # Returns a conversation including messages, with the given parameters.
  #   AUTHENTICATION REQUIRED
  #
  # [GET] /v1/conversation/:id
  # 
  # @param [Required, String] id The id of the conversation
  def show
    StatsManager::StatsD.client.time(Settings::StatsNames.api['video']['show']) do
      if @conversation = Conversation.find(params[:id])
        @status = 200
      else
        render_error(404, "could not find conversation")
      end
    end
  end
  
end