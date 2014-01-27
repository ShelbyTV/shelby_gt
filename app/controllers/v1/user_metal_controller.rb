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
  #   NB!!: skip and limit parameters are not supported when retrieving the followings for the curently authenticated user
  #
  # [GET] /v1/user/:id/rolls/following
  # [GET] /v1/user/:id/rolls/postable (returns the subset of rolls the user is following which they can also post to)
  #
  # @param [Required, String] id The id of the user
  # @param [Optional, boolean] postable Set this to true (or use the second route) if you only want rolls postable by current user returned (used by bookmarklet)
  # @param [Optional, Integer] skip The number of non-special rolls to skip
  # @param [Optional, Integer] limit The number of non-special rolls to return
  def roll_followings
    StatsManager::StatsD.time(Settings::StatsConstants.api['user']['rolls']) do
      if current_user
        commandParams = "-u #{params[:id]}"
        commandParams += " -p" if params[:postable]
        commandParams += " -s #{params[:skip]}" if params[:skip]
        commandParams += " -l #{params[:limit]}" if params[:limit]
        commandParams += " -i" if params[:include_faux]
        commandParams += " --include-special" if current_user.id.to_s == params[:id]
        commandParams += " -e #{Rails.env}"
        fast_stdout = `cpp/bin/userRollFollowings #{commandParams}`
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
