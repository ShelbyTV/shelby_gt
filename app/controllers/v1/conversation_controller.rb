class V1::ConversationController < ApplicationController  
  
  before_filter :user_authenticated?
  before_filter :set_current_user
  oauth_required
  
  ##
  # Returns a conversation including messages, with the given parameters.
  #   AUTHENTICATION REQUIRED
  #
  # [GET] /v1/conversation/:id
  # 
  # @param [Required, String] id The id of the conversation
  def show
    StatsManager::StatsD.time(Settings::StatsConstants.api['video']['show']) do
      if params[:id]
        return render_error(404, "please specify a valid id") unless (id = ensure_valid_bson_id(params[:id]))

        if @conversation = Conversation.find(id)
          @status = 200
        else
          render_error(404, "could not find conversation")
        end
      else
        render_error(404, "must supply an id")
      end
    end
  end

  protected
    def set_current_user
      @current_user = User.find(oauth.identity) if oauth.authenticated?
    end
  
end
