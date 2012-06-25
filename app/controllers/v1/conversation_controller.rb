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
 
  ##
  # Returns all conversations for a video
  #   AUTHENTICATION OPTIONAL
  #
  # [GET] /v1/video/:id/conversations
  # @param [Optional, Integer] limit limit the number of frames returned, default 50
  def index
    StatsManager::StatsD.time(Settings::StatsConstants.api['conversation']['index']) do
      # default params
      @limit = params[:limit] ? params[:limit] : 50
      # put an upper limit on the number of entries returned
      @limit = 50 if @limit.to_i > 50
      
      if @conversations = Conversation.sort(:id.desc).limit(@limit).where(
        :video_id => BSON::ObjectId(params[:video_id]), 
        :public => true, 
        :from_deeplink => {:$ne => true} )
        @status =  200
      else
        render_error(404, "could not find conversations for video with id #{params[:video_id]}")
      end
    end
  end
  
end
