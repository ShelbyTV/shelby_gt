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
  #
  # @param [Required, String] id The id of the user
  # @param [Optional, Integer] skip The number of non-special rolls to skip
  # @param [Optional, Integer] limit The number of non-special rolls to return
  def roll_followings
    StatsManager::StatsD.time(Settings::StatsConstants.api['user']['rolls']) do
      if current_user
        commandParams = "-u #{params[:id]}"
        commandParams += " -s #{params[:skip]}" if params[:skip]
        commandParams += " -l #{params[:limit]}" if params[:limit]
        commandParams += " -i" if params[:include_faux]
        commandParams += " --include-special" if current_user.id.to_s == params[:id]
        commandParams += " -e #{Rails.env}"

        cmd = "cpp/bin/userRollFollowings #{commandParams}"

        fast_status = 0
        fast_stdout = ''
        log_text = ''
        Open3.popen3 cmd do |stdin, stdout, stderr, wait_thr|
          fast_stdout = stdout.read
          log_text = stderr.read
          fast_status = wait_thr.value.exitstatus
        end

        ShelbyGT_EM.next_tick {
          # Append logging from the c executable to our log file, but don't
          # make responding to the request wait on that
          File.open("#{Settings::CExtensions.log_file}_#{Rails.env}.log","a") do |f|
            f.puts "[#{Time.now.strftime("%m-%d-%Y %T")}] -------RUBY SAYS: HANDLE v1/user/#{params[:id]}/rolls/following START-------"
            f.puts log_text
            f.puts "[#{Time.now.strftime("%m-%d-%Y %T")}] STATUS: #{fast_status == 0 ? 'SUCCESS' : 'ERROR'}"
            if fast_status != 0
              f.puts "[#{Time.now.strftime("%m-%d-%Y %T")}] -------------------C OUTPUT FOR DEBUGGING START-----------------------------"
              f.puts fast_stdout
              f.puts "[#{Time.now.strftime("%m-%d-%Y %T")}] -------------------C OUTPUT FOR DEBUGGING END-------------------------------"
            end
            f.puts "[#{Time.now.strftime("%m-%d-%Y %T")}] --------RUBY SAYS: HANDLE v1/user/#{params[:id]}/rolls/following END--------"
          end
        }

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
