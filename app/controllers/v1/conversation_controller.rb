class V1::ConversationController < ApplicationController  
  
  before_filter :user_authenticated?, :except => [:index]
  
  ##
  # Returns a conversation including messages, with the given parameters.
  #   AUTHENTICATION REQUIRED
  #
  # [GET] /v1/conversation/:id
  # 
  # @param [Required, String] id The id of the conversation
  def show
    StatsManager::StatsD.time(Settings::StatsConstants.api['conversation']['show']) do
      if @conversation = Conversation.find(params[:id])
        @status = 200
      else
        render_error(404, "could not find conversation for id #{params[:id]}")
      end
    end
  end
 
end
