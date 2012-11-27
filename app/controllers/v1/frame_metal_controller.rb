require 'discussion_roll_utils'

class V1::FrameMetalController < MetalController
  include AbstractController::Logger
  include AbstractController::Callbacks
  include AbstractController::Helpers
  include Devise::Controllers::Helpers
  include GT::DiscussionRollUtils

  ##
  # Returns frames in a roll
  #   AUTHENTICATION OPTIONAL
  #
  # [GET] /v1/roll/:roll_id/frames
  # @param [Optional, Integer] limit limit the number of frames returned, default 20
  # @param [Optional, Integer] skip the number of frames to skip, default 0
  # @param [Optional, String]  since_id the id of the frame to start from (inclusive)
  # @param [Optional, String]  token The access token granting view permission of a private discussion Roll
  def index
    StatsManager::StatsD.time(Settings::StatsConstants.api['frame']['index']) do
      limit = params[:limit] ? params[:limit].to_i : 20
      skip = params[:skip] ? params[:skip] : 0
      limit = 500 if limit.to_i > 500
      sinceId = params[:since_id]

      if params[:token] and token_valid_for_discussion_roll?(params[:token], params[:roll_id])
        if (sinceId) 
          fast_stdout = `cpp/bin/frameIndex --permissionGranted -r #{params[:roll_id]} -l #{limit} -s #{skip} -i #{sinceId} -e #{Rails.env}`
        else
          fast_stdout = `cpp/bin/frameIndex --permissionGranted -r #{params[:roll_id]} -l #{limit} -s #{skip} -e #{Rails.env}`
        end
      elsif (current_user)
        if (sinceId) 
          fast_stdout = `cpp/bin/frameIndex -u #{current_user.id} -r #{params[:roll_id]} -l #{limit} -s #{skip} -i #{sinceId} -e #{Rails.env}`
        else
          fast_stdout = `cpp/bin/frameIndex -u #{current_user.id} -r #{params[:roll_id]} -l #{limit} -s #{skip} -e #{Rails.env}`
        end
      else
        if (sinceId) 
          fast_stdout = `cpp/bin/frameIndex -r #{params[:roll_id]} -l #{limit} -s #{skip} -i #{sinceId} -e #{Rails.env}`
        else
          fast_stdout = `cpp/bin/frameIndex -r #{params[:roll_id]} -l #{limit} -s #{skip} -e #{Rails.env}`
        end
      end
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

  ##
  # Returns frames in a user's personal roll
  #   AUTHENTICATION OPTIONAL
  #
  # [GET] /v1/user/:id/personal/frames
  # @param [Required, String] id The id of the user
  # @param [Optional, Integer] limit limit the number of frames returned, default 20
  # @param [Optional, Integer] skip the number of frames to skip, default 0
  # @param [Optional, String]  since_id the id of the frame to start from (inclusive)
  def index_for_users_public_roll
    StatsManager::StatsD.time(Settings::StatsConstants.api['frame']['index_for_users_public_roll']) do 
      # default params
      limit = params[:limit] ? params[:limit].to_i : 20
      # put an upper limit on the number of entries returned
      limit = 500 if limit.to_i > 500
          
      skip = params[:skip] ? params[:skip] : 0
      sinceId = params[:since_id]

      if (sinceId) 
        fast_stdout = `cpp/bin/frameIndex -u #{params[:user_id]} -l #{limit} -s #{skip} -i #{sinceId} -e #{Rails.env}`
      else
        fast_stdout = `cpp/bin/frameIndex -u #{params[:user_id]} -l #{limit} -s #{skip} -e #{Rails.env}`
      end
      fast_status = $?.to_i

      if (fast_status == 0)
        renderMetalResponse(200, fast_stdout)
      else 
        renderMetalResponse(404, "{\"status\" : 404, \"message\" : \"fast index failed with status #{fast_status}\"}")
      end
    end
  end
  include ::NewRelic::Agent::Instrumentation::ControllerInstrumentation
  add_transaction_tracer :index_for_users_public_roll

end
