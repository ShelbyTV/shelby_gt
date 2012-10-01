class V1::ConversationMetalController < MetalController
  include AbstractController::Logger
  include AbstractController::Callbacks
  include AbstractController::Helpers

  ##
  # Returns conversations for a particular video
  #   AUTHENTICATION OPTIONAL
  #
  # [GET] /v1/video/:id/conversations
  # @param [Optional, Integer] limit limit the number of frames returned, default 20
  def index
    StatsManager::StatsD.time(Settings::StatsConstants.api['frame']['index']) do
      limit = params[:limit] ? params[:limit].to_i : 50
      limit = 50 if limit.to_i > 50

      fast_stdout = `cpp/bin/conversationIndex -v #{params[:video_id]} -l #{limit} -e #{Rails.env}`
      fast_status = $?.to_i

      if (fast_status == 0)
        renderMetalResponse(200, fast_stdout)
      else 
        renderMetalResponse(404, "{\"status\" : 404, \"message\" : \"fast index failed with status #{fast_status}\"}")
      end
    end
  end
  include ::NewRelic::Agent::Instrumentation::ControllerInstrumentation
  add_transaction_tracer :index

end
