class V1::FrameMetalController < ActionController::Metal
  include AbstractController::Logger
  include AbstractController::Callbacks
  include AbstractController::Helpers
  include Devise::Controllers::Helpers

  ##
  # Returns frames in a roll
  #   AUTHENTICATION OPTIONAL
  #
  # [GET] /v1/roll/:id/frames
  # @param [Optional, Integer] limit limit the number of frames returned, default 20
  # @param [Optional, Integer] skip the number of frames to skip, default 0
  def index
    StatsManager::StatsD.time(Settings::StatsConstants.api['frame']['index']) do
      limit = params[:limit] ? params[:limit].to_i : 20
      skip = params[:skip] ? params[:skip] : 0
      limit = 500 if limit.to_i > 500

      if (current_user)
        fast_stdout = `cpp/bin/frameIndex -u #{current_user.id} -r #{params[:roll_id]} -l #{limit} -s #{skip} -e #{Rails.env}`
      else
        fast_stdout = `cpp/bin/frameIndex -r #{params[:roll_id]} -l #{limit} -s #{skip} -e #{Rails.env}`
      end
      fast_status = $?.to_i

      if (fast_status == 0)
        self.status = 200
        self.content_type = "application/json"
        self.response_body = "#{fast_stdout}"
      else 
        self.status = 404
        self.content_type = "application/json"
        self.response_body = "{\"status\" : 404, \"message\" : \"fast index failed with status #{fast_status}\"}"
      end
    end
  end
  include ::NewRelic::Agent::Instrumentation::ControllerInstrumentation
  add_transaction_tracer :index

  ##
  # Returns frames in a user's personal roll
  #   AUTHENTICATION OPTIONAL
  #
  # [GET] /v1/user/:id/personal/frames
  # @param [Required, String] id The id of the user
  # @param [Optional, Integer] limit limit the number of frames returned, default 20
  # @param [Optional, Integer] skip the number of frames to skip, default 0
  def index_for_users_public_roll
    StatsManager::StatsD.time(Settings::StatsConstants.api['frame']['index_for_users_public_roll']) do 
      # default params
      limit = params[:limit] ? params[:limit].to_i : 20
      # put an upper limit on the number of entries returned
      limit = 500 if limit.to_i > 500
          
      skip = params[:skip] ? params[:skip] : 0

      fast_stdout = `cpp/bin/frameIndex -u #{params[:user_id]} -l #{limit} -s #{skip} -e #{Rails.env}`
      fast_status = $?.to_i

      if (fast_status == 0)
        self.status = 200
        self.content_type = "application/json"
        self.response_body = "#{fast_stdout}"
      else 
        self.status = 404
        self.content_type = "application/json"
        self.response_body = "{\"status\" : 404, \"message\" : \"fast index failed with status #{fast_status}\"}"
      end
    end
  end
  include ::NewRelic::Agent::Instrumentation::ControllerInstrumentation
  add_transaction_tracer :index_for_users_public_roll

end
