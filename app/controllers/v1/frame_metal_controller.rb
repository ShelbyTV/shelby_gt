class V1::FrameMetalController < ActionController::Metal

  ##
  # Returns frames in a roll
  #   AUTHENTICATION OPTIONAL
  #
  # [GET] /v1/roll/:id/frames
  # @param [Optional, Integer] limit limit the number of frames returned, default 20
  # @param [Optional, Integer] skip the number of frames to skip, default 0
  def index
    StatsManager::StatsD.time(Settings::StatsConstants.api['frame']['index']) do
       limit = [params[:limit] ? params[:limit].to_i : 20, 500].min
       skip = params[:skip] ? params[:skip] : 0

       fast_stdout = `cpp/bin/frameIndex -r #{params[:roll_id]} -l #{@limit} -s #{skip} -e #{Rails.env}`
       fast_status = $?.to_i

       if (fast_status == 0)
         self.status = 200
         self.content_type = "text/plain"
         self.response_body = "#{fast_stdout}"
       else 
         self.status = 404
         self.content_type = "text/plain"
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
  # [GET] /v1/roll/:id/frames
  # @param [Required, ] user_id ID of the user
  # @param [Optional, Integer] limit limit the number of frames returned, default 20
  # @param [Optional, Integer] skip the number of frames to skip, default 0
  def index_for_users_public_roll
    StatsManager::StatsD.time(Settings::StatsConstants.api['frame']['index_for_users_public_roll']) do 
       # default params
       limit = params[:limit] ? params[:limit].to_i : 20
       # put an upper limit on the number of entries returned
       limit = 500 if limit.to_i > 500
           
       skip = params[:skip] ? params[:skip] : 0

       fast_stdout = `cpp/bin/frameIndex -p #{params[:user_id]} -l #{@limit} -s #{skip} -e #{Rails.env}`
       fast_status = $?.to_i

       if (fast_status == 0)
         self.status = 200
         self.content_type = "text/plain"
         self.response_body = "#{fast_stdout}"
       else 
         self.status = 404
         self.content_type = "text/plain"
         self.response_body = "{\"status\" : 404, \"message\" : \"fast index failed with status #{fast_status}\"}"
       end
    end
  end
  include ::NewRelic::Agent::Instrumentation::ControllerInstrumentation
  add_transaction_tracer :index_for_users_public_roll

end
