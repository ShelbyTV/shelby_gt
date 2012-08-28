class V1::UserMetalController < ActionController::Metal
  include AbstractController::Logger
  include AbstractController::Callbacks
  include AbstractController::Helpers
  include Devise::Controllers::Helpers
  before_filter :authenticate_user!

  ##
  # Returns the rolls the current_user is following
  #   REQUIRES AUTHENTICATION
  #
  # [GET] /v1/user/:id/rolls/following
  # [GET] /v1/user/:id/rolls/postable (returns the subset of rolls the user is following which they can also post to)
  # 
  # @param [Required, String] id The id of the user
  # @param [Optional, boolean] postable Set this to true (or use the second route) if you only want rolls postable by current user returned (used by bookmarklet)
  def roll_followings
    StatsManager::StatsD.time(Settings::StatsConstants.api['user']['rolls']) do
      if current_user.id.to_s != params[:id]
        self.status = 403
        self.content_type = "application/json"
        self.response_body = "{\"status\" : 403, \"message\" : \"you are not authorized to view that users rolls.""}"
        return
      end 

      fast_stdout = `cpp/bin/userRollFollowings -u #{current_user.downcase_nickname} #{params[:postable] ? "-p" : ""} -e #{Rails.env}`
      fast_status = $?.to_i

      if (fast_status == 0)
        self.status = 200
        self.content_type = "application/json"
        self.response_body = "#{fast_stdout}"
      else 
        self.status = 404
        self.content_type = "application/json"
        self.response_body = "{\"status\" : 404, \"message\" : \"fast roll_followings failed with status #{fast_status}\"}"
      end
    end
  end
  include ::NewRelic::Agent::Instrumentation::ControllerInstrumentation
  add_transaction_tracer :roll_followings
end
