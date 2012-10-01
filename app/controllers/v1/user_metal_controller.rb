class V1::UserMetalController < MetalController
  include AbstractController::Logger
  include AbstractController::Callbacks
  include AbstractController::Helpers
  include Devise::Controllers::Helpers
  before_filter :user_authenticated?

  # === Unlike the default user_authenticated! helper that ships with devise,
  #  We want to render our json response as well as just the http 401 response
  #  Duplicates the code in ApplicationController, but we need the metal version...
  def user_authenticated?
    warden.authenticate(:oauth) unless user_signed_in?
    unless user_signed_in?
      renderMetalResponse(401, "{\"status\" : 401, \"message\" : \"you must be authenticated\"}")
    end
  end

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
      if current_user and current_user.id.to_s == params[:id]
        fast_stdout = `cpp/bin/userRollFollowings -u #{current_user.downcase_nickname} #{params[:postable] ? "-p" : ""} -e #{Rails.env}`
        fast_status = $?.to_i

        if (fast_status == 0)
          renderMetalResponse(200, fast_stdout)
        else 
          renderMetalResponse(404, "{\"status\" : 404, \"message\" : \"fast roll_followings failed with status #{fast_status}\"}")
        end
      else  
        renderMetalResponse(403, "{\"status\" : 403, \"message\" : \"you are not authorized to view that users rolls.\"}")
      end
    end
  end
  include ::NewRelic::Agent::Instrumentation::ControllerInstrumentation
  add_transaction_tracer :roll_followings
end
